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
  - Saved now: `EggsCollected`, `Coins`, `Jetpack`, `CoinBoostEndsAt` and `LuckBoostEndsAt` (attributes), and `EggInventory`, `EggDiscoveries`, `OwnedJetpacks`, `SpaceGUIData` and `PurchaseHistory` (folders).
  - `ServerStorage.SavePlayerNow` (a BindableFunction) saves one player at once and returns whether it worked. Robux purchases use it.
- **Coins and jetpacks**: these are the game's main progression.
  - **Coins**: `CoinPickups.server.luau` scatters 18 coins on each planet. They're worth 5/15/40/100/250 on planets 01–05 and reappear elsewhere 15s after pickup. Touching one adds to the player's `Coins` attribute, and `CoinEffects.client.luau` spins the coins and shows "+value" pop-ups.
  - **Jetpack data**: tiers and prices are in `ReplicatedStorage.Jetpacks.JetpackConfig`, and `JetpackModels` builds them from Parts.
  - **Server**: `Jetpacks.server.luau` creates the `BuyJetpack`, `EquipJetpack`, `JetpackThrust` and `TeleportToLaunchSite` remotes in that folder. It also straps the equipped jetpack to each player's back.
  - **Flying**: it happens on the client in `JetpackFlight`. It only works inside a `LaunchZone`, which `RideARocketLaunchSiteBuilder` puts on each station.
  - **Shop**: the Jetpacks page in SpaceGUI (4th right-column button, with the vector `Jetpack` icon from `SpaceIcons`).
    - It lists every tier cheapest first, each spinning in a ViewportFrame, with its coin price in a gold pill and a Buy / Equip / Equipped button that calls the remotes.
    - Unowned jetpacks are greyed out and see-through.
    - The page re-renders when coins, the equipped jetpack or `OwnedJetpacks` change.
  - **Flight controls**: `JetpackHUD.client.luau` draws cartoon buttons in SpaceGUI's style. It's the only script that requires `JetpackFlight`.
    - LAUNCH (F key) slides up from the bottom while you stand in a `LaunchZone` and drops away when you leave it. It breathes, a shine sweeps across it, and it turns grey while recharging.
    - MY PAD (T key) is shown instead while you're off the pad and teleports you to your launch pad.
    - Both buttons slide away while a menu is open. SpaceGUI sets the local player attribute `SpaceGUIOpen` and the admin panel sets `AdminPanelOpen`; add any new window's attribute to `MENU_ATTRIBUTES`.
    - T still teleports while the buttons are hidden, but F only launches while LAUNCH is showing.
  - Each tier can climb to just above one planet. The server works out these heights from the planet positions when it starts, as `Ceiling_<Id>` attributes, so moving planets doesn't break flying.
- **Stations**: `StationClaims.server.luau` gives each joining player the first free `StationPlot1..8` and spawns them on its pad, facing the airlock (also after respawning).
  - Ownership is stored in the plot attributes `OwnerUserId`/`OwnerName` and the player attribute `Station`. Use these to find a player's station or farm.
  - An `OwnerSign` billboard above each claimed station shows only the owner's username; it's hidden on free stations. `StationOwnerLabels.client.luau` turns your own sign gold.
  - A station's tier resets to 0 when its owner leaves. A 9th player gets no station and stays at the plaza, so max players should be 8.
- **Admin panel**: `AdminPanel.server.luau` decides who's an admin when they join. That's the game owner (or group rank 254+), `ADMIN_USERNAMES`, and any real account in Studio.
  - Only admins get `ServerStorage.AdminPanelClient` copied into their PlayerGui.
  - Every `AdminRemote` request re-checks admin status and validates its arguments. Keep it that way when adding actions to the `actions` table.
  - Announcements are filtered with TextService and shown to everyone by `Announcements.client.luau`.
- **Pets, boosts and the Robux shop**: `PetsAndShop.server.luau` is the server side of SpaceGUI's Eggs, Pets, Boosts and Shop pages.
  - It creates the `SpaceGUIAction` RemoteEvent and handles `HatchEgg`, `TogglePet`, `EquipBest`, `UseBoost`, `SetSlowMode` and `GiftItem`. It fires `("Hatched", petId)` and `("Notice", text)` back to the client.
  - Each player gets a `SpaceGUIData` folder with `Eggs`, `Pets` and `Boosts` (StringValues). `Eggs` is a copy of `EggInventory`, rebuilt on every change.
  - Hatching uses the odds in `SpaceGUIConfig.Pets`. Pets stack one entry per kind: duplicates raise `Count` and `Power`. Up to 3 are equipped, which sets the player attributes `EquippedPets`, `PetPower` and `CoinMultiplier`. `CoinPickups` multiplies coins by `CoinMultiplier`.
  - `PetFollowers.client.luau` builds the equipped pets with `SpaceModels` on each device and floats them behind their owner.
  - Boosts (`CoinBoost`, `LuckBoost`) drop from 15% of hatches. Their end times are saved unix times.
  - Robux: rewards are in `PRODUCT_REWARDS` and `PASS_KEYS`. Product IDs come from `SpaceGUIConfig`. Speed packs and the x2 Growth pass have no reward yet.
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
