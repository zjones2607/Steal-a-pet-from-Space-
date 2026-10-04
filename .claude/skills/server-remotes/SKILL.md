---
name: server-remotes
description: Write or review client/server communication — RemoteEvents, RemoteFunctions, ProximityPrompts, purchases, rewards or anything a player triggers that changes the game. Use whenever adding a button, pickup, shop action or reward, so exploiters can't grant themselves items.
---

# Client/server code

Assume every client is an exploiter. Anything arriving from a client — `OnServerEvent` arguments, `ProximityPrompt.Triggered`, `ClickDetector` clicks — is a request, not a fact.

## Where things go

- Granting items, currency, pets, eggs or upgrades: **server only** (`src/ServerScriptService`).
- UI, effects, toasts, local fades: client (`StarterGui/SpaceGUI`, `StarterPlayerScripts`).
- The server tells the client what happened with `:FireClient` (see `PlanetEggPickupFeedback` used by `PlanetEggCollection` → `PlanetEggFeedback`).

## Checklist for a server handler

Model it on `PlanetEggCollection.server.luau`:

1. **Data loaded** — `if not player:GetAttribute("DataLoaded") then return end`.
2. **Validate types** of every argument (`typeof(x) == "string"`, numbers finite and in range). Look items up in a server-side table by key; never take a price, amount or reward from the client.
3. **Character alive and close enough** for anything physical: check `HumanoidRootPart` distance against the prompt's `MaxActivationDistance` (+ a small margin) and `Humanoid.Health > 0`.
4. **Target still valid** — e.g. `egg:IsDescendantOf(map)`.
5. **Not already done** — one-time rewards keep a server-side record (the `EggDiscoveries` markers).
6. **Rate-limit** anything that can be spammed (store `os.clock()` per player).
7. Then change state, then `FireClient` the result.

## SpaceGUI actions

The shop sends `remote:FireServer(action, value)` on the RemoteEvent named `Config.ActionRemoteName` (`SpaceGUIAction`) in ReplicatedStorage. The GUI never grants anything itself. When wiring a new action:

- Handle it in a server script with an explicit allow-list of action names.
- Keep `Config.PurchasesEnabled` / `Config.GiftsEnabled` false until the server grants **and saves** the reward (see `saved-data`).
- Real-money purchases must go through `MarketplaceService.ProcessReceipt` on the server, granting before returning `PurchaseGranted`.

## Remote instances

RemoteEvents live in Studio/`game.rbxl`, not in `src/`. Either create them on the server at startup if missing, or tell the user exactly which RemoteEvent to add and where. Clients should `WaitForChild` them.
