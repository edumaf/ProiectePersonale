--!strict
--[[
	RoundService

	The round state machine, written as a plain loop rather than a web of
	callbacks - reading top to bottom tells you exactly what a round does:

	    Waiting   -> not enough players, nothing is live
	    Starting  -> everyone respawned at the start zones, combat disabled,
	                 countdown on screen
	    InProgress-> combat live, objectives ticking, clock running
	    Ended     -> combat disabled, result on screen, then round over

	Attackers win by taking every point before the clock runs out; every capture
	buys them extra time. Defenders win by running the clock out.

	Timestamps sent to clients use Workspace:GetServerTimeNow(), which is
	synchronised across server and clients - the client can render a smooth
	countdown from a single number instead of us pushing a "seconds remaining"
	message every second to 100 people.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Enums = require(ReplicatedStorage.Modules.Enums)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local RoundConfig = require(ReplicatedStorage.Modules.RoundConfig)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local DamageService = require(script.Parent.Parent.Combat.DamageService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local SpawnService = require(script.Parent.Parent.Spawning.SpawnService)
local TeamService = require(script.Parent.TeamService)

local RoundService = {}

local state = Enums.RoundState.Waiting
local endsAt = 0
local scores = { [Enums.TeamId.Attackers] = 0, [Enums.TeamId.Defenders] = 0 }
local headline = "Waiting for players"

local function broadcast()
	Remotes.get("RoundUpdate"):FireAllClients(state, endsAt, scores, headline)
end

local function setState(newState: number, duration: number?, message: string)
	state = newState
	endsAt = if duration then Workspace:GetServerTimeNow() + duration else 0
	headline = message
	broadcast()
end

function RoundService.getState(): number
	return state
end

local function addScore(teamId: number?, amount: number)
	if not teamId or not scores[teamId] then
		return
	end
	scores[teamId] += amount
	broadcast()
end

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= RoundConfig.MinPlayersToStart
end

--[[
	Blocks until there are enough players. Polls once a second - a round that
	starts a second late is invisible, and this keeps the loop trivially simple.
]]
local function waitForPlayers()
	if enoughPlayers() then
		return
	end

	setState(Enums.RoundState.Waiting, nil, "Waiting for players")
	ObjectiveService.setRunning(false)
	CombatService.setCombatEnabled(true) -- free play while we wait

	while not enoughPlayers() do
		task.wait(1)
	end
end

local function startCountdown()
	scores[Enums.TeamId.Attackers] = 0
	scores[Enums.TeamId.Defenders] = 0

	ObjectiveService.setRunning(false)
	ObjectiveService.reset()

	-- Combat off *before* the respawn, so nobody can swing at a player who is
	-- still materialising at a spawn point.
	CombatService.setCombatEnabled(false)
	SpawnService.setRespawnEnabled(true)
	SpawnService.respawnAll()

	setState(Enums.RoundState.Starting, RoundConfig.CountdownSeconds, "Form up!")
	task.wait(RoundConfig.CountdownSeconds)
end

local function runRound(): number
	CombatService.setCombatEnabled(true)
	ObjectiveService.setRunning(true)

	local attackerName = MapConfig.TeamNames[Enums.TeamId.Attackers]
	setState(Enums.RoundState.InProgress, RoundConfig.RoundSeconds, `{attackerName} advance!`)

	while true do
		if ObjectiveService.allCaptured() then
			return Enums.TeamId.Attackers
		end
		if Workspace:GetServerTimeNow() >= endsAt then
			return Enums.TeamId.Defenders
		end
		if not enoughPlayers() then
			-- Everyone left mid-round. Bail out rather than running an empty
			-- clock down for ten minutes.
			return Enums.TeamId.Defenders
		end
		task.wait(0.5)
	end
end

local function endRound(winner: number)
	ObjectiveService.setRunning(false)
	CombatService.setCombatEnabled(false)

	local winnerName = MapConfig.TeamNames[winner]
	local detail = if winner == Enums.TeamId.Attackers
		then "every point taken"
		else `held {ObjectiveService.getPointCount() - ObjectiveService.getCaptureCount()} of {ObjectiveService.getPointCount()} points`

	setState(Enums.RoundState.Ended, RoundConfig.IntermissionSeconds, `{winnerName} win - {detail}`)
	task.wait(RoundConfig.IntermissionSeconds)
end

function RoundService.init()
	-- Kills feed the team score. Registering here rather than inside
	-- DamageService keeps scoring a round concern, not a damage concern.
	DamageService.onKill(function(killer: Player?, _victim: Player)
		if killer then
			addScore(TeamService.getTeamId(killer), RoundConfig.ScorePerKill)
		end
	end)

	ObjectiveService.onCaptured(function()
		addScore(Enums.TeamId.Attackers, RoundConfig.ScorePerCapture)
		-- Every capture buys the attackers more time, which is what makes a
		-- push mode tense instead of a single unwinnable timer.
		endsAt += RoundConfig.CaptureTimeBonus
		broadcast()
	end)

	-- Forward spawns follow objective progress.
	SpawnService.setCaptureCountProvider(ObjectiveService.getCaptureCount)

	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		if player.Parent == Players then
			Remotes.get("RoundUpdate"):FireClient(player, state, endsAt, scores, headline)
		end
	end)

	task.spawn(function()
		while true do
			waitForPlayers()
			startCountdown()
			local winner = runRound()
			endRound(winner)
		end
	end)
end

return RoundService
