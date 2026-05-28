# KNOWN_ISSUES.md — Bugs, Risks, and What NOT to Break

## Known Issues

### 1. Circular requires (runtime, safe)
`UpgradeService.Purchase()` and `LocationService.Unlock()` both `require(script.Parent.CombatService)` at runtime to call `SpawnEnemiesForPlayer()`. This works because the require happens inside a function, not at module scope. Do NOT move these requires to module top-level — that would create a circular dependency loop.

### 2. File content duplication (disk error)
Two files in `src/shared/` contain wrong content (confirmed by disk read):
- `src/shared/noYield.lua` contains `mergeArraysUniqueOnly` code instead of the noYield wrapper
- `src/shared/ThreadQueue.lua` contains `TableUtils` code instead of ThreadQueue implementation

These file duplicates happen in the src/ folder which is a workspace copy. The actual Roblox Studio modules have the correct implementations since they were placed manually. Do NOT re-copy these files to Studio; the correct versions are already in place.

### 3. Enemy count upgrade does not re-sync visuals
When `moreenemies_1` upgrade is purchased, `CombatService.SpawnEnemiesForPlayer()` runs on the server but the client has no mechanism to spawn new enemy 3D models. This will be addressed in Day 3.

### 4. Equip slot boundary race
When a player equips/unequips rapidly, multiple `updateValue("equippedPets")` calls can race. The server validates slot count at read time but doesn't lock between read and write. Impact: rare double-equip into the same slot. Acceptable for MVP.

### 5. Pet ID collision on server restart
Pet IDs are generated as `petType_<count>` based on `#pets + 1`. After a DataStore load, `#pets` reflects the last count, so new rolls will continue incrementing correctly. However, if pets are removed from the table in a future feature, IDs may collide.

### 6. LocationGate BillboardGui not tested
LocationController handles both SurfaceGui and BillboardGui types via `FindFirstChildOfClass`, but only SurfaceGui has been tested for Location1. Location9 uses BillboardGui.

### 7. Roll cooldown is per-server (not per-DataStore)
`lastRollTime` is an in-memory table. If the server restarts, cooldown resets. This is intentional for MVP.

## Risks

### What NOT to break
1. **PlayerData system** — Do NOT modify `PlayerDataServer` or `PlayerDataClient` modules. They are stable external dependencies.
2. **RemoteEvents** — Do NOT delete or rename any existing RemoteEvent. Add new ones only after user approval.
3. **RollService anti-spam** — The `lastRollTime` cooldown is the only anti-cheat. Removing it would allow spam-rolling.
4. **Economy validation** — `SubtractCoins` and `SubtractCurrency` must remain server-authoritative. Never do currency math on the client.

### Risk areas
1. **CombatService tick** crashes a single player > `pcall` catches, but if `PlayerService.GetValue` throws, all subsequent players in that tick are skipped.
2. **PathfindingService** in Day 3 — expensive on large maps. Must throttle recomputation.
3. **Pet HP is not persisted** — only stored in-memory `petCombat`. On server restart, all pets are alive. Acceptable for MVP.
4. **Enemy model cleanup** — If a player leaves while enemies exist, their models must be cleaned up. Currently handled by table GC when `enemyState[userId]` is not explicitly cleaned.

## Testing Notes
- DataStore warning in Studio: `warn("DataStores are disabled...")` is expected when running unpublished. The game uses default data.
- To test rolling: Press the Roll button in GameplayGui > check Output for pet result
- To test currency: Check EconomyController reads after enemy defeats
- To test combat: Wait 3s+ after loading in, enemies should spawn and pets begin dealing damage
