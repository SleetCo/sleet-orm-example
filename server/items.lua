--[[
    items.lua — 物品 & 背包系统示例

    展示：
      · 使用非自增主键（name 作为 VARCHAR PK）
      · BETWEEN / IS NULL / NOT NULL 条件
      · 多条件复合查询
      · 背包与物品关联查询（JOIN）
--]]

local sl = Sleet
local s  = require 'schema'
local db = sl.connect()

-- ────────────────────────────────────────────────
-- 物品定义
-- ────────────────────────────────────────────────

--- 获取所有物品（ItemsRecord[]）
local function getAllItems()
    return db.select()
        .from(s.items)
        .orderBy(s.items.label, 'asc')
        .execute()
end

--- 按名称获取物品
local function getItem(name)
    local rows = db.select()
        .from(s.items)
        .where(sl.eq(s.items.name, name))
        .limit(1)
        .execute()
    return rows[1]
end

--- 获取可用物品（usable = true）
local function getUsableItems()
    return db.select()
        .from(s.items)
        .where(sl.eq(s.items.usable, true))
        .execute()
end

--- 按重量范围查询物品
local function getItemsByWeight(minWeight, maxWeight)
    return db.select()
        .from(s.items)
        .where(sl.between(s.items.weight, minWeight, maxWeight))
        .orderBy(s.items.weight, 'asc')
        .execute()
end

--- 查询有描述的物品
local function getItemsWithDescription()
    return db.select()
        .from(s.items)
        .where(sl.isNotNull(s.items.description))
        .execute()
end

--- 按名称列表批量获取物品
local function getItemsByNames(names)
    return db.select()
        .from(s.items)
        .where(sl.inArray(s.items.name, names))
        .execute()
end

-- ────────────────────────────────────────────────
-- 背包操作
-- ────────────────────────────────────────────────

--- 获取玩家背包（InventoryRecord[]）
local function getPlayerInventory(identifier)
    return db.select()
        .from(s.inventory)
        .where(sl.eq(s.inventory.identifier, identifier))
        .execute()
end

--- 获取背包 + 物品详情（JOIN）
---@return table[]
local function getPlayerInventoryFull(identifier)
    return db.select({
        s.inventory.item,
        s.inventory.amount,
        s.inventory.metadata,
        s.items.label,
        s.items.weight,
        s.items.usable,
        s.items.description,
    })
        .from(s.inventory)
        .innerJoin(s.items, sl.eq(s.inventory.item, s.items.name))
        .where(sl.eq(s.inventory.identifier, identifier))
        .orderBy(s.items.label, 'asc')
        .execute()
end

--- 获取某物品在玩家背包中的数量（InventoryRecord | nil）
local function getPlayerItemAmount(identifier, itemName)
    local rows = db.select()
        .from(s.inventory)
        .where(sl.and_(
            sl.eq(s.inventory.identifier, identifier),
            sl.eq(s.inventory.item, itemName)
        ))
        .limit(1)
        .execute()
    local row = rows[1]
    return row and row.amount or 0
end

--- 添加物品到背包（已有则增加数量，没有则插入）
local function addItem(identifier, itemName, amount, metadata)
    local existing = getPlayerItemAmount(identifier, itemName)
    if existing > 0 then
        return db.update(s.inventory)
            .set({ amount = sl.sql('`amount` + ?', { amount }) })
            .where(sl.and_(
                sl.eq(s.inventory.identifier, identifier),
                sl.eq(s.inventory.item, itemName)
            ))
            .execute()
    else
        return db.insert(s.inventory)
            .values({
                identifier = identifier,
                item       = itemName,
                amount     = amount,
                metadata   = metadata,
            })
            .execute()
    end
end

--- 移除物品（减少数量，数量为 0 时删除记录）
local function removeItem(identifier, itemName, amount)
    local current = getPlayerItemAmount(identifier, itemName)
    if current <= 0 then return false end

    if current <= amount then
        db.delete(s.inventory)
            .where(sl.and_(
                sl.eq(s.inventory.identifier, identifier),
                sl.eq(s.inventory.item, itemName)
            ))
            .execute()
    else
        db.update(s.inventory)
            .set({ amount = sl.sql('`amount` - ?', { amount }) })
            .where(sl.and_(
                sl.eq(s.inventory.identifier, identifier),
                sl.eq(s.inventory.item, itemName)
            ))
            .execute()
    end
    return true
end

--- 注册新物品（不存在则插入）
local function registerItem(name, label, weight, usable, description)
    local existing = getItem(name)
    if existing then return false end

    db.insert(s.items)
        .values({
            name        = name,
            label       = label,
            weight      = weight or 0,
            usable      = usable or false,
            description = description,
        })
        .execute()
    return true
end

-- ────────────────────────────────────────────────
-- FiveM 事件示例
-- ────────────────────────────────────────────────

RegisterNetEvent('sleet_example:useItem', function(itemName)
    local identifier = 'steam:' .. (GetPlayerIdentifier(source, 0) or 'unknown')
    local item       = getItem(itemName)

    if not item or not item.usable then
        TriggerClientEvent('sleet_example:notify', source, '该物品无法使用')
        return
    end

    local removed = removeItem(identifier, itemName, 1)
    if removed then
        -- item: ItemsRecord — IDE 可推断 item.label, item.weight 等字段
        TriggerClientEvent('sleet_example:notify', source, ('已使用 %s'):format(item.label))
        TriggerEvent('sleet_example:onItemUsed', source, itemName)
    else
        TriggerClientEvent('sleet_example:notify', source, '背包中没有该物品')
    end
end)
