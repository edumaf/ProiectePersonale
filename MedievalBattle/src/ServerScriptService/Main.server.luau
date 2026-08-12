--!strict
--[[
	Main

	The one server entry point. Everything else in ServerScriptService is a
	ModuleScript with an explicit init(), so the boot order is visible in one
	place instead of being an emergent property of however many Script
	instances happened to run first.

	Boot order is load-bearing:
	  Remotes    - every remote must exist before any client can ask for one
	  Map        - the world has to exist before anyone spawns into it
	  Teams      - a character cannot be tagged with a team that does not exist
	  Combat     - handlers connected before the first character appears
	  Classes    - loadouts, needs CombatService
	  Spawning   - spawns players, needs all of the above
	  Rounds     - drives spawning and objectives, so it goes last
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)

local ClassService = require(script.Parent.Classes.ClassService)
local CollisionGroups = require(script.Parent.Spawning.CollisionGroups)
local CombatService = require(script.Parent.Combat.CombatService)
local MapBuilder = require(script.Parent.Map.MapBuilder)
local ObjectiveService = require(script.Parent.Rounds.ObjectiveService)
local RangedService = require(script.Parent.Combat.RangedService)
local RoundService = require(script.Parent.Rounds.RoundService)
local SpawnService = require(script.Parent.Spawning.SpawnService)
local TeamService = require(script.Parent.Rounds.TeamService)
local TrainingDummy = require(script.Parent.Map.TrainingDummy)
local WeaponRack = require(script.Parent.Classes.WeaponRack)

local START = os.clock()

Remotes.init()

local map = MapBuilder.build()
MapBuilder.buildSpawnPads(map)

CollisionGroups.setup()
TeamService.init()
ObjectiveService.init(map)
CombatService.init()
RangedService.init()
ClassService.init()
SpawnService.init()
-- Needs ClassService, and parents its stands into the map folder.
WeaponRack.build(map)
TrainingDummy.build(map)
-- Last: the round loop drives spawning and objectives, so both must exist.
RoundService.init()

--[[
	Players.MaxPlayers cannot be raised from a script - it is a place setting.
	Studio allows up to 200 in Game Settings > Basic Info; anything above that
	needs Roblox's large-server programme. Without this the game silently caps
	at 12 and you will "test" 50v50 with 12 people.
]]
if Players.MaxPlayers < 100 then
	warn(
		`[MedievalBattle] Players.MaxPlayers is {Players.MaxPlayers}. `
			.. "Set it to 100 in Studio: Home > Game Settings > Basic Info > Max Players. "
			.. "See README.md - it cannot be changed from code."
	)
end

print(`[MedievalBattle] server ready in {math.floor((os.clock() - START) * 1000)}ms`)
