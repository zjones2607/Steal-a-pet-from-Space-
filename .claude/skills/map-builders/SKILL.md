---
name: map-builders
description: Change the map, base, stations, farms or other world geometry through the builder modules in src/ServerStorage (RideARocketMapBuilder, RideARocketBaseBuilder, RideARocketExpansion). Use for any request to move, add, recolor or resize parts of the world.
---

# Map builder modules

The world is built by ModuleScripts in `src/ServerStorage` that the user runs **once from Studio's command bar in edit mode** (not Play). The results are then saved into the place. They are not run by the game at runtime.

| Module | Entry points | Purpose |
|---|---|---|
| `RideARocketMapBuilder` | `Build(kitFolder, opts)`, `RestyleStations(kitFolder)` | Assembles the map from the Blender kit |
| `RideARocketBaseBuilder` | `RebuildBase(kitFolder, opts)`, `TonePlanets(amount)` | Player-scaled space base |
| `RideARocketExpansion` | `Apply(opts)` | Plaza growth, wall, farms behind stations |

## Rules

- **Make edits idempotent.** Running twice must not duplicate parts. Follow `RideARocketExpansion`: a `VERSION` constant, an attribute on the target model (`ExpansionVersion`), early return unless `opts.force`, and remove/replace old parts by name before creating new ones.
- **For a new change to an existing base, prefer a new step or module** over editing an earlier builder, since the user's place already contains that builder's output. Bump `VERSION` when changing what `Apply` does.
- **Keep layout constants in sync.** `RideARocketExpansion` copies values from `RideARocketBaseBuilder` (`Y0`, `R_PLOT`, `PLOT_R`); change both or neither.
- Runtime scripts look things up by name (`JetpackPetRescueMap`, `SpaceStation`, `StationPlot1..8`, `Tier1..3`, `LockedOutline1..3`, `PetSlot`, `CollectEgg` prompts with `EggId`/`EggType` attributes). Don't rename these, or update every `grep -rn` hit.
- Wrap the edit in a `ChangeHistoryService:TryBeginRecording(...)` / `FinishRecording(..., Commit)` pair (inside `pcall`, as `Apply` does) so the user can undo it with Ctrl+Z.
- Use the existing palette tables (`C`, `rgb(...)`) and part helper (`block(...)`) rather than ad-hoc colors.
- Anchor everything; set `CanCollide`/`CanQuery` deliberately for decoration.

## Handing off to the user

Finish with the exact command-bar line to run, e.g.

```lua
require(game.ServerStorage.RideARocketExpansion).Apply()
```

and remind them to have `rojo serve` connected first so Studio has the new module, then to save the place (and re-export `game.rbxl` if they want the repo snapshot updated). You can't run Studio or edit `game.rbxl` from here.
