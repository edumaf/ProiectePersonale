--!strict
--[[
	EffectBroadcaster

	Cosmetic combat events (swings, impacts, blocks, arrows) go out on an
	UnreliableRemoteEvent and only to players near the action.

	Why this matters at 100 players: an unfiltered FireAllClients for every
	swing is O(players) packets per swing, and in a 50v50 blob there can be
	dozens of swings per second. Distance filtering cuts that to the handful of
	people who could actually see it, and the unreliable channel means a dropped
	effect never delays the reliable, gameplay-critical traffic behind it.

	Nothing sent through here may affect gameplay - the client is free to ignore
	all of it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)

local EffectBroadcaster = {}

local effectRemote: RemoteEvent? = nil

local function remote(): RemoteEvent
	if not effectRemote then
		effectRemote = Remotes.get("CombatEffect")
	end
	return effectRemote :: RemoteEvent
end

--[[
	Sends an effect to every player whose character is within
	CombatConfig.EffectBroadcastRadius of `origin`.

	Players with no character yet are skipped - they have nothing to render it
	on, and they are usually mid-respawn.
]]
function EffectBroadcaster.broadcast(origin: Vector3, kind: number, ...: any)
	local event = remote()
	local radiusSq = CombatConfig.EffectBroadcastRadiusSq

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character.PrimaryPart
		if not root then
			continue
		end
		local delta = root.Position - origin
		if delta:Dot(delta) <= radiusSq then
			event:FireClient(player, kind, ...)
		end
	end
end

--[[
	Same as broadcast, but always includes `always` even if they are out of
	range. Used for the actor of the effect: you must always see your own swing,
	and the victim must always see the hit that killed them.
]]
function EffectBroadcaster.broadcastIncluding(origin: Vector3, always: { Player }, kind: number, ...: any)
	local event = remote()
	local radiusSq = CombatConfig.EffectBroadcastRadiusSq

	local forced: { [Player]: boolean } = {}
	for _, player in always do
		forced[player] = true
		event:FireClient(player, kind, ...)
	end

	for _, player in Players:GetPlayers() do
		if forced[player] then
			continue
		end
		local character = player.Character
		local root = character and character.PrimaryPart
		if not root then
			continue
		end
		local delta = root.Position - origin
		if delta:Dot(delta) <= radiusSq then
			event:FireClient(player, kind, ...)
		end
	end
end

function EffectBroadcaster.toPlayer(player: Player, kind: number, ...: any)
	remote():FireClient(player, kind, ...)
end

return EffectBroadcaster
