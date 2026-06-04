# PROJECT_STATE.md — Current State of Roblox RNG Game

## Goal
First-person Roblox game where players roll dice to obtain Petrocks (pets), which automatically attack enemies (Angry Rocks) to earn coins. Players spend coins/dice on upgrades, unlock new locations (via Gate + Baseplate touch), and rebirth for permanent luck bonuses.

## Completed Features

### Shared Configs (in ReplicatedStorage)
| File | Purpose |
|---|---|
| `PetConfig` | 8 pets with rarity weights (1040 total), damage, hp, attackRate, attackRange, displayName |
| `EnemyConfig` | 3 enemy types with hp, reward, movementSpeed, attackRange, attackDamage, attackRate |
| `CombatConfig` | Shared constants: PET_DETECTION_RANGE=30, PET_ATTACK_RANGE=15 |
| `UpgradeConfig` | Full upgrade tree (~30 nodes), dynamic position/requires from UpgradeTileInstaller, `buildUpgradeTree()` for children, `isPermanent` flag |
| `LocationConfig` | 3 locations with connectedLocationIds, defaultEnemyTypes |
| `RebirthConfig` | 3 rebirth tiers with requiredLocations, coins, dices, rocks, enemyKills, minPets, luckBonus |
| `RarityCalculator` | RNG with luck-weighted rarity (non-Common weight * luck) |
| `FormatNumber` | Display formatting (1K, 2.3M) |
| `Signal` | Custom Signal used by PlayerData system |
| `OfflineIncomeConfig` | 12h cap, 5min minimum, 4 tier config (capacity/rate coins + rocks) |
| `DailyRewardConfig` | 7 fixed-day rewards (coins, dice, rocks) |
| `MicroRewardConfig` | 3 timer tiers (30/60/120 min) |

### Server Services (ServerScriptService)
| Service | Role |
|---|---|
| `PlayerService` | Initializes PlayerDataServer, fires PlayerReady Signal, GetValue/UpdateValue wrappers, DEFAULT_DATA schema (30 fields) |
| `EconomyService` | Per-field currency operations (coins, rocks, dice). AddRocks() checks rocksUnlocked before granting |
| `RollService` | RNG + anti-spam cooldown + auto-equip + dice grant + rebirthLuck in effectiveLuck |
| `CombatService` | Heartbeat-loop: server-authoritative attack state machine (ready→jumpTo→jumpBack→cooldown), per-pet and per-enemy cooldowns, SyncCombatState sends only HP deltas + newSpawn positions. Target selection: each pet hits nearest enemy within PET_ATTACK_RANGE; each enemy focuses one pet until it dies, then picks nearest alive pet. Respawn queue (3s), revive (5s) |
| `UpgradeService` | Purchase validation + effect application + isPermanent → immediate permanentUpgrades recording |
| `LocationService` | Unlock validation (prerequisite + cost), Baseplate Touch → currentLocation update + enemy respawn |
| `PetEquipService` | Equip/Unequip validation (ownership, slots, duplicates). Auto-swap on full slots: replaces equipped pet with highest weight |
| `RebirthService` | Rebirth validation, SKIP_FIELDS (9 preserved fields), permanentUpgrades merge from owned isPermanent upgrades, upgrades dict restoration |
| `OfflineIncomeService` | Calculates offline coins/rocks on player join, warning logic for full bucket, popup via ShowOfflineIncome |
| `DailyRewardService` | 7-day cycle: advance/reset on entry based on elapsed days, claim validation, maxCombo from daily_reward_level upgrades |
| `MicroRewardService` | 3 independent timer-based tiers, unlocked sequentially via upgrades, claim validation per tier |

### Client Controllers (StarterPlayerScripts)
| Controller | Role |
|---|---|
| `EconomyController` | Reads currency from PlayerDataClient, updates HUD labels (coins, rocks, luck sum, roll speed), AnimateCoin() on EnemyDefeated |
| `RollController` | HUD Roll button, AutoRoll toggle, ViewingRoll display (cloned from template), auto-roll loop, HideRoll button. Checks permanentUpgrades for autoll visibility |
| `CombatController` | Spawns 3D pet/enemy models with HealsBarGui. Pets: Idle→Move→Fight→Attack→Recovery state machine. Procedural jumping, Flat XZ look. PetAttack/EnemyAttack remote subscriptions |
| `UpgradeController` | Interactive tree board (pan, no zoom), `_isBranchComplete()` for extinct dimmed state, `_getStatus()` merges upgrades+permanentUpgrades, notification badge counts affordable upgrades + claimable daily/micro rewards |
| `LocationController` | Scans Gate/Back for SurfaceGui/BillboardGui, connects unlock buttons, toggles PriceFrame, UpdateGateStates(), Refresh() for rebirth restore |
| `BackpackController` | Renders pets sorted by rarity, ScrollingFrame for unequipped, EquippedBoard.Tiles for equipped |
| `MenuController` | Centralized window manager: HUD buttons → MenuGui windows (toggle, close one-at-a-time) |
| `RebirthController` | Renders requirement tiles (red if unmet), ResultBoard, ConfirmationMenu popup, fires PerformRebirth |
| `VisibilityController` | Shows/hides HUD elements (Rocks, Shop, Rebirth, Index) based on upgrades dict + permanentUpgrades dict |
| `OfflineIncomeController` | Subscribes to ShowOfflineIncome, shows ConfirmationMenu popup with earned coins/rocks |
| `DailyRewardController` | Renders 7 tiles in MenuGui.Upgrade.DailyReward, claim on click via ClaimDailyReward, receives DailyRewardStatus |
| `MicroRewardController` | Renders 3 timer tiles in MenuGui.Upgrade.MicroReward, countdown display, claim on click via ClaimMicroReward, polls MicroRewardStatus |

### UI Components
| Component | Location | Role |
|---|---|---|
| `ItemTile` | `ReplicatedStorage.UI.Components` | Factory: clones ItemTileButton, fills IconLabel/CountLabel, binds equip/unequip |
| `ViewingRoll` | `ReplicatedStorage.UI.Objects` | Template for roll result display (PetIcon + NameLabel + RarityLabel), cloned by RollController |
| `HealsBarGui` | `ReplicatedStorage.UI.Objects` | BillboardGui template (Fillbar.Filler + CountLabel), cloned for pet/enemy HP bars |
| `GateBillboardGui` | `ReplicatedStorage.UI.Objects` | Template for billboard-style gate unlock UI |
| `GateSurfaceGui` | `ReplicatedStorage.UI.Objects` | Template for surface-style gate unlock UI |
| `ConfirmationMenu` | `ReplicatedStorage.UI.Objects` | Template for rebirth confirmation + offline income popup |

## PlayerData Schema (30 fields)
coins, rocks, dice, pets (dict), equippedPets (array), maxEquipSlots (1), upgrades (dict), unlockedLocations (array), currentLocation, rollCooldown (2s), luck (1.0), autoRollUnlocked, rocksUnlocked, shopUnlocked, indexUnlocked, rebirthUnlocked, rebirthCount (0), rebirthBonusLuck (0.0), enemyCount (1), enemyKills (0), permanentUpgrades (dict), dailyRewardDay (1), dailyRewardClaimed (dict), dailyRewardLastSeen (0), microRewardLastClaim (dict), offlineIncomeLastSeen (0), offlineIncomeWarned (0), questProgress (dict)

## Key Architecture Decisions
- **No framework**: pure Luau modules via `require()`
- **No Rojo**: manual placement in Roblox Studio
- **PlayerData** handles all persistence, session locking, auto-save (180s)
- **Per-field API**: `updateValue(key, fn)` not bulk update
- **Enemies per player**: independent `enemyState` table, dynamic create/destroy model
- **3D pets**: cloned from `ReplicatedStorage.PetModels`, free follow (no orbit)
- **Location tracking**: LocationService.Unlock adds to unlocked list; Baseplate.Touched sets currentLocation
- **Rebirth reset**: iterates `PlayerService.DEFAULT_DATA`, skips via SKIP_FIELDS table (9 fields), clones non-table defaults. After reset: merges owned isPermanent upgrades into permanentUpgrades, restores them to upgrades dict
- **Permanent upgrades**: `isPermanent` flag in UpgradeConfig. At purchase time: recorded in both upgrades + permanentUpgrades. After rebirth: preserved via SKIP_FIELDS + merge logic
- **Branch completion**: `_isBranchComplete()` traverses parent/children (from `buildUpgradeTree`), checks all nodes owned → shows as `"extinct"` (dimmed, `GroupTransparency=0.7`)
- **No Pathfinding**: enemies move directly toward player each tick
- **Circular requires handled**: CombatService required inside function bodies (not module scope) by UpgradeService, LocationService, RebirthService
- **Auto-roll**: client-side loop fires `RollPet` every `rollCooldown`, server validates cooldown
- **UI gating**: `VisibilityController` and `RollController.UpdateAutoRollVisibility()` read from `upgrades` + `permanentUpgrades` dicts (not individual `*Unlocked` fields) for reliable post-rebirth sync
- **PetEquipService auto-swap**: when `Equip()` is called with all slots filled, replaces highest-weight equipped pet
- **RarityCalculator luck scaling**: `non-Common weight * luck`
- **CombatService attack model**: Unified state machine `ready→jumpTo(0.25s)→jumpBack(0.25s)→cooldown→ready`. Server fires PetAttack/EnemyAttack remotes
- **Offline income**: calculated on player join. Elapsed time capped at 12h, minimum 5min. Combined from upgrades + permanentUpgrades
- **Daily Rewards**: 7-day cycle advances 1 day per calendar day (max 2-day miss → reset). Claim per day, cycle resets naturally after day 7. maxCombo controlled by daily_reward_level upgrades (unlock=2 → level_5=7)
- **Micro Rewards**: 3 independent timer tiers (30/60/120 min). Unlocked via micro_reward_level upgrades. Client polls every 60s

## Upgrade Tree (UpgradeConfig — dynamic loading via UpgradeTileInstaller)
```
luck_1 → luck_2 → luck_3 → luck_4
                    shop (isPermanent)
        rollspeed_1 → rollspeed_2 → rollspeed_3
                                    index (isPermanent)
        micro_reward_unlock (isPermanent) → micro_reward_level_1 → micro_reward_level_2
luck_1 → extraslot_1 → extraslot_2 → extraslot_3
                    rebirth (isPermanent)
                    micro_reward_unlock (isPermanent) → micro_reward_level_1 → micro_reward_level_2
        moreenemies_1 → moreenemies_2 → moreenemies_3 → moreenemies_4
                                                rocks_unlock → rocks_2 → rocks_3 → rocks_4
                                                offline_income_1 → 2 → 3 → 4 (all isPermanent)
                        autoll (isPermanent)
luck_4 → daily_reward_unlock (isPermanent) → level_1 → ... → level_5
```
(Nodes are dynamically positioned via UpgradeTileInstaller ImageButtons in Studio. `requires` from attributes. Tree built by `buildUpgradeTree()`)

## RemoteEvents (19 total)
RollPet, EquipPet, UnequipPet, PurchaseUpgrade, UnlockLocation, EnemyDefeated, SyncCombatState, PetDefeated, PetRevived, PetAttack, EnemyAttack, PerformRebirth, PlayerDataLoaded, PlayerDataUpdated, PlayerDataSaved, ShowOfflineIncome, ClaimDailyReward, DailyRewardStatus, ClaimMicroReward, MicroRewardStatus