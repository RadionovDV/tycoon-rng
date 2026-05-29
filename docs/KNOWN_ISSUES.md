# KNOWN_ISSUES.md — Bugs, Risks, and What NOT to Break

## Known Issues

### 1. Circular requires (runtime, safe)
`UpgradeService.Purchase()`, `LocationService.Unlock()`, and `RebirthService.PerformRebirth()` all `require(script.Parent.CombatService)` at runtime to call `SpawnEnemiesForPlayer()` / `ClearPlayer()`. This works because the require happens inside a function, not at module scope. Do NOT move these requires to module top-level — that would create a circular dependency loop.

### 2. File content duplication (disk error — src/ only)
Two files in `src/shared/` contain wrong content (confirmed by disk read):
- `src/shared/noYield.lua` contains `mergeArraysUniqueOnly` code instead of the noYield wrapper
- `src/shared/ThreadQueue.lua` contains `TableUtils` code instead of ThreadQueue implementation

These duplicates exist only in the `src/` workspace copy. The actual Roblox Studio modules have the correct implementations. Do NOT re-copy these files to Studio.

### 3. Location name mismatch risk
`LocationService._initBaseplateTriggers()` uses `Workspace:GetChildren()` and matches against `LocationConfig[location.Name]`. If a Location folder in Workspace is named differently from its config key, the baseplate trigger silently skips it. Currently all 3 locations match.

### 4. Rebirth teleport may fail if character is dead
`RebirthService.PerformRebirth()` teleports via `root.CFrame = spawnPart.CFrame`. If the player's character is destroyed (death during rebirth), `player.Character` is nil and teleport is skipped. The player spawns at default spawn on next respawn. Acceptable for MVP.

### 5. Pet ID collision on server restart
Pet IDs are `petType_<count>`. After DataStore load, `#pets` continues from the saved count. If pets are removed in a future feature, IDs may collide.

### 6. ConfirmationMenu popup stacking
RebirthController clones ConfirmationMenu from ReplicatedStorage each time. If the player double-clicks the rebirth button rapidly before the popup appears, multiple popups stack. Currently no debounce on button click.

### 7. Roll cooldown is per-server (not per-DataStore)
`lastRollTime` is an in-memory table. Server restart resets cooldown. Intentional for MVP.

### 8. EnemyKills only increments on pet damage kill
`enemyKills` is incremented only when an enemy dies from pet damage (in `CombatService._processEnemyDamage`). Enemies that despawn on location change or server restart do not count as kills.

## Risks — What NOT to Break

1. **PlayerData system** — Do NOT modify `PlayerDataServer` or `PlayerDataClient` modules. Stable external dependencies.

2. **RemoteEvents** — Do NOT delete or rename any existing RemoteEvent. Add new ones only after user approval.

3. **RollService anti-spam** — `lastRollTime` cooldown is the only anti-cheat. Removing it allows spam-rolling.

4. **Economy validation** — `SubtractCoins` and `SubtractCurrency` must remain server-authoritative. Never do currency math on the client.

5. **CombatService tick** — crashes on one player are caught by `pcall`, but if `PlayerService.GetValue` throws, all subsequent players in that tick are skipped.

6. **Pet HP is not persisted** — stored only in-memory `petCombat`. On server restart all pets are revived. Acceptable for MVP.

7. **Rebirth uses PlayerService.DEFAULT_DATA** — RebirthService references `PlayerService.DEFAULT_DATA` for field reset. If DEFAULT_DATA structure changes, ensure RebirthService retains correct fields (rebirthCount, rebirthBonusLuck, enemyKills).

## Testing Notes
- DataStore warning in Studio: expected when running unpublished. Game uses default data.
- Roll button → check Output for pet result
- Currency: check EconomyController reads after enemy defeats
- Combat: wait 3s+ after loading in, enemies spawn and pets attack
- Location change: walk to another location's Baseplate (must be unlocked first via Gate)
- Rebirth: unlock Location2, collect 5+ pets, open Rebirth window, check requirements