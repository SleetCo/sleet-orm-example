# Sleet ORM 完整示例

这是一个展示 Sleet ORM 所有功能的完整示例项目。

## 🚀 特性演示

### 基础 CRUD 操作
- ✅ **SELECT**: 全字段查询、指定列、条件查询、分页、排序
- ✅ **INSERT**: 单条插入、批量插入
- ✅ **UPDATE**: 字段更新、原子操作 (`sl.sql()`)
- ✅ **DELETE**: 软删除（自动）

### 高级功能
- ✅ **软删除 (Soft Delete)**: 自动将 DELETE 转换为 UPDATE deleted_at
- ✅ **onUpdate 自动更新**: 字段在 UPDATE 时自动设置值
- ✅ **JOIN 查询**: LEFT/INNER/RIGHT JOIN 跨表关联
- ✅ **复杂条件**: AND/OR/NOT、IN/BETWEEN、IS NULL 等
- ✅ **聚合查询**: COUNT/SUM/AVG 等统计功能
- ✅ **原始 SQL**: `sl.sql()` 嵌入原生 SQL 表达式

### 数据库关系
- ✅ **外键约束**: `.references()` 定义表间关系
- ✅ **主键**: 自增 ID 和自定义主键
- ✅ **索引**: 唯一约束、复合索引

## 📁 文件结构

```
sleet_orm_example/
├── schema.lua          # 数据库结构定义
├── schema.sql          # 自动生成的 SQL (by CLI)
├── fxmanifest.lua      # FiveM 资源配置
└── server/
    ├── main.lua        # 入口文件 + 测试命令
    ├── players.lua     # 玩家系统示例
    ├── gangs.lua       # 帮派系统示例
    └── items.lua       # 物品背包示例
```

## 🎮 测试命令

在游戏中使用以下命令测试各项功能：

### 基础查询
```bash
sleet_items                           # 查看所有物品
sleet_player <identifier>             # 查看玩家信息
```

### 软删除演示
```bash
sleet_create_test_players             # 创建测试玩家
sleet_delete_player <identifier>      # 软删除玩家
sleet_deleted_players                 # 查看已删除玩家
sleet_restore_player <identifier>     # 恢复已删除玩家
```

### onUpdate 演示
```bash
sleet_touch_player <identifier>       # 触发 last_seen 自动更新
```

### 高级功能
```bash
sleet_rich_stats                      # 富有玩家统计 (聚合查询)
sleet_money <identifier> <amount>     # 原子金钱操作
```

## 🔧 软删除 (Soft Delete)

在 schema 中定义软删除字段：
```lua
deleted_at = sl.timestamp().softDelete().comment('软删除时间戳')
```

使用方式：
```lua
-- 删除 (实际执行 UPDATE deleted_at = NOW())
db.delete(s.players)
    .where(sl.eq(s.players.identifier, 'steam:xxx'))
    .execute()

-- 查询时自动过滤已删除记录
db.select().from(s.players).execute()  -- 只返回未删除的

-- 包含已删除记录
db.select().from(s.players).withDeleted().execute()  -- 包含已删除的
```

## ⚡ onUpdate 自动更新

在 schema 中定义自动更新字段：
```lua
last_seen = sl.timestamp().defaultNow().onUpdate(sl.sql('NOW()')).comment('最后在线时间（自动更新）')
```

每次 UPDATE 该表时，`last_seen` 会自动更新为当前时间。

## 🏗️ 重新生成 SQL

当修改 schema.lua 后，使用 CLI 重新生成 SQL：
```bash
cd sleet/cli
go run . sql ../../sleet_orm_example/schema.lua --out ../../sleet_orm_example/schema.sql
```

## 📚 更多信息

- [Sleet ORM 文档](../sleet/README_CN.md)
- [CLI 工具文档](../sleet/cli/README_CN.md)
