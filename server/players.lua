--[[
    players.lua — 玩家 CRUD 示例

    展示：
      · SELECT 全字段/指定列/条件/分页
      · INSERT 并获取 insertId
      · UPDATE 普通字段 & sl.sql() 原始表达式 & onUpdate 自动更新
      · 软删除 (DELETE 自动转为 UPDATE deleted_at)
      · withDeleted() 查询已删除记录
      · toSQL() 调试输出
      · 零 ---@type：LuaLS 全程推断 PlayersRecord / PlayersRecord[]
--]]

local sl = Sleet
local s  = require 'schema'
local db = sl.connect()

--- 获取所有玩家（PlayersRecord[]，无需手写类型）
local function getAllPlayers()
    return db.select()
        .from(s.players)
        .orderBy(s.players.id, 'asc')
        .execute()
end

--- 按标识符查找单个玩家，返回 PlayersRecord | nil
local function getPlayerByIdentifier(identifier)
    local rows = db.select()
        .from(s.players)
        .where(sl.eq(s.players.identifier, identifier))
        .limit(1)
        .execute()
    return rows[1]
end

--- 分页获取玩家列表
local function getPlayersPaged(page, perPage)
    local offset = (page - 1) * perPage
    return db.select()
        .from(s.players)
        .orderBy(s.players.created_at, 'desc')
        .limit(perPage)
        .offset(offset)
        .execute()
end

--- 查询有钱的管理员
local function getRichAdmins(minBalance)
    return db.select()
        .from(s.players)
        .where(sl.and_(
            sl.eq(s.players.is_admin, true),
            sl.gte(s.players.bank, minBalance)
        ))
        .orderBy(s.players.bank, 'desc')
        .execute()
end

--- 按职业查询玩家
local function getPlayersByJob(job)
    return db.select()
        .from(s.players)
        .where(sl.eq(s.players.job, job))
        .execute()
end

--- 查询指定列（只取 id / name / money）
local function getPlayerSummaries()
    return db.select({ s.players.id, s.players.name, s.players.money, s.players.bank })
        .from(s.players)
        .where(sl.gt(s.players.money, 0))
        .execute()
end

--- 调试：打印 SQL 但不执行
local function debugQuery(identifier)
    local sql, params = db.select()
        .from(s.players)
        .where(sl.eq(s.players.identifier, identifier))
        .limit(1)
        .toSQL()
    print(('[sleet] SQL: %s | params: %s'):format(sql, json.encode(params)))
end

-- ────────────────────────────────────────────────
-- 写入
-- ────────────────────────────────────────────────

--- 创建新玩家，返回 insertId
local function createPlayer(identifier, name)
    return db.insert(s.players)
        .values({
            identifier = identifier,
            name       = name,
        })
        .execute()
end

--- 更新玩家名称 & 职业
local function updatePlayerInfo(identifier, name, job)
    return db.update(s.players)
        .set({ name = name, job = job })
        .where(sl.eq(s.players.identifier, identifier))
        .execute()
end

--- 存入现金（用 sl.sql 做原子加法，避免并发问题）
local function depositCash(identifier, amount)
    return db.update(s.players)
        .set({
            money = sl.sql('`money` - ?', { amount }),
            bank  = sl.sql('`bank` + ?', { amount }),
        })
        .where(sl.and_(
            sl.eq(s.players.identifier, identifier),
            sl.gte(s.players.money, amount)   -- 确保现金足够
        ))
        .execute()
end

--- 给所有玩家发放工资
local function paySalaryToAll(amount)
    return db.update(s.players)
        .set({ bank = sl.sql(('`bank` + %d'):format(amount)) })
        .execute()
end

--- 软删除玩家（实际执行 UPDATE deleted_at = NOW()）
local function deletePlayer(identifier)
    return db.delete(s.players)
        .where(sl.eq(s.players.identifier, identifier))
        .execute()
end

--- 获取已删除的玩家列表（包含软删除的记录）
local function getDeletedPlayers()
    return db.select()
        .from(s.players)
        .withDeleted()  -- 包含已删除记录
        .where(sl.isNotNull(s.players.deleted_at))
        .orderBy(s.players.deleted_at, 'desc')
        .execute()
end

--- 恢复已删除的玩家（清除 deleted_at 时间戳）
local function restorePlayer(identifier)
    return db.update(s.players)
        .set({ deleted_at = nil })
        .where(sl.and_(
            sl.eq(s.players.identifier, identifier),
            sl.isNotNull(s.players.deleted_at)
        ))
        .execute()
end

--- 永久删除玩家（真正的物理删除，慎用！）
local function forceDeletePlayer(identifier)
    -- 注意：这会真正删除数据库记录，无法恢复
    local sql = 'DELETE FROM `players` WHERE `identifier` = ?'
    return MySQL.query.await(sql, { identifier })
end

--- 演示 onUpdate 功能：每次更新玩家信息时，last_seen 会自动更新
local function touchPlayer(identifier)
    -- 这个更新会自动触发 last_seen 的 onUpdate，设置为当前时间
    return db.update(s.players)
        .set({ name = sl.sql('`name`') })  -- 用原值更新name，触发onUpdate
        .where(sl.eq(s.players.identifier, identifier))
        .execute()
end

--- 批量插入示例
local function createMultiplePlayers(playersData)
    -- playersData = { {identifier='steam:xxx', name='Player1'}, ... }
    return db.insert(s.players)
        .values(playersData)
        .execute()
end

-- ────────────────────────────────────────────────
-- FiveM 事件绑定示例
-- ────────────────────────────────────────────────

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    local identifier = 'steam:' .. (GetPlayerIdentifier(src, 0) or 'unknown')
    deferrals.defer()

    local player = getPlayerByIdentifier(identifier)
    if not player then
        -- 首次连接，创建账号
        createPlayer(identifier, name)
        print(('[sleet] 新玩家注册: %s (%s)'):format(name, identifier))
    else
        -- player: PlayersRecord — IDE 可推断 player.name, player.bank 等
        print(('[sleet] 玩家回归: %s，上次在线: %s'):format(player.name, player.last_seen))
    end

    deferrals.done()
end)

AddEventHandler('sleet_example:depositCash', function(identifier, amount)
    -- assert()
    if not identifier then
        return
    end
    local affected   = depositCash(identifier, amount)
    if affected > 0 then
        print('存钱成功')
    else
        -- cash < amount
        print('存钱失败')
    end
end)
