# 烬山问道

Windows PC 单人离线、手绘国风 2D 横版修仙动作肉鸽。引擎 Godot 4.7.2 stable，GDScript，gl_compatibility。

当前交付是阶段 1 工程框架：主菜单、游戏场景、暂停、设置与切换已实现；角色移动、战斗、敌人、随机地图、装备和游戏存档尚未实现。开始新游戏进入问道残庭框架场景，不代表首个可玩版本完成。继续游戏按钮保持禁用。

唯一设计基准：[完整开发方案](docs/GAME_DEVELOPMENT_PLAN.md)。[开发约定](AGENTS.md)、[阶段验收报告](docs/PHASE_1_REPORT.md)。用户本轮阶段 1 对应原路线图的工程框架阶段；下一阶段等待新指令。

## 运行

在项目根目录打开 PowerShell。若会话中 godot 命令未刷新，直接使用现有绝对路径：

```powershell
& 'E:\Godot\bin\godot.bat' --path .
```

打开编辑器：

```powershell
& 'E:\Godot\Godot_v4.7.2-stable_win64.exe' --editor --path .
```

首次打开或新增运行资源后导入：

```powershell
& 'E:\Godot\bin\godot.bat' --headless --path . --import
```

引擎无需重装。本机尚无匹配导出模板，当前从编辑器或引擎运行；尚未生成独立 exe。

## 菜单与设置

主菜单可开始新游戏、打开设置和退出；无游戏存档时继续不可用。游戏场景中点击暂停或按暂停键，菜单提供恢复、设置、返回主菜单和退出。返回菜单会清除暂停状态，窗口关闭也走统一退出流程。

设置包括总音量、音乐、音效、窗口／全屏、1280×720／1600×900／1920×1080 窗口分辨率、垂直同步和键位重绑定。全屏使用显示器尺寸。调整后点击“应用并保存”；未应用即关闭会放弃修改。“恢复默认”先修改面板草稿，再由应用确认。

点击键位按钮后按新键，Esc 取消；冲突按键不接受。重绑只替换键盘绑定，鼠标和手柄默认映射保留。Esc 在设置界面始终可关闭该层；暂停键重绑后游戏内按新键操作。控件可用 Tab 和方向键导航，设置开启时不能选中背后的菜单。

设置独立保存在 `user://settings.cfg`，本项目 Windows 默认位置为 `%APPDATA%\EmberpeakDao\settings.cfg`。它只保存用户偏好，不是角色档案或探索存档。Music、SFX 总线已配置，目前没有音乐与音效素材。

## 输入映射

| 动作 ID | 默认键鼠 | 默认手柄 |
|---|---|---|
| move_left / move_right | A / D | 方向键或左摇杆 |
| jump | Space | A |
| attack | J / 鼠标左键 | X |
| heavy_attack | K / 鼠标右键 | Y |
| dodge | Shift | B |
| skill | Q | 左肩键 |
| heal | E | 右肩键 |
| interact | F | 右摇杆按下 |
| pause | Esc | Start |

当前仅暂停接入游戏行为，其余动作供后续角色与战斗统一读取。物理手柄尚未实测；不同品牌的按钮图案可能不同。

## 代码与模块接入

| 位置 | 当前用途 |
|---|---|
| project.godot / default_bus_layout.tres | 工程入口、窗口、输入与音频总线 |
| scripts/managers/app.gd | 生命周期、场景切换、状态、暂停和日志 |
| scripts/managers/settings.gd | 设置校验、应用与独立持久化 |
| scenes/main/、scenes/ui/ | 主菜单、暂停、设置的场景入口与界面脚本 |
| scenes/world/game.tscn | 游戏框架场景；World 接地图、Actors 接角色、UI/Overlay 接 HUD |
| scripts/ui/ui_style.gd、backdrop.gd | SystemFont 中文主题及程序绘制背景，无外部素材依赖 |
| tests/ | 真实输入、设置文件和进程重启回归 |

后续新局模块订阅 App.session_started（场景就绪后触发）；暂停状态订阅 App.state_changed；切换完成订阅 App.scene_changed。App 不保存境界或装备数据，Settings 不承担游戏存档。未来资源与存档边界见 [技术设计](docs/TECH_DESIGN.md)，未提前创建空壳服务。

原始中文参考图目录和失败动画试验目录通过 .gdignore 排除运行资源导入；所有源图仍保留，正式验收资产将另存正式目录。

## 测试

```powershell
# 无窗口测试
pwsh -File tests/run_checks.ps1

# 包含真实图形窗口、显示设置测试和截图
pwsh -File tests/run_checks.ps1 -Windowed
```

使用其他引擎路径时加 `-Godot '完整入口路径'`。窗口测试会短暂打开窗口、切换分辨率和全屏；结束后恢复用户设置。请勿与手动修改设置同时运行。

测试会检查完整日志中的 SCRIPT ERROR、Parse Error、ERROR:，并检查结果标记，防止达到帧数上限却误报通过。日志及截图保存于 `builds/phase1/`；Godot 缓存在 `.godot/`，均不提交。

本轮未验证 Windows 独立导出、物理手柄、音频听感与后续游戏系统。没有使用空函数或假存档模拟这些功能。
