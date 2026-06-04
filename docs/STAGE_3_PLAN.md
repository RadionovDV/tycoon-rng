# STAGE_3_PLAN.md — CombatController Ground Collision + Final Integration

## Что осталось реализовать

### 1. Ground collision (Raycast на границах прыжков)
Pet и Enemy при перемещении по вертикальному рельефу должны стоять на земле.

**Файл:** `CombatController.lua`

**Решение:** Raycast вниз при старте прыжка. 2 raycast'а на прыжок:
- `jumpStart` → clamp Y
- `jumpEnd` → clamp Y

```lua
-- Кешированный RaycastParams на уровне модуля
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

-- Определение высоты земли в точке
local function _getGroundY(worldPos, blacklist)
    raycastParams.FilterDescendantsInstances = blacklist or {}
    local origin = worldPos + Vector3.new(0, 10, 0)
    local ray = Workspace:Raycast(origin, Vector3.new(0, -20, 0), raycastParams)
    if ray then
        return ray.Position.Y + 0.5
    end
    return worldPos.Y
end
```

**Вызов в `_applyJump`:** при установке `jumpStart` и `jumpEnd`:
```lua
entry.jumpStart = Vector3.new(entry.position.X, _getGroundY(entry.position, blacklist), entry.position.Z)
entry.jumpEnd = Vector3.new(jumpEnd.X, _getGroundY(jumpEnd, blacklist), jumpEnd.Z)
```

**Для `_processAttackPhase`:** то же самое — clamp Y прыжка к земле.

**ToDo:**
- [ ] Добавить `raycastParams` на уровне модуля
- [ ] Создать `_getGroundY(pos, blacklist)` helper
- [ ] Черный список: character модели игрока (чтобы не raycast'ить сквозь персонажа)
- [ ] Обновить `_applyJump`: clamp `jumpStart.Y` и `jumpEnd.Y`
- [ ] Обновить `_processAttackPhase`: clamp `jumpEnd.Y` если targetPos известен
- [ ] Опционально: raycast в середине дуги для крутых обрывов

---

### 2. Финальная верификация

- [ ] Проверить: PetAttack анимация (jumpTo → damage → jumpBack)
- [ ] Проверить: EnemyAttack анимация (jumpTo → damage → jumpBack)
- [ ] Проверить: enemy фокус на одном pet, смена при смерти
- [ ] Проверить: Recovery state (пет умер → стоит + прозрачный)
- [ ] Проверить: HP bar (Filler.Size + CountLabel текст)
- [ ] Проверить: ground collision (вертикальные подъёмы/спуски)

---

## Изменяемые файлы (Stage 3)

| Файл | Изменения |
|---|---|
| `src/client/modules/CombatController.lua` | RaycastParams, _getGroundY, clamp Y в _applyJump и _processAttackPhase |
| В Studio | создан PetAttack, EnemyAttack, HealsBarGui, CombatConfig |

## Взаимодействие с существующими системами

- **RaycastParams** фильтрует Character модели — не ломает игрока
- Ground collision — чисто визуальное (clamp Y). Не влияет на серверные позиции врагов (server-side `state.position` остаётся без изменений)
- PetAttack/EnemyAttack — новые RemoteEvents, не конфликтуют с существующими
- CombatConfig — новый shared модуль, независимый от других config-файлов
- HealsBarGui — новый BillboardGui шаблон, не влияет на существующие UI-объекты
