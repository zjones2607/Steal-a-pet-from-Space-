# Steal a Pet from Space

Roblox game ("Ride a Rocket!"), with scripts synced to Studio using [Rojo](https://rojo.space) 7.7.1.

## How it's set up

- `game.rbxl` is a snapshot of the full place: map, parts, GUIs and everything else.
- `src/` holds the scripts. The folders mirror the Studio Explorer:

| Folder | In Studio |
|---|---|
| `src/ServerScriptService` | ServerScriptService |
| `src/ServerStorage` | ServerStorage |
| `src/StarterGui/SpaceGUI` | StarterGui → SpaceGUI |
| `src/StarterPlayer/StarterPlayerScripts` | StarterPlayer → StarterPlayerScripts |

File endings decide the script type: `.server.luau` is a Script, `.client.luau` is a LocalScript and plain `.luau` is a ModuleScript.

Rojo only manages the scripts listed in `default.project.json`. Everything else in Studio, such as parts, GUI elements and RemoteEvents, is left alone.

## Syncing into Studio

1. Open the game in Roblox Studio.
2. In this folder, run:

   ```bash
   rojo serve
   ```

3. In Studio, open the Rojo plugin and click **Connect**.

Changes to files in `src/` now show up in Studio straight away.

## Adding a new script

Create the file in the right `src/` folder, then add an entry for it in `default.project.json`, next to the other scripts in the same place.
