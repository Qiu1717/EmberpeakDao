# 山魈单房美术接入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans；按任务执行并记录实际验证。

**Goal:** 将现有山魈造型和补绘动作接入一个能真实战斗、暂停、重开的独立样板房，验证显示比例与动画判定同步。

**Architecture:** 复用Enemy和Player物理／伤害逻辑，仅给样板敌人挂载独立动画表现节点；动画读取真实AI状态和clock，不能反向驱动伤害。原六房路线和其他敌人保持当前表现。新增主菜单入口，复用App切换与暂停菜单。

**Tech Stack:** Godot4.7.2、GDScript、内置imagegen、透明PNG和Godot原生导入；不新增软件或运行依赖。

**Spec:** GAME_DEVELOPMENT_PLAN.md第4–9／16–17／23／41节、ART_DIRECTION.md，以及用户批准的“一只山魈在一个房间里”三步方案。本计划是其实施细化，不另定玩法。

## Global Constraints

- 仅完善山魈待机、移动、扑击、受击、死亡和单房接入，不启动阶段4，不扩展全部角色。
- 保留原始素材、v1失败／待审记录及用户外部文件；仅新增版本化文件。
- 生命90、伤害12、移动165、扑击430、前摇0.50／有效0.30／收招0.65和身体32×56均沿用当前配置，不重定平衡。
- 主角继续临时几何；样板房镜头候选1.5倍，山魈中立身体高56世界像素，约84屏幕像素；不是最终比例冻结。
- 原PNG不通过Python编辑；透明绘制使用imagegen，Godot导入／画布定位只负责资源接入，保留完整提示词、来源与像素实查。
- 样板的技术检查与用户美术／手感验收分开；没有执行或没有通过的项目明确记录。

## Review Focus

- 朝右翻转须围绕脚底根节点，不因大透明画布偏移角色位置；测试两方向锚点。
- 前摇无伤害，有效期间才能伤害，收招显示反击机会；测试真实玩家生命与阶段画面。
- 空中扑击与落地画面依据真实is_on_floor，不靠固定动画帧伪造落地；测试平台及空中转收招。
- 暂停须同时冻结AI与画面，重开须清理旧敌人并恢复初始状态；测试真实场景重载。
- 受击中断、死亡只结算一次；缺少动作时不能退回静态概念板冒充动画；测试攻击被打断及完整死亡流程。

### Task 1: 动作素材与动画表现

**Files:** 新增assets/enemies/shan_xiao/playable_v1/（原始透明帧、动画清单／来源／QA）；scripts/art/shan_xiao_visual.gd；tests/test_art_room.gd。旧v1只读取。

**Interfaces:** `ShanXiaoVisual`作为Enemy子节点，`sync_pose() -> void`读取父节点state、clock、facing、velocity、attack和is_on_floor；对外提供`animation_name`与`sprite`供实际状态验证，绝不修改父节点战斗数据。

- [ ] 写专项测试：初始无新表现脚本时“可试玩山魈表现存在”失败；补齐后验证idle/run/telegraph/airborne/recovery/hurt/death真实纹理及左右锚点。
- [ ] 以原中立姿势为参照补绘呼吸／跑动／受击／倒下和必要扑击过渡；单张检查后保存，逐帧校准元数据，保留未合格点。
- [ ] 实现状态同步和脚底锚点；动作时钟沿用AI，移动按真实位移推进；死亡依已有0.60秒生命周期播放。
- [ ] 运行专项无窗口测试；预期逐项PASS且无SCRIPT ERROR／Parse Error／ERROR:。保存有限范围版本。

### Task 2: 一个真实可玩房间

**Files:** 新增scenes/art/shan_xiao_art_room.tscn、scripts/art/shan_xiao_art_room.gd；最小修改enemy.gd（仅关闭该实例几何身体的开关）、app.gd和main_menu.gd（独立入口）；扩展专项测试。

**Interfaces:** `App.start_art_room() -> void`复用已有切换；样板房暴露`player`与`enemy`，`restart_room() -> void`重载同一场景。挂载Task1表现，实际地面／平台沿用StaticBody2D，暂停复用既有场景。

- [ ] 先验证无场景时入口检查失败；再实现菜单入口、地面／墙／平台、镜头、HUD、暂停、重开与返回菜单。
- [ ] 扩展真实物理测试：追踪跑动、前摇不扣血、有效攻击扣12且不重复、受击中断、死亡单次事件、暂停冻结、重开恢复与入口往返。
- [ ] 在图形窗口实际运行，保存待机／追踪／前摇／攻击／受击／死亡截图，检查轮廓、脚底、翻转与平台遮挡；不将截图当作用户手感验收。
- [ ] 专项绿后运行原tests/run_checks.ps1 -Windowed，预期现有全部断言通过；间歇失败单独记录，不凭重跑声称修复。

### Task 3: 报告与版本

**Files:** 更新README.md、ART_DIRECTION.md、ART_PRODUCTION_TRACKER.md、TECH_DESIGN.md／TEST_PLAN.md相关接入记录；新增SHAN_XIAO_PLAYABLE_REPORT.md，完整主方案不改。

- [ ] 核对来源、格式、真实帧数／复用、角色尺寸、判定偏差、未完成事项及实际测试结果，区分候选与正式美术。
- [ ] 依requesting-code-review做独立只读审查，修复重要问题；验收仅覆盖该山魈单房。
- [ ] 选择性提交并沿既有授权同步GitHub，保留外部素材变动；完成后停止，交由用户实际试玩审阅。

## 执行记录

任务1、2已实现并联合验证：16张PNG来源和alpha检查，专项24项无窗口／窗口通过；任务3文档与独立只读审查已完成，无重要缺陷。完整回归31脚本解析及原框架／战斗／敌人／路线／设置通过。详细实际记录以SHAN_XIAO_PLAYABLE_REPORT.md为准，上述复选项保留为原实施步骤而非测试通过清单；没有单独执行的缺场景门禁故障注入不声明已执行。整体专项先以缺少表现失败，再实现并实际运行至通过。

本轮沿用用户已批准的聊天方案，直接实施，未要求重复确认。使用codex/shan-xiao-playable-art分支在原目录作有限范围修改，保留全部外部素材变动。用户最终美术／手感审阅尚未完成，不视为阶段4启动授权。
