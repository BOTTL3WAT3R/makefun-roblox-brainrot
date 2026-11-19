-- GameConfig.luau (ModuleScript, ReplicatedStorage.Shared)
-- Neon Shores -- every tunable number for the whole game lives here,
-- so the economy, the steal rules, the Big Wave cycle and the rebirth ladder stay in one place.

local GameConfig = {}

-- Game identity
GameConfig.GameTitle = "Neon Shores"
GameConfig.WorldName = "Neon Shores"
GameConfig.Tagline = "Buy the glow. Guard the glow. Outrun the Big Wave."
GameConfig.StartingCash = 100
GameConfig.MaxPlacedPerBase = 10
GameConfig.BaseCount = 8

-- Economy tick: placed brainrots pay their income once per tick.
GameConfig.IncomeTickSeconds = 1

-- Shop conveyor: a new brainrot steps onto the belt every few seconds and
-- walks its length; the walk itself is its lifetime on the belt.
GameConfig.ConveyorSpawnSeconds = 3.5
GameConfig.ConveyorMaxOnBelt = 7

-- Egg machine: hatching costs cash and rolls a rarity, then a mutation.
GameConfig.EggPrice = 250
GameConfig.EggHatchSeconds = 3

-- Stealing and base defence
GameConfig.LockDurationSeconds = 60
GameConfig.LockCooldownSeconds = 15
GameConfig.StealTouchCooldownSeconds = 2
GameConfig.CarriedWalkSpeed = 12
GameConfig.NormalWalkSpeed = 16
GameConfig.DashWalkSpeed = 26
GameConfig.DashDurationSeconds = 3
GameConfig.DashCooldownSeconds = 6

-- Big Wave hazard: warn, count down, sweep, calm, repeat.
GameConfig.TsunamiPeriodSeconds = 120
GameConfig.TsunamiWarningSeconds = 15
GameConfig.TsunamiSweepSeconds = 8
GameConfig.TsunamiWallSpeed = 55

-- Rebirth ladder: cost grows fast, the income multiplier grows forever.
GameConfig.RebirthBaseCost = 10000
GameConfig.RebirthCostGrowth = 8
GameConfig.RebirthMultiplierPerRebirth = 1

-- Sell a brainrot back for a share of what it cost.
GameConfig.SellRefundFraction = 0.5

function GameConfig.GetRebirthCost(currentRebirths: number): number
	return math.floor(GameConfig.RebirthBaseCost * (GameConfig.RebirthCostGrowth ^ currentRebirths))
end

function GameConfig.GetIncomeMultiplier(currentRebirths: number): number
	return 1 + currentRebirths * GameConfig.RebirthMultiplierPerRebirth
end

function GameConfig.FormatCash(amount: number): string
	amount = math.floor(amount)
	if amount >= 1000000000 then
		return string.format("$%.2fB", amount / 1000000000)
	elseif amount >= 1000000 then
		return string.format("$%.2fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("$%.1fK", amount / 1000)
	end
	return "$" .. tostring(amount)
end

return GameConfig
