--!strict
--[[
	CollisionGroups

	Puts every character part into one "Players" collision group so
	player-vs-player collision can be switched off from a single config flag.

	This is the cheapest large lever we have on server performance. 100 humanoids
	shoving each other around a chokepoint is real physics work every step, and
	it is the first thing to try when a 100-player test starts eating frame
	time. It is left ON by default because shield walls and chokepoints are the
	whole point of the mode - but the switch is here, tested, and one line away.
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)

local CollisionGroups = {}

local PLAYER_GROUP = "Players"
local registered = false

function CollisionGroups.setup()
	if registered then
		return
	end
	registered = true

	-- RegisterCollisionGroup throws if the group already exists (e.g. a Studio
	-- session that kept the group between runs).
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)

	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, CombatConfig.PlayerCollisions)
end

function CollisionGroups.applyToCharacter(character: Model)
	if not registered then
		CollisionGroups.setup()
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end
end

return CollisionGroups
