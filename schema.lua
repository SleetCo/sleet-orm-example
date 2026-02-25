--[[
    schema.lua — Sleet ORM 数据库结构定义
--]]

local sl = Sleet

-- ──────────────────────────────────────────
-- 玩家账户表
-- ──────────────────────────────────────────
local players = sl.table('players', {
    id         = sl.serial().primaryKey().comment('玩家自增ID'),
    identifier = sl.varchar(64).notNull().unique().comment('玩家唯一标识符（Steam/Discord）'),
    name       = sl.varchar(255).notNull().comment('玩家名称'),
    money      = sl.int().default(500).comment('现金'),
    bank       = sl.int().default(2500).comment('银行余额'),
    is_admin   = sl.boolean().default(false).comment('是否为管理员'),
    job        = sl.varchar(64).default('unemployed').comment('当前职业'),
    metadata   = sl.json().comment('扩展数据（许可证、角色信息等）'),
    last_seen  = sl.timestamp().defaultNow().onUpdate(sl.sql('NOW()')).comment('最后在线时间（自动更新）'),
    created_at = sl.timestamp().defaultNow().comment('账号创建时间'),
    deleted_at = sl.timestamp().softDelete().comment('软删除时间戳'),
})

-- ──────────────────────────────────────────
-- 帮派表
-- ──────────────────────────────────────────
local gangs = sl.table('gangs', {
    id         = sl.serial().primaryKey().comment('帮派自增ID'),
    name       = sl.varchar(64).notNull().unique().comment('帮派唯一名称'),
    label      = sl.varchar(128).notNull().comment('帮派显示名称'),
    owner      = sl.varchar(64).references(players.identifier).comment('帮主标识符'),
    bank       = sl.bigint().default(0).comment('帮派金库余额'),
    max_grade  = sl.tinyint().default(4).comment('最高等级数'),
    created_at = sl.timestamp().defaultNow().comment('创建时间'),
})

-- ──────────────────────────────────────────
-- 帮派成员表
-- ──────────────────────────────────────────
local gangMembers = sl.table('gang_members', {
    id         = sl.serial().primaryKey().comment('记录ID'),
    gang_id    = sl.int().notNull().references(gangs.id).comment('所属帮派ID'),
    identifier = sl.varchar(64).notNull().references(players.identifier).comment('成员标识符'),
    grade      = sl.tinyint().default(0).comment('成员等级（0 = 新兵）'),
    grade_name = sl.varchar(64).default('Recruit').comment('等级名称'),
    joined_at  = sl.timestamp().defaultNow().comment('加入时间'),
})

-- ──────────────────────────────────────────
-- 物品定义表
-- ──────────────────────────────────────────
local items = sl.table('items', {
    name        = sl.varchar(64).primaryKey().comment('物品唯一名称（作为主键）'),
    label       = sl.varchar(128).notNull().comment('物品显示名称'),
    weight      = sl.decimal(8, 2).default(0).comment('物品重量（克）'),
    stack       = sl.boolean().default(true).comment('是否可叠加'),
    usable      = sl.boolean().default(false).comment('是否可使用'),
    description = sl.text().comment('物品描述'),
})

-- ──────────────────────────────────────────
-- 玩家背包表
-- ──────────────────────────────────────────
local inventory = sl.table('inventory', {
    id         = sl.serial().primaryKey().comment('记录ID'),
    identifier = sl.varchar(64).notNull().references(players.identifier).comment('玩家标识符'),
    item       = sl.varchar(64).notNull().references(items.name).comment('物品名称'),
    amount     = sl.int().default(1).comment('数量'),
    metadata   = sl.json().comment('物品元数据（耐久、序列号等）'),
})

return {
    players     = players,
    gangs       = gangs,
    gangMembers = gangMembers,
    items       = items,
    inventory   = inventory,
}