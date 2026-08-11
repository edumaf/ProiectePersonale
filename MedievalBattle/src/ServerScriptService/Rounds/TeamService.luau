--!strict
--[[
	TeamService

	Owns team membership and keeps the two sides within
	RoundConfig.MaxTeamSizeDifference of each other.

	Two representations, on purpose:
	  * Real Roblox Team instances, so the player list, name colours and
	    chat all work for free.
	  * A "TeamId" attribute mirrored onto the Player *and* the character model.
	    Hit resolution runs off the character attribute: going from a hit part
	    to `model:GetAttribute("TeamId")` is a couple of pointer hops, whereas
	    Players:GetPlayerFromCharacter is a lookup we would otherwise do
	    thousands of times per second in a 50v50 fight.

	Rebalancing only ever happens at a respawn. Teleporting someone to the other
	team mid-swing is the kind of thing players quit over.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local RoundConfig = require(ReplicatedStorage.Modules.RoundConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)

local TeamService = {}

local teamById: { [number]: Team } = {}
local changedCallbacks: { (player: Player, teamId: number) -> () } = {}

local ORDER = { Enums.TeamId.Attackers, Enums.TeamId.Defenders }

function TeamService.init()
	for _, teamId in ORDER do
		local team = Instance.new("Team")
		team.Name = MapConfig.TeamNames[teamId]
		team.TeamColor = BrickColor.new(MapConfig.TeamColors[teamId])
		team.AutoAssignable = false -- we assign, not Roblox
		team:SetAttribute("TeamId", teamId)
		team.Parent = Teams
		teamById[teamId] = team
	end
end

function TeamService.getTeamInstance(teamId: number): Team?
	return teamById[teamId]
end

function TeamService.getTeamId(player: Player): number?
	local value = player:GetAttribute("TeamId")
	return if typeof(value) == "number" then value else nil
end

function TeamService.getCounts(): { [number]: number }
	local counts = { [Enums.TeamId.Attackers] = 0, [Enums.TeamId.Defenders] = 0 }
	for _, player in Players:GetPlayers() do
		local teamId = TeamService.getTeamId(player)
		if teamId then
			counts[teamId] = (counts[teamId] or 0) + 1
		end
	end
	return counts
end

function TeamService.getPlayers(teamId: number): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if TeamService.getTeamId(player) == teamId then
			table.insert(list, player)
		end
	end
	return list
end

--[[
	The team a new (or rebalancing) player should join: whichever is smaller,
	with attackers winning ties so the pushing side is never short-handed.
]]
function TeamService.getSmallestTeam(excluding: Player?): number
	local counts = { [Enums.TeamId.Attackers] = 0, [Enums.TeamId.Defenders] = 0 }
	for _, player in Players:GetPlayers() do
		if player ~= excluding then
			local teamId = TeamService.getTeamId(player)
			if teamId then
				counts[teamId] += 1
			end
		end
	end

	if counts[Enums.TeamId.Attackers] <= counts[Enums.TeamId.Defenders] then
		return Enums.TeamId.Attackers
	end
	return Enums.TeamId.Defenders
end

function TeamService.setTeam(player: Player, teamId: number)
	local team = teamById[teamId]
	if not team then
		warn(`TeamService: unknown team id {teamId}`)
		return
	end

	player.Neutral = false
	player.Team = team
	player:SetAttribute("TeamId", teamId)

	local character = player.Character
	if character then
		character:SetAttribute("TeamId", teamId)
	end

	Remotes.get("TeamUpdate"):FireClient(player, teamId)

	for _, callback in changedCallbacks do
		task.spawn(callback, player, teamId)
	end
end

function TeamService.assign(player: Player): number
	local teamId = TeamService.getSmallestTeam(player)
	TeamService.setTeam(player, teamId)
	return teamId
end

--[[
	Called at respawn time. Moves the player only if their team is genuinely
	over-full, so casual joins/leaves do not shuffle people every death.
]]
function TeamService.rebalanceOnRespawn(player: Player): number
	local current = TeamService.getTeamId(player)
	if not current then
		return TeamService.assign(player)
	end
	if not RoundConfig.BalanceOnDeath then
		return current
	end

	local counts = TeamService.getCounts()
	local other = if current == Enums.TeamId.Attackers then Enums.TeamId.Defenders else Enums.TeamId.Attackers
	local difference = counts[current] - counts[other]

	if difference > RoundConfig.MaxTeamSizeDifference then
		TeamService.setTeam(player, other)
		Remotes.get("Notify"):FireClient(player, `Moved to {MapConfig.TeamNames[other]} to balance the teams`, 4)
		return other
	end

	return current
end

--[[
	Stamps the team onto the character model. Called by SpawnService the moment
	a character exists, before it is placed in the world, so no hit can ever
	resolve against a character with no team.
]]
function TeamService.tagCharacter(player: Player, character: Model)
	local teamId = TeamService.getTeamId(player)
	if teamId then
		character:SetAttribute("TeamId", teamId)
	end
end

--[[
	The hot path. Both arguments are character models; reads two attributes and
	compares them. Returns false when either side is untagged (a character
	mid-spawn cannot be hit).
]]
function TeamService.areEnemies(a: Model, b: Model): boolean
	local teamA = a:GetAttribute("TeamId")
	local teamB = b:GetAttribute("TeamId")
	if typeof(teamA) ~= "number" or typeof(teamB) ~= "number" then
		return false
	end
	return teamA ~= teamB
end

function TeamService.onTeamChanged(callback: (player: Player, teamId: number) -> ())
	table.insert(changedCallbacks, callback)
end

return TeamService
