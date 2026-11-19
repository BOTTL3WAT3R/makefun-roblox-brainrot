-- GameConfig.luau (ModuleScript, ReplicatedStorage.Shared)
-- Candy Island -- every tunable number for the whole game lives here,
-- so the economy, the steal rules, the Big Wave cycle and the rebirth ladder stay in one place.

local GameConfig = {}

-- Game identity
GameConfig.GameTitle = "Candy Island"
GameConfig.WorldName = "Candy Island"
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

-- Gacha capsule: the premium spin west of the arena, for players who have
-- outgrown the $250 egg. Ten thousand a spin and NO Commons, ever -- the
-- rarity table starts at Rare and climbs all the way to Transcendent, so
-- every pull lands somewhere exciting. The weights add up to 100.
GameConfig.GachaPrice = 10000
GameConfig.GachaRarityWeights = {
	Rare = 30,
	Epic = 28,
	Legendary = 20,
	Mythic = 12,
	["Brainrot God"] = 6,
	Cosmic = 3,
	Transcendent = 1,
}

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

-- Boosts: cash-bought powers that replace the old shop panel. There is NO
-- direct brainrot purchase any more -- the walking belt is the only shop --
-- so cash beyond brainrots goes into these four boosts instead. This table
-- is the single source of truth: the server validates against it and the
-- client BOOST panel renders straight from it.
GameConfig.SpeedBoostWalkSpeed = 24
GameConfig.Boosts = {
	{ Id = "Speed", Name = "SPEED SURGE", Price = 400, DurationSeconds = 60,
		Description = "Walk 50% faster. Outrun thieves and waves." },
	{ Id = "WaveShield", Name = "WAVE SHIELD", Price = 800, OneTime = true,
		Description = "The next Big Wave cannot wash you. One save." },
	{ Id = "Income", Name = "INCOME X2", Price = 2500, DurationSeconds = 120,
		Description = "Every placed brainrot earns double." },
	{ Id = "Luck", Name = "LUCKY CHARM", Price = 3000, DurationSeconds = 90,
		Description = "Luckier mutations at the Egg and Fuse Machines." },
}

local boostsById: { [string]: any } = {}
for _, boost in ipairs(GameConfig.Boosts) do
	boostsById[boost.Id] = boost
end

function GameConfig.GetBoostById(boostId: string)
	return boostsById[boostId]
end

-- Lucky Charm odds. While the charm is active, hatch and fuse mutation rolls
-- shift weight away from Normal toward Gold / Diamond / Rainbow, and the
-- hatch rarity roll tilts up the ladder (Common gives up ground to every
-- tier above it, and even Cosmic and Transcendent double their sliver). The
-- charm is personal: it never touches the shared belt spawns. All tables
-- add up to 100.
GameConfig.LuckyHatchMutationWeights = { Normal = 50, Gold = 32, Diamond = 13, Rainbow = 5 }
GameConfig.LuckyHatchRarityWeights = { Common = 33.3, Rare = 32, Epic = 18, Legendary = 10, Mythic = 4, ["Brainrot God"] = 1, Cosmic = 1.2, Transcendent = 0.5 }
GameConfig.FuseMutationWeights = { Normal = 55, Gold = 25, Diamond = 13, Rainbow = 7 }
GameConfig.LuckyFuseMutationWeights = { Normal = 40, Gold = 32, Diamond = 18, Rainbow = 10 }

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
