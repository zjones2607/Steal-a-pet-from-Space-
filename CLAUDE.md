# Steal a Pet from Space: notes for Claude

A Roblox game ("Ride a Rocket!"). The owner and other developers don't write code. They ask Claude for every change and do only the Studio steps themselves. Explain those steps plainly and number them, and ask for a screenshot when something goes wrong.

## How the project fits together

- **Scripts** live in `src/` and are synced into Studio by **Rojo 7.7.1**. Run it with `rojo serve`, and the Studio plugin must be 7.7.x too: a 7.6 plugin fails with "Can't parse JSON".
  - Every script is mapped explicitly in `default.project.json`, with `$ignoreUnknownInstances`, so Rojo never touches parts, GUIs or RemoteEvents. **A new script must be added to `default.project.json`**, or it won't sync.
  - File endings: `.server.luau` is a Script, `.client.luau` is a LocalScript, plain `.luau` is a ModuleScript.
  - Edit scripts in `src/`, not in Studio: a connected Rojo overwrites Studio with the repo version. Every script in the place is in the repo except two disabled backups in `ServerStorage` (`RemovedMapBackups`, `SpaceGUI_Backup_v1`).
  - Windows checkouts use CRLF (`core.autocrlf`) while Studio uses LF, so file sizes differ from Studio's by one byte per line even when the code is identical.
  - `ReplicatedStorage.Shared.Hello`, `ServerScriptService.Server` and `StarterPlayerScripts.Client` are leftovers from Rojo's template that only print "Hello world". They're safe to delete.
- **Never edit a Rojo-managed script inside Studio.** Rojo overwrites it with the repo copy the next time anyone connects, and the Studio edit is lost. Change the file in `src/` instead.
- **Everything else** (map, parts, GUI instances) lives only in the Studio place. `game.rbxl` is a snapshot of it, but it's **stale**: it predates the plaza/wall/farm expansion. Don't assume it shows the current map.
- **Map changes are made with builder scripts in `src/ServerStorage`**, not by hand. The developer runs one command in Studio's command bar in edit mode (not Play), then saves/publishes.
  - `RideARocketBaseBuilder`: built the space station base. The layout constants are at the top: `Y0=8`, `R_PLOT=272`, `PLOT_R=81.6`, `HUB_R=50`.
  - `RideARocketExpansion`: run with `require(game.ServerStorage.RideARocketExpansion).Apply()`.
    - It grows the spawn plaza (radius 80), moves the wall out (~417), and adds a 110×51 farm behind each of the 8 stations, parented to `StationPlot<i>.Farm`, with `CropSlot` attributes on each crop.
    - It's versioned through the `ExpansionVersion` attribute on `SpaceStation`. Every step is idempotent, so to change the farms, edit `buildFarm`, bump `VERSION`, and have them run `Apply()` again.
    - The current version is 3. The owner has run at least v2.
  - `RideARocketLaunchSiteBuilder`: run with `require(game.ServerStorage.RideARocketLaunchSiteBuilder).Apply()` (`Revert()` undoes it).
    - It swaps the satellite on each base (`StationPlotN.Core.SS_*`) for a jetpack launch site, and keeps the old parts in `ServerStorage.RemovedMapBackups.Satellites_BeforeLaunchSites`.
    - Each site has an invisible `LaunchZone` part tagged `LaunchZone`, with a `SpawnPoint` attachment for the base teleport.
    - Run it again after re-running `RideARocketBaseBuilder`.
  - `RideARocketMapDetailer`: run with `require(game.ServerStorage.RideARocketMapDetailer).Apply()` (`Revert()` undoes it).
    - It restyles the map as the real solar system without moving anything: the station's planet becomes Earth, and the five floating planets become the Moon, Mars, Mercury, Venus and Jupiter.
    - Added parts go in `Detail` folders, removed decorations go in `ServerStorage.RemovedMapBackups.Decor_BeforeRealPlanets`, and changed parts keep their old looks in `Original...` attributes.
    - Run it again after re-running `RideARocketBaseBuilder` or `RideARocketMapBuilder`.
- **Saving**: `src/ServerScriptService/PlayerSaving.server.luau` uses the DataStore `PlayerData_v1` with a per-session lock.
  - To save something new, add a player attribute or folder name to `SAVED_ATTRIBUTES` / `SAVED_FOLDERS`.
  - Other scripts must wait for the player's `DataLoaded` attribute before changing saved data. `PlanetEggCollection`, `CoinPickups` and `Jetpacks` already do.
  - Saved now: `EggsCollected`, `Coins` and `Jetpack` (attributes), and `EggInventory`, `EggDiscoveries` and `OwnedJetpacks` (folders).
- **Coins and jetpacks**: these are the game's main progression.
  - **Coins**: `CoinPickups.server.luau` scatters 18 coins on each planet. They're worth 5/15/40/100/250 on planets 01–05 and reappear elsewhere 15s after pickup. Touching one adds to the player's `Coins` attribute, and `CoinEffects.client.luau` spins the coins and shows "+value" pop-ups.
  - **Jetpack data**: tiers and prices are in `ReplicatedStorage.Jetpacks.JetpackConfig`, and `JetpackModels` builds them from Parts.
  - **Server**: `Jetpacks.server.luau` creates the `BuyJetpack`, `EquipJetpack`, `JetpackThrust` and `TeleportToLaunchSite` remotes in that folder. It also straps the equipped jetpack to each player's back.
  - **Flying**: it happens on the client in `JetpackFlight`, which is triggered by SpaceGUI's LAUNCH button. It only works inside a `LaunchZone`.
  - **Missing UI**: nothing in the repo's `SpaceGUIController` requires `JetpackFlight` or shows a Jetpacks page or LAUNCH button. That UI was added to SpaceGUI inside Studio, and Rojo replaced it with the older repo copy. Recover it from Studio's version history (or rebuild it) before relying on it.
  - Each tier can climb to just above one planet. The server works out these heights from the planet positions when it starts, as `Ceiling_<Id>` attributes, so moving planets doesn't break flying.
- **Stations**: `StationClaims.server.luau` gives each joining player the first free `StationPlot1..8` and spawns them on its pad, facing the airlock (also after respawning).
  - Ownership is stored in the plot attributes `OwnerUserId`/`OwnerName` and the player attribute `Station`. Use these to find a player's station or farm.
  - An `OwnerSign` billboard above each claimed station shows only the owner's username; it's hidden on free stations. `StationOwnerLabels.client.luau` turns your own sign gold.
  - A station's tier resets to 0 when its owner leaves. A 9th player gets no station and stays at the plaza, so max players should be 8.
- **Admin panel**: `AdminPanel.server.luau` decides who's an admin when they join. That's the game owner (or group rank 254+), `ADMIN_USERNAMES`, and any real account in Studio.
  - Only admins get `ServerStorage.AdminPanelClient` copied into their PlayerGui.
  - Every `AdminRemote` request re-checks admin status and validates its arguments. Keep it that way when adding actions to the `actions` table.
  - Announcements are filtered with TextService and shown to everyone by `Announcements.client.luau`.
- **Not built yet**: pets, boosts and the Robux shop.
  - `SpaceGUI` has the UI for these, and talks to a `SpaceGUIAction` RemoteEvent and a `SpaceGUIData` folder that no server script creates yet. See `SpaceGUIConfig`.
  - SpaceGUI's "Credits" stat shows the player's `Coins`.

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
