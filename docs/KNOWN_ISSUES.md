# KNOWN_ISSUES.md — Bugs, Risks, and What NOT to Break

## Recent Fixes (Session 2026-05-30–2026-06-04)

- **RarityCalculator inverse scaling (FIXED)**: Formula `weight / luckMultiplier` caused rare pets to become *rarer* as luck increased (e.g., Divine_Opal chance dropped from 0.00094% to 0.00004% at rebirthBonusLuck=30). Fixed to `weight * luckMultiplier`. Rare weights now scale up with luck, correctly increasing rare roll chances.

- **PetEquipService auto-swap (ADDED)**: `Equip()` now replaces the highest-weight equipped pet when all slots are full, instead of silently failing.

- **CombatService Heartbeat loop (REWRITTEN)**: Changed from `task.wait(1)` to `RunService.Heartbeat` with real dt. SyncCombatState now sends only Hp deltas + newSpawn positions (no full-state every tick). Per-entity attack state machine replaces per-tick combined damage.

- **Pet attack damage model (REWRITTEN)**: Replaced per-tick `totalDamage` from all pets with per-pet cooldown-based attacks. Each pet picks nearest enemy within `PET_ATTACK_RANGE`, applies `petEntry.damage` once per `attackRate` seconds. Enemies focus one pet until it dies.

- **Pet visual movement (REWRITTEN)**: Removed orbit system. Pets freely follow player. Detection range = 30 studs (approach enemy), attack range = 15 studs (start fight). Procedural jump arcs every 0.7s with state-dependent height.

- **HP bars (REWRITTEN)**: Replaced inline BillboardGui TextLabel with `HealsBarGui` template (Fillbar.Filler + CountLabel). Cloned from `ReplicatedStorage.UI.Objects.HealsBarGui`, attached via `Adornee = model.BillboardAttachment`.

- **CombatConfig (ADDED)**: New shared config file `ReplicatedStorage.CombatConfig` with `PET_DETECTION_RANGE=30` and `PET_ATTACK_RANGE=15`. Used by both CombatService and CombatController.

- **PetAttack/EnemyAttack remotes (ADDED)**: Two new S>C RemoteEvents: `PetAttack{petId,enemyId}` and `EnemyAttack{enemyId,petId,targetPosition}` for attack animation triggers.

- **PetConfig attackRate/attackRange (ADDED)**: Added `attackRate` (0.5–1.2s) and `attackRange` (25–32) fields to all 8 pets.

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
`enemyKills` is incremented only when an enemy dies from pet damage (in `CombatService._handleEnemyKill`). Enemies that despawn on location change or server restart do not count as kills.

### 9. VisibilityController relies on `upgrades` dict (not individual `*Unlocked` fields)
`shopUnlocked`, `indexUnlocked`, `rebirthUnlocked`, `rocksUnlocked`, `autoRollUnlocked` are set in DEFAULT_DATA and by UpgradeService, but `PlayerDataClient.get()` may return stale values after rebirth for newly added fields. Workaround: `VisibilityController` and `RollController.UpdateAutoRollVisibility()` read from the `upgrades` dict instead. The individual `*Unlocked` fields are still updated by the server but not used for client-side visibility decisions.

### 10. Auto-roll loop is client-side
The auto-roll loop runs in `RollController._startAutoRoll()` using `task.spawn`. There is no server-side check for whether the player has the `autoll` upgrade — the server validates cooldown per-request but doesn't distinguish auto-roll from manual rolls. A malicious client could fire `RollPet` rapidly regardless of upgrade ownership. Acceptable for MVP.

### 11. Auto-roll loop doesn't handle server-side cooldown changes
If `rollCooldown` changes during auto-roll (e.g., upgrade purchased), the loop reads `PlayerDataClient.get("rollCooldown")` each iteration but the cooldown is only read after a response is received. Cooldown reductions take effect on the next roll cycle.

### 12. SyncCombatState still sends `pets` table with HP deltas (not used for attack animation)
PetAttack/EnemyAttack remotes handle attack animation triggers, but SyncCombatState still includes `pets` table with HP data. This is fine — HP updates from SyncCombatState update the HP bar, while PetAttack triggers the visual jump animation. The two systems are complementary.

### 13. Pet/enemy models move in air (no ground collision yet)
All pet/enemy movement uses pure math arcs (Lerp + sin). On vertical terrain, entities float above or clip into ground. Ground collision (Raycast at jump boundaries) is planned for Stage 3.

### 14. PetAttack and EnemyAttack remote events need manual creation in Studio
These two RemoteEvents are referenced in code (`ReplicatedStorage.Remotes.PetAttack` / `EnemyAttack`) but must be created manually in Roblox Studio. Same for `CombatConfig` ModuleScript and `HealsBarGui` BillboardGui template. If absent, `WaitForChild` blocks indefinitely.

### 15. HealsBarGui template must exist in Studio
`CombatController.lua` uses `ReplicatedStorage.UI.Objects:WaitForChild("HealsBarGui")` at module top-level. If the template doesn't exist, the module will not load.

### 16. Enemy targeting may briefly target player if all pets are dead and re-appear mid-cooldown
When all pets are dead, enemy targets player. When a pet revives, server checks every "ready" phase (max 1s delay). Client switches immediately via `_findNearestAlivePet`. Acceptable for MVP.

## Risks — What NOT to Break

1. **PlayerData system** — Do NOT modify `PlayerDataServer` or `PlayerDataClient` modules. Stable external dependencies.

2. **RemoteEvents** — Do NOT delete or rename any existing RemoteEvent. Add new ones only after user approval.

3. **RollService anti-spam** — `lastRollTime` cooldown is the only anti-cheat. Removing it allows spam-rolling.

4. **Economy validation** — `SubtractCoins` and `SubtractCurrency` must remain server-authoritative. Never do currency math on the client.

5. **CombatService tick** — crashes on one player are caught by `pcall`, but if `PlayerService.GetValue` throws, all subsequent players in that tick are skipped.

6. **Pet HP is not persisted** — stored only in-memory `petCombat`. On server restart all pets are revived. Acceptable for MVP.

7. **Rebirth uses PlayerService.DEFAULT_DATA** — RebirthService references `PlayerService.DEFAULT_DATA` for field reset. If DEFAULT_DATA structure changes, ensure RebirthService retains correct fields (rebirthCount, rebirthBonusLuck, enemyKills).

8. **ViewingRoll is a cloned template** — `RollController` clones `ReplicatedStorage.UI.Objects.ViewingRoll` once at module load. If the template is renamed or moved, the `WaitForChild` call fails and the module doesn't load.

9. **VisibilityController path resolution** — `VisibilityController` finds UI elements dynamically at `Refresh()` time (`FindFirstChild`). If the target elements are renamed or moved in StarterGui, they won't be found and will stay in their Studio-default visibility state.

10. **PetEquipService now requires PetConfig at module scope** — `PetEquipService.lua` now has `local PetConfig = require(ReplicatedStorage.PetConfig)` at the top level. If PetConfig is renamed, moved, or fails to load, PetEquipService will not load and all equip/unequip operations will fail silently (no handler connected).

11. **Combat module structure** — CombatService and CombatController are tightly coupled. Changes to the attack state machine fields (`attackPhase`, `attackState`, jump timing) must be mirrored in both files.

## Testing Notes
- DataStore warning in Studio: expected when running unpublished. Game uses default data.
- Roll button → check Output for pet result
- Currency: check EconomyController reads after enemy defeats
- Combat: wait 3s+ after loading in, enemies spawn and pets attack
- Location change: walk to another location's Baseplate (must be unlocked first via Gate)
- Rebirth: unlock Location2, collect 5+ pets, open Rebirth window, check requirements
- Auto-roll: buy `autoll` upgrade → AutoRoll button visible in Roll window → click to start → ViewingRoll moves to GameplayGui.Autoroll → click again to stop → 1.5s animation → Roll window closes
- UI gating: buy `rocks_unlock` → Rocks appears in HUD. Buy `shop` → Shop appears in RightSide. After rebirth all reset to hidden.
- Auto-swap: equip `maxEquipSlots` pets (default 1), then roll a new pet → if autoEquip triggers but slot is full, Equip() should replace the equipped pet with the new one. The replaced pet stays in inventory.
- Luck scaling: rebirth with `rebirthBonusLuck=30` (via RebirthConfig or manual DataStore edit), then roll → Divine/Epic/Legendary pets should appear noticeably more often, not less.
- Combat animation: watch pet behavior — should detect enemy at 30 studs (Move toward), approach to 3 studs (Fight hops), then jump attack (0.25s to enemy, damage, 0.25s back). Enemy should focus one pet until it dies, then switch. When all pets dead, enemy moves toward player.