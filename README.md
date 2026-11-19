# makefun-roblox-brainrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/BOTTL3WAT3R/makefun-roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/BOTTL3WAT3R/makefun-roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Brainrot Tycoon: Tsunami Dash** — a 3D Roblox brainrot game. Collect absurd meme-born characters that each earn cash every second, stand them on the pads at your base, climb a ladder of rarities and mutations, steal brainrots from other players' unlocked bases and dash home with the catch — and when the tsunami warning sounds, run for your base or the shelter hill, or the wave takes what you are carrying and washes you back to spawn. Rebirth at the golden shrine to reset for a permanent income multiplier.

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

1. You spawn on the plaza and get your own base plot (your name is on its sign).
2. Walk into a brainrot on the **conveyor belt** by the shop row to buy it, or use the
   **SHOP** panel. It appears on a pad at your base and starts earning cash every second —
   its floating label shows its name, rarity and $/s.
3. Stand by the **Egg Machine** and press **EGG** to hatch a random brainrot: rarities roll
   from Common to Brainrot God, and mutations multiply income (Gold x2, Diamond x4, Rainbow x8).
4. **Steal:** walk into a brainrot on another player's *unlocked* base to rip it off its pad
   and carry it on your back (you are slower while carrying). Reach your own base floor to
   bank it. Victims can chase you down — and a tsunami ends the run for both of you.
5. **Defend:** step on your base's red **LOCK** button (or the LOCK BASE button) to raise
   laser walls for 60 seconds. Nobody can steal from a locked base.
6. **Tsunami:** every 120 seconds a warning counts down, then a wall of water sweeps the
   island. If it catches you in the open, you lose the brainrot you are carrying and wash
   back to spawn. Your base and the shelter hill are safe.
7. **Rebirth:** at the **Rebirth Shrine**, pay the cost to reset your cash and brainrots for
   a permanent +100% income multiplier (x2, x3, x4...). Costs grow 8x per rebirth.

## Controls

- **WASD / joystick** — move through the 3D world (standard Roblox character controls)
- **Left Shift or the DASH button** — 3-second speed burst (dash home with a stolen brainrot!)
- **Walk into** belt brainrots, placed brainrots, lock buttons and base floors to interact
- **SHOP / MY BASE / EGG / REBIRTH buttons** — panels and actions, top-right and bottom-centre

## The cast

Sixteen original characters, built from primitive parts (body, head, eyes, one accessory),
each with a floating name / rarity / $/s label. Prices and income per second:

| Brainrot | Rarity | Price | $/s | The joke |
|---|---|---|---|---|
| Capyccino | Common | $50 | 1 | A capybara who only drinks foam art |
| Noodle Newt | Common | $90 | 2 | A salamander made of instant noodles |
| Sigma Spud | Common | $150 | 3 | A lone-wolf potato. Grinds. Never peels |
| Sir Flushalot | Rare | $400 | 7 | A gremlin knight of the porcelain throne |
| Bananashark | Rare | $700 | 12 | Half shark, half banana, fully slippery |
| Disco Turnip | Rare | $1,100 | 19 | Boogies underground |
| Postman Peck | Epic | $2,500 | 40 | Delivers your mail three weeks late, proudly |
| Waffle Wyvern | Epic | $4,200 | 68 | Breathes syrup. Hoards butter. Fears forks |
| Lo-Fi Loaf | Epic | $6,500 | 105 | A bread loaf that streams beats to study to |
| Emperor Emoticon | Legendary | $14,000 | 220 | Rules a kingdom of one facial expression |
| Count Suckula | Legendary | $22,000 | 350 | A vacuum vampire. Fears full dustbins |
| Astrolotl | Mythic | $55,000 | 850 | An axolotl astronaut. Regrew the Moon once |
| Quantum Quokka | Mythic | $90,000 | 1,400 | Smiles in two timelines at once |
| Giga Chadpole | Brainrot God | $250,000 | 4,000 | A tadpole who skipped frog and went to legend |
| The Waffle King | Brainrot God | $400,000 | 6,500 | Final form of breakfast |
| Moist Megazord | Brainrot God | $750,000 | 12,000 | Five damp sponges, one soggy titan |

Mutations on hatch: Normal x1 (70%), Gold x2 (20%), Diamond x4 (8%), Rainbow x8 (2%).

## Structure

Rojo project — `src/` maps into the place, and `game.rbxl` is built from it:

- `src/shared/BrainrotCatalog.luau` — the cast table, rarities, mutations, hatch rolls
- `src/shared/GameConfig.luau` — every tunable: tick rate, lock/steal rules, tsunami cycle, rebirth formula
- `src/server/Main.server.luau` — bootstrap: builds the world, creates RemoteEvents, assigns bases, starts all loops
- `src/server/WorldBuilder.luau` — builds the 3D world from Parts: island, plaza, conveyor shop row, egg machine, rebirth shrine, 8 bases with pads/lock lasers, shelter hill, tsunami wall, and every brainrot model with its floating label
- `src/server/PlayerData.luau` — all per-player state in one place: cash, placed/carried brainrots, rebirths, multiplier
- `src/server/EconomyService.luau` — income tick, conveyor buying, egg hatching, placing, selling
- `src/server/StealService.luau` — carry/steal, base lock lasers, dash, banking a stolen brainrot
- `src/server/TsunamiService.luau` — wave cycle: calm, warning countdown, sweep, safe zones
- `src/server/RebirthService.luau` — rebirth cost check, reset, permanent multiplier
- `src/client/Hud.client.luau` — ScreenGui HUD: cash, $/s, multiplier, tsunami banner, DASH/LOCK buttons (kept clear of the top-left corner)
- `src/client/ShopUI.client.luau` — shop panel, my-base panel with sell buttons, egg and rebirth buttons
- `src/world/` — static 3D structures as Rojo model files (plaza arch, shop stall, rarity pedestals)

Client and server talk only through the RemoteEvents the server bootstrap creates under
`ReplicatedStorage.Remotes`; every purchase, hatch, sale, lock and rebirth is validated
server-side before money moves.

## License

MIT — see `LICENSE`.
