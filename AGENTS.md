# AGENTS.md — OpenCode AI Development Guide

## Перед любыми изменениями

1. **Прочитать все docs:**
   - `docs/PROJECT_STATE.md` — архитектура, что построено, ключевые файлы
   - `docs/KNOWN_ISSUES.md` — баги, риски, что НЕЛЬЗЯ ломать
   - `docs/STAGE_3_PLAN.md` — что осталось сделать в CombatSystem
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
- **Позиции узлов апгрейда** загружаются динамически через `UpgradeConfig.setPosition()` из `UpgradeTileInstaller` в Studio, не хардкодятся.
- **`requires` апгрейда** загружается из атрибута `"requires"` на тайле в `UpgradeTileInstaller`.
- **Cost display** читается через `tile.Price.PriceLabel` + `tile.Price.CurrencyImage`.
- **HUD visibility** контролируется через `VisibilityController` и `RollController.UpdateAutoRollVisibility()`. Оба читают словарь `upgrades` **и** `permanentUpgrades` — из-за ненадёжной синхронизации новых полей после ребирта.
- **PetEquipService auto-swap**: когда `Equip()` вызывается при заполненных слотах, пет с наибольшим `weight` (самый частый/дешёвый) автоматически заменяется новым. В `Unequip()` логика замены отсутствует — только ручное снятие.
- **Перманентные апгрейды**: при покупке `isPermanent`-узла он записывается и в `upgrades`, и в `permanentUpgrades`. Клиентский `UpgradeController._isBranchComplete()` определяет, вся ли ветка куплена, и показывает её как `"extinct"` (dimmed, `GroupTransparency=0.7`).
- **`buildUpgradeTree()`** в `UpgradeConfig` строит поле `children` для `isPermanent`-узлов на основе обратного `requires`-лукапа. Используется в `_isBranchComplete`.

## Require path conventions

- **Серверные модули** — относительно `script.Parent`: `require(script.Parent.PlayerService)`
- **Клиентские контроллеры** — относительно `script.Parent.Modules`: `require(module.EconomyController)`
- **Шаренные модули** — напрямую из `ReplicatedStorage`:
  - `ReplicatedStorage.PlayerData.PlayerDataServer` / `PlayerDataClient`
  - `ReplicatedStorage.Signal`
  - `ReplicatedStorage.PetConfig`, `EnemyConfig`, `UpgradeConfig`, `LocationConfig`,
    `RebirthConfig`, `RarityCalculator`, `FormatNumber`, `CombatConfig`,
    `OfflineIncomeConfig`, `DailyRewardConfig`, `MicroRewardConfig`
  - `ReplicatedStorage.UI.Components.ItemTile`
  - `ReplicatedStorage.UI.Objects.ItemTileButton`
  - `ReplicatedStorage.UI.Objects.UpgradeTileButton`
  - `ReplicatedStorage.UI.Objects.ViewingRoll` (шаблон, клонируется в RollController)
  - `ReplicatedStorage.UI.Objects.HealsBarGui` (шаблон, клонируется в CombatController)
  - `ReplicatedStorage.UI.Objects.ConfirmationMenu` (шаблон, используется в RebirthController и OfflineIncomeController)
- **UpgradeConfig** — через `ReplicatedFirst.UpgradeConfig` (загружается раньше для динамического позиционирования)

## RemoteEvents в использовании

| RemoteEvent | Direction | Назначение |
|---|---|---|
| `RollPet` | C>S + S>C | Roll request + result |
| `EquipPet` | C>S | Equip pet |
| `UnequipPet` | C>S | Unequip pet |
| `PurchaseUpgrade` | C>S | Buy upgrade |
| `UnlockLocation` | C>S | Unlock location (Gate) |
| `EnemyDefeated` | S>C | Coin animation trigger + enemy cleanup |
| `SyncCombatState` | S>C | Enemy/pet HP deltas + new spawn positions (no full-state sync) |
| `PetDefeated` | S>C | Pet death notification (transparency fade) |
| `PetRevived` | S>C | Pet revive notification (transparency restore) |
| `PetAttack` | S>C | Triggers pet attack animation (jumpTo enemy → damage → jumpBack) |
| `EnemyAttack` | S>C | Triggers enemy attack animation (jumpTo pet → damage → jumpBack) |
| `PerformRebirth` | C>S | Player initiates rebirth |
| `PlayerDataLoaded` | S>C | PlayerData system |
| `PlayerDataUpdated` | S>C | PlayerData system |
| `PlayerDataSaved` | S>C | PlayerData system |
| `ShowOfflineIncome` | S>C | Popup с накопленным офлайн-доходом |
| `ClaimDailyReward` | C>S | Запрос получения daily reward (tileIndex) |
| `DailyRewardStatus` | S>C + C>S | Статус daily rewards + запрос обновления |
| `ClaimMicroReward` | C>S | Запрос получения micro reward (tier) |
| `MicroRewardStatus` | S>C + C>S | Статус micro rewards + запрос обновления |

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
│   ├── States/ (Luck — x2.0 label, Speed — cooldown label)
│   └── Autoroll/ (ViewingRoll when auto-rolling)
├── MenuGui/
│   ├── Backpack/ > Body/ScrollingFrame + EquippedBoard/Tiles + CloseButton
│   ├── Upgrade/ > Canvas/Board/UIScale + CloseButton
│   │   ├── DailyReward/ (контейнер для 7 плиток daily reward)
│   │   └── MicroReward/ (контейнер для 3 плиток micro reward)
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
│   ├── GateSurfaceGui (template)
│   └── HealsBarGui (template — cloned for pet/enemy HP bars)
├── UI/Components/ItemTile (module)
├── CombatConfig (shared ModuleScript)
├── OfflineIncomeConfig (shared ModuleScript)
├── DailyRewardConfig (shared ModuleScript)
├── MicroRewardConfig (shared ModuleScript)
└── Remotes/ (all RemoteEvents)

## ModuleScripts in ServerScriptService

ServerScriptService/
└── GameServer (Script — entry point)
    └── Modules/
        ├── PlayerService.lua         — PlayerData lifecycle, GetValue/UpdateValue wrappers, DEFAULT_DATA schema
        ├── EconomyService.lua        — Currency add/subtract/canAfford, AddRocks checks rocksUnlocked
        ├── RollService.lua           — RNG, anti-spam, auto-equip
        ├── CombatService.lua         — Heartbeat-loop: per-entity attack state machine, HP/shield, respawn/revive, per-tick SyncCombatState deltas
        ├── UpgradeService.lua        — Purchase validation, effect application, permanentUpgrades recording
        ├── LocationService.lua       — Unlock via Gate, Baseplate Touch → currentLocation
        ├── PetEquipService.lua       — Equip/Unequip validation + auto-swap on full slots
        ├── RebirthService.lua        — Rebirth validation, reset via DEFAULT_DATA, SKIP_FIELDS, permanentUpgrades merge
        ├── OfflineIncomeService.lua  — Offline income calculation on player entry, warning logic
        ├── DailyRewardService.lua    — 7-day cycle, advance/reset on entry, claim validation
        └── MicroRewardService.lua    — 3 independent timer-based rewards (30/60/120 min)

## Client Controllers (StarterPlayerScripts/GameClient/Modules/)

| Controller | Role |
|---|---|
| `EconomyController.lua` | Currency HUD (coins, rocks, luck, speed), AnimateCoin |
| `RollController.lua` | Roll + AutoRoll: HUD button, ViewingRoll display, auto-roll loop |
| `CombatController.lua` | 3D enemy/pet models, procedural jumping, attack animation (jumpTo/jumpBack), HealsBarGui HP bars, Flat XZ look, Recovery state, ground tracking via Raycast (planned) |
| `UpgradeController.lua` | Upgrade tree board (pan, no zoom), notifications badge, `_isBranchComplete` для extinct-состояния, счётчик claimable наград |
| `LocationController.lua` | Gate GUIs (create/restore/destroy), Rebirth Refresh |
| `BackpackController.lua` | Pet inventory: ScrollingFrame + EquippedBoard |
| `MenuController.lua` | Window manager: toggle MenuGui windows |
| `RebirthController.lua` | Rebirth menu: requirements, ResultBoard, confirmation popup |
| `VisibilityController.lua` | HUD visibility gating by upgrades + permanentUpgrades (Rocks, Shop, Rebirth, Index) |
| `OfflineIncomeController.lua` | Popup с накопленным офлайн-доходом при входе |
| `DailyRewardController.lua` | Рендер 7 плиток в MenuGui.Upgrade.DailyReward, claim по клику |
| `MicroRewardController.lua` | Рендер 3 плиток в MenuGui.Upgrade.MicroReward, таймеры обратного отсчёта |