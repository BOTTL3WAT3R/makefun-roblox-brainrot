-- GameConfig.luau (ModuleScript, ReplicatedStorage.Shared)
-- PLUNDERROT: Kraken's Curse -- every tunable number for the whole game lives here,
-- so the economy, the steal rules, the Kraken Tide cycle and the rebirth ladder stay in one place.

local GameConfig = {}

-- Game identity
GameConfig.GameTitle = "PLUNDERROT: Kraken's Curse"
GameConfig.WorldName = "Plunderrot Lagoon"
GameConfig.Tagline = "Plunder them. Guard them. Outrun the Kraken Tide."
GameConfig.StartingCash = 100
GameConfig.MaxPlacedPerBase = 10
GameConfig.BaseCount = 8

-- Economy tick: placed brainrots pay their income once per tick.
GameConfig.IncomeTickSeconds = 1

-- Shop conveyor: a new brainrot rolls onto the belt every few seconds.
GameConfig.ConveyorSpawnSeconds = 4
GameConfig.ConveyorMaxOnBelt = 6
GameConfig.ConveyorLifetimeSeconds = 25

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

-- Kraken Tide hazard: warn, count down, sweep, calm, repeat.
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
