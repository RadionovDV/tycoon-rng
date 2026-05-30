# PROJECT_STATE.md — Current State of MVP Roblox RNG Game

## Goal
First-person Roblox game where players roll dice to obtain Petrocks (pets), which automatically attack enemies (Angry Rocks) to earn coins. Players spend coins/dice on upgrades, unlock new locations (via Gate + Baseplate touch), and rebirth for permanent luck bonuses.

## Completed Features

### Shared Configs (in ReplicatedStorage)
| File | Purpose |
|---|---|
| `PetConfig` | 8 pets with rarity weights (1040 total), damage, hp, displayName |
| `EnemyConfig` | 3 enemy types with hp, reward, movementSpeed, attackRange, attackDamage, attackRate |
| `UpgradeConfig` | 13 upgrades (luck, rollSpeed, extraSlots, moreEnemies, autoRoll, rocks, shop, index, rebirth) |
| `LocationConfig` | 3 locations with connectedLocationIds, defaultEnemyTypes |
| `RebirthConfig` | 3 rebirth tiers with requiredLocations, coins, dices, rocks, enemyKills, minPets, luckBonus |
| `RarityCalculator` | RNG with luck-weighted rarity (non-Common weight * luck). Fixed from `/` to `*` to prevent inverse scaling bug at high rebirthBonusLuck |
| `FormatNumber` | Display formatting (1K, 2.3M) |
| `Signal` | Custom Signal used by PlayerData system |

### Server Services (ServerScriptService)
| Service | Role |
|---|---|
| `PlayerService` | Initializes PlayerDataServer, fires PlayerReady Signal, GetValue/UpdateValue wrappers, DEFAULT_DATA schema |
| `EconomyService` | Per-field currency operations (coins, rocks, dice). AddRocks() checks rocksUnlocked before granting |
| `RollService` | RNG + anti-spam cooldown + auto-equip + dice grant + rebirthLuck in effectiveLuck |
| `CombatService` | 1s tick: direct enemy movement, pet attack, enemy/pet HP, death/revive (5s), respawn queue (3s), enemyKills counter, rockReward if rocksUnlocked |
| `UpgradeService` | Purchase validation + effect application (luck, rollCooldown, maxEquipSlots, unlockAutoRoll, unlockRocks, unlockShop, unlockIndex, unlockRebirth, enemyCount) |
| `LocationService` | Unlock validation (prerequisite + cost), Baseplate Touch → currentLocation update + enemy respawn |
| `PetEquipService` | Equip/Unequip validation (ownership, slots, duplicates). Auto-swap on full slots: replaces equipped pet with highest weight |
| `RebirthService` | Rebirth validation (all config requirements), reset fields via DEFAULT_DATA, additive luck bonus, teleport to Location1 |

### Client Controllers (StarterPlayerScripts)
| Controller | Role |
|---|---|
| `EconomyController` | Reads currency from PlayerDataClient, updates HUD labels (coins, rocks, luck sum, roll speed), AnimateCoin() on EnemyDefeated |
| `RollController` | HUD Roll button, AutoRoll toggle, ViewingRoll display (cloned from template), auto-roll loop (fires RollPet on cooldown), HideRoll button |
| `CombatController` | Spawns 3D enemy/pet models, HP bars (BillboardGui), pet orbit via Heartbeat, death/revive transparency, orphaned enemy cleanup on location change |
| `UpgradeController` | Interactive tree board (pan, no zoom), clones UpgradeTileButton, dynamic cost/status colors, HUD notification badge |
| `LocationController` | Scans Gate/Back for SurfaceGui/BillboardGui, connects unlock buttons, toggles PriceFrame, UpdateGateStates(), Refresh() for rebirth restore |
| `BackpackController` | Renders pets sorted by rarity, ScrollingFrame for unequipped, EquippedBoard.Tiles for equipped |
| `MenuController` | Centralized window manager: HUD buttons → MenuGui windows (toggle, close one-at-a-time) |
| `RebirthController` | Renders requirement tiles (red if unmet), ResultBoard, ConfirmationMenu popup, fires PerformRebirth |
| `VisibilityController` | Shows/hides HUD elements (Rocks, Shop, Rebirth, Index) based on upgrades dict |

### UI Components
| Component | Location | Role |
|---|---|---|
| `ItemTile` | `ReplicatedStorage.UI.Components` | Factory: clones ItemTileButton, fills IconLabel/CountLabel, binds equip/unequip |
| `ViewingRoll` | `ReplicatedStorage.UI.Objects` | Template for roll result display (PetIcon + NameLabel + RarityLabel), cloned by RollController |
| `GateBillboardGui` | `ReplicatedStorage.UI.Objects` | Template for billboard-style gate unlock UI |
| `GateSurfaceGui` | `ReplicatedStorage.UI.Objects` | Template for surface-style gate unlock UI |
| `ConfirmationMenu` | `ReplicatedStorage.UI.Objects` | Template for rebirth confirmation popup |

## PlayerData Schema (23 fields)
coins, rocks, dice, pets (dict), equippedPets (array), maxEquipSlots (1), upgrades (dict), unlockedLocations (array), currentLocation, rollCooldown (2s), luck (1.0), autoRollUnlocked, rocksUnlocked, shopUnlocked, indexUnlocked, rebirthUnlocked, rebirthCount (0), rebirthBonusLuck (0.0), enemyCount (1), enemyKills (0)

## Key Architecture Decisions
- **No framework**: pure Luau modules via `require()`
- **No Rojo**: manual placement in Roblox Studio
- **PlayerData** handles all persistence, session locking, auto-save (180s)
- **Per-field API**: `updateValue(key, fn)` not bulk update
- **Enemies per player**: independent `enemyState` table, dynamic create/destroy model
- **3D pets**: cloned from `ReplicatedStorage.PetModels`, orbit via Heartbeat
- **Location tracking**: LocationService.Unlock adds to unlocked list; Baseplate.Touched sets currentLocation
- **Rebirth reset**: iterates `PlayerService.DEFAULT_DATA`, skips rebirthCount/rebirthBonusLuck/enemyKills, clones non-table defaults
- **No Pathfinding**: enemies move directly toward player each tick
- **Circular requires handled**: CombatService required inside function bodies (not module scope) by UpgradeService, LocationService, RebirthService
- **Auto-roll**: client-side loop fires `RollPet` every `rollCooldown`, server validates cooldown. No new RemoteEvent needed.
- **UI gating**: `VisibilityController` and `RollController.UpdateAutoRollVisibility()` read from `upgrades` dict (not individual `*Unlocked` fields) for reliable post-rebirth sync
- **ViewingRoll**: single cloned instance, parented to either `MenuGui.Roll.Background` or `GameplayGui.Autoroll` depending on auto-roll state and Roll window visibility
- **PetEquipService auto-swap**: when `Equip()` is called with all slots filled, the function iterates equipped pets, finds the one with the highest `PetConfig.weight` (most common/least rare), removes it from `equippedPets`, and inserts the new pet. The replaced pet stays in the inventory and can be re-equipped later. Logic is in a single `UpdateValue` call.
- **RarityCalculator luck scaling**: `non-Common weight * luck` (fixed from original `/`). At default luck=1.0 behavior is identical; at high rebirthBonusLuck (e.g., +30), rare weights scale up proportionally, making Divine/Epic rolls dramatically more likely instead of vanishing.

## Upgrade Tree (UpgradeConfig)
```
luck_1 (coins 10)
├── luck_2 (coins 500)
│   ├── shop (coins 1000)
│   ├── rollspeed_1 (dice 5)
│   │   ├── rollspeed_2 (dice 20)
│   │   │   └── index (coins 50000)
│   │   └── extraslot_1 (coins 200)
│   │       ├── extraslot_2 (coins 800)
│   │       │   └── rebirth (coins 5000)
│   │       └── moreenemies_1 (coins 300)
│   │           ├── moreenemies_2 (coins 2000)
│   │           │   └── rocks_unlock (coins 2000)
│   │           └── autoll (coins 1000)
```

## RemoteEvents (13 total)
RollPet, EquipPet, UnequipPet, PurchaseUpgrade, UnlockLocation, EnemyDefeated, SyncCombatState, PetDefeated, PetRevived, PerformRebirth, PlayerDataLoaded, PlayerDataUpdated, PlayerDataSaved
