# 阶段3：第一地图敌人与固定战斗路线实施计划

执行依据：用户当前阶段3任务、完整 GAME_DEVELOPMENT_PLAN.md 第16–23节及 ART_DIRECTION.md。执行方法：本会话逐项实施、先红后绿、完成前真实验证和独立审查；用户已明确要求正式执行，不重复请求开工确认。

目标：六种实际不同行为的敌人，共享伤害／硬直／死亡／掉落事件；六个可进入清场解锁的固定房间；保留阶段2训练场。Godot4.7.2／GDScript，无新增依赖，不实现随机地图、装备、成长或存档。

## 数值与选择记录

已定：山魈90/12、尸兵75/10、游魂58/9、弩傀65/11、精英420/18；精英60%新增砸地，完整甲减伤约25%；Boss1100、挥击22、重击28、冲锋24、55%转二阶段。来源主方案17、18.1、20.1。敌人未定的速度、检测／脱战距离、前摇、有效／收招／冷却、连击间隔、弹速寿命、碰撞尺寸、硬直／抗打断、护甲总量与破甲硬直、Boss冲击波伤害和演出时长统一为可编辑测试值，具体记录在ENEMY_BALANCE.md；不得称正式平衡。

掉落概率、奖励数量、随机装备／材料表尚缺，drop_table不伪造概率；死亡一次发reward_requested载荷，Boss含确定奖励名“筑基灵髓”，不冒充背包到账／存档／剧情已实现。精英不产出筑基灵髓。祭坛只做测试休整，明确无记录／突破。6房是本轮固定测试子集，主方案8模板和后续随机连接保留。Boss后可返回同一祭坛，清场房不重复生成奖励。

素材：六图均PNG RGB1448×1086概念板。原图保留；字节相同副本进assets/enemies/concepts，Texture2D只用于敌人资料卡，不用整张三视图冒充动画。战斗几何图形标记临时；记录正式动画需求。沿用现有山魑文件名，UI与ID仍取方案山魈。

## 实施与文件

1. [x] 数据／共享战斗。新增 scripts/enemies/{enemy_data,attack_profile,enemy,projectile}.gd、六份 resources/enemies/*.tres、scenes/enemies/enemy.tscn。Enemy.activate(player)、receive_hit(amount,impulse,armor_damage=0)；died(source_id)、reward_requested(payload)、phase_changed(phase)、attack_started(id)；实例唯一结算。tests/test_enemies.gd先检查缺资源失败，再验证六种移动、预警、命中、受击、死亡，远程撞墙／无敌、护甲和Boss阶段。
2. [x] 六房与路线。新增scripts/world/{combat_room,sword_route}.gd、scenes/rooms/六场景。房间enter(player,cleared)、cleared(room_id)、reward_requested；路线enter_room(index)、interact()、room_changed、reward_requested，维护本次路线清场集合，不写存档。锁门有实际碰撞，F近门切换；玩家独立留在Actors，进门清动作但保留生命。tests/test_route.gd验证锁门、物理平台、六场景进入、清场一次、实际输入门交互、回祭坛和新路线重置。
3. [x] 接入和回归。game.gd共用HUD，默认固定路线；training_game.tscn保留原训练，App新增start_training，旧test_combat只改明确入口；菜单增加训练按钮。资料卡显示概念板，HUD显示预警／Boss生命阶段／结算事件状态。玩家只新增换房清动作接口。
4. [x] 验收。run_checks.ps1加入两类实际测试（无窗口与窗口）、逐脚本解析与旧菜单／设置／战斗回归；截图目视检查，独立审查修复；更新AGENTS、README、TECH、WORKFLOW、ART、TEST与PHASE_3_REPORT。只提交本轮文件，保留外部图片移动和Word文件；同步已授权仓库；停止等待阶段4。

## 审查重点

- 死亡或阶段切换取消待发攻击；离房释放投射物；玩家死亡不再受攻击。
- 前摇锁定方向／落点，不在命中前突然转向；冲击波可跳过，收招有反击时间。
- 杀死最后敌人仅通知一次；重访清场房不重生、不重复奖励。
- GUI不触发世界攻击；暂停冻结敌人和弹体；换房保留生命、清旧攻击。
- 世界边界、地面与相机一致；原图保留、运行引用有效、无假动画或假掉落概率。
