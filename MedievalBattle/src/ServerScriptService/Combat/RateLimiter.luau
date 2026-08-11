--!strict
--[[
	RateLimiter

	Token bucket, one bucket per player per action.

	Every RemoteEvent handler on the server must pass through one of these
	before it touches game state. A client can fire a RemoteEvent as fast as it
	likes, and an exploiter absolutely will: without a limiter, a single
	attacker spamming AttackRequest costs the server a state-machine reset and a
	broadcast per call, for all 100 players.

	The limits are deliberately loose (see CombatConfig.RateLimits) - a human
	mashing the mouse must never be throttled. Anything over the limit is
	dropped silently; we do not kick, because false positives on a laggy client
	are worse than an ignored packet.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = {
	capacity: number,
	refillPerSecond: number,
	buckets: { [Player]: Bucket },
	consume: (self: RateLimiter, player: Player) -> boolean,
	forget: (self: RateLimiter, player: Player) -> (),
}

--[[
	capacity        - burst allowance (how many actions can happen back to back)
	refillPerSecond - sustained rate
]]
function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local self = setmetatable({}, RateLimiter)
	self.capacity = capacity
	self.refillPerSecond = refillPerSecond
	self.buckets = {}
	return (self :: any) :: RateLimiter
end

-- Returns true if the action is allowed, false if the player is over budget.
function RateLimiter.consume(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.capacity, last = now }
		self.buckets[player] = bucket
	end

	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.last) * self.refillPerSecond)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, player: Player)
	self.buckets[player] = nil
end

return RateLimiter
