--[[
    players.lua — 玩家 CRUD 示例

    展示：
      · SELECT 全字段/指定列/条件/分页
      · INSERT 并获取 insertId
      · UPDATE 普通字段 & sl.sql() 原始表达式
      · DELETE
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

--- 删除玩家
local function deletePlayer(identifier)
    return db.delete(s.players)
        .where(sl.eq(s.players.identifier, identifier))
        .execute()
end

-- ────────────────────────────────────────────────
-- FiveM 事件绑定示例
-- ────────────────────────────────────────────────

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local identifier = 'steam:' .. (GetPlayerIdentifier(source, 0) or 'unknown')
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

RegisterNetEvent('sleet_example:depositCash', function(amount)
    local identifier = 'steam:' .. (GetPlayerIdentifier(source, 0) or 'unknown')
    local affected   = depositCash(identifier, amount)
    if affected > 0 then
        TriggerClientEvent('sleet_example:notify', source, ('已存入 $%d'):format(amount))
    else
        TriggerClientEvent('sleet_example:notify', source, '现金不足')
    end
end)
