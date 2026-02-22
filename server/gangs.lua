--[[
    gangs.lua — 帮派系统示例

    展示：
      · LEFT JOIN / INNER JOIN 跨表查询
      · IN 查询 / BETWEEN / IS NULL
      · 复合 WHERE 条件
      · INSERT + 关联更新（事务式写法）
--]]

local sl = Sleet
local s  = require('schema')
local db = sl.connect()

--- 获取所有帮派
local function getAllGangs()
    return db.select()
        .from(s.gangs)
        .orderBy(s.gangs.bank, 'desc')
        .execute()
end

--- 获取帮派及其帮主信息（JOIN 跨表，需手动标注类型）
---@return table[]
local function getGangsWithOwner()
    return db.select({
        s.gangs.id,
        s.gangs.name,
        s.gangs.label,
        s.gangs.bank,
        s.players.name,
        s.players.identifier,
    })
        .from(s.gangs)
        .leftJoin(s.players, sl.eq(s.gangs.owner, s.players.identifier))
        .orderBy(s.gangs.bank, 'desc')
        .execute()
end

--- 获取某帮派的所有成员（GangMembersRecord[]）
local function getGangMembers(gangId)
    return db.select()
        .from(s.gangMembers)
        .where(sl.eq(s.gangMembers.gang_id, gangId))
        .orderBy(s.gangMembers.grade, 'desc')
        .execute()
end

--- 获取成员 + 玩家信息（INNER JOIN）
---@return table[]
local function getGangMembersWithPlayerInfo(gangId)
    return db.select({
        s.gangMembers.grade,
        s.gangMembers.grade_name,
        s.gangMembers.joined_at,
        s.players.name,
        s.players.identifier,
        s.players.money,
    })
        .from(s.gangMembers)
        .innerJoin(s.players, sl.eq(s.gangMembers.identifier, s.players.identifier))
        .where(sl.eq(s.gangMembers.gang_id, gangId))
        .orderBy(s.gangMembers.grade, 'desc')
        .execute()
end

--- 查询一个玩家所属的帮派（PlayersRecord + GangsRecord 交叉）
---@return table[]
local function getPlayerGang(identifier)
    return db.select({
        s.gangs.id,
        s.gangs.name,
        s.gangs.label,
        s.gangMembers.grade,
        s.gangMembers.grade_name,
    })
        .from(s.gangMembers)
        .innerJoin(s.gangs, sl.eq(s.gangMembers.gang_id, s.gangs.id))
        .where(sl.eq(s.gangMembers.identifier, identifier))
        .limit(1)
        .execute()
end

--- 查询资产排行（金库 > 0 的帮派）
local function getWealthyGangs(minBank)
    return db.select()
        .from(s.gangs)
        .where(sl.gt(s.gangs.bank, minBank))
        .orderBy(s.gangs.bank, 'desc')
        .execute()
end

--- 按 ID 列表批量获取帮派
local function getGangsByIds(ids)
    return db.select()
        .from(s.gangs)
        .where(sl.inArray(s.gangs.id, ids))
        .execute()
end

--- 没有设置帮主的帮派
local function getGangsWithoutOwner()
    return db.select()
        .from(s.gangs)
        .where(sl.isNull(s.gangs.owner))
        .execute()
end

-- ────────────────────────────────────────────────
-- 写入
-- ────────────────────────────────────────────────

--- 创建帮派，返回新帮派 ID
local function createGang(name, label, ownerIdentifier)
    local gangId = db.insert(s.gangs)
        .values({
            name  = name,
            label = label,
            owner = ownerIdentifier,
        })
        .execute()

    -- 将创始人设为最高等级成员
    if gangId and gangId > 0 then
        db.insert(s.gangMembers)
            .values({
                gang_id    = gangId,
                identifier = ownerIdentifier,
                grade      = 4,
                grade_name = 'Boss',
            })
            .execute()
    end

    return gangId
end

--- 添加成员
local function addMember(gangId, identifier, grade, gradeName)
    return db.insert(s.gangMembers)
        .values({
            gang_id    = gangId,
            identifier = identifier,
            grade      = grade or 0,
            grade_name = gradeName or 'Recruit',
        })
        .execute()
end

--- 更新成员等级
local function setMemberGrade(gangId, identifier, grade, gradeName)
    return db.update(s.gangMembers)
        .set({ grade = grade, grade_name = gradeName })
        .where(sl.and_(
            sl.eq(s.gangMembers.gang_id, gangId),
            sl.eq(s.gangMembers.identifier, identifier)
        ))
        .execute()
end

--- 帮派存款（原子加法）
local function depositToGang(gangId, amount)
    return db.update(s.gangs)
        .set({ bank = sl.sql('`bank` + ?', { amount }) })
        .where(sl.eq(s.gangs.id, gangId))
        .execute()
end

--- 踢出成员
local function kickMember(gangId, identifier)
    return db.delete(s.gangMembers)
        .where(sl.and_(
            sl.eq(s.gangMembers.gang_id, gangId),
            sl.eq(s.gangMembers.identifier, identifier)
        ))
        .execute()
end

--- 解散帮派（先删成员，再删帮派）
local function disbandGang(gangId)
    db.delete(s.gangMembers)
        .where(sl.eq(s.gangMembers.gang_id, gangId))
        .execute()

    return db.delete(s.gangs)
        .where(sl.eq(s.gangs.id, gangId))
        .execute()
end

-- ────────────────────────────────────────────────
-- FiveM 事件示例
-- ────────────────────────────────────────────────

RegisterNetEvent('sleet_example:createGang', function(name, label)
    local identifier = 'steam:' .. (GetPlayerIdentifier(source, 0) or 'unknown')
    local gangId     = createGang(name, label, identifier)
    if gangId then
        TriggerClientEvent('sleet_example:notify', source, ('帮派 [%s] 创建成功，ID: %d'):format(label, gangId))
    end
end)

RegisterNetEvent('sleet_example:depositToGang', function(gangId, amount)
    local affected = depositToGang(gangId, amount)
    if affected > 0 then
        TriggerClientEvent('sleet_example:notify', source, ('已向帮派金库存入 $%d'):format(amount))
    end
end)
