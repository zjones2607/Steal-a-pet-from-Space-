---
name: add-script
description: Add, rename, move or delete a Luau script in this Roblox/Rojo project. Use whenever a file under src/ is created, renamed, moved or removed, or when default.project.json is edited, so the script actually shows up in Studio.
---

# Adding a script

Rojo only syncs scripts that are listed in `default.project.json`. A file in `src/` with no entry never reaches Studio, and an entry whose file is missing breaks `rojo serve`.

## Steps

1. **Pick the folder** by where the script runs:

   | Runs on / used by | Folder | Studio location |
   |---|---|---|
   | Server logic | `src/ServerScriptService` | ServerScriptService |
   | Server-only modules, one-off Studio tools | `src/ServerStorage` | ServerStorage |
   | Shop / HUD UI | `src/StarterGui/SpaceGUI` | StarterGui → SpaceGUI |
   | Per-player client logic | `src/StarterPlayer/StarterPlayerScripts` | StarterPlayerScripts |

2. **Pick the file ending** — it decides the script type:
   - `Name.server.luau` → Script
   - `Name.client.luau` → LocalScript
   - `Name.luau` → ModuleScript (must `return` a value)

3. **Start the file with a short header comment**: what it does, and for modules, how to call it. Match the existing files, e.g.:

   ```lua
   -- StationUpgrades: show/hide a station's upgrade deck rings.
   -- Usage (server):  require(game.ServerScriptService.StationUpgrades).SetTier(plotModel, 2)
   ```

4. **Add the entry to `default.project.json`** under the matching service, next to its siblings, keeping keys alphabetical. The key is the instance name in Studio (no `.server`/`.client`):

   ```json
   "MyScript": {
     "$path": "src/ServerScriptService/MyScript.server.luau"
   }
   ```

   Never remove `"$ignoreUnknownInstances": true` from a service — without it Rojo deletes everything in that service that isn't in `src/` (parts, GUIs, RemoteEvents).

5. **Validate**:

   ```bash
   python3 .claude/skills/add-script/scripts/check_project.py
   ```

   It fails if a `$path` points to a missing file or a `.luau` file in `src/` has no entry.

## Renaming, moving or deleting

Change the file and its `default.project.json` entry in the same commit, then run the check. If other scripts `require` or `WaitForChild` it by name, update those too (`grep -rn "OldName" src/`).

## Things that are not scripts

Parts, GUI elements, RemoteEvents, values in `ReplicatedStorage` and so on live only in `game.rbxl`/Studio. Don't try to create them through `default.project.json`. Either create them from code at runtime (`Instance.new`, like `PlanetEggFeedback.client.luau` builds its own GUI), or tell the user exactly what to add in Studio. `game.rbxl` is a binary snapshot — never edit it.
