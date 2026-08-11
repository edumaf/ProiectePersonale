--!strict
--[[
	Remotes

	The whole network surface of the game in one file.

	Why a module instead of committing RemoteEvent instances (or listing them in
	default.project.json): four people adding remotes to the same JSON file is a
	merge conflict every week. Adding a line to one of the arrays below is not.

	Rules for anything added here:
	  1. Client -> server messages are *requests*. The server decides. Never send
	     "I hit Bob" - send "I pressed attack" and let the server trace it.
	  2. Cosmetic-only, high-frequency traffic goes in UNRELIABLE. Losing one of
	     those costs a visual effect, never a gameplay outcome, and it does not
	     block the reliable channel behind it.
	  3. Server -> client state pushes should be throttled and, where possible,
	     sent only to the players who can actually perceive them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- Reliable, ordered. Everything gameplay-critical.
local RELIABLE = {
	-- client -> server (requests)
	"AttackRequest", -- (direction: number)
	"FeintRequest", -- ()
	"BlockRequest", -- (down: boolean)
	"SprintRequest", -- (on: boolean)
	"RangedRequest", -- (action: number, aim: Vector3)
	"SelectClass", -- (classId: string)
	"SwapWeapon", -- ()

	-- server -> client (state)
	"StatusUpdate", -- (stamina, staminaMax, exhausted, phase) - owner only
	"LoadoutUpdate", -- (classId, weaponId) - owner only
	"ClassMenu", -- (open: boolean, reason: string?) - owner only
	"KillFeed", -- (killerName, victimName, weaponId, killerTeam, victimTeam)
	"RoundUpdate", -- (state, endsAt, scores, headline)
	"ObjectiveUpdate", -- (points: {{index, state, progress, contested}})
	"Notify", -- (text: string, seconds: number?)
	"TeamUpdate", -- (teamId: number) - owner only
}

-- Unreliable + unordered. Cosmetic only. Requires a reasonably recent Roblox
-- client; we fall back to a normal RemoteEvent if the class is unavailable.
local UNRELIABLE = {
	"CombatEffect", -- (kind, ...) broadcast to nearby players only
}

local FOLDER_NAME = "Net"
local WAIT_TIMEOUT = 20

local cache: { [string]: RemoteEvent } = {}
local folder: Instance? = nil

local function makeEvent(name: string, unreliable: boolean, parent: Instance): RemoteEvent
	local instance: Instance
	if unreliable then
		-- UnreliableRemoteEvent is relatively new; degrade gracefully rather
		-- than hard-failing on an older client build.
		local ok, created = pcall(function()
			return Instance.new("UnreliableRemoteEvent")
		end)
		instance = if ok then created else Instance.new("RemoteEvent")
	else
		instance = Instance.new("RemoteEvent")
	end
	instance.Name = name
	instance.Parent = parent
	return instance :: any
end

local function serverInit(): Instance
	local existing = script.Parent :: Instance
	local net = existing:FindFirstChild(FOLDER_NAME)
	if not net then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = existing
		net = created
	end
	assert(net, "Remotes: failed to create Net folder")

	for _, name in RELIABLE do
		if not net:FindFirstChild(name) then
			cache[name] = makeEvent(name, false, net)
		end
	end
	for _, name in UNRELIABLE do
		if not net:FindFirstChild(name) then
			cache[name] = makeEvent(name, true, net)
		end
	end
	return net
end

local function getFolder(): Instance
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = serverInit()
	else
		local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents", WAIT_TIMEOUT)
		assert(remoteFolder, "Remotes: RemoteEvents folder never replicated")
		local net = remoteFolder:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
		assert(net, "Remotes: Net folder never replicated - is the server bootstrap running?")
		folder = net
	end
	return folder :: Instance
end

--[[
	Fetches a remote by name. On the server every remote exists immediately
	after the bootstrap runs; on the client this yields until it replicates.
]]
function Remotes.get(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end

	local net = getFolder()
	local found: Instance?
	if RunService:IsServer() then
		found = net:FindFirstChild(name)
	else
		found = net:WaitForChild(name, WAIT_TIMEOUT)
	end
	if not found then
		error(`Remotes: no remote named "{name}" - add it to RELIABLE or UNRELIABLE in Remotes.luau`, 2)
	end

	local event = found :: RemoteEvent
	cache[name] = event
	return event
end

--[[
	Called once by the server bootstrap, before any service connects handlers,
	so no remote is ever missing when a client asks for it.
]]
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")
	getFolder()
end

Remotes.RELIABLE = RELIABLE
Remotes.UNRELIABLE = UNRELIABLE

return Remotes
