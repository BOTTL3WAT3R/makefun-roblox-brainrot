# makefun-roblox-brainrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/BOTTL3WAT3R/makefun-roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/BOTTL3WAT3R/makefun-roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**PLUNDERROT: Kraken's Curse** — a 3D Roblox brainrot game with a pirate curse. Plunder absurd meme-born characters that each earn doubloons every second, stand them on the pads at your base, climb a ladder of rarities and mutations, steal brainrots from other players' unlocked bases and dash home with the catch — and when the Kraken Tide warning sounds, run for your base or the Crow's Nest Cliffs, or the tide takes what you are carrying and washes you back to spawn. Sell your crew to Davy Jones at his golden shrine to reset for a permanent income multiplier.

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

1. You spawn on the dock-town plaza in Plunderrot Lagoon and get your own base plot
   (an anchor and your name are on its sign). A treasure chest guards every base.
2. Walk into a brainrot on the **Plunder Belt** on the dock to buy it, or use the
   **PLUNDER SHOP** panel. It appears on a pad at your base and starts earning doubloons
   every second — its floating label shows its name, rarity and $/s.
3. Stand by the **Kraken Egg Vault** and press **KRAKEN EGG** to hatch a random brainrot:
   rarities roll from Common to Brainrot God, and mutations multiply income (Gold x2, Diamond x4, Rainbow x8).
4. **Steal:** walk into a brainrot on another player's *unlocked* base to rip it off its pad
   and carry it on your back (you are slower while carrying). Reach your own base floor to
   bank it. Victims can chase you down — and the Kraken Tide ends the run for both of you.
5. **Defend:** step on your base's red **LOCK** button (or the LOCK YER BASE button) to raise
   laser walls for 60 seconds. Nobody can steal from a locked base.
6. **Kraken Tide:** every 120 seconds a warning counts down, then a wall of water sweeps the
   island. If it catches you in the open, you lose the brainrot you are carrying and wash
   back to spawn. Your base and the Crow's Nest Cliffs are safe.
7. **Rebirth:** at **Davy Jones' Shrine**, pay the cost to reset your doubloons and brainrots
   for a permanent +100% income multiplier (x2, x3, x4...). Costs grow 8x per rebirth.

## Controls

- **WASD / joystick** — move through the 3D world (standard Roblox character controls)
- **Left Shift or the DASH button** — 3-second speed burst (dash home with a stolen brainrot!)
- **Walk into** belt brainrots, placed brainrots, lock buttons and base floors to interact
- **PLUNDER SHOP / ME BASE / KRAKEN EGG / DAVY JONES buttons** — panels and actions, top-right and bottom-centre

## The cast

Sixteen original characters, built from primitive parts (body, head, eyes, one accessory),
each with a floating name / rarity / $/s label. Prices and income per second:

| Brainrot | Rarity | Price | $/s | The joke |
|---|---|---|---|---|
| Cap'n Capybara | Common | $50 | 1 | A capybara captain who only drinks foam art |
| Noodle Newt | Common | $90 | 2 | A salamander made of instant noodles |
| Sigma Spud | Common | $150 | 3 | A lone-wolf potato. Grinds. Never peels |
| Sir Barnacle | Rare | $400 | 7 | A barnacle knight of the sunken porcelain throne |
| Bananashark | Rare | $700 | 12 | Half shark, half banana, fully slippery |
| Disco Turnip | Rare | $1,100 | 19 | Boogies underground |
| Postman Peck | Epic | $2,500 | 40 | Delivers your mail three weeks late, proudly |
| Waffle Wyvern | Epic | $4,200 | 68 | Breathes syrup. Hoards butter. Fears forks |
| Lo-Fi Loaf | Epic | $6,500 | 105 | A bread loaf that streams beats to study to |
| Emperor Emoticon | Legendary | $14,000 | 220 | Rules a kingdom of one facial expression |
| Count Suckula | Legendary | $22,000 | 350 | A vacuum vampire. Fears full dustbins |
| Krakenolotl | Mythic | $55,000 | 850 | An axolotl of the deep. Regrew a tentacle once |
| Quantum Quokka | Mythic | $90,000 | 1,400 | Smiles in two timelines at once |
| Giga Chadpole | Brainrot God | $250,000 | 4,000 | A tadpole who skipped frog and went to legend |
| The Pirate Waffle King | Brainrot God | $400,000 | 6,500 | Final form of breakfast. All syrup bows to the captain |
| Moist Krakenzord | Brainrot God | $750,000 | 12,000 | Five damp sponges, one soggy sea titan |

Mutations on hatch: Normal x1 (70%), Gold x2 (20%), Diamond x4 (8%), Rainbow x8 (2%).

## Structure

Rojo project — `src/` maps into the place, and `game.rbxl` is built from it:

- `src/shared/BrainrotCatalog.luau` — the cast table, rarities, mutations, hatch rolls
- `src/shared/GameConfig.luau` — every tunable: tick rate, lock/steal rules, Kraken Tide cycle, rebirth formula
- `src/server/Main.server.luau` — bootstrap: builds the world, creates RemoteEvents, assigns bases, starts all loops
- `src/server/WorldBuilder.luau` — builds the 3D world from Parts: island, wooden dock-town plaza, plunder belt on its dock, Kraken Egg Vault, Davy Jones' Shrine, 8 bases with pads/lock lasers and treasure chests, Crow's Nest Cliffs, the Kraken Tide wall, the docked pirate ship THE SOGGY WAFFLE with mast, sail, Jolly Roger, cannons and treasure chests, scattered barrels and cannons, and every brainrot model with its floating label
- `src/server/PlayerData.luau` — all per-player state in one place: doubloons, placed/carried brainrots, rebirths, multiplier
- `src/server/EconomyService.luau` — income tick, belt buying, Kraken egg hatching, placing, selling
- `src/server/StealService.luau` — carry/steal, base lock lasers, dash, banking a stolen brainrot
- `src/server/TsunamiService.luau` — Kraken Tide cycle: calm, warning countdown, sweep, safe zones
- `src/server/RebirthService.luau` — Davy Jones rebirth: cost check, reset, permanent multiplier
- `src/client/Hud.client.luau` — ScreenGui HUD: doubloons, $/s, multiplier, Kraken Tide banner, DASH/LOCK buttons (kept clear of the top-left corner)
- `src/client/ShopUI.client.luau` — plunder shop panel, me-base panel with sell buttons, Kraken egg and Davy Jones buttons
- `src/world/` — static 3D structures as Rojo model files (plaza arch, shop stall, rarity pedestals)

Client and server talk only through the RemoteEvents the server bootstrap creates under
`ReplicatedStorage.Remotes`; every purchase, hatch, sale, lock and rebirth is validated
server-side before money moves.

## License

MIT — see `LICENSE`.
