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

- **isPermanent upgrades (ADDED)**: `UpgradeConfig` now has `isPermanent` flag on selected nodes (autoll, shop, index, rebirth, daily_reward_*, micro_reward_*, offline_income_*, quest_system). Purchase records in both `upgrades` + `permanentUpgrades`. Rebirth preserves via SKIP_FIELDS + merge.

- **UpgradeConfig dynamic loading (ADDED)**: `setPosition()` reads `nodePosition` from `UpgradeTileInstaller` ImageButtons in Studio. `requires` from `GetAttribute("requires")`. `buildUpgradeTree()` builds `children` from reverse `requires` lookup for isPermanent nodes.

- **Offline Income system (ADDED)**: Four offline_income upgrade nodes. `OfflineIncomeService` calculates accumulated coins/rocks on player join (12h cap, 5min minimum). `OfflineIncomeController` shows ConfirmationMenu popup.

- **Daily Reward system (ADDED)**: 7-day cycle with `daily_reward_unlock` + 5 `daily_reward_level` upgrades. Server advances/resets day on entry. Client renders 7 tiles in `MenuGui.Upgrade.DailyReward`. maxCombo (2→7) controlled by purchased levels.

- **Micro Reward system (ADDED)**: 3 timer tiers (30/60/120 min) unlocked via `micro_reward_unlock` + `micro_reward_level_1/2`. Client renders 3 tiles in `MenuGui.Upgrade.MicroReward` with countdown timers.

- **Branch completion check (ADDED)**: `UpgradeController._isBranchComplete()` traverses parents+children of isPermanent nodes. When all owned → shows as `"extinct"` (dimmed, `GroupTransparency=0.7`).

- **UpgradeController notifications (ENHANCED)**: Notification badge now counts affordable upgrades + claimable daily reward + claimable micro rewards.

- **_getStatus merged upgrades (CHANGED)**: Uses `combinedUpgrades` (upgrades + permanentUpgrades) for branch check, ownership check, and prerequisite check — ensures owned permanent upgrades unlock locked children.

- **PlayerData schema (EXPANDED)**: +7 new fields (permanentUpgrades, dailyRewardDay, dailyRewardClaimed, dailyRewardLastSeen, microRewardLastClaim, offlineIncomeLastSeen, offlineIncomeWarned, questProgress). Replaced `dailyRewardProgress` with `dailyRewardDay` + `dailyRewardClaimed`.

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

### 17. New RemoteEvents for Daily/Micro/Offline systems must be created in Studio
Five new RemoteEvents: `ShowOfflineIncome`, `ClaimDailyReward`, `DailyRewardStatus`, `ClaimMicroReward`, `MicroRewardStatus`. If absent, the corresponding services/controllers will not function (no event handler connected).

### 18. DailyReward and MicroReward UI containers must exist in Studio
`DailyRewardController` and `MicroRewardController` use `WaitForChild("DailyReward")` and `WaitForChild("MicroReward")` on `MenuGui.Upgrade` at module top-level. If these containers don't exist, the modules will not load.

### 19. Upgraded UpgradeConfig now required from ReplicatedFirst
`UpgradeController` and `RebirthService` require `UpgradeConfig` from `ReplicatedFirst` instead of `ReplicatedStorage`. The UpgradeConfig module reads `UpgradeTileInstaller` from `StarterGui.MenuGui.Upgrade.Canvas.Board` at load time for dynamic positioning. If the installer doesn't exist, the module errors.

### 20. UpgradeTileInstaller ImageButtons must have correct Name and "requires" attribute
`setPosition()` iterates children of `UpgradeTileInstaller`. Each tile's `Name` must match an `UpgradeConfig` key. The `requires` attribute string must match another config key (or be nil for root nodes). If a name doesn't match, it logs a warning and skips. Missing attributes silently leave `requires` as nil.

### 21. MicroRewardController polls every 60s with task.spawn
`MicroRewardController.Start()` spawns an infinite loop that fires `MicroRewardStatus:FireServer()` every 60s. If the GameClient script is stopped (e.g., player leaves), this thread leaks. Acceptable for MVP — PlayerRemoving handles cleanup via PlayerData.

### 22. DailyRewardStatus and MicroRewardStatus are bidirectional
Both events use the same RemoteEvent for C>S (request) and S>C (response). This works because `OnServerEvent` and `OnClientEvent` are separate callbacks on the same event, but it's non-standard.

## Risks — What NOT to Break

1. **PlayerData system** — Do NOT modify `PlayerDataServer` or `PlayerDataClient` modules. Stable external dependencies.

2. **RemoteEvents** — Do NOT delete or rename any existing RemoteEvent. Add new ones only after user approval.

3. **RollService anti-spam** — `lastRollTime` cooldown is the only anti-cheat. Removing it allows spam-rolling.

4. **Economy validation** — `SubtractCoins` and `SubtractCurrency` must remain server-authoritative. Never do currency math on the client.

5. **CombatService tick** — crashes on one player are caught by `pcall`, but if `PlayerService.GetValue` throws, all subsequent players in that tick are skipped.

6. **Pet HP is not persisted** — stored only in-memory `petCombat`. On server restart all pets are revived. Acceptable for MVP.

7. **Rebirth uses PlayerService.DEFAULT_DATA** — RebirthService references `PlayerService.DEFAULT_DATA` for field reset. If DEFAULT_DATA structure changes, ensure RebirthService retains correct SKIP_FIELDS (rebirthCount, rebirthBonusLuck, enemyKills, permanentUpgrades, dailyRewardDay, dailyRewardClaimed, dailyRewardLastSeen, microRewardLastClaim, offlineIncomeLastSeen, offlineIncomeWarned, questProgress).

8. **ViewingRoll is a cloned template** — `RollController` clones `ReplicatedStorage.UI.Objects.ViewingRoll` once at module load. If the template is renamed or moved, the `WaitForChild` call fails and the module doesn't load.

9. **VisibilityController path resolution** — `VisibilityController` finds UI elements dynamically at `Refresh()` time (`FindFirstChild`). If the target elements are renamed or moved in StarterGui, they won't be found and will stay in their Studio-default visibility state.

10. **PetEquipService now requires PetConfig at module scope** — `PetEquipService.lua` now has `local PetConfig = require(ReplicatedStorage.PetConfig)` at the top level. If PetConfig is renamed, moved, or fails to load, PetEquipService will not load and all equip/unequip operations will fail silently (no handler connected).

11. **Combat module structure** — CombatService and CombatController are tightly coupled. Changes to the attack state machine fields (`attackPhase`, `attackState`, jump timing) must be mirrored in both files.

12. **permanentUpgrades and upgrades must stay in sync** — `RebirthService` restores permanent upgrades to the `upgrades` dict so `_isBranchComplete()` works. If only one dict is updated (e.g., direct PlayerData edit), branches may show incorrect status.

13. **UpgradeConfig requires from ReplicatedFirst** — `UpgradeController` and `RebirthService` now use `ReplicatedFirst.UpgradeConfig` (not `ReplicatedStorage`). If moved, the require will fail silently as `require()` returns `nil` for missing modules.

14. **UpgradeTileInstaller must exist at module load** — `UpgradeConfig.lua` reads `StarterGui.MenuGui.Upgrade.Canvas.Board.UpgradeTileInstaller` at top-level. If removed or renamed, the module fails to load entirely, breaking the upgrade tree, rebirth, and all controllers that depend on it.

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
- Luck scaling: rebirth with `rebirthBonusLuck=30`, then roll → Divine/Epic/Legendary pets should appear noticeably more often, not less.
- Combat animation: watch pet behavior — should detect enemy at 30 studs (Move toward), approach to 3 studs (Fight hops), then jump attack (0.25s to enemy, damage, 0.25s back).
- Permanent upgrades (extinct): buy all nodes in a permanent branch → all tiles should dim (GroupTransparency=0.7). Rebirth → branch stays dimmed immediately.
- Offline income: wait 5+ minutes, rejoin → should see ConfirmationMenu popup with coins/rocks earned.
- Daily Rewards: buy `daily_reward_unlock` → open Upgrade window → see 7 tiles in DailyReward container. Day 1 tile clickable. Wait 24h → day advances. Wait 48h+ → cycle resets.
- Micro Rewards: buy `micro_reward_unlock` → see 30min tile in MicroReward container. Wait 30min → Claim available. Buy `level_1` → 60min tile appears. Buy `level_2` → 120min tile appears.
- Notification badge: when upgrades affordable + daily claimable + micro claimable → red dot number = sum of all three.
- Upgrade tree: new nodes (luck_3/4, rollspeed_3, extraslot_3, moreenemies_4, rocks_2/3/4, offline_income_1-4, daily_reward nodes, micro_reward nodes) should appear with correct positions from UpgradeTileInstaller.