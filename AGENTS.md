# AGENTS.md — OpenCode AI Development Guide

## Перед любыми изменениями

1. **Прочитать все docs:**
   - `docs/PROJECT_STATE.md` — архитектура, что построено, ключевые файлы
   - `docs/KNOWN_ISSUES.md` — баги, риски, что НЕЛЬЗЯ ломать
   - Этот файл (AGENTS.md) — конвенции разработки

2. **Предложить короткий план** перед любыми правками. В плане указать:
   - Какие файлы меняются и почему
   - Новые модули/файлы, если нужны
   - Новые RemoteEvents, если нужны
   - Как изменения взаимодействуют с существующими системами

3. **Дождаться подтверждения пользователя** перед реализацией.

## Конвенции

- **Нет Rojo**. Все файлы размещаются вручную в Roblox Studio.
- **Нет кастомного DataService**. Использовать `PlayerDataServer` / `PlayerDataClient` из `ReplicatedStorage.PlayerData`.
- **UI элементы уже существуют в StarterGui**. Контроллеры ссылаются на них через `WaitForChild` / `FindFirstChild`.
- **UI-ссылки пре-фетчатся на уровне модуля (top-level)**, не внутри функций.
- **Per-field API**: `PlayerDataServer.getValue/setValue/updateValue` (не bulk get/update).
- **Именование модулей**: Config-файлы заканчиваются на `Config.lua`.
- **Позиции узлов апгрейда** берутся из `UpgradeConfig[upgradeId].nodePosition`, не хардкодятся в контроллере.
- **Cost display** читается через `tile.Price.PriceLabel` + `tile.Price.CurrencyImage`.
- **HUD visibility** контролируется через `VisibilityController` и `RollController.UpdateAutoRollVisibility()`. Оба читают словарь `upgrades`, а не отдельные PlayerData поля — из-за ненадёжной синхронизации новых полей после ребирта.
- **PetEquipService auto-swap**: когда `Equip()` вызывается при заполненных слотах, пет с наибольшим `weight` (самый частый/дешёвый) автоматически заменяется новым. В `Unequip()` логика замены отсутствует — только ручное снятие.

## Require path conventions

- **Серверные модули** — относительно `script.Parent`: `require(script.Parent.PlayerService)`
- **Клиентские контроллеры** — относительно `script.Parent.Modules`: `require(module.EconomyController)`
- **Шаренные модули** — напрямую из `ReplicatedStorage`:
  - `ReplicatedStorage.PlayerData.PlayerDataServer` / `PlayerDataClient`
  - `ReplicatedStorage.Signal`
  - `ReplicatedStorage.PetConfig`, `EnemyConfig`, `UpgradeConfig`, `LocationConfig`,
    `RebirthConfig`, `RarityCalculator`, `FormatNumber`
  - `ReplicatedStorage.UI.Components.ItemTile`
  - `ReplicatedStorage.UI.Objects.ItemTileButton`
  - `ReplicatedStorage.UI.Objects.UpgradeTileButton`
  - `ReplicatedStorage.UI.Objects.ViewingRoll` (шаблон, клонируется в RollController)

## RemoteEvents в использовании

| RemoteEvent | Direction | Назначение |
|---|---|---|
| `RollPet` | C>S + S>C | Roll request + result |
| `EquipPet` | C>S | Equip pet |
| `UnequipPet` | C>S | Unequip pet |
| `PurchaseUpgrade` | C>S | Buy upgrade |
| `UnlockLocation` | C>S | Unlock location (Gate) |
| `EnemyDefeated` | S>C | Coin animation trigger + enemy cleanup |
| `SyncCombatState` | S>C | Enemy/pet positions + HP sync every tick |
| `PetDefeated` | S>C | Pet death notification (transparency fade) |
| `PetRevived` | S>C | Pet revive notification (transparency restore) |
| `PerformRebirth` | C>S | Player initiates rebirth |
| `PlayerDataLoaded` | S>C | PlayerData system |
| `PlayerDataUpdated` | S>C | PlayerData system |
| `PlayerDataSaved` | S>C | PlayerData system |

## Workspace structure (expected)

Workspace/
├── Location1/
│   ├── POI/
│   │   ├── EnemySpawns/ (SpawnPoint parts)
│   │   ├── Baseplate (Part, triggers Touch → currentLocation)
│   │   └── PlayerSpawn (Part, rebirth teleport target)
│   └── Gate/
│       └── Back (SurfaceGui or BillboardGui with UnlockButton)
├── Location2/ (same structure)
└── Location3/ (same structure)

## StarterGui structure (expected)

StarterPlayerScripts/
├── GameClient (LocalScript)
│   └── Modules/ (все контроллеры)
└── PlayerData Modules (в ReplicatedStorage)
StarterGui/
├── GameplayGui/
│   ├── RightSide/ (Shop, Rebirth, Index — visibility gated by upgrades)
│   ├── BottomSide/ (Backpack, Roll, Upgrade)
│   ├── LeftSide/  (Coins, Rocks — Rocks visibility gated by rocks_unlock)
│   └── States/ (Luck — x2.0 label, Speed — cooldown label)
├── MenuGui/
│   ├── Backpack/ > Body/ScrollingFrame + EquippedBoard/Tiles + CloseButton
│   ├── Upgrade/ > Canvas/Board/UIScale + CloseButton
│   ├── Rebirth/ > TopBar/Frame/TitleLabel + Body/RequirementBoard/Tiles + ResultBoard/Tiles + RebirthButton + CloseButton
│   ├── Shop/
│   ├── Index/
│   └── Roll/ > Background/ViewingRoll (cloned from template) + AutoRoll + HideRoll
└── MessageGui/
    └── Background/ (container for ConfirmationMenu)
ReplicatedStorage/
├── PetModels (3D models by pet ID)
├── EnemyModels (3D meshes)
├── UI/Objects/
│   ├── ItemTileButton (template)
│   ├── UpgradeTileButton (template with IconLabel + NameLabel + Price)
│   ├── ViewingRoll (template with PetIcon + NameLabel + RarityLabel)
│   ├── ConfirmationMenu (Frame template with Body/MessageLabel + Body/ConfirmButton)
│   ├── GateBillboardGui (template)
│   └── GateSurfaceGui (template)
├── UI/Components/ItemTile (module)
└── Remotes/ (all RemoteEvents)

## ModuleScripts in ServerScriptService

ServerScriptService/
└── GameServer (Script — entry point)
    └── Modules/
        ├── PlayerService.lua      — PlayerData lifecycle, GetValue/UpdateValue wrappers, DEFAULT_DATA schema
        ├── EconomyService.lua     — Currency add/subtract/canAfford, AddRocks checks rocksUnlocked
        ├── RollService.lua        — RNG, anti-spam, auto-equip
        ├── CombatService.lua      — 1s tick: enemy movement, pet damage, respawn queue, revive
        ├── UpgradeService.lua     — Purchase validation, effect application (luck/cooldown/slots/unlocks/enemyCount)
        ├── LocationService.lua    — Unlock via Gate, Baseplate Touch → currentLocation
        ├── PetEquipService.lua    — Equip/Unequip validation + auto-swap on full slots (replaces highest-weight pet)
        └── RebirthService.lua     — Rebirth validation, reset via DEFAULT_DATA, luck bonus, teleport

## Client Controllers (StarterPlayerScripts/GameClient/Modules/)

| Controller | Role |
|---|---|
| `EconomyController.lua` | Currency HUD (coins, rocks, luck, speed), AnimateCoin |
| `RollController.lua` | Roll + AutoRoll: HUD button, ViewingRoll display, auto-roll loop |
| `CombatController.lua` | 3D enemy/pet models, HP bars, orbit, death/revive transparency |
| `UpgradeController.lua` | Upgrade tree board (pan, no zoom), notifications badge |
| `LocationController.lua` | Gate GUIs (create/restore/destroy), Rebirth Refresh |
| `BackpackController.lua` | Pet inventory: ScrollingFrame + EquippedBoard |
| `MenuController.lua` | Window manager: toggle MenuGui windows |
| `RebirthController.lua` | Rebirth menu: requirements, ResultBoard, confirmation popup |
| `VisibilityController.lua` | HUD visibility gating by upgrades dict (Rocks, Shop, Rebirth, Index) |
