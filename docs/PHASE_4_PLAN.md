# 阶段 4：肉鸽探索实施计划

计划日期：2026-10-23，续行验收日期：2026-10-24。依据完整 GAME_DEVELOPMENT_PLAN.md；范围由本轮用户阶段 4 指令确定。

## 已确认决策与边界

- 用户确认：战斗房首次清场提供三选一局内强化；包含精英与 Boss 战斗房。回访不再次发放。
- 用户授权制定缺项的待平衡测试表，覆盖奖励数量、概率、强化权重、商品价格；不把测试值称为正式平衡。已有敌人、玩家伤害与移动基准不变。
- 手工模板 + 受控随机连接。补弩傀儡祭室、旧碑奇遇，合计八模板；商店复用奇遇模板，奖励房复用入口模板。保留原六房固定路线作为独立回归入口。
- 大小境界、永久登记、游戏存档、完整装备穿戴属于后续阶段。本轮只有独立局内资源与装备掉落实例接口；丹田灵气为唯一成长资源，继续游戏仍禁用。祭坛仅恢复生命，明确提示尚不能记录资源或突破。
- 无面商人用现有概念图作资料肖像，世界交互点明确临时；不冒充已具备行走动画。旧碑原图接入真实地面碰撞；弩室复用现有荒地地形，独立建筑素材待制作。

## 执行顺序与文件责任

1. 路线：`scripts/roguelite/run_graph.gd`、两间新增房间与旧碑地形。测试入口到所有节点与 Boss 可达、关键节点不可绕过、种子复现、不同种子差异、实际碰撞。
2. 规则：`run_rules.gd`、`run_state.gd`、`resources/roguelite/nameless_tomb_rules.tres`。测试先于实现；奖励去重、三选一缓存和叠加上限、奇遇代价、交易原子性、死亡清理。
3. 接入：`rogue_route.gd`、`run_interface.gd`、`roguelite_game.tscn`；增量调整 App、Game、Player 和 SwordRoute。新游戏进入肉鸽路线，固定路线测试显式使用旧入口；真实死亡事件、房间清场与 UI 操作接入规则。
4. 回归：新增整合测试，保留原战斗/动画/地图/设置测试，实际无窗口与有窗口运行，记录截图与未验证范围。
5. 交付：更新技术/流程/测试/运行文档与 PHASE_4_REPORT.md，有限范围版本提交；停止等待阶段 5。

## 跨模块契约

`RunGraph extends RefCounted`：`generate(seed_value)`，字段 `seed`、`nodes`；节点字典含 id、kind、template_id、scene_path、label、next（字符串数组）、previous（字符串数组）。固定 ID：entry、melee、platform、monument、archer、side_before、side_after、elite、altar、boss。入口分叉到 melee/platform 后汇入 monument，再到 archer；入口两战斗房随机无连边／单向连边，保持有向无环。两侧支路分别为 reward/shop（种子决定前后），都汇入下一战斗节点；elite → altar → boss。前进沿 next，回退限已访问 previous。Boss 可回原祭坛。

`RunState extends RefCounted`：构造 `_init(seed_value=0, rules_data=null)`；字段 `seed`、`run_id`、`spirit`、`stones`、`materials`、`equipment_rewards`、`upgrades`、`ended`、`rules`。信号 changed、reward_granted(payload)、equipment_dropped(record)。方法：

- `claim_enemy(source_id, enemy_id) -> Dictionary`、`claim_chest(source_id) -> Dictionary`；成功含 accepted=true、message；重复/无效失败不改余额。
- `offer_upgrades(source_id) -> Array`：缓存 ID 数组；`choose_upgrade(source_id, upgrade_id) -> bool`，只允许本次选项和一次选择。
- `resolve_event(source_id, event_id, choice_id, current_hp, max_hp) -> Dictionary`：accepted、message、health_cost、health_restored；choice_id 为 a/b，事件为 sword_question/well_echo；成功即完成，失败可重试。
- `shop_inventory(source_id) -> Array`：商品字典 id/name/description/price/remaining；`buy(source_id, good_id, current_hp, max_hp) -> Dictionary`：accepted、message、health_restored，原子检查余额/库存/效果上限。
- `stat_modifiers() -> Dictionary`：attack_multiplier、health_bonus、defense_bonus、crit_bonus、dodge_reduction、haste。所有强化相对初始属性重算，不能叠乘当前值。
- `use_lethal_guard() -> bool`，一次替劫符实际阻止致死；`finish_run(reason) -> Dictionary` 返回结束前摘要并清空局内余额、装备、强化、来源、库存和选项，ended 后拒收任何奖励。

`RunRules extends Resource` 导出字典 enemies、upgrades、events、goods、equipment，以及 chest 字典、material_names 字典。配置字段与取值由实现者在 PHASE_4_BALANCE.md 逐一登记；UI 读取同一配置。地图、掉落、强化分别使用独立 RandomNumberGenerator。

## 验收与限制

- 实际点击三选一、奇遇选择和购买；UI 关闭恢复世界输入，暂停不能绕过模态冻结。
- 实际死亡/重开清空局内强化与未记录资源；新局新种子，固定种子测试可复现。
- 实际 Boss 死亡发一次筑基灵髓并可回原祭坛；精英绝不掉落此材料。
- 装备接口真实生成有唯一实例 ID 的奖励记录和信号，穿戴不在本轮验收范围。
- 所有自动测试须有成功标记且无脚本/资源错误。注入致死伤害只证明流程，不等于人工无辅助通关或平衡验收。导出、永久保存、正式动画未验证。
