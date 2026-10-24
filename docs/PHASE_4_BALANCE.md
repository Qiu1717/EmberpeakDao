# 阶段 4：局内规则待平衡测试表

日期：2026-10-23。唯一玩法基准为 GAME_DEVELOPMENT_PLAN.md；本轮用户授权制定缺失的奖励、概率、权重和价格。本文中的测试值可执行，但不代表已完成正式平衡。运行配置位于 `resources/roguelite/nameless_tomb_rules.tres`，UI 同样读取该资源。

## 已定规则与本轮补充

- 已定：丹田灵气与技能真气分开；死亡清除未记录资源、局内强化、掉落装备与事件状态。本轮不创建永久档案、记录资源或存档模块。
- 用户本轮确认：战斗房首次清场提供一次三选一，含精英、Boss 房；回访不再发奖。
- 已定：残剑问心 A 消耗当前生命15%、本次探索攻击力 +20%；B 获得少量灵气。古井 A 恢复生命或真气，B 可触发装备奖励。本轮取恢复生命、直接装备两分支。
- 已定：镇山妖将掉筑基灵髓，裂甲山魈不掉；Boss 有一件武器或功法奖励。本轮只生成破山长枪实物记录，不解锁、不自动穿戴。
- 已定：替劫符抵挡本次探索首次致死伤害，保留1点生命后消耗。RunState 的 `use_lethal_guard()` 只在有符时返回一次 true，玩家层据此保留1点生命。
- 已定装备名取 GDD 第15.1节的“青布道袍”“残剑坠”及第14节的“破山长枪”；装备效果与穿戴均不在本轮实现。

## 敌人奖励

| 敌人 ID | 丹田灵气 | 灵石 | 材料 ID × 数量 | 材料概率 | 装备概率 |
| --- | ---: | ---: | --- | ---: | ---: |
| shan_xiao | 12 | 6 | demon_blood_crystal × 1 | 25% | 10% |
| corpse | 10 | 5 | corpse_iron × 1 | 25% | 10% |
| ghost | 12 | 7 | spirit_dust × 1 | 25% | 10% |
| crossbow | 10 | 6 | puppet_parts × 1 | 25% | 10% |
| armored_xiao | 60 | 35 | demon_blood_crystal × 1 | 100% | 60% |
| mountain_general | 120 | 80 | foundation_marrow × 1 | 100% | 100% |

以上数量和掉率均为待平衡测试值。每项材料和装备各自判定，互不排斥；灵气和灵石固定发放。普通敌人与精英装备池为 qing_bu / can_jian / po_shan，三项等概率；Boss 装备池仅 po_shan。每次装备判定成功生成一件。

宝箱：固定灵气20、灵石20、从上述三项装备池等概率生成一件，均为测试值。

材料使用稳定英文 ID。当前显示名为 corpse_iron → 剑冢残铁、spirit_dust → 残魂碎片、puppet_parts → 傀儡机芯、demon_blood_crystal → 妖血结晶、foundation_marrow → 筑基灵髓。普通材料类别沿用用户现有《第一地图素材开发.docx》对应敌人资料，数量和概率由本轮测试表提供；山魈与精英共用妖血结晶库存。Word 中精英可能掉筑基灵髓的旧描述与 GDD 冲突，未采用，筑基灵髓严格仅 Boss 发放。

## 三选一与属性计算

| 强化 ID | 名称 | 每层效果 | 上限 | 抽取权重 |
| --- | --- | --- | ---: | ---: |
| attack | 磨砺剑锋 | 基础攻击力 +5% | 3 | 1 |
| health | 淬炼体魄 | 最大生命 +10 | 3 | 1 |
| defense | 护身真诀 | 防御 +3 | 3 | 1 |
| crit | 识破要害 | 暴击率 +4个百分点 | 3 | 1 |
| dodge | 踏风步 | 闪避冷却减少基础值的8% | 3 | 1 |
| haste | 迅剑诀 | 攻击速度 +5% | 3 | 1 |
| sword_insight | 残剑剑意（仅奇遇） | 基础攻击力 +20% | 1 | 0（不入池） |

普通六项幅度、层数和权重均待平衡；残剑攻击20%来自 GDD，事件专属上限1与代价取整方式是本轮测试规则。抽取按权重且不重复，已满层项退出后续新抽取池。可用项不足三项时按实际数量提供，全部满层时不提供空奖励按钮。同来源缓存第一次抽取，不因重复打开而消耗随机数；选择成功后不再展示。缓存中某项因交易已满层时该项不能再领取，可选择其他未满层项。

属性均相对初始值重算。攻击20%奇遇与5%普通强化合计倍率1.25；不将当前攻击逐次乘1.2、1.05。生命/防御直接加；暴击加百分点；闪避冷却用基础冷却 × (1 − dodge_reduction)；攻击时长按基础时长 ÷ (1 + haste)。最大生命增加是否同步回复由玩家接入层执行，规则层只返回上限修正，不直接持有生命。

## 奇遇和商店

| 内容 | 选择/商品 ID | 效果 | 价格/限制 |
| --- | --- | --- | --- |
| 残剑问心 sword_question | a | 当前HP × 15% 向下取整作为代价；攻击 +20% | 每来源完成一次，事件攻击全局最多1层 |
| 残剑问心 sword_question | b | 灵气 +10（测试量） | 同来源与 A 互斥 |
| 古井回声 well_echo | a | 恢复35生命（测试量），上限为缺失生命 | 满血失败且不消耗事件 |
| 古井回声 well_echo | b | 三项装备池等概率获得一件（测试分支） | 同来源与 A 互斥 |
| 回春散 | heal | 恢复35生命（测试量） | 12灵石，库存2；满血不扣费 |
| 砺剑石 | attack | 磨砺剑锋 +1层 | 20灵石，库存1；共用3层上限 |
| 替劫符 | talisman | 实际抵挡一次致死伤害 | 40灵石，库存1；未消耗符不能重复购买 |

价格与库存均为测试值。奇遇失败不会标记完成，允许重新选择。1生命时15%向下取整为0，不造成致死。交易先检查余额、库存和效果上限，再一次性扣款、减库存、增加效果；失败不扣费。库存按商店来源保存，返回的 UI 字典不与实际库存共用引用。

## 配置字段与实例接口

`RunRules extends Resource` 的导出字段均为字典：

| 字段 | 项目结构 |
| --- | --- |
| enemies | 敌人 ID → spirit / stones（整数）；materials（材料 ID → 数量）；material_chance / equipment_chance（0..1）；equipment_pool（物品 ID 数组） |
| chest | 同奖励结构，本轮无 materials |
| upgrades | 强化 ID → name / description；stat（下述修正键）；amount（每层量）；cap（整数）；weight（抽取权重，0排除） |
| events | 事件 ID → name / description / choices；choices 的 a、b 各含 name / description，并含效果字段 |
| goods | 商品 ID → name / description / price / stock，并含效果字段 |
| equipment | 物品 ID → name / kind（armor、accessory 或 weapon） |
| material_names | 材料 ID → 中文显示名 |

效果字段按需要出现：health_fraction（当前生命代价比例）、heal（治疗量）、upgrade（强化 ID）、spirit（灵气）、equipment_chance / equipment_pool（真实装备掉落）、lethal_guard（防致死次数）。

`RunState.new(seed_value=0, rules_data=null)` 默认载入上述 `.tres`。对外字段为 seed、run_id、spirit、stones、materials、equipment_rewards、upgrades、ended、rules。所有状态仅属于本次探索。

- `claim_enemy(source_id, enemy_id)` / `claim_chest(source_id)` 返回 accepted / message；成功含本次实际 spirit / stones / materials / equipment、run_id / source_id / kind。按奖励类型和来源去重，run_id 隔离不同探索。
- `offer_upgrades(source_id)` 返回 ID 数组；`choose_upgrade(source_id, upgrade_id)` 返回 bool。无已发选项、池外选择、满层、重复选择均拒绝。
- `resolve_event(source_id, event_id, choice_id, current_hp, max_hp)` / `buy(source_id, good_id, current_hp, max_hp)` 返回 accepted / message / health_cost / health_restored；调用方只在 accepted 时执行生命增减。
- `is_event_completed(source_id)` 返回实际完成标记，世界入口据此显示已完成，不再提供可选项。
- `shop_inventory(source_id)` 返回 id / name / description / price / remaining 商品数组。
- `stat_modifiers()` 返回 attack_multiplier / health_bonus / defense_bonus / crit_bonus / dodge_reduction / haste，空强化时依次为1、0、0、0、0、0。
- `equipment_rewards` 是真实实物记录数组，每件含 instance_id / item_id / name；实例 ID 带本局 run_id 和递增序号，同名装备可有不同实例。未实现穿戴、词条或永久解锁。
- 信号 changed 通知实际状态变更；reward_granted(payload) 对成功敌人/宝箱/奇遇发一次完整结算，事件生命代价与返回值一致；equipment_dropped(record) 对每个实物发一次记录副本。
- `finish_run(reason)` 返回结束前 reason / run_id / seed / spirit / stones / materials / equipment_rewards / upgrades 摘要，随后清空局内状态、来源、库存与待选项，ended=true。之后任何领取、购买、奇遇、选强化、防致死均拒绝；新探索新建 RunState。

掉落与强化各有独立 RandomNumberGenerator，分别由 seed 派生；地图另用路线模块自己的随机流。同种子、同类操作序列重现同种结果；查看强化不会改变掉落，掉落不会改变强化。run_id 保证实例唯一，不用于抽样。固定种子仅用于回归，正常新探索种子由应用入口生成；没有实现存档/恢复接口。

## 当前规则验证证据

2026-10-23 Godot 4.7.2：先编写 `tests/test_run_state.gd`，首次运行因缺少 RunState 的行为入口失败，退出码1；实现后56项通过。追加事件信号内容断言后发现信号早于生命代价填充，实际红灯退出码1；将完整结果构建移到发信号前，57项通过、退出码0，无 SCRIPT ERROR / Parse Error / ERROR 输出。

范围覆盖：真实0/1概率边界、同种子重现、随机流隔离、装备实例与信号、未知/重复来源、仅Boss出筑基灵髓、三选一缓存/重复/上限、六类修正、事件互斥与生命代价、交易余额/库存/上限原子性、一次防致死、死亡清理及新局重获Boss材料。玩家真实伤害与场景接入由阶段4整合验证负责；本文件不把规则单测称为自然通关、人工手感、正式平衡、存档或Windows发布通过。

待平衡截止：阶段4功能验收记录测试数值与实际运行差异；进入数值、成长或装备后续阶段前复核奖励节奏、生命代价取整、强化层数、掉率和商品价格。不将本表数值自动提升为正式设计。
