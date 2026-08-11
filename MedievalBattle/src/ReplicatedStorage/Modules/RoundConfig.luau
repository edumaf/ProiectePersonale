--!strict
--[[
	RoundConfig

	Round pacing, objective rules and team balance thresholds.
	Shared so the HUD can render countdowns without a second copy of the numbers.
]]

local RoundConfig = {}

-- Round flow -------------------------------------------------------------------

RoundConfig.MinPlayersToStart = 2 -- keep at 2 so a Studio playtest actually starts
RoundConfig.IntermissionSeconds = 12 -- score screen between rounds
RoundConfig.CountdownSeconds = 10 -- players frozen at spawn
RoundConfig.RoundSeconds = 600 -- attackers must take everything inside this
RoundConfig.CaptureTimeBonus = 90 -- seconds added to the clock per point taken

-- Objective --------------------------------------------------------------------

-- Capture rate scales with the number of attackers in the zone, but only up to
-- this many - otherwise a 50-man blob takes a point instantly and the mode
-- collapses into "whoever zerged first wins".
RoundConfig.MaxCaptureContributors = 5
-- Every defender in the zone cancels out one attacker. Equal numbers = frozen.
RoundConfig.DefenderCancelsAttacker = true
-- Progress decays back toward 0 when no attackers are present.
RoundConfig.CaptureDecayRate = 0.5 -- fraction of the capture rate
RoundConfig.ObjectiveTickRate = 0.25 -- seconds between objective evaluations
RoundConfig.ObjectiveBroadcastRate = 0.25 -- seconds between network updates

-- Teams ------------------------------------------------------------------------

-- Teams may differ by at most this much before the balancer moves someone.
RoundConfig.MaxTeamSizeDifference = 1
-- Players are only reassigned on death/spawn, never mid-fight.
RoundConfig.BalanceOnDeath = true

-- Scoring ----------------------------------------------------------------------

RoundConfig.ScorePerKill = 10
RoundConfig.ScorePerCapture = 250

return table.freeze(RoundConfig)
