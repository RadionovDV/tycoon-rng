# PROJECT_STATE.md — Current State of MVP Roblox RNG Game

## Goal
First-person Roblox game where players roll dice to obtain Petrocks (pets), which automatically attack enemies (Angry Rocks) to earn coins. Players spend coins/dice on upgrades, unlock new locations, and eventually rebirth for permanent bonuses.

## Completed — Day 1 (Core Server + Shared Data)
All shared configs and server services implemented and tested (Roll button > server RNG > pet in inventory confirmed working).

### Shared configs (in `ReplicatedStorage`)
| File | Purpose |
|---|---|
| `PetConfig` | 8 pets with rarity weights (1040 total), damage, displayName |
| `EnemyConfig` | 3 enemy types: Weak (30HP), Medium (80HP), Strong (200HP) |
| `UpgradeConfig` | 9 upgrades in a tree (luck, rollSpeed, slots, autoRoll, etc.) |
| `LocationConfig` | 2 locations: Location1 (free), Location2 (5000 coins) |
| `RarityCalculator` | RNG with luck-weighted rarity |
| `FormatNumber` | Display formatting (1K, 2.3M) |
| `Signal` | Custom Signal implementation used by PlayerData system |

### Server services (in ServerScriptService)
| Service | Role |
|---|---|
| `PlayerService` | Initializes PlayerDataServer with default data, fires `PlayerReady` Signal |
| `EconomyService` | Per-field currency operations (coins, rocks, dice) |
| `RollService` | RNG + anti-spam cooldown + auto-equip + dice grant |
| `CombatService` | 1s combat tick: equippped pets damage > enemy death > coins > respawn (3s) |
| `UpgradeService` | Purchase validation + effect application |
| `LocationService` | Unlock validation + prerequisite + enemy re-spawn |
| `PetEquipService` | Equip/Unequip validation (ownership, slots, duplicates) |

## Completed — Day 2 (Client Controllers + UI Integration)

### Client controllers (in StarterPlayerScripts)
| Controller | Role |
|---|---|
| `EconomyController` | Reads coins/rocks/dice from PlayerDataClient, updates HUD labels |
| `RollController` | Binds Roll button > FireServer, shows result in RollUI (1.5s) |
| `CombatController` | Spawns 3D pet models orbiting player via Heartbeat, handles respawn |
| `UpgradeController` | Renders upgrade nodes in UpgradeUI, purchase buttons, notification badge |
| `LocationController` | Scans Location/Gate/Back for SurfaceGui/BillboardGui, connects unlock buttons |
| `BackpackController` | Uses `ItemTile` component to render pet list sorted by rarity, equip/unequip |
| `MenuController` | Centralized window manager: HUD buttons > MenuGui windows (toggle, close) |

### UI Components
| Component | Location | Role |
|---|---|---|
| `ItemTile` | `ReplicatedStorage.UI.Components` | Factory: clones `ItemTileButton`, fills IconLabel/CountLabel, binds equip/unequip |

## Key Architecture Decisions
- **No framework**: pure Luau modules via `require()`
- **No Rojo**: manual placement in Roblox Studio
- **PlayerData** handles all persistence, session locking, auto-save (180s)
- **Per-field API**: `updateValue(key, fn)` not bulk update
- **Enemies per player**: independent `enemyState` table, spawned in `Location/POI/EnemySpawns`
- **3D pets**: cloned from `ReplicatedStorage.PetModels`, orbit via Heartbeat

## PlayerData Schema (15 fields)
coins, rocks, dice, pets (dict), equippedPets (array), maxEquipSlots (1), upgrades (dict), unlockedLocations (array), currentLocation, rollCooldown (2s), luck (1.0), autoRollUnlocked, rocksUnlocked, rebirthCount, rebirthBonusLuck, enemyCount (1)

## RemoteEvents Created
RollPet, EquipPet, UnequipPet, PurchaseUpgrade, UnlockLocation, EnemyDefeated, PlayerDataLoaded, PlayerDataUpdated, PlayerDataSaved
