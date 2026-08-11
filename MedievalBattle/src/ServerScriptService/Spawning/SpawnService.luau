--!strict
--[[
	SpawnService

	Owns the whole spawn pipeline, in a fixed order that the rest of the game
	depends on:

	    1. team assigned / rebalanced      (so the character can be tagged)
	    2. LoadCharacter
	    3. character tagged with TeamId    (hit resolution reads this)
	    4. loadout applied                 (health, weapon, livery)
	    5. combat state bound              (fresh stamina, Idle phase)
	    6. placed in the correct spawn zone + given spawn protection

	Step 3 before step 6 matters: a character standing in the world with no team
	attribute is unhittable, and one placed before it is tagged could be hit by
	a swing that is already tracing.

	Forward spawns: each team's zones are gated behind objective progress
	(MapConfig.SpawnZones.RequiresCaptures) and we always pick the
	furthest-unlocked one. That keeps the walk to the front short as the line
	moves, which is what stops a push mode from turning into a jogging
	simulator.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local Types = require(ReplicatedStorage.Modules.Types)

local ClassService = require(script.Parent.Parent.Classes.ClassService)
local CombatService = require(script.Parent.Parent.Combat.CombatService)
local TeamService = require(script.Parent.Parent.Rounds.TeamService)
local CollisionGroups = require(script.Parent.CollisionGroups)

type SpawnZoneDef = Types.SpawnZoneDef

local SpawnService = {}

local respawnEnabled = true
local pendingRespawn: { [Player]: thread } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

-- Injected by ObjectiveService once it exists. Defaults to "no progress", which
-- is exactly right before the objective system is wired up.
local captureCountProvider: () -> number = function()
	return 0
end

function SpawnService.setCaptureCountProvider(provider: () -> number)
	captureCountProvider = provider
end

function SpawnService.setRespawnEnabled(enabled: boolean)
	respawnEnabled = enabled
end

--[[
	The furthest-forward zone this team has unlocked. Ties break toward the last
	one listed in MapConfig, so ordering the table front-to-back is optional.
]]
local function pickZone(teamId: number): SpawnZoneDef?
	local captures = captureCountProvider()
	local best: SpawnZoneDef? = nil
	local bestRequirement = -1

	for _, zone in MapConfig.SpawnZones do
		if zone.Team ~= teamId then
			continue
		end
		local requirement = zone.RequiresCaptures or 0
		if requirement <= captures and requirement >= bestRequirement then
			best = zone
			bestRequirement = requirement
		end
	end

	return best
end

--[[
	A random point inside the zone, facing the enemy. Random placement matters
	with 50 people spawning together: a fixed point means everyone spawns inside
	everyone else and the physics solver has to push them apart.
]]
function SpawnService.getSpawnCFrame(teamId: number): CFrame
	local zone = pickZone(teamId)
	if not zone then
		return CFrame.new(0, 8, 0)
	end

	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * zone.Radius
	local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local position = zone.Position + offset + Vector3.new(0, 4, 0)

	-- Attackers look up the map (+X), defenders look back down it.
	local facing = if teamId == Enums.TeamId.Attackers then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
	return CFrame.lookAt(position, position + facing)
end

local function onCharacterAdded(player: Player, character: Model)
	-- The rig is normally complete by the time CharacterAdded fires, but a
	-- missing root here would silently break the weapon weld and the spawn
	-- placement, so it is worth one defensive wait.
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", 5)
	end

	-- 3. tag before anything can interact with it
	TeamService.tagCharacter(player, character)
	character:SetAttribute("InvulnerableUntil", os.clock() + CombatConfig.SpawnProtection)

	-- 4/5. loadout, then combat state
	ClassService.applyLoadout(player, character)
	CombatService.bindCharacter(player, character)
	CollisionGroups.applyToCharacter(character)

	-- 6. place it
	local teamId = TeamService.getTeamId(player) or Enums.TeamId.Attackers
	character:PivotTo(SpawnService.getSpawnCFrame(teamId))

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local connection
	connection = humanoid.Died:Connect(function()
		if connection then
			connection:Disconnect()
		end
		CombatService.unbindCharacter(player)
		SpawnService.scheduleRespawn(player, CombatConfig.RespawnDelay)
	end)

	local list = connections[player]
	if list then
		table.insert(list, connection)
	end
end

function SpawnService.spawnPlayer(player: Player)
	local existing = pendingRespawn[player]
	if existing then
		task.cancel(existing)
		pendingRespawn[player] = nil
	end

	TeamService.rebalanceOnRespawn(player)
	player:LoadCharacter()
end

function SpawnService.scheduleRespawn(player: Player, delay: number)
	if pendingRespawn[player] then
		return
	end

	pendingRespawn[player] = task.delay(delay, function()
		pendingRespawn[player] = nil
		if not respawnEnabled then
			return
		end
		if player.Parent ~= Players then
			return -- left while dead
		end
		SpawnService.spawnPlayer(player)
	end)
end

--[[
	Round transitions: wipe everyone and put them back at the starting zones.
]]
function SpawnService.respawnAll()
	for _, player in Players:GetPlayers() do
		SpawnService.spawnPlayer(player)
	end
end

local function onPlayerAdded(player: Player)
	connections[player] = {}

	local characterConnection = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	table.insert(connections[player], characterConnection)

	TeamService.assign(player)

	if respawnEnabled then
		SpawnService.spawnPlayer(player)
	end
end

local function onPlayerRemoving(player: Player)
	local pending = pendingRespawn[player]
	if pending then
		task.cancel(pending)
		pendingRespawn[player] = nil
	end

	local list = connections[player]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
		connections[player] = nil
	end
end

function SpawnService.init()
	-- We control every spawn ourselves; Roblox's automatic one would place
	-- characters before they have a team or a loadout.
	Players.CharacterAutoLoads = false

	ClassService.setRespawnHandler(function(player: Player)
		SpawnService.spawnPlayer(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return SpawnService
