--[[
    main.lua — 资源入口，初始化示例数据

    展示：
      · 资源启动时自动建表 / 填充默认数据
      · 批量 INSERT
      · 跨文件共享 schema（require 'schema' 按需加载，结果自动缓存）
--]]

local sl = Sleet
local s  = require 'schema'
local db = sl.connect()

-- ────────────────────────────────────────────────
-- 初始化默认物品（仅当表为空时执行）
-- ────────────────────────────────────────────────
local function seedItems()
    local existing = db.select()
        .from(s.items)
        .limit(1)
        .execute()

    if existing[1] then return end   -- 已有数据，跳过

    local defaultItems = {
        { name = 'water',      label = '矿泉水',   weight = 0.5,  usable = true,  description = '解渴用的矿泉水' },
        { name = 'bread',      label = '面包',     weight = 0.3,  usable = true,  description = '能填饱肚子的面包' },
        { name = 'phone',      label = '手机',     weight = 0.2,  usable = true,  description = '智能手机' },
        { name = 'lockpick',   label = '撬锁工具', weight = 0.1,  usable = true,  description = '可以撬开普通门锁' },
        { name = 'bandage',    label = '绷带',     weight = 0.15, usable = true,  description = '简单包扎伤口' },
        { name = 'weapon_pistol', label = '手枪',  weight = 1.2,  usable = false, description = nil },
        { name = 'cash',       label = '现金',     weight = 0.01, usable = false, description = '游戏内现金' },
    }

    for _, item in ipairs(defaultItems) do
        db.insert(s.items)
            .values(item)
            .execute()
    end

    print('[sleet_example] 默认物品初始化完成')
end

-- ────────────────────────────────────────────────
-- 初始化测试帮派
-- ────────────────────────────────────────────────
local function seedGang()
    local existing = db.select()
        .from(s.gangs)
        .where(sl.eq(s.gangs.name, 'example_gang'))
        .limit(1)
        .execute()

    if existing[1] then return end

    db.insert(s.gangs)
        .values({
            name      = 'example_gang',
            label     = '示例帮派',
            max_grade = 4,
        })
        .execute()

    print('[sleet_example] 示例帮派初始化完成')
end

-- ────────────────────────────────────────────────
-- 统计信息（展示聚合 + sl.sql）
--
-- 聚合查询（COUNT/SUM/AVG 等）使用了 sl.sql() 原始表达式，
-- 其返回列无法被 CLI 静态分析，需手动用 ---@type 标注行形状。
-- JOIN / 多表混合查询同理。
-- ────────────────────────────────────────────────
local function printStats()
    ---@type { total: integer }[]
    local playerCount = db.select({ sl.sql('COUNT(*) AS total') })
        .from(s.players)
        .execute()

    ---@type { total: integer }[]
    local gangCount = db.select({ sl.sql('COUNT(*) AS total') })
        .from(s.gangs)
        .execute()

    ---@type { total: integer }[]
    local itemCount = db.select({ sl.sql('COUNT(*) AS total') })
        .from(s.items)
        .execute()

    print(('[sleet_example] 统计 — 玩家: %d | 帮派: %d | 物品: %d'):format(
        playerCount[1] and playerCount[1].total or 0,
        gangCount[1]   and gangCount[1].total   or 0,
        itemCount[1]   and itemCount[1].total    or 0
    ))
end

-- ────────────────────────────────────────────────
-- 资源启动
-- ────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    seedItems()
    seedGang()
    printStats()

    print('[sleet_example] 资源启动完成 ✓')
end)

-- 查询所有物品（供测试用）
RegisterCommand('sleet_items', function(source)
    local items = db.select()
        .from(s.items)
        .orderBy(s.items.label, 'asc')
        .execute()

    -- items: ItemsRecord[] — 全字段推断
    for _, item in ipairs(items) do
        print(('[%s] %s  %.2f g  usable=%s'):format(
            item.name, item.label, item.weight, tostring(item.usable)
        ))
    end
end, true)

-- 查询玩家信息（供测试用）
RegisterCommand('sleet_player', function(source, args)
    local identifier = args[1]
    if not identifier then return print('用法: sleet_player <identifier>') end

    local sl_local = Sleet
    local rows = db.select()
        .from(s.players)
        .where(sl_local.eq(s.players.identifier, identifier))
        .limit(1)
        .execute()

    local player = rows[1]
    if not player then
        return print('玩家不存在: ' .. identifier)
    end

    -- player: PlayersRecord — IDE 可精确推断每个字段
    print(('玩家: %s | 现金: $%d | 银行: $%d | 职业: %s | 管理员: %s'):format(
        player.name, player.money, player.bank, player.job, tostring(player.is_admin)
    ))
end, true)
