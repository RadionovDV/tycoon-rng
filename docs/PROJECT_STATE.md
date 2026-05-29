# PROJECT_STATE.md — Current State of MVP Roblox RNG Game

## Goal
First-person Roblox game where players roll dice to obtain Petrocks (pets), which automatically attack enemies (Angry Rocks) to earn coins. Players spend coins/dice on upgrades, unlock new locations (via Gate + Baseplate touch), and rebirth for permanent luck bonuses.

## Completed Features

### Shared Configs (in ReplicatedStorage)
| File | Purpose |
|---|---|
| `PetConfig` | 8 pets with rarity weights (1040 total), damage, hp, displayName |
| `EnemyConfig` | 3 enemy types with hp, reward, movementSpeed, attackRange, attackDamage, attackRate |
| `UpgradeConfig` | 10 upgrades with icon, nodePosition, costs, prerequisite tree |
| `LocationConfig` | 3 locations with connectedLocationIds, defaultEnemyTypes |
| `RebirthConfig` | 3 rebirth tiers with requiredLocations, coins, dices, rocks, enemyKills, minPets, luckBonus |
| `RarityCalculator` | RNG with luck-weighted rarity (non-Common weight / luck) |
| `FormatNumber` | Display formatting (1K, 2.3M) |
| `Signal` | Custom Signal used by PlayerData system |

### Server Services (ServerScriptService)
| Service | Role |
|---|---|
| `PlayerService` | Initializes PlayerDataServer, fires PlayerReady Signal, GetValue/UpdateValue wrappers |
| `EconomyService` | Per-field currency operations (coins, rocks, dice) |
| `RollService` | RNG + anti-spam cooldown + auto-equip + dice grant + rebirthLuck in effectiveLuck |
| `CombatService` | 1s tick: direct enemy movement, pet attack, enemy/pet HP, death/revive (5s), respawn queue (3s), enemyKills counter |
| `UpgradeService` | Purchase validation + effect application + enemy re-spawn on enemyCount effect |
| `LocationService` | Unlock validation (prerequisite + cost), Baseplate Touch → currentLocation update + enemy respawn |
| `PetEquipService` | Equip/Unequip validation (ownership, slots, duplicates) |
| `RebirthService` | Rebirth validation (all config requirements), reset fields via DEFAULT_DATA, additive luck bonus, teleport to Location1 |

### Client Controllers (StarterPlayerScripts)
| Controller | Role |
|---|---|
| `EconomyController` | Reads currency from PlayerDataClient, updates HUD labels, AnimateCoin() on EnemyDefeated |
| `RollController` | Binds Roll button, shows result in RollUI (1.5s) |
| `CombatController` | Spawns 3D enemy/pet models, HP bars (BillboardGui), pet orbit via Heartbeat, death/revive transparency, orphaned enemy cleanup on location change |
| `UpgradeController` | Interactive tree board (pan, no zoom), clones UpgradeTileButton, dynamic cost/status colors |
| `LocationController` | Scans Gate/Back for SurfaceGui/BillboardGui, connects unlock buttons, toggles PriceFrame |
| `BackpackController` | Renders pets sorted by rarity, ScrollingFrame for unequipped, EquippedBoard.Tiles for equipped |
| `MenuController` | Centralized window manager: HUD buttons → MenuGui windows (toggle, close one-at-a-time) |
| `RebirthController` | Renders requirement tiles (red if unmet), ResultBoard, ConfirmationMenu popup, fires PerformRebirth |

### UI Components
| Component | Location | Role |
|---|---|---|
| `ItemTile` | `ReplicatedStorage.UI.Components` | Factory: clones ItemTileButton, fills IconLabel/CountLabel, binds equip/unequip |

## PlayerData Schema (18 fields)
coins, rocks, dice, pets (dict), equippedPets (array), maxEquipSlots (1), upgrades (dict), unlockedLocations (array), currentLocation, rollCooldown (2s), luck (1.0), autoRollUnlocked, rocksUnlocked, rebirthCount (0), rebirthBonusLuck (0.0), enemyCount (1), enemyKills (0)

## Key Architecture Decisions
- **No framework**: pure Luau modules via `require()`
- **No Rojo**: manual placement in Roblox Studio
- **PlayerData** handles all persistence, session locking, auto-save (180s)
- **Per-field API**: `updateValue(key, fn)` not bulk update
- **Enemies per player**: independent `enemyState` table, dynamic create/destroy model
- **3D pets**: cloned from `ReplicatedStorage.PetModels`, orbit via Heartbeat
- **Location tracking**: LocationService.Unlock adds to unlocked list; Baseplate.Touched sets currentLocation
- **Rebirth reset**: uses `table.clone(PlayerService.DEFAULT_DATA)` for each field, retains rebirthCount/rebirthBonusLuck/enemyKills
- **No Pathfinding**: enemies move directly toward player each tick
- **Circular requires handled**: CombatService required inside function bodies (not module scope) by UpgradeService, LocationService, RebirthService

## RemoteEvents (12 total)
RollPet, EquipPet, UnequipPet, PurchaseUpgrade, UnlockLocation, EnemyDefeated, SyncCombatState, PetDefeated, PetRevived, PerformRebirth, PlayerDataLoaded, PlayerDataUpdated, PlayerDataSaved