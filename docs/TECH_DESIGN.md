# 《烬山问道》技术设计

版本：0.4。日期：2026-10-23。状态：框架、角色基础战斗、第一地图六敌与固定六房路线已实现；成长、完整武器系统、随机地图与游戏存档仍为设计。实际接口见第 11–13 节；第 3 节的完整模块表是预定契约。核心规则取自主方案，待决项不作为实现授权。

唯一设计基准：[GAME_DEVELOPMENT_PLAN.md](GAME_DEVELOPMENT_PLAN.md)。本文件细化接口和数据边界，不另设玩法基准。

## 1. 范围与技术栈

Windows 单人离线，Godot 4.7.2 stable、GDScript、Git、gl_compatibility。内容用 Godot Resource 配置，存档采用带版本号的 JSON。不增加联网、数据库、第三方运行时或编辑器插件。

阶段 0 不创建 project.godot、游戏脚本或场景。目录按主方案第 33 节设计，实际使用时再建立，不预先生成空模块。

## 2. 成长模型

- `realm_id`：炼气／筑基／金丹／元婴／化神。
- `subrealm_id`：初期／中期／后期／圆满。
- `banked_spirit`：祭坛已记录且尚未消耗的丹田灵气。
- `pending_spirit`：未记录新增灵气。
- `banked_stones`、`pending_stones`：已记录与未记录灵石。
- `banked_materials`、`pending_materials`：按材料 ID 存数量。
- `qi`：战斗主动技能使用的真气，与成长用的丹田灵气不同，不得混用。

有效成长灵气为两个灵气余额之和，不再同时维护经验等级和永久修为两套成长计数。临时强化仍是局内构筑，触发方式须在阶段 6 前确认。

每个小境界门槛为正整数。大境界资源包含四个阶段门槛，前三级自动结算，圆满阶段门槛用于向下一大境界突破。小境界加属性，大境界另解锁武器品阶和能力；属性增量在相关阶段实测后配置。

溢出灵气满足下一小境界门槛时继续结算，到圆满停下等待材料与祭坛。化神圆满不再触发突破，封顶数值在阶段 10 前冻结。旧版 120/240/420/650 不作为有效配置。

## 3. 模块边界与预定接口

以下是后续实现契约，不表示已有函数。

| 模块 | 责任与预定接口 | 信号／输出 |
|---|---|---|
| PlayerController／状态机 | 统一输入、移动、跳跃、闪避和动作切换 | 动作状态，不直接写存档 |
| CombatSystem | `resolve_hit(attack, target)`：统一伤害、命中去重、击退与硬直 | 命中和击杀事件 |
| WeaponSystem | 读取武器动作和攻击资源 | 攻击请求，不独立实现防御公式 |
| EnemyAI／BossController | 共用基础状态语义；Boss 增加招式与阶段 | 带来源实例 ID 的击杀事件 |
| RewardService | `claim_reward(reward_id, payload)`：校验来源并仅发放一次 | 灵气、灵石、材料或装备奖励 |
| RealmSystem | `grant_spirit(amount, source_id)`；`try_major_breakthrough(shrine_id)` | `realm_changed`，只负责成长规则 |
| RunManager | 当前探索、种子、临时强化、未记录资源、死亡流程 | 局内状态变化 |
| InventorySystem | `can_equip(item_id)`：依大境界验证权限 | 装卸事件；卸下恢复属性 |
| ShrineService | `record_resources(shrine_id)`：记录、补给与突破交互 | 提交祭坛保存事务 |
| SaveManager | `commit_snapshot(reason)`；`load_snapshot()` | 成功或明确失败；负责统一提交边界 |
| MapGenerator／EventSystem | 房间图与事件数据解释 | 连接图、事件结果，不直接改内部档案 |
| NPCManager | 管理对话入口、任务状态和永久标记，不复制事件奖励规则 | 对话／任务事件，经奖励与存档边界提交 |
| UI／设置 | 显示状态、重绑输入、音量、暂停 | 用户请求，不独立计算成长 |

类型与具体签名随所属阶段实施计划确定；这里的命名是接口方向，不能据此创建空函数。仅共享跨场景且确有需要的服务成为 Autoload，不为每个系统生成单例。

## 4. 状态归属

| 状态 | 运行期归属 | 退出后继续 | 死亡后 |
|---|---|---|---|
| 已完成大小境界、武器解锁、登记蓝图、永久剧情 | ProfileState | 保留 | 保留 |
| 已记录且未消耗灵气、灵石、材料 | ProfileState | 保留 | 保留 |
| 未记录灵气、灵石、材料 | RunState | 成功快照可恢复 | 清除 |
| 掉落装备实物、词条、临时强化 | RunState | 成功快照可恢复 | 清除 |
| 地图、房间、事件、当局已领奖标识、生命与真气 | RunState | 成功快照可恢复 | 旧局失效 |
| 输入和显示音量设置 | Settings | 保留 | 保留 |

“已保存快照”和“已记录永久资源”是两个概念。自动突破保存快照不会将背包内其他资源自动登记。

## 5. 突破、记录与死亡事务

1. 击杀通过 RewardService 进入一次奖励结算，将灵气加入 pending_spirit。
2. 达到小境界门槛，优先消耗 pending_spirit，再消耗 banked_spirit；提升小境界并计算属性。
3. 提交境界、消耗、奖励标识和关联局内快照。失败须明确提示并允许重试，不显示永久保存成功；不能先把未提交状态当作已保存状态。
4. 祭坛将 pending 余额转入 banked 并清零 pending；同一交互不能重复记录。
5. 大境界突破校验圆满、灵气、对应材料和祭坛交互；扣灵气与一份材料，进入下一大境界初期，统一提交。
6. 死亡保留 ProfileState 当前有效余额，清除 RunState 并使旧局失效；不能加载旧局重复领奖或返还消耗。

账本示例仅用于测试，不是正式数值：已记录灵气 30，新增灵气 25，小境界门槛 40。自动突破先扣新增 25，再扣已记录 15，剩余已记录 15。死亡后该小境界和已记录 15 均保留，不能回到已记录 30。

材料示例：已记录 1 份，新获未记录 1 份，死亡后仍为 1 份。在祭坛记录后共有 2 份，突破消耗 1 份后永久余额为 1 份。

## 6. 存档与恢复

ProfileState 与 RunState 逻辑分开，持久化写入同一个包含 `save_version`、提交编号、profile 和 run_snapshot 的封套。写临时文件、验证、保留有效备份后替换；设置独立保存。

祭坛、自动小境界突破、大境界突破和死亡都是提交边界。自动突破附带一致快照，继续时从当前房间安全点恢复，不从命中帧中恢复；这是技术选择，确保永久成长与消耗一致。死亡返回驻地，仍不能继续旧局。

RunState 保存 run_id、地图 seed、分用途 RNG 状态、房间图和清理状态、敌人及领奖标识、当前装备和强化、未记录资源、事件选择、生命真气与安全恢复点。种子本身不足以恢复探索。

Boss 永久首杀奖励与可重复获得的突破材料使用不同奖励类型。材料丢失后允许新探索再次击杀获取；同一来源实例奖励只能领取一次。旧版迁移用测试夹具验证，当前没有实际旧档。

加载校验类型、必需字段、版本和 ID 关系，损坏时尝试有效备份。离线单机不增加存档加密或联网验证，不承诺阻止手工复制存档。

## 7. 资源与随机规范

资源 ID 使用稳定的英文 snake_case，UI 名称中文。武器品阶、稀有度、境界门槛独立；内容字段遵循主方案第 35 节。新增灵气门槛、分段属性与材料 ID 配置，不散落在角色脚本内。

地图使用手工房间模板加受控连接。入口至 Boss 可达，Boss 后可回原祭坛；商人复用奇遇房，不增加首版模板总数。地图、掉落、事件使用独立 RandomNumberGenerator 流，避免一个额外掉落调用改变地图。

调试和回归使用固定 seed；正常新探索记录实际 seed，死亡后的新探索生成新 seed。角色和平台不使用系统时间作为不可复现的随机来源。

## 8. 待所属阶段冻结

- 阶段 1：主角最终服饰方向、游戏尺寸、侧视角、动画画布。
- 阶段 3–7：各小境界门槛、属性增量、奖励量、灵气溢出上限。
- 阶段 6 前：临时强化何时触发，禁止擅自保留第二条经验条。
- 阶段 7：保存失败时的交互提示和恢复流程，用故障测试验证。
- 阶段 10：高阶试炼和化神圆满封顶数值。

## 9. 数据驱动契约

以下为 Resource 设计，不在阶段 0 创建资源类、.tres 或加载器。稳定 ID 用于引用与存档，display_name 仅用于中文展示，不能用显示名作保存键。不存在的 ID、缺失必要字段、非法类型及不合理数值应在加载配置时明确报告，不能静默生成假内容。

| 数据 | 主方案字段与约束 | 目录 |
|---|---|---|
| 武器 | weapon_id、display_name、weapon_tier、required_realm、base_damage、attack_speed、attack_range、qi_cost、special_effect_id、animation_set、icon、drop_weight；品阶与稀有度独立 | resources/weapons/ |
| 敌人 | enemy_id、display_name、max_hp、contact_damage、attack_profiles、movement_speed、telegraph_duration、recovery_duration、armor、loot_table、region_id | resources/enemies/、resources/bosses/ |
| 境界 | realm_id、小境界顺序、各阶段灵气门槛、属性增量、材料 ID、装备权限与能力解锁；数值冻结前不能填假正式值 | resources/realms/ |
| 装备与词条 | 稳定 ID、品阶、稀有度、境界要求、属性修正、词条上限与互斥；装卸可逆且不重复生效 | resources/equipment/、resources/affixes/ |
| 技能与攻击 | 攻击开始／生效／结束窗口、范围、伤害、击退、硬直、打断和破甲参数；技能消耗战斗真气 | resources/skills/；武器和敌人引用攻击配置 |
| 事件 | 触发条件、至少两个选择、立即效果、奖励或代价、后续标记、保存规则 | resources/events/ |
| 区域与房间 | 模板 ID、入口出口、碰撞、敌人和交互点、连接限制、关键节点 | resources/stages/ 与 scenes/rooms/ |

伤害遵循主方案第 9.3 节：攻击基础伤害 × 境界倍率 × 技能倍率 × 暴击倍率 × 防御系数；防御系数为 100 / (100 + 目标防御值)。所有武器共用结算模块，不能各自改变防御算法。

新数据字段在所属阶段先更新规格与测试，再实现；资源类型变化与存档版本变化分别管理。旧版测试档仅作为迁移夹具，不声称已存在用户历史存档。

## 10. 当前目录一致性与未决问题

阶段 0 的目录快照只有文档和参考素材；当前已新增 project.godot、scenes/、scripts/ 与 tests/。resources/player/ 已由训练主角读取；其余资源类型按后续功能需求建立，不生成未使用的空资源类。游戏服务的实际边界见第 11 节。

原始中文素材目录完整保留，不自动移动或重命名。文件名与主方案名称差异、主角服饰取舍、强化触发等问题统一记录在 [阶段 0 报告](PHASE_0_PLAN.md)，不由技术文档擅自裁定。

## 11. 当前工程的真实接入接口

- App Autoload：State 为 BOOT／MENU／PLAYING／PAUSED；start_new_game()、return_to_menu()、set_paused(bool)、quit_game() 管理实际生命周期。state_changed(state)、session_started、scene_changed(path) 均在真实操作后发出；新局信号在场景就绪后发送，后续局内模块可订阅，不在这里写成长数据。
- Settings Autoload：values 是音量、显示和 bindings 字典；apply_options(Dictionary) 校验后应用，save_options()/load_options() 操作独立 user://settings.cfg，changed 信号通知界面。Master／Music／SFX 总线有效。它不读取或创建游戏存档。
- Game 场景根是 Control，提供 World、Actors 两个 Node2D 接入节点和 UI/Overlay 控件层；阶段2时 World 下挂 TrainingArena，内含 Player、木桩及平台；当时 Actors 保留框架接点，未使用。阶段3的默认路线和 Actors 接入见第13节；HUD 挂 UI/Overlay（CanvasLayer 10），PauseLayer（20）承载暂停菜单，背景层为 -10。后续正式地图与角色在所属阶段迁接，各模块不直接修改 App 内部状态。
- 当前 UI 使用缓存的 /root/App 与 /root/Settings 引用，支持单脚本 --check-only；未来按所属阶段接入真实服务，不预生成 SaveManager、InventorySystem 等空函数。
- 角色通过 InputMap 的 move_left、move_right、jump、attack、heavy_attack、dodge、skill、heal、interact、pause 读输入。鼠标及手柄替代映射保留；暂停键优先于 GUI 导航，但设置层先消费关闭／改键输入。
- 存档模块实现并验证后再启用“继续游戏”，能力检测应来自有效档案，不能仅以文件存在或常量 true 冒充。当前按钮无可用操作。
- 原始参考图目录和 validation/ 用 .gdignore 排除引擎导入，不作为可运行资源；将来验收合格后另存正式资产目录。

## 12. 阶段 2 实际角色与战斗接口

- scenes/player/player.tscn 是 CharacterBody2D，脚底原点 (0,0)，碰撞 24×56、中心 (0,-28)；Camera2D 水平跟随，范围 0..2200 与训练场实体边界一致。碰撞层 1=环境、2=主角、4=训练目标；主角／木桩只与环境产生实体碰撞，攻击查询层 4。
- scripts/player/player_stats.gd + resources/player/training_stats.tres 提供实例独立的 Resource 参数。生命100、速度280、闪避150／无敌0.20／冷却0.70、硬直0.20、剑14/18/24、暴击5%及1.5倍率沿用方案。其余调试参数与来源见 PHASE_2_PLAN.md，不作为最终平衡。
- Player 状态为 IDLE／MOVE／JUMP／ATTACK／DODGE／HURT／DEAD；health_changed(current, maximum)、state_changed(state)、died 为真实事件。try_attack()、try_dodge() 返回是否进入动作；receive_hit(amount, impulse) 接收攻击方倍率处理后的伤害并统一应用本方防御，拒绝死亡状态或闪避无敌内的命中。
- 移动／跳跃读取统一 InputMap；攻击／闪避通过 _unhandled_input 请求进入物理帧，避免点击 GUI 按钮时同时挥剑。HUD 非交互容器穿透鼠标，按钮消费点击。离地容错在各动作分支之前更新，不因攻击、受击或闪避冻结。
- 一次基础攻击包含前摇、有效、收招，总时长兼作再次攻击冷却。仅有效窗口用实际矩形物理查询，按目标实例去重；三段伤害14/18/24，超过连段窗口重新第一段。无输入缓冲连段；闪避可取消攻击，受击中断攻击，死亡停止动作输入。
- scripts/combat/damage.gd 统一防御公式、倍率与整数舍入。主角施加境界与暴击倍率，目标接收时调用同一模块结算防御；不另写武器防御算法。当前固定 seed 仅用于训练与回归，正式探索 RNG 归属仍按第 7 节实施。
- TrainingArena 创建静态平台和边墙；TrainingTarget 仅受击、击退及血条，无 AI、接触伤害、掉落或奖励。受击／致死按钮是调试伤害源。Game HUD 显示生命、状态、冷却；重新训练调用 App.start_training()（阶段3将训练与正式路线入口分开） 真实重载场景，不是存档恢复。
- 正式动画尚缺，_draw() 仅表示功能状态，挥剑显示的矩形与实际有效窗口／范围一致；保留原始图和失败图集。没有接入真气、药品、重击、技能、永久死亡事务或境界系统，不提供空接口假装完成。

## 13. 阶段3真实接口与固定路线

- EnemyData 与 AttackProfile 是 Resource 脚本，六份 resources/enemies/*.tres 集中生命、速度、攻击模式、前摇／有效／收招／额外冷却、阶段、概念图引用。已定与未定值见 ENEMY_BALANCE.md，禁止把测试默认值当正式表。
- Enemy（CharacterBody2D）共享 DORMANT／INTRO／IDLE／PATROL／DETECT／APPROACH／TELEGRAPH／ATTACK／RECOVERY／RETURN／HURT／PHASE／DEAD。activate(player) 实际激活感知；receive_hit(amount, impulse, armor_damage=0) 统一伤害、护甲、击退与硬直。普通剑攻击未新增破甲能力，第三参数只提供给以后真实重击或特定破甲来源。
- died(source_id)、reward_requested(payload)、phase_changed(phase)、attack_started(attack_id)、state_changed(state) 均在真实动作发出。死亡先关闭碰撞并停止攻击，再发送唯一来源结算及死亡通知，保留0.60秒淡出。载荷含 source_id／enemy_id／guaranteed_material／drop_rates_defined=false／amounts_defined=false；路线按来源去重。Boss确定材料名是筑基灵髓，其他奖励种类仍待后续配置；当前无背包、成长、存档消费者。
- 山魈扑击、尸兵慢重劈、游魂双击、灵弩后撤与射击、精英甲壳／冲撞／60%砸地、Boss固定轮换重斩／冲锋／跳砸／二阶段连斩与双向地波在共享状态机中走实际不同攻击分支。收招结束后才启动额外冷却。预警锁方向／落点，普通攻击可受击打断，精英有甲和Boss预警／攻击抗打断，破甲可中断；入场／转阶段不受伤是本轮测试决定，仍待手感评审。
- 弩箭和地面波用实际射线扫帧位移，环境层1阻挡、玩家层2受伤；单弹只命中一次，无敌内不扣血。源敌死亡、玩家死亡或离房时释放弹体；暂停实际冻结物理帧。地面波可跳过。
- 固定房间为矩形碰撞；Boss起跳前按物理步长和脚底左中右射线预测首个可落平台，预警与首次落点对应，落地同帧结算并停止水平速度。敌人目标在下方时可穿过当前单向平台下降，离开该平台横向范围后恢复碰撞；预测也排除本体正在忽略的平台。移动平台／斜坡／任意地形尚未验证，扩展此类地图需替换或扩大预测验证。
- CombatRoom 的 enter(player, was_cleared)、cleared(room_id)、reward_requested(payload) 管理本房激活、剩余敌人和实体门；普通平台单向碰撞，地面、墙及锁门是实体碰撞。最后敌人死亡仅清场一次，延迟禁用门碰撞。
- SwordRoute 实例化六份 scenes/rooms/*.tscn；World/SwordRoute/CombatRoom 是房间，Actors/Player 是持续主角，换房调用 Player.reset_motion_at(spawn)，保留生命与闪避冷却，清旧攻击和连段，重置镜头平滑。enter_room(index) 是实际房间切换；interact() 仅在清场、活着、近地面且靠门时响应。清场集合只在本次路线内有效，重访不再生成敌人和奖励，Boss后可回同一祭坛。
- 祭坛交互只恢复训练生命，无存档、资源记录和境界突破；界面明确说明。App.start_new_game() 进入默认固定路线；start_training() 进入继承 game.tscn 的 training_game.tscn，保留旧训练。菜单新增训练入口，旧暂停设置统一复用。
- EnemyData.concept_texture 只绑定原图字节副本，资料卡显示整张概念板；战斗身体为临时几何，资料卡不代表动画。正式 SpriteFrames 或 AnimationPlayer 接入前必须有透明帧、脚底锚点、帧时长及命中窗口验收，不先生成空动画资源。

## 14. 山魈单房美术候选真实接入

用户批准先做单房美术验证。App.start_art_room()切换独立场景，enter_playing()使F6直接运行也能暂停；主菜单增加独立入口。房间复用CombatRoom、Player、Enemy、原暂停菜单与重新加载流程。Enemy.show_placeholder_body默认true，仅该房实例关闭几何身体。

ShanXiaoVisual作为Enemy子节点，根据真实state／clock／facing／地面检测选择SpriteFrames帧；不调用伤害、改速度或决定死亡。待机与跑动循环，前摇／扑击／收招按真实阶段时长同步，未着地时保留腾空姿势。左右翻转围绕根节点，Godot缩图后的纹理按源画布比例换算枢轴。素材与当前候选比例见SHAN_XIAO_PLAYABLE_REPORT.md；不把该样板视为其他角色正式动画完成。
