# 阶段 1：工程框架实施计划

规格：用户最新阶段 1 指令、[完整方案](GAME_DEVELOPMENT_PLAN.md) 及四份规范。按最新指令，本轮阶段 1 是工程框架，对应旧路线图的阶段 2；旧阶段 1 美术验证未因此被宣称通过。后续阶段 2 的内容等待用户新指令，不自动编号或开工。

目标：Godot 4.7.2 中可启动、切换、暂停、设置、返回及退出的真实工程框架，无游戏存档时禁用继续。使用 gl_compatibility、SystemFont、GDScript 和 Godot 原生测试，不安装依赖，不修改既有素材。

沿用用户当前工作目录就地开发，保留素材搬移与 Word 文档的未提交改动，不将其混入本次提交。

## 文件结构与任务

1. project.godot：主场景、渲染、窗口、输入和两个 Autoload；default_bus_layout.tres：音乐与音效总线。
2. scripts/managers/app.gd：初始化、应用状态、场景切换、暂停与日志；settings.gd：显示／音量／输入与独立设置持久化。
3. scenes/main/main_menu.tscn、scenes/world/game.tscn、scenes/ui/pause_menu.tscn、settings_menu.tscn：可编辑场景入口；各自脚本处理各自交互。
4. scripts/ui/ui_style.gd、backdrop.gd：共享中文主题与简洁背景；不生成角色或地图。
5. tests/test_framework.gd：先编写并运行红灯，再实现真实菜单流程；覆盖暂停冻结、设置保存重载、输入冲突与重复切换；退出用真实按钮结束进程。
6. README.md、docs/PHASE_1_REPORT.md：运行方法、模块接入边界、证据和未测试范围；更新 AGENTS、WORKFLOW、TECH_DESIGN、TEST_PLAN 的当前状态，保留完整方案原文并追加阶段变更记录。

## 验证与停止条件

- 首先运行缺少主菜单的测试，确认因功能未实现而失败。
- 导入后逐脚本 --check-only，检查完整输出中的 SCRIPT ERROR／Parse Error／ERROR:。
- 无窗口完整菜单流程及真实退出；窗口模式重复流程并截取真实渲染结果。
- 正常启动主场景运行有限帧，启动编辑器验证工程可打开。
- 用独立文件验证用户设置重启读取；不修改用户游戏档案，不伪造继续状态。
- 最后进行一次独立代码审查，修复实际问题，记录通过项、遗留项和未验证项。
- 不安装导出模板；Windows 独立导出、物理手柄和战斗／存档／地图玩法尚不在本轮通过范围。完成即停止。
