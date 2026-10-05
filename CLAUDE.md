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
    - **The base has been moved in the owner's place.** The whole SpaceStation sits about 1000 studs higher than the builder put it. So never assume world coordinates: measure from the base itself.
    - `RideARocketExpansion` measures everything from the spawn plaza: base origin = `SpawnHub.PlazaRim` centre minus `Y0`.
    - `StationClaims` and `RideARocketLaunchSiteBuilder` aim at the plaza's real position.
  - `RideARocketExpansion`: run with `require(game.ServerStorage.RideARocketExpansion).Apply()`.
    - It grows the spawn plaza (radius 80) and moves the wall out to a fixed 410 (`Apply({force = true, wallApothem = n})` to change). Auto-probing the ground edge was removed: the planet's collision hull doesn't match its visible rim. It also builds a fenced 110×51 pet pen behind each of the 8 stations: `StationPlot<i>.PetPen`, whose `Floor` part is the walkable grass slab. The fence opening faces the station.
    - v4 replaced the old crop farms (`Farm`) with these pens. It moves any MapDetailer decor that lands inside a pen to `ServerStorage.RemovedMapBackups.Decor_InPetPens`. After re-running the MapDetailer, run `Apply({force = true})`.
    - `ClearPaths()` (also part of `Apply`) slides loose decor (BaseDecor and the detailer's `Detail` items on the planet top) sideways off the walkways and entry paths.
    - It's versioned through the `ExpansionVersion` attribute on `SpaceStation`. Every step is idempotent, so to change the pens, edit `buildPen`, bump `VERSION`, and have them run `Apply()` again.
    - The current version is 4. The owner has run at least v3.
  - `RideARocketLaunchSiteBuilder`: run with `require(game.ServerStorage.RideARocketLaunchSiteBuilder).Apply()` (`Revert()` undoes it).
    - Each site has a cartoon `LaunchPadSign` on the gantry: a marquee-lit board with a SurfaceGui. Every part of the sign is non-collidable decoration.
    - Rebuilt sites keep the MapDetailer's metal finishes (`OriginalMaterial`).
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
  - Saved now: `EggsCollected`, `Coins`, `Jetpack`, `CoinBoostEndsAt`, `LuckBoostEndsAt` and `PenLevel` (attributes), and `EggInventory`, `EggDiscoveries`, `OwnedJetpacks`, `SpaceGUIData`, `PurchaseHistory` and `IncubatingEggs` (folders).
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
- **Admin panel**: `AdminPanel.server.luau` decides who's an admin when they join. That's the game owner (or group rank 254+), `ADMIN_USERNAMES` (includes the owner, `ZJONES262007`), and every player in Studio, including the negative-UserId test players from Test > Clients.
  - Only admins get `ServerStorage.AdminPanelClient` copied into their PlayerGui.
  - Every `AdminRemote` request re-checks admin status and validates its arguments. Keep it that way when adding actions to the `actions` table.
  - Announcements are filtered with TextService and shown to everyone by `Announcements.client.luau`.
  - The Give tab lets an admin give **themselves** (never others) coins (Give or Set), any number of copies of a pet (`ServerStorage.GivePet`), or any jetpack (owned and equipped).
  - The Eggs tab instantly hatches pen eggs: the admin's own, everyone's in this server, or everyone's in every server (MessagingService topic `AdminInstantHatch`). It calls `ServerStorage.InstantHatch`.
- **Pets, boosts and the Robux shop**: `PetsAndShop.server.luau` is the server side of SpaceGUI's Eggs, Pets, Boosts and Shop pages.
  - **Eggs hatch in the pen on a timer.** Collected or bought eggs land in `EggInventory`, and PetsAndShop moves them straight into the player's `IncubatingEggs` folder.
    - Each egg there is a StringValue `Egg1..EggN` (its spot in the pen). Its kind is in `Value`, and it has the attributes `HatchAt` (unix time) and `Seconds`.
    - Up to `Config.PenEggSlots` (12) fit at once; the rest wait in `EggInventory` and move in as eggs hatch.
    - The timer is `Config.EggHatchSeconds` (60), or `EggHatchSecondsByKind`. The x2 Growth pass halves it.
    - The 1-second loop hatches due eggs (also while offline, on the next join) and fires `"Hatched"` for each one.
    - `PenEggs.client.luau` shows them in nests along the back fence of each pen, with a countdown, and they wobble harder near hatching. SpaceGUI's Eggs page lists them (`Pen_EggN` entries in `SpaceGUIData.Eggs`) with live timers.
    - `ServerStorage.InstantHatch` (BindableFunction) hatches one player's pen eggs now and returns how many.
  - It creates the `SpaceGUIAction` RemoteEvent and handles `HatchEgg` (now only moves waiting eggs into the pen), `TogglePet`, `EquipBest`, `UseBoost`, `SetSlowMode` and `GiftItem`. It fires `("Hatched", petId)` and `("Notice", text)` back to the client.
  - Each player gets a `SpaceGUIData` folder with `Eggs`, `Pets` and `Boosts` (StringValues). `Eggs` is a copy of `EggInventory`, rebuilt on every change.
  - Hatching uses the odds in `SpaceGUIConfig.Pets`.
  - **Every pet is its own entry**: a StringValue `Pet<N>` in `SpaceGUIData.Pets` with the kind in `Value`, and the attributes `Size`, `Kg`, `Power`, `Equipped` and `DisplayName`. The folder's `NextId` attribute numbers new pets.
    - Sizes roll from `Config.PetSizes`. `Kg` = `BaseKg` × size, and the pet earns `Config.PetIncome(kind, size)` = Income × size (rounded, at least 1). Sizes of 2+ show as BIG and 3+ as HUGE.
    - Old saves (one entry per kind with `Count`) are split into single size-1 pets by `migratePets` on load.
    - Any mix of pets can be equipped, up to the pen's capacity. New pets go straight in while there's room. Equip Best fills the pen with the best pets: most coins/s, then rarest, then heaviest.
    - `PetPower` is the 3 strongest equipped pets' Power, so `CoinMultiplier` = 1 + PetPower/100 (× boosts). `CoinPickups` multiplies coins by `CoinMultiplier`.
  - **Pet income**: equipped pets earn coins every second. Each `SpaceGUIConfig.Pets` entry has `Income` (coins/s per copy), and `refresh()` sets three player attributes:
    - `PenPets`: "Pet12:astro_dog:1.25:3,..." (name, kind, size, coins/s before boosts) for every pet in the pen, best first
    - `IncomeMultiplier`: x2 for the Coins boost, x2 for the Credits pass
    - `PetIncome`: the total coins/s
    - The 1-second loop adds `PetIncome` to `Coins`, but only for players whose data has loaded.
  - **Pens**: `PetPens.client.luau` builds every pet in each claimed station's pen (up to 30), scaled by √size so big pets look bigger, from `SpaceModels` on each device.
    - They roam inside `PetPen.Floor`, each with a name and "+N/s" billboard.
    - Only pens near the camera are animated.
    - Unequipped pets stay in the inventory only.
    - `PetFollowers.client.luau` is a retired no-op stub (pets no longer follow players) and can be deleted.
  - **Pen upgrades**: a pen holds `Config.PenCapacity(PenLevel)` pets (10, +1 per level, max level 20 = 30 pets). Upgrades cost `Config.PenUpgradeCost(level)` coins (1,000 growing ×1.35) and are bought only from the Pet Pen card at the top of SpaceGUI's Pets page (`UpgradePen` action).
    - `refresh()` sets `PenCapacity` and `PenPetCount`.
    - `PenSigns.server.luau` keeps the "PET PEN  N / C PETS" sign on every pen up to date. It takes over the old Studio-made sign if it finds one, otherwise it builds its own over the fence opening. It also deletes any old "Upgrade Pen" ProximityPrompt.
  - Boosts (`CoinBoost`, `LuckBoost`) drop from 15% of hatches. Their end times are saved unix times.
  - Robux: rewards are in `PRODUCT_REWARDS` and `PASS_KEYS`. Product IDs come from `SpaceGUIConfig`. Speed packs have no reward yet.
  - SpaceGUI's Pets page (`makePets`) lists every pet on its own row, best first, with its kg (and BIG/HUGE), coins/s, rarity and whether it's in the pen. It has a search box (name or rarity), a rarity Filter button, Equip Best, and shows 30 rows at a time with a "Show more" button. The server fires `("Hatched", petId, {Kg, Size, Income, New})`. Hatching shows a reveal card (`playHatch`: 3D pet, name, rarity, kg, coins/s, NEW! tag) that stays until clicked; hatches in a row queue up.
  - SpaceGUI's "Credits" stat shows the player's `Coins`. It counts up smoothly, and shows a green "+N/s" badge from `PetIncome`.

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
