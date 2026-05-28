# MVP_PART_3_PLAN.md — Day 3 Implementation Plan

## Goal
Full real-time combat with 3D enemy movement, pet HP/revive system, coin-fly animation, and polish.

## Status
Not started. All Day 1 and Day 2 systems are complete and functional.

## Planned Changes

### 1. EnemyConfig — add combat stats
Add fields: `movementSpeed`, `attackRange`, `attackDamage`, `attackRate`

```lua
{ id = "AngryRock_Weak", hp = 30, reward = 10,
  movementSpeed = 8, attackRange = 15,
  attackDamage = 5, attackRate = 1,            -- NEW
  displayName = "Angry Rock", locations = { "Location1" } },
```

### 2. PetConfig — add HP
Add `hp` field to each pet:
```lua
{ id = "Common_Pebble", weight = 500, rarity = "Common",
  damage = 5, hp = 20, displayName = "Pebble" },  -- NEW: hp
```

### 3. RollService — store maxHp on pet creation
When creating pet entry in inventory, save `maxHp = petData.hp or 20`.

### 4. CombatService — major rewrite
- **Enemy AI**: PathfindingService > move toward player along waypoints
- **Attack trigger**: enemy in range > pick random alive pet > deal damage per tick
- **Pet combat state**: in-memory `petCombat[userId][petId] = { hp, maxHp, isAlive, reviveTimer }`
- **Pet death**: when HP ? 0 > `isAlive = false`, FireClient(PetDefeated)
- **Pet revive**: after 5s > `isAlive = true`, FireClient(PetRevived)
- **Enemy death**: destroy model, EconomyService.AddCoins, respawn after delay
- **Sync state**: FireClient(SyncCombatState) every tick with enemy/pet HP and positions

### 5. New RemoteEvents (must create in Studio)
| RemoteEvent | Direction | Payload |
|---|---|---|
| `SyncCombatState` | S>C | `{ enemies: {id={hp,maxHp,pos}}, pets: {id={hp,maxHp,isAlive}} }` |
| `PetDefeated` | S>C | `{ petId }` |
| `PetRevived` | S>C | `{ petId }` |

### 6. CombatController — major rewrite (client)
- Spawn 3D enemy models from `ReplicatedStorage.EnemyModels.<type>`
- HP bars (BillboardGui) on enemies and pets
- Handle `SyncCombatState` > update HP displays
- Handle `PetDefeated` > pet model fades out (transparency)
- Handle `PetRevived` > pet model fades back in
- Handle `EnemyDefeated` > destroy enemy model, trigger coin animation

### 7. EconomyController — coin-fly animation
- `AnimateCoin(amount, screenPosition)`: create ImageLabel, TweenService to `GameplayGui.LeftSide.Coins`, destroy on complete, update label

### 8. GameClient — add new subscriptions
Connect `SyncCombatState`, `PetDefeated`, `PetRevived` events.

## Files to modify

| File | Type | Change |
|---|---|---|
| `shared/EnemyConfig.lua` | MODIFY | +movementSpeed, attackRange, attackDamage, attackRate |
| `shared/PetConfig.lua` | MODIFY | +hp field |
| `server/modules/RollService.lua` | MODIFY | +maxHp in petEntry |
| `server/modules/CombatService.lua` | REWRITE | Pathfinding, enemy AI, pet HP/revive |
| `client/modules/CombatController.lua` | REWRITE | Enemy models, HP bars, death/revive visual |
| `client/modules/EconomyController.lua` | MODIFY | +AnimateCoin |
| `client/GameClient.lua` | MODIFY | +subscriptions to new events |

## MVP simplifications
- Pathfinding recomputed every 2s (not every tick)
- Enemy model: simple mesh without animations (already in ReplicatedStorage.EnemyModels)
- Pet HP bar: TextLabel "HP: 30/30" rather than colored bar
- Pet attack animation: instant damage tick (no Tween to enemy)
- Coin animation: straight Tween (not bezier curve)
- No particles or sound effects (post-MVP)
