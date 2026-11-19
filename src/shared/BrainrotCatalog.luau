-- BrainrotCatalog.luau (ModuleScript, ReplicatedStorage.Shared)
-- PLUNDERROT: Kraken's Curse -- the full original cast of absurd meme characters.
-- Every brainrot is built from primitive Parts at runtime: a body, a head and one silly
-- accessory, painted from the colour recipe below. No character here copies any other game:
-- the names, shapes and jokes are this game's own.
--
-- Rarity ladder (weakest to strongest): Common, Rare, Epic, Legendary, Mythic, Brainrot God.
-- Mutations multiply income: Normal x1, Gold x2, Diamond x4, Rainbow x8.

local BrainrotCatalog = {}

BrainrotCatalog.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God" }

BrainrotCatalog.RarityColors = {
	Common = Color3.fromRGB(170, 170, 170),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 120),
	["Brainrot God"] = Color3.fromRGB(255, 255, 255),
}

-- Hatch odds per rarity, in percent. They add up to 100.
BrainrotCatalog.RarityHatchWeights = {
	Common = 45,
	Rare = 28,
	Epic = 15,
	Legendary = 8,
	Mythic = 3,
	["Brainrot God"] = 1,
}

BrainrotCatalog.Mutations = {
	{ Name = "Normal", IncomeMultiplier = 1, Weight = 70, Tint = nil },
	{ Name = "Gold", IncomeMultiplier = 2, Weight = 20, Tint = Color3.fromRGB(255, 205, 60) },
	{ Name = "Diamond", IncomeMultiplier = 4, Weight = 8, Tint = Color3.fromRGB(120, 235, 255) },
	{ Name = "Rainbow", IncomeMultiplier = 8, Weight = 2, Tint = Color3.fromRGB(255, 120, 220) },
}

-- The cast. BodyShape is one of Block, Ball, Cylinder. Accessory is one of
-- Cap, Horns, Crown, Antenna, Mohawk, Halo, None. Colours are {r, g, b} triples.
BrainrotCatalog.Characters = {
	{ Id = "capyccino", Name = "Cap'n Capybara", Rarity = "Common", Price = 50, IncomePerSecond = 1,
		BodyShape = "Block", Accessory = "Cap", BodyColor = { 176, 125, 74 }, HeadColor = { 196, 148, 92 },
		AccessoryColor = { 240, 240, 240 }, Tagline = "A capybara captain who only drinks foam art." },
	{ Id = "noodle_newt", Name = "Noodle Newt", Rarity = "Common", Price = 90, IncomePerSecond = 2,
		BodyShape = "Cylinder", Accessory = "Antenna", BodyColor = { 245, 205, 90 }, HeadColor = { 250, 220, 120 },
		AccessoryColor = { 255, 90, 90 }, Tagline = "A salamander made of instant noodles." },
	{ Id = "sigma_spud", Name = "Sigma Spud", Rarity = "Common", Price = 150, IncomePerSecond = 3,
		BodyShape = "Ball", Accessory = "Mohawk", BodyColor = { 198, 160, 105 }, HeadColor = { 210, 175, 120 },
		AccessoryColor = { 60, 60, 70 }, Tagline = "A lone-wolf potato. Grinds. Never peels." },
	{ Id = "toilet_gremlin", Name = "Sir Barnacle", Rarity = "Rare", Price = 400, IncomePerSecond = 7,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 235, 240, 245 }, HeadColor = { 110, 200, 120 },
		AccessoryColor = { 120, 120, 130 }, Tagline = "A barnacle knight of the sunken porcelain throne." },
	{ Id = "banana_shark", Name = "Bananashark", Rarity = "Rare", Price = 700, IncomePerSecond = 12,
		BodyShape = "Cylinder", Accessory = "None", BodyColor = { 250, 220, 60 }, HeadColor = { 250, 230, 100 },
		AccessoryColor = { 250, 220, 60 }, Tagline = "Half shark, half banana, fully slippery." },
	{ Id = "disco_turnip", Name = "Disco Turnip", Rarity = "Rare", Price = 1100, IncomePerSecond = 19,
		BodyShape = "Ball", Accessory = "Antenna", BodyColor = { 235, 225, 250 }, HeadColor = { 200, 160, 255 },
		AccessoryColor = { 255, 215, 0 }, Tagline = "Boogies underground. Roots down, leaves up." },
	{ Id = "pigeon_postman", Name = "Postman Peck", Rarity = "Epic", Price = 2500, IncomePerSecond = 40,
		BodyShape = "Block", Accessory = "Cap", BodyColor = { 130, 140, 160 }, HeadColor = { 100, 190, 200 },
		AccessoryColor = { 200, 60, 60 }, Tagline = "Delivers your mail three weeks late, proudly." },
	{ Id = "waffle_wyvern", Name = "Waffle Wyvern", Rarity = "Epic", Price = 4200, IncomePerSecond = 68,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 225, 165, 80 }, HeadColor = { 240, 185, 100 },
		AccessoryColor = { 150, 90, 40 }, Tagline = "Breathes syrup. Hoards butter. Fears forks." },
	{ Id = "lofi_loaf", Name = "Lo-Fi Loaf", Rarity = "Epic", Price = 6500, IncomePerSecond = 105,
		BodyShape = "Block", Accessory = "Antenna", BodyColor = { 215, 175, 130 }, HeadColor = { 225, 190, 145 },
		AccessoryColor = { 90, 200, 255 }, Tagline = "A bread loaf that streams beats to study to." },
	{ Id = "emperor_emoticon", Name = "Emperor Emoticon", Rarity = "Legendary", Price = 14000, IncomePerSecond = 220,
		BodyShape = "Ball", Accessory = "Crown", BodyColor = { 255, 215, 70 }, HeadColor = { 255, 225, 100 },
		AccessoryColor = { 255, 170, 0 }, Tagline = "Rules a kingdom of exactly one facial expression." },
	{ Id = "vampire_vacuum", Name = "Count Suckula", Rarity = "Legendary", Price = 22000, IncomePerSecond = 350,
		BodyShape = "Cylinder", Accessory = "Crown", BodyColor = { 90, 60, 120 }, HeadColor = { 230, 225, 235 },
		AccessoryColor = { 200, 40, 60 }, Tagline = "A vacuum vampire. Fears stairs and full dustbins." },
	{ Id = "astro_axolotl", Name = "Krakenolotl", Rarity = "Mythic", Price = 55000, IncomePerSecond = 850,
		BodyShape = "Cylinder", Accessory = "Halo", BodyColor = { 255, 160, 200 }, HeadColor = { 255, 185, 215 },
		AccessoryColor = { 255, 255, 200 }, Tagline = "An axolotl of the deep. Regrew a tentacle once." },
	{ Id = "quantum_quokka", Name = "Quantum Quokka", Rarity = "Mythic", Price = 90000, IncomePerSecond = 1400,
		BodyShape = "Ball", Accessory = "Halo", BodyColor = { 170, 140, 110 }, HeadColor = { 190, 165, 135 },
		AccessoryColor = { 120, 255, 230 }, Tagline = "Smiles in two timelines at once." },
	{ Id = "giga_chadpole", Name = "Giga Chadpole", Rarity = "Brainrot God", Price = 250000, IncomePerSecond = 4000,
		BodyShape = "Block", Accessory = "Crown", BodyColor = { 120, 200, 110 }, HeadColor = { 140, 220, 130 },
		AccessoryColor = { 255, 215, 0 }, Tagline = "A tadpole who skipped frog and went straight to legend." },
	{ Id = "the_waffle_king", Name = "The Pirate Waffle King", Rarity = "Brainrot God", Price = 400000, IncomePerSecond = 6500,
		BodyShape = "Block", Accessory = "Crown", BodyColor = { 235, 180, 95 }, HeadColor = { 245, 195, 110 },
		AccessoryColor = { 255, 60, 90 }, Tagline = "Final form of breakfast. All syrup bows to the captain." },
	{ Id = "moist_megazord", Name = "Moist Krakenzord", Rarity = "Brainrot God", Price = 750000, IncomePerSecond = 12000,
		BodyShape = "Block", Accessory = "Mohawk", BodyColor = { 90, 180, 220 }, HeadColor = { 110, 200, 240 },
		AccessoryColor = { 255, 140, 60 }, Tagline = "Five damp sponges combined into one soggy sea titan." },
}

local byId: { [string]: any } = {}
for _, character in ipairs(BrainrotCatalog.Characters) do
	byId[character.Id] = character
end

function BrainrotCatalog.GetCharacterById(characterId: string)
	return byId[characterId]
end

function BrainrotCatalog.GetCharactersOfRarity(rarity: string)
	local matches = {}
	for _, character in ipairs(BrainrotCatalog.Characters) do
		if character.Rarity == rarity then
			table.insert(matches, character)
		end
	end
	return matches
end

function BrainrotCatalog.RollRarity(rng: Random): string
	local totalWeight = 0
	for _, weight in pairs(BrainrotCatalog.RarityHatchWeights) do
		totalWeight += weight
	end
	local roll = rng:NextNumber(0, totalWeight)
	local running = 0
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		running += BrainrotCatalog.RarityHatchWeights[rarity]
		if roll <= running then
			return rarity
		end
	end
	return "Common"
end

function BrainrotCatalog.RollMutation(rng: Random)
	local totalWeight = 0
	for _, mutation in ipairs(BrainrotCatalog.Mutations) do
		totalWeight += mutation.Weight
	end
	local roll = rng:NextNumber(0, totalWeight)
	local running = 0
	for _, mutation in ipairs(BrainrotCatalog.Mutations) do
		running += mutation.Weight
		if roll <= running then
			return mutation
		end
	end
	return BrainrotCatalog.Mutations[1]
end

function BrainrotCatalog.RollHatch(rng: Random)
	local rarity = BrainrotCatalog.RollRarity(rng)
	local pool = BrainrotCatalog.GetCharactersOfRarity(rarity)
	local character = pool[rng:NextInteger(1, #pool)]
	local mutation = BrainrotCatalog.RollMutation(rng)
	return character, mutation
end

function BrainrotCatalog.GetIncomePerSecond(character: any, mutationName: string): number
	local multiplier = 1
	for _, mutation in ipairs(BrainrotCatalog.Mutations) do
		if mutation.Name == mutationName then
			multiplier = mutation.IncomeMultiplier
			break
		end
	end
	return character.IncomePerSecond * multiplier
end

return BrainrotCatalog
