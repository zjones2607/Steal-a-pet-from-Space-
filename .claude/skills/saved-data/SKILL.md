---
name: saved-data
description: Make player progress persist across sessions, or change what is saved. Use when adding currency, stats, inventory, pets, upgrades or anything a player should keep after leaving, or when touching PlayerSaving.server.luau or DataStores.
---

# Saving player data

All persistence goes through `src/ServerScriptService/PlayerSaving.server.luau`. Don't create another DataStore or call `GetDataStore` from other scripts — two writers on the same player will overwrite each other, and PlayerSaving's session lock only protects its own saves.

## What PlayerSaving can store

- **Player attributes** listed in `SAVED_ATTRIBUTES` (numbers, strings, booleans).
- **Folders under the player** listed in `SAVED_FOLDERS`. Everything inside is saved recursively, as long as it is made of `Folder`, `IntValue`, `NumberValue`, `BoolValue` or `StringValue`, plus number/string/boolean attributes on those. Other instance types are silently skipped.

## Adding something new to save

1. Store it on the player as an attribute or inside a folder parented to the player, created **on the server**.
2. Add its name to `SAVED_ATTRIBUTES` or `SAVED_FOLDERS`.
3. In the script that owns it, create the default only if it doesn't exist yet (see `inventory()` in `PlanetEggCollection.server.luau`) — PlayerSaving may already have loaded a saved value.
4. Gate every change on the load finishing:

   ```lua
   if not player:GetAttribute("DataLoaded") then return end
   ```

   Changes made before `DataLoaded` are overwritten by the loaded save.

## Rules

- **Never change `STORE_NAME`** (`PlayerData_v1`) unless the user explicitly wants to wipe everyone's progress. Renaming it makes every player start over.
- **Never rename a saved attribute or folder** without migrating: old saves keep the old name. Add migration in `apply()` (read the old key, write the new one) rather than renaming in place.
- Keep the save small. A DataStore value is capped at 4 MB, and each `UpdateAsync` per key is rate-limited — don't call `save()` on every change; the autosave (`AUTOSAVE_EVERY`), leave and shutdown saves already cover it.
- Leave the session lock (`load`/`save`/`release`) and `BindToClose` logic intact. If you must change them, explain the server-hop scenario you've reasoned through.
- Clients can read replicated attributes and folders but must never be trusted to set them — see the `server-remotes` skill.

## Testing

Saving only works in Studio when **Game Settings → Security → Enable Studio Access to API Services** is on; otherwise PlayerSaving warns and skips. Tell the user to test by playing, changing the value, stopping, and playing again.
