-- BrainrotCatalog.luau (ModuleScript, ReplicatedStorage.Shared)
-- Neon Shores -- the full original cast of 42 absurd meme characters.
-- Every brainrot is built from primitive Parts at runtime: a body, a head and one silly
-- accessory, painted from the colour recipe below. No character here copies any other game:
-- the names, shapes and jokes are this game's own.
--
-- Rarity ladder (weakest to strongest): Common, Rare, Epic, Legendary, Mythic,
-- Brainrot God, Cosmic, Transcendent.
-- Mutations multiply income: Normal x1, Gold x2, Diamond x4, Rainbow x8.

local BrainrotCatalog = {}

BrainrotCatalog.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Cosmic", "Transcendent" }

BrainrotCatalog.RarityColors = {
	Common = Color3.fromRGB(170, 170, 170),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 120),
	["Brainrot God"] = Color3.fromRGB(255, 255, 255),
	Cosmic = Color3.fromRGB(120, 60, 255),
	Transcendent = Color3.fromRGB(255, 244, 200),
}

-- Hatch odds per rarity, in percent. They add up to 100.
BrainrotCatalog.RarityHatchWeights = {
	Common = 44.15,
	Rare = 28,
	Epic = 15,
	Legendary = 8,
	Mythic = 3,
	["Brainrot God"] = 1,
	Cosmic = 0.6,
	Transcendent = 0.25,
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
	{ Id = "capyccino", Name = "Capyccino", Rarity = "Common", Price = 50, IncomePerSecond = 1,
		BodyShape = "Block", Accessory = "Cap", BodyColor = { 176, 125, 74 }, HeadColor = { 196, 148, 92 },
		AccessoryColor = { 240, 240, 240 }, Tagline = "A capybara who only drinks foam art." },
	{ Id = "pudding_pug", Name = "Pudding Pug", Rarity = "Common", Price = 65, IncomePerSecond = 1,
		BodyShape = "Ball", Accessory = "Cap", BodyColor = { 240, 220, 180 }, HeadColor = { 245, 230, 195 },
		AccessoryColor = { 120, 80, 200 }, Tagline = "A pug made of pudding. Wobbles with confidence." },
	{ Id = "noodle_newt", Name = "Noodle Newt", Rarity = "Common", Price = 90, IncomePerSecond = 2,
		BodyShape = "Cylinder", Accessory = "Antenna", BodyColor = { 245, 205, 90 }, HeadColor = { 250, 220, 120 },
		AccessoryColor = { 255, 90, 90 }, Tagline = "A salamander made of instant noodles." },
	{ Id = "socksquatch", Name = "Socksquatch", Rarity = "Common", Price = 120, IncomePerSecond = 2,
		BodyShape = "Block", Accessory = "Mohawk", BodyColor = { 150, 110, 80 }, HeadColor = { 165, 125, 95 },
		AccessoryColor = { 255, 120, 180 }, Tagline = "Bigfoot's little brother. Only ever caught wearing one sock." },
	{ Id = "sigma_spud", Name = "Sigma Spud", Rarity = "Common", Price = 150, IncomePerSecond = 3,
		BodyShape = "Ball", Accessory = "Mohawk", BodyColor = { 198, 160, 105 }, HeadColor = { 210, 175, 120 },
		AccessoryColor = { 60, 60, 70 }, Tagline = "A lone-wolf potato. Grinds. Never peels." },
	{ Id = "muffin_moose", Name = "Muffin Moose", Rarity = "Common", Price = 175, IncomePerSecond = 4,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 170, 130, 90 }, HeadColor = { 185, 145, 105 },
		AccessoryColor = { 240, 200, 120 }, Tagline = "Antlers of bran. Heart of chocolate chips." },
	{ Id = "pickle_penguin", Name = "Pickle Penguin", Rarity = "Common", Price = 200, IncomePerSecond = 4,
		BodyShape = "Cylinder", Accessory = "Antenna", BodyColor = { 80, 180, 90 }, HeadColor = { 150, 230, 140 },
		AccessoryColor = { 255, 200, 40 }, Tagline = "Brined for winter. Slippery all year." },
	{ Id = "toilet_gremlin", Name = "Sir Flushalot", Rarity = "Rare", Price = 400, IncomePerSecond = 7,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 235, 240, 245 }, HeadColor = { 110, 200, 120 },
		AccessoryColor = { 120, 120, 130 }, Tagline = "A gremlin knight of the porcelain throne." },
	{ Id = "toaster_otter", Name = "Toaster Otter", Rarity = "Rare", Price = 550, IncomePerSecond = 9,
		BodyShape = "Block", Accessory = "Antenna", BodyColor = { 190, 120, 70 }, HeadColor = { 205, 140, 90 },
		AccessoryColor = { 90, 200, 255 }, Tagline = "Pops up twice as fast when nobody is watching." },
	{ Id = "banana_shark", Name = "Bananashark", Rarity = "Rare", Price = 700, IncomePerSecond = 12,
		BodyShape = "Cylinder", Accessory = "None", BodyColor = { 250, 220, 60 }, HeadColor = { 250, 230, 100 },
		AccessoryColor = { 250, 220, 60 }, Tagline = "Half shark, half banana, fully slippery." },
	{ Id = "bubblewrap_buffalo", Name = "Bubblewrap Buffalo", Rarity = "Rare", Price = 850, IncomePerSecond = 15,
		BodyShape = "Ball", Accessory = "Horns", BodyColor = { 200, 215, 235 }, HeadColor = { 215, 228, 245 },
		AccessoryColor = { 255, 110, 160 }, Tagline = "Every step is a tiny celebration. Pop. Pop. Pop." },
	{ Id = "disco_turnip", Name = "Disco Turnip", Rarity = "Rare", Price = 1100, IncomePerSecond = 19,
		BodyShape = "Ball", Accessory = "Antenna", BodyColor = { 235, 225, 250 }, HeadColor = { 200, 160, 255 },
		AccessoryColor = { 255, 215, 0 }, Tagline = "Boogies underground. Roots down, leaves up." },
	{ Id = "karaoke_crab", Name = "Karaoke Crab", Rarity = "Rare", Price = 1300, IncomePerSecond = 22,
		BodyShape = "Cylinder", Accessory = "Mohawk", BodyColor = { 240, 100, 80 }, HeadColor = { 250, 120, 95 },
		AccessoryColor = { 255, 215, 0 }, Tagline = "Sings one song. It is always the same song." },
	{ Id = "donut_deer", Name = "Donut Deer", Rarity = "Rare", Price = 1600, IncomePerSecond = 28,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 235, 180, 150 }, HeadColor = { 245, 195, 165 },
		AccessoryColor = { 255, 130, 200 }, Tagline = "Sprinkles are just antler confetti." },
	{ Id = "pigeon_postman", Name = "Postman Peck", Rarity = "Epic", Price = 2500, IncomePerSecond = 40,
		BodyShape = "Block", Accessory = "Cap", BodyColor = { 130, 140, 160 }, HeadColor = { 100, 190, 200 },
		AccessoryColor = { 200, 60, 60 }, Tagline = "Delivers your mail three weeks late, proudly." },
	{ Id = "saxophone_snail", Name = "Saxophone Snail", Rarity = "Epic", Price = 3400, IncomePerSecond = 55,
		BodyShape = "Cylinder", Accessory = "Antenna", BodyColor = { 120, 200, 160 }, HeadColor = { 140, 215, 175 },
		AccessoryColor = { 255, 190, 50 }, Tagline = "Slow jazz. The slowest jazz there is." },
	{ Id = "waffle_wyvern", Name = "Waffle Wyvern", Rarity = "Epic", Price = 4200, IncomePerSecond = 68,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 225, 165, 80 }, HeadColor = { 240, 185, 100 },
		AccessoryColor = { 150, 90, 40 }, Tagline = "Breathes syrup. Hoards butter. Fears forks." },
	{ Id = "viking_velociraptor", Name = "Viking Velociraptor", Rarity = "Epic", Price = 5200, IncomePerSecond = 85,
		BodyShape = "Block", Accessory = "Horns", BodyColor = { 110, 170, 90 }, HeadColor = { 125, 185, 105 },
		AccessoryColor = { 160, 160, 170 }, Tagline = "Raids fridges. Leaves tiny horned helmets." },
	{ Id = "lofi_loaf", Name = "Lo-Fi Loaf", Rarity = "Epic", Price = 6500, IncomePerSecond = 105,
		BodyShape = "Block", Accessory = "Antenna", BodyColor = { 215, 175, 130 }, HeadColor = { 225, 190, 145 },
		AccessoryColor = { 90, 200, 255 }, Tagline = "A bread loaf that streams beats to study to." },
	{ Id = "espresso_elephant", Name = "Espresso Elephant", Rarity = "Epic", Price = 8000, IncomePerSecond = 130,
		BodyShape = "Ball", Accessory = "Cap", BodyColor = { 150, 150, 170 }, HeadColor = { 165, 165, 185 },
		AccessoryColor = { 90, 60, 40 }, Tagline = "Never sleeps. Trunk full of beans." },
	{ Id = "pajama_llama", Name = "Pajama Llama", Rarity = "Epic", Price = 9800, IncomePerSecond = 160,
		BodyShape = "Block", Accessory = "Mohawk", BodyColor = { 240, 200, 220 }, HeadColor = { 248, 212, 230 },
		AccessoryColor = { 120, 200, 255 }, Tagline = "Ready for bed since 2019." },
	{ Id = "emperor_emoticon", Name = "Emperor Emoticon", Rarity = "Legendary", Price = 14000, IncomePerSecond = 220,
		BodyShape = "Ball", Accessory = "Crown", BodyColor = { 255, 215, 70 }, HeadColor = { 255, 225, 100 },
		AccessoryColor = { 255, 170, 0 }, Tagline = "Rules a kingdom of exactly one facial expression." },
	{ Id = "baron_broccoli", Name = "Baron von Broccoli", Rarity = "Legendary", Price = 17500, IncomePerSecond = 280,
		BodyShape = "Ball", Accessory = "Crown", BodyColor = { 70, 160, 80 }, HeadColor = { 85, 180, 95 },
		AccessoryColor = { 255, 170, 0 }, Tagline = "Aristocracy, but make it vegetable." },
	{ Id = "vampire_vacuum", Name = "Count Suckula", Rarity = "Legendary", Price = 22000, IncomePerSecond = 350,
		BodyShape = "Cylinder", Accessory = "Crown", BodyColor = { 90, 60, 120 }, HeadColor = { 230, 225, 235 },
		AccessoryColor = { 200, 40, 60 }, Tagline = "A vacuum vampire. Fears stairs and full dustbins." },
	{ Id = "madame_moonmoth", Name = "Madame Moonmoth", Rarity = "Legendary", Price = 28000, IncomePerSecond = 450,
		BodyShape = "Cylinder", Accessory = "Halo", BodyColor = { 210, 200, 240 }, HeadColor = { 225, 215, 250 },
		AccessoryColor = { 255, 255, 200 }, Tagline = "Flutters only toward porch lights and destiny." },
	{ Id = "captain_cereal", Name = "Captain Cereal", Rarity = "Legendary", Price = 34000, IncomePerSecond = 540,
		BodyShape = "Block", Accessory = "Cap", BodyColor = { 250, 170, 60 }, HeadColor = { 252, 190, 90 },
		AccessoryColor = { 220, 40, 60 }, Tagline = "Part of a balanced breakfast. Captain of none." },
	{ Id = "astro_axolotl", Name = "Astrolotl", Rarity = "Mythic", Price = 55000, IncomePerSecond = 850,
		BodyShape = "Cylinder", Accessory = "Halo", BodyColor = { 255, 160, 200 }, HeadColor = { 255, 185, 215 },
		AccessoryColor = { 255, 255, 200 }, Tagline = "An axolotl astronaut. Regrew the Moon once." },
	{ Id = "disco_yeti", Name = "Disco Yeti", Rarity = "Mythic", Price = 70000, IncomePerSecond = 1100,
		BodyShape = "Ball", Accessory = "Mohawk", BodyColor = { 235, 240, 250 }, HeadColor = { 245, 248, 255 },
		AccessoryColor = { 200, 110, 255 }, Tagline = "Abominable on the dance floor. In a good way." },
	{ Id = "quantum_quokka", Name = "Quantum Quokka", Rarity = "Mythic", Price = 90000, IncomePerSecond = 1400,
		BodyShape = "Ball", Accessory = "Halo", BodyColor = { 170, 140, 110 }, HeadColor = { 190, 165, 135 },
		AccessoryColor = { 120, 255, 230 }, Tagline = "Smiles in two timelines at once." },
	{ Id = "professor_pancake", Name = "Professor Pancake", Rarity = "Mythic", Price = 120000, IncomePerSecond = 1900,
		BodyShape = "Block", Accessory = "Crown", BodyColor = { 240, 190, 110 }, HeadColor = { 248, 205, 130 },
		AccessoryColor = { 150, 90, 40 }, Tagline = "Tenured in syrup studies." },
	{ Id = "neon_narwhal", Name = "Neon Narwhal", Rarity = "Mythic", Price = 160000, IncomePerSecond = 2600,
		BodyShape = "Cylinder", Accessory = "Horns", BodyColor = { 90, 200, 230 }, HeadColor = { 120, 215, 240 },
		AccessoryColor = { 255, 120, 220 }, Tagline = "The unicorn of the sea, but make it glow." },
	{ Id = "giga_chadpole", Name = "Giga Chadpole", Rarity = "Brainrot God", Price = 250000, IncomePerSecond = 4000,
		BodyShape = "Block", Accessory = "Crown", BodyColor = { 120, 200, 110 }, HeadColor = { 140, 220, 130 },
		AccessoryColor = { 255, 215, 0 }, Tagline = "A tadpole who skipped frog and went straight to legend." },
	{ Id = "the_waffle_king", Name = "The Waffle King", Rarity = "Brainrot God", Price = 400000, IncomePerSecond = 6500,
		BodyShape = "Block", Accessory = "Crown", BodyColor = { 235, 180, 95 }, HeadColor = { 245, 195, 110 },
		AccessoryColor = { 255, 60, 90 }, Tagline = "Final form of breakfast." },
	{ Id = "moist_megazord", Name = "Moist Megazord", Rarity = "Brainrot God", Price = 750000, IncomePerSecond = 12000,
		BodyShape = "Block", Accessory = "Mohawk", BodyColor = { 90, 180, 220 }, HeadColor = { 110, 200, 240 },
		AccessoryColor = { 255, 140, 60 }, Tagline = "Five damp sponges, one soggy titan." },
	{ Id = "final_croissant", Name = "The Final Croissant", Rarity = "Brainrot God", Price = 950000, IncomePerSecond = 16000,
		BodyShape = "Ball", Accessory = "Crown", BodyColor = { 235, 175, 95 }, HeadColor = { 245, 195, 115 },
		AccessoryColor = { 255, 60, 90 }, Tagline = "All butter. All layers. No mercy." },
	{ Id = "grandma_singularity", Name = "Grandma Singularity", Rarity = "Brainrot God", Price = 1200000, IncomePerSecond = 20000,
		BodyShape = "Ball", Accessory = "Halo", BodyColor = { 200, 170, 220 }, HeadColor = { 215, 190, 235 },
		AccessoryColor = { 120, 255, 230 }, Tagline = "Her knitting bends spacetime. Her soup bends knees." },
	{ Id = "captain_quasar_quesadilla", Name = "Captain Quasar Quesadilla", Rarity = "Cosmic", Price = 2800000, IncomePerSecond = 38000,
		BodyShape = "Cylinder", Accessory = "Antenna", BodyColor = { 52, 34, 105 }, HeadColor = { 74, 50, 140 },
		AccessoryColor = { 120, 255, 230 }, Tagline = "Sails the cheese seas between the stars." },
	{ Id = "madame_nebula_noodles", Name = "Madame Nebula Noodles", Rarity = "Cosmic", Price = 3400000, IncomePerSecond = 46000,
		BodyShape = "Cylinder", Accessory = "Halo", BodyColor = { 40, 26, 88 }, HeadColor = { 92, 56, 158 },
		AccessoryColor = { 255, 120, 220 }, Tagline = "Her broth contains entire galaxies. Slurp responsibly." },
	{ Id = "baron_blackhole_bagel", Name = "Baron Blackhole Bagel", Rarity = "Cosmic", Price = 4200000, IncomePerSecond = 58000,
		BodyShape = "Ball", Accessory = "Crown", BodyColor = { 26, 20, 50 }, HeadColor = { 46, 36, 82 },
		AccessoryColor = { 120, 60, 255 }, Tagline = "Everything orbits his breakfast. Everything." },
	{ Id = "seraphim_spaghetti", Name = "Seraphim Spaghetti", Rarity = "Transcendent", Price = 5500000, IncomePerSecond = 75000,
		BodyShape = "Cylinder", Accessory = "Halo", BodyColor = { 250, 240, 210 }, HeadColor = { 255, 248, 226 },
		AccessoryColor = { 255, 205, 60 }, Tagline = "Six wings, every one of them al dente." },
	{ Id = "the_last_brain_cell", Name = "The Last Brain Cell", Rarity = "Transcendent", Price = 6800000, IncomePerSecond = 90000,
		BodyShape = "Ball", Accessory = "Antenna", BodyColor = { 246, 236, 202 }, HeadColor = { 255, 247, 218 },
		AccessoryColor = { 255, 170, 60 }, Tagline = "The final one. It is doing its best." },
	{ Id = "the_big_bang_burrito", Name = "The Big Bang Burrito", Rarity = "Transcendent", Price = 8000000, IncomePerSecond = 110000,
		BodyShape = "Block", Accessory = "Crown", BodyColor = { 252, 244, 206 }, HeadColor = { 255, 250, 228 },
		AccessoryColor = { 255, 120, 90 }, Tagline = "It all started with a wrap. It all ends with one too." },
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

-- weightOverrides, when given, is a { [name] = weight } map that replaces the
-- base weights for this one roll (the Lucky Charm boost passes its own).
function BrainrotCatalog.RollRarity(rng: Random, weightOverrides: { [string]: number }?): string
	local totalWeight = 0
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		totalWeight += (weightOverrides and weightOverrides[rarity]) or BrainrotCatalog.RarityHatchWeights[rarity]
	end
	local roll = rng:NextNumber(0, totalWeight)
	local running = 0
	for _, rarity in ipairs(BrainrotCatalog.RarityOrder) do
		running += (weightOverrides and weightOverrides[rarity]) or BrainrotCatalog.RarityHatchWeights[rarity]
		if roll <= running then
			return rarity
		end
	end
	return "Common"
end

function BrainrotCatalog.RollMutation(rng: Random, weightOverrides: { [string]: number }?)
	local totalWeight = 0
	for _, mutation in ipairs(BrainrotCatalog.Mutations) do
		totalWeight += (weightOverrides and weightOverrides[mutation.Name]) or mutation.Weight
	end
	local roll = rng:NextNumber(0, totalWeight)
	local running = 0
	for _, mutation in ipairs(BrainrotCatalog.Mutations) do
		running += (weightOverrides and weightOverrides[mutation.Name]) or mutation.Weight
		if roll <= running then
			return mutation
		end
	end
	return BrainrotCatalog.Mutations[1]
end

function BrainrotCatalog.RollHatch(rng: Random, rarityWeights: { [string]: number }?, mutationWeights: { [string]: number }?)
	local rarity = BrainrotCatalog.RollRarity(rng, rarityWeights)
	local pool = BrainrotCatalog.GetCharactersOfRarity(rarity)
	local character = pool[rng:NextInteger(1, #pool)]
	local mutation = BrainrotCatalog.RollMutation(rng, mutationWeights)
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
