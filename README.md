# makefun-roblox-brainrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/BOTTL3WAT3R/makefun-roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/BOTTL3WAT3R/makefun-roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Neon Shores** — a 3D Roblox brainrot game set on a tropical island at golden hour, lit by neon. The sun sits low and peachy, the plaza and paths go dark slate so every sign, pad and laser glows, and palm trees carry neon glowfruit. Buy absurd meme-born characters that each earn cash every second, stand them on the glowing pads at your base, climb a ladder of 36 original brainrots across six rarities and four mutations, steal brainrots from other players' unlocked bases and dash home with the catch — and when the Big Wave warning sounds, run for your base or the high hill, or the wave takes what you are carrying and washes you back to spawn. Rebirth at the golden shrine to reset for a permanent income multiplier, and fill in your **Index**: a collection grid that lights up in rarity colours for every brainrot you own. The world stays readable at a glance — one neon colour per zone, one vivid colour per base — because all the motion lives on the brainrots: they bob, the rarest ones spin, and the valuable ones sparkle.

## Run it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

Open `game.rbxl` in Roblox Studio to play: publish it as a Public experience, put the
place link, place id and universe id in `PLAY.json`, and upload an icon and a thumbnail
(one of the screenshots in `screenshots/`) on the Creator Dashboard.

---

<sub>Entered on [make.fun](https://make.fun/?ref=beyt0vmy&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>

## How to play

1. You spawn on the dark neon-edged plaza in the middle of the island at sunset and get
   your own base plot — every base glows in its own neon colour, and your name is on its sign.
2. Follow the cyan neon path to the orange **Shop Belt** and walk into a brainrot to buy
   it, or use the **SHOP** panel. It appears on a glowing pad at your base and starts
   earning cash every second — its floating label shows its name, rarity and $/s.
3. Stand by the pink **Egg Machine** and press **EGG** to hatch a random brainrot:
   rarities roll from Common to Brainrot God, and mutations multiply income (Gold x2, Diamond x4, Rainbow x8).
4. **Steal:** walk into a brainrot on another player's *unlocked* base to rip it off its pad
   and carry it on your back (you are slower while carrying). Reach your own base floor to
   bank it. Victims can chase you down — and the Big Wave ends the run for both of you.
5. **Defend:** step on your base's red **LOCK** button (or the LOCK BASE button) to raise
   laser walls for 60 seconds. Nobody can steal from a locked base.
6. **Big Wave:** every 120 seconds a warning counts down, then a wall of water with a white
   foam crest sweeps the island. If it catches you in the open, you lose the brainrot you
   are carrying and wash back to spawn. Your base and the green high hill are safe.
7. **Rebirth:** at the gold **Rebirth Shrine**, pay the cost to reset your cash and brainrots
   for a permanent +100% income multiplier (x2, x3, x4...). Costs grow 8x per rebirth.
8. **Index:** press **INDEX** to open your collection grid — all 36 brainrots, lit up in
   their rarity colour once you own them, greyed out while they are still out there glowing.

## Controls

- **WASD / joystick** — move through the 3D world (standard Roblox character controls)
- **Left Shift or the DASH button** — 3-second speed burst (dash home with a stolen brainrot!)
- **Walk into** belt brainrots, placed brainrots, lock buttons and base floors to interact
- **SHOP / MY BASE / INDEX / EGG / REBIRTH buttons** — panels and actions, top-right and bottom-centre

## The cast

Thirty-six original characters, built from primitive parts (body, head, eyes, one accessory),
each with a floating name / rarity / $/s label. Prices and income per second:

| Brainrot | Rarity | Price | $/s | The joke |
|---|---|---|---|---|
| Capyccino | Common | $50 | 1 | A capybara who only drinks foam art |
| Pudding Pug | Common | $65 | 1 | A pug made of pudding. Wobbles with confidence |
| Noodle Newt | Common | $90 | 2 | A salamander made of instant noodles |
| Socksquatch | Common | $120 | 2 | Bigfoot's little brother. Only ever caught wearing one sock |
| Sigma Spud | Common | $150 | 3 | A lone-wolf potato. Grinds. Never peels |
| Muffin Moose | Common | $175 | 4 | Antlers of bran. Heart of chocolate chips |
| Pickle Penguin | Common | $200 | 4 | Brined for winter. Slippery all year |
| Sir Flushalot | Rare | $400 | 7 | A gremlin knight of the porcelain throne |
| Toaster Otter | Rare | $550 | 9 | Pops up twice as fast when nobody is watching |
| Bananashark | Rare | $700 | 12 | Half shark, half banana, fully slippery |
| Bubblewrap Buffalo | Rare | $850 | 15 | Every step is a tiny celebration. Pop. Pop. Pop |
| Disco Turnip | Rare | $1,100 | 19 | Boogies underground |
| Karaoke Crab | Rare | $1,300 | 22 | Sings one song. It is always the same song |
| Donut Deer | Rare | $1,600 | 28 | Sprinkles are just antler confetti |
| Postman Peck | Epic | $2,500 | 40 | Delivers your mail three weeks late, proudly |
| Saxophone Snail | Epic | $3,400 | 55 | Slow jazz. The slowest jazz there is |
| Waffle Wyvern | Epic | $4,200 | 68 | Breathes syrup. Hoards butter. Fears forks |
| Viking Velociraptor | Epic | $5,200 | 85 | Raids fridges. Leaves tiny horned helmets |
| Lo-Fi Loaf | Epic | $6,500 | 105 | A bread loaf that streams beats to study to |
| Espresso Elephant | Epic | $8,000 | 130 | Never sleeps. Trunk full of beans |
| Pajama Llama | Epic | $9,800 | 160 | Ready for bed since 2019 |
| Emperor Emoticon | Legendary | $14,000 | 220 | Rules a kingdom of one facial expression |
| Baron von Broccoli | Legendary | $17,500 | 280 | Aristocracy, but make it vegetable |
| Count Suckula | Legendary | $22,000 | 350 | A vacuum vampire. Fears full dustbins |
| Madame Moonmoth | Legendary | $28,000 | 450 | Flutters only toward porch lights and destiny |
| Captain Cereal | Legendary | $34,000 | 540 | Part of a balanced breakfast. Captain of none |
| Astrolotl | Mythic | $55,000 | 850 | An axolotl astronaut. Regrew the Moon once |
| Disco Yeti | Mythic | $70,000 | 1,100 | Abominable on the dance floor. In a good way |
| Quantum Quokka | Mythic | $90,000 | 1,400 | Smiles in two timelines at once |
| Professor Pancake | Mythic | $120,000 | 1,900 | Tenured in syrup studies |
| Neon Narwhal | Mythic | $160,000 | 2,600 | The unicorn of the sea, but make it glow |
| Giga Chadpole | Brainrot God | $250,000 | 4,000 | A tadpole who skipped frog and went to legend |
| The Waffle King | Brainrot God | $400,000 | 6,500 | Final form of breakfast |
| Moist Megazord | Brainrot God | $750,000 | 12,000 | Five damp sponges, one soggy titan |
| The Final Croissant | Brainrot God | $950,000 | 16,000 | All butter. All layers. No mercy |
| Grandma Singularity | Brainrot God | $1,200,000 | 20,000 | Her knitting bends spacetime. Her soup bends knees |

Mutations on hatch: Normal x1 (70%), Gold x2 (20%), Diamond x4 (8%), Rainbow x8 (2%).

## Structure

Rojo project — `src/` maps into the place, and `game.rbxl` is built from it:

- `src/shared/BrainrotCatalog.luau` — the 36-character cast table, rarities, mutations, hatch rolls
- `src/shared/GameConfig.luau` — every tunable: tick rate, lock/steal rules, Big Wave cycle, rebirth formula
- `src/server/Main.server.luau` — bootstrap: golden-hour Lighting (bloom, sun rays, atmosphere), builds the world, creates RemoteEvents, assigns bases, starts all loops
- `src/server/WorldBuilder.luau` — builds the 3D world from Parts: grass island on a sand rim in a deep teal sea, dark slate plaza with cyan neon edging and fountain, orange shop belt, pink egg machine, gold rebirth shrine, 8 neon-trimmed bases with pads and lock lasers, green high hill, palm trees with glowfruit, the Big Wave wall with its foam crest, and every brainrot model with its floating label
- `src/server/AnimationService.luau` — the animation layer: one Heartbeat loop bobs every brainrot (Mythic and Brainrot God also spin), sparkle emitters for Legendary+ and mutated brainrots, the pulsing egg dome and the conveyor chase lights
- `src/server/PlayerData.luau` — all per-player state in one place: cash, placed/carried brainrots, rebirths, multiplier
- `src/server/EconomyService.luau` — income tick, belt buying, egg hatching, placing, selling
- `src/server/StealService.luau` — carry/steal, base lock lasers, dash, banking a stolen brainrot
- `src/server/TsunamiService.luau` — Big Wave cycle: calm, warning countdown, tweened sweep, safe zones
- `src/server/RebirthService.luau` — rebirth: cost check, reset, permanent multiplier
- `src/client/Hud.client.luau` — ScreenGui HUD: cash (pops when it changes), $/s, multiplier, Big Wave banner (pulses red under 10s), DASH/LOCK buttons (kept clear of the top-left corner)
- `src/client/ShopUI.client.luau` — shop panel, my-base panel with sell buttons, the Index collection grid, egg and rebirth buttons
- `src/world/` — static 3D structures as Rojo model files (plaza arch, shop stall, rarity pedestals)

Client and server talk only through the RemoteEvents the server bootstrap creates under
`ReplicatedStorage.Remotes`; every purchase, hatch, sale, lock and rebirth is validated
server-side before money moves.

## License

MIT — see `LICENSE`.
