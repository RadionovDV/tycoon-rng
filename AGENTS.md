# AGENTS.md — OpenCode AI Development Guide

## Before making ANY changes

1. **Read all docs first:**
   - `docs/PROJECT_STATE.md` — current architecture, what is built, key files
   - `docs/KNOWN_ISSUES.md` — bugs, risks, what NOT to break
   - `docs/MVP_PART_3_PLAN.md` — next implementation plan (if active)
   - This file (AGENTS.md) — development conventions

2. **Propose a short plan** before touching any code. Include:
   - Which files will change and why
   - Any new modules/files needed
   - Any new RemoteEvents needed
   - How existing systems interact with the change

3. **Wait for user approval** before implementing.

## Conventions

- **No Rojo**. All files are manually placed in Roblox Studio.
- **No custom DataService**. Use `PlayerDataServer` / `PlayerDataClient` from `ReplicatedStorage.PlayerData`.
- **No UI creation in code**. All UI elements already exist in StarterGui. Controllers reference them via `WaitForChild` / `FindFirstChild`.
- **UI references are pre-fetched at module top-level**, not inside functions.
- **Per-field API**: use `PlayerDataServer.getValue/setValue/updateValue` (not a bulk `get/update`).
- **Module naming**: Config files end with `Config.lua` (e.g., `PetConfig.lua`).

## Require path conventions

- **Server modules** relative to `script.Parent`: `require(script.Parent.PlayerService)`
- **Client modules** relative to `script.Parent.Modules`: `require(module.EconomyController)`
- **Shared modules** from `ReplicatedStorage` directly:
  - `ReplicatedStorage.PlayerData.PlayerDataServer` (or `PlayerDataClient`)
  - `ReplicatedStorage.Signal`
  - `ReplicatedStorage.PetConfig`, `ReplicatedStorage.EnemyConfig`, etc.
  - `ReplicatedStorage.UI.Components.ItemTile`
  - `ReplicatedStorage.FormatNumber`, `ReplicatedStorage.RarityCalculator`

## RemoteEvents in use

Do NOT delete or rename these. Add new ones only after user approval.

| RemoteEvent | Direction | Purpose |
|---|---|---|
| `RollPet` | C>S + S>C | Roll request + result |
| `EquipPet` | C>S | Equip pet |
| `UnequipPet` | C>S | Unequip pet |
| `PurchaseUpgrade` | C>S | Buy upgrade |
| `UnlockLocation` | C>S | Unlock location |
| `EnemyDefeated` | S>C | Coin animation trigger |
| `PlayerDataLoaded` | S>C | PlayerData system |
| `PlayerDataUpdated` | S>C | PlayerData system |
| `PlayerDataSaved` | S>C | PlayerData system |

## Workspace structure (expected)

```
Workspace/
+-- Location1/
¦   +-- POI/
¦   ¦   L-- EnemySpawns/
¦   ¦       L-- SpawnPoint (BasePart, array)
¦   L-- Gate/
¦       L-- Back (BasePart with SurfaceGui or BillboardGui)
+-- Location2/
¦   L-- ...
L-- ...
```

## StarterGui structure (expected)

```
StarterPlayerScripts/
+-- GameClient (LocalScript)
¦   L-- Modules/ (all controllers)
L-- PlayerData Modules (in ReplicatedStorage)

StarterGui/
+-- GameplayGui/
¦   +-- HUD/
¦   +-- BottomSide/ (buttons: Backpack, Upgrade, Shop, Rebirth, Index)
¦   L-- LeftSide/  (currency labels: Coins, Rocks)
+-- MenuGui/
¦   +-- Backpack/ > Body/ScrollingFrame + CloseButton
¦   +-- Upgrade/ > ListContainer + NotificationBadge + CloseButton
¦   +-- Shop/
¦   +-- Rebirth/
¦   +-- Index/
¦   L-- Roll/ (roll result popup)

ReplicatedStorage/
+-- PetModels (3D models by pet ID)
+-- EnemyModels (3D meshes: AngryRock_Weak etc.)
+-- UI/Objects/ItemTileButton (template)
+-- UI/Components/ItemTile (module)
L-- Remotes/ (all RemoteEvents)
