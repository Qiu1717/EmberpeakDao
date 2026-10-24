# 阶段5装备实例模块交付

日期：2026-10-24。范围仅为装备目录、局内实物与穿戴、快照严格恢复；永久武器解锁、死亡事务、战斗属性和界面由 Session 接入，不在此模块复制。

## 实际接口

- `equipment_catalog.gd` 是 Resource，`items` 字典含六件 GDD 物品。`tier` 与 `required_realm` 为0至4，对应炼气至化神；两项均满足才允许穿戴。`rarity` 单独保留，未生成任何词条。
- `Inventory.new(catalog=null)` 默认加载 `resources/equipment/first_map_equipment.tres`。`items` 为实物数组，实物精确含 `instance_id`、`item_id`、`name` 三个非空字符串，名称与目录匹配。实例唯一编号由调用方提供。
- `add_item(record)`、`equip(instance_id, realm)`、`unequip(slot)` 返回含 `accepted` 和中文 `message` 的字典。槽位为 `weapon`、`armor`、`accessory`，同槽替换不丢弃旧实物。
- `modifiers()` 每次从已穿戴实物重算，返回 `health_bonus`、`defense_bonus`、`qi_bonus`、`attack_bonus`（默认0），以及 `third_attack_multiplier`、`qi_regen_multiplier`（默认1）。目录 effects 的 `max_health`、`defense`、`max_qi` 映射为前三项，两个倍率字段保存加法增量。无装备赋予额外攻击属性。
- `weapon_id()` 返回当前武器物品ID，无武器返回空字符串；基础三段伤害读取 `catalog.items[weapon_id].damage`。旧剑14/18/24，长枪22/28/38，不在此处计算境界、强化、暴击或防御。
- `to_dict()` 深复制 `{items: Array, equipped: Dictionary}`；`restore(data, realm=0)` 先验证完整候选再替换，拒绝未知物品、坏字段、重复实例、无实物引用、错槽、未知槽、非法境界及越境界／越品阶穿戴。允许低境界收藏未装备的高阶实物。失败时现有状态保持原样。

首图五件有素材物品的 `icon_path` 引用已有概念图，不冒充正式装备图标；玄纹法衣无素材，路径为空。基础武器解锁不自动生成实物，调用方在新探索创建基础武器实例。死亡后的空实物快照可恢复，永久解锁由外层保留。

## 真实验证

使用已有 Godot 4.7.2 控制台入口，在项目根目录执行：

```powershell
& 'E:\Godot\bin\godot.bat' --headless --path . --script res://tests/test_inventory.gd --quit-after 120
```

1. 红测：实现前执行，输出 `FAIL: 真实装备实例与目录模块存在`，退出码1，原因是尚未建立真实模块。
2. 绿测：实现后相同命令输出 `INVENTORY_CHECKS_PASSED=58`，退出码0，无 `SCRIPT ERROR`、`Parse Error` 或 `ERROR:`。
3. 对目录脚本、库存脚本、库存测试分别执行 `--headless --path . --check-only --script <脚本路径>`，三个进程均退出0且无错误。

58项实际断言覆盖实例唯一性、字段校验、未持有拒绝、武器槽替换和伤害来源、境界不足／足够、品阶不可被稀有度绕过、同槽替换、重复穿卸不叠加、真实属性归原点、JSON往返、快照深复制和损坏快照原子拒绝。空快照测试只证明本模块清理实物；完整死亡、继续探索、战斗手感和界面尚需根代理集成验收。本子任务未执行导入、全套回归、窗口或Windows发布验证，未安装依赖，未提交版本。

## 武器与Player后续接入

`scripts/combat/weapon_rules.gd` 和 `resources/weapons/first_map_weapons.tres` 提供真正用于攻击的两件武器配置。`Player.apply_weapon(id) -> bool` 重置武器的三段伤害、判定尺寸、偏移及普攻时序，调用方先换武器再叠加境界、装备和局内强化。未知ID返回false，空ID取消当前攻击且禁用普通／重击，不改写其他基础stats。旧训练场默认青锋旧剑。

|武器|普攻伤害|判定尺寸|中心偏移|普攻前摇／有效／总时长|重击倍率|重击前摇／有效／总时长|重击削甲|
|---|---|---|---|---|---|---|---|
|青锋旧剑|14／18／24|100×58|(60,-30)|0.10／0.10／0.42秒|1.5|0.28／0.14／0.72秒|20|
|破山长枪|22／28／38|160×54|(90,-30)|0.18／0.12／0.62秒|1.6|0.34／0.14／0.90秒|45|

三段伤害沿用GDD，枪的距离与时长、两武器重击倍率／时长／削甲以及基础每秒真气恢复4均为本轮授权待平衡测试值。重击使用首段伤害乘重击倍率，继续应用原境界与暴击公式，不享受第三段饰品倍率；普通攻击第三段额外乘 `stats.third_attack_multiplier`（默认1）。重击通过敌人已有 `receive_hit(amount, impulse, armor_damage)` 第三参消耗护甲并触发现有破甲硬直，木桩仍使用原两参接口。

普通与重击仍共用ATTACK状态，每次开始攻击保存本次时序；重击按已修改普通总时长的比例适配攻速。新增 `try_heavy_attack()`；已有K／鼠标右键的 `heavy_attack` 输入实际触发重击。动画控制器真实路径为 `scripts/art/player_animation_visual.gd`，读取 `attack_windup()`、`attack_active()`、`attack_duration()`，不再用普通攻击时间错误切换重击画面。**长枪与重击暂借现有剑术候选帧测试，正式长枪与重击动画尚未制作或验收**；命中范围和时序已真实不同，现有候选帧不等于正式动作完成。

新增 `stats.qi_max=60.0`、`stats.qi_regen=4.0` 和实际 `Player.qi`，准备时满真气，存活时逐物理帧恢复至真实上限。`spend_qi(amount) -> bool` 真实扣除，余额不足、非法数值或死亡时拒绝且不扣款。普通／重击不耗真气，本轮不增加主动技能。回灵玉佩由调用方将恢复率乘1.15得到4.6；卸装后重新计算回4。最大真气改变后的即时夹取及HUD由根代理接入。

追加实际验证：

```powershell
& 'E:\Godot\bin\godot.bat' --headless --path . --script res://tests/test_weapons.gd --quit-after 1800
& 'E:\Godot\bin\godot.bat' --headless --path . --script res://tests/test_combat.gd --quit-after 1800
& 'E:\Godot\bin\godot.bat' --headless --path . --script res://tests/test_actor_animation.gd --quit-after 1800
```

- 武器红测：实现前首条功能断言 `主角具有真实换武器、重击和真气消耗接口` 失败，退出1。
- 武器绿测：`WEAPON_CHECKS_PASSED=26`，退出0；剑14／枪22、150距离仅枪可命中、不同收招、第三段26、实际输入重击及一次削甲、破甲硬直、候选帧同步、卸武器禁攻、实际真气扣除与4／4.6恢复均执行。
- 必要旧战斗回归：`COMBAT_CHECKS_PASSED=28`，退出0。
- 触及的动作控制器回归：`ACTOR_ANIMATION_CHECKS_PASSED=68`，退出0。

三个实际进程均无 `SCRIPT ERROR`、`Parse Error` 或 `ERROR:`。这些结果不等同于完整阶段5集成、正式动画、窗口手感或Windows发布通过。
