# Steal a Pet from Space: notes for Claude

A Roblox game ("Ride a Rocket!"). The owner and other developers don't write code. They ask Claude for every change and do only the Studio steps themselves. Explain those steps plainly and number them, and ask for a screenshot when something goes wrong.

## How the project fits together

- **Scripts** live in `src/` and are synced into Studio by **Rojo 7.7.1**. Run it with `rojo serve`, and the Studio plugin must be 7.7.x too: a 7.6 plugin fails with "Can't parse JSON".
  - Every script is mapped explicitly in `default.project.json`, with `$ignoreUnknownInstances`, so Rojo never touches parts, GUIs or RemoteEvents. **A new script must be added to `default.project.json`**, or it won't sync.
  - File endings: `.server.luau` is a Script, `.client.luau` is a LocalScript, plain `.luau` is a ModuleScript.
- **Everything else** (map, parts, GUI instances) lives only in the Studio place. `game.rbxl` is a snapshot of it, but it's **stale**: it predates the plaza/wall/farm expansion. Don't assume it shows the current map.
- **Map changes are made with builder scripts in `src/ServerStorage`**, not by hand. The developer runs one command in Studio's command bar in edit mode (not Play), then saves/publishes.
  - `RideARocketBaseBuilder`: built the space station base. The layout constants are at the top: `Y0=8`, `R_PLOT=272`, `PLOT_R=81.6`, `HUB_R=50`.
  - `RideARocketExpansion`: run with `require(game.ServerStorage.RideARocketExpansion).Apply()`.
    - It grows the spawn plaza (radius 80), moves the wall out (~417), and adds a 110×51 farm behind each of the 8 stations, parented to `StationPlot<i>.Farm`, with `CropSlot` attributes on each crop.
    - It's versioned through the `ExpansionVersion` attribute on `SpaceStation`. Every step is idempotent, so to change the farms, edit `buildFarm`, bump `VERSION`, and have them run `Apply()` again.
    - The current version is 3. The owner has run at least v2.
- **Saving**: `src/ServerScriptService/PlayerSaving.server.luau` uses the DataStore `PlayerData_v1` with a per-session lock.
  - To save something new, add a player attribute or folder name to `SAVED_ATTRIBUTES` / `SAVED_FOLDERS`.
  - Other scripts must wait for the player's `DataLoaded` attribute before changing saved data. `PlanetEggCollection` already does.
- **Stations**: `StationClaims.server.luau` gives each joining player the first free `StationPlot1..8` and spawns them on its pad, facing the airlock (also after respawning).
  - Ownership is stored in the plot attributes `OwnerUserId`/`OwnerName` and the player attribute `Station`. Use these to find a player's station or farm.
  - An `OwnerSign` billboard above each claimed station shows only the owner's username; it's hidden on free stations. `StationOwnerLabels.client.luau` turns your own sign gold.
  - A station's tier resets to 0 when its owner leaves. A 9th player gets no station and stays at the plaza, so max players should be 8.
- **Not built yet**: Credits, pets, boosts and the shop. `SpaceGUI` has the UI for these and talks to a `SpaceGUIAction` RemoteEvent and a `SpaceGUIData` folder that no server script creates yet. See `SpaceGUIConfig`.

## Working in a cloud session

- **Tools**: GitHub release downloads are blocked, but crates.io works.
  - `cargo install rojo --version 7.7.1 --locked`
  - `cargo install lune --locked`
- **Reading the place**: convert `game.rbxl` with `tools/rbxl-to-rbxlx` (`cargo run --release -- game.rbxl out.rbxlx`), then parse the XML.
- **Testing map scripts**: load the place in Lune with `roblox.deserializePlace` and run the module through `luau.load` with an environment that provides `workspace`, `game`, `Instance`, `CFrame`, etc. Check the result, and render top-down images if useful.
  - **Lune's `CFrame.lookAt` returns the inverse rotation.** It looks right on the axes and wrong on diagonals. In tests, swap in a correct `lookAt` built with `CFrame.fromMatrix`.
  - Lune can't read `BasePart.Position`, so use `CFrame.Position` in code that Lune runs. That works the same in Studio.
  - Lune can't raycast, so wrap Studio-only calls in `pcall`.
- **Testing server scripts**: run them in Lune with fake services, such as a fake DataStore that round-trips through JSON. Call `process.exit()` at the end, because background loops keep Lune alive.
- **Before every push**, run `rojo build -o /tmp/check.rbxlx`.

## Git workflow

The owner wants changes merged to `main` so they can pull them in GitHub Desktop.
1. Work on the session's branch, rebased on the latest `main`.
2. Open a PR and merge it.
3. Tell the owner to **Fetch origin → Pull origin**, plus any command to run in Studio, then **File → Publish to Roblox**.
