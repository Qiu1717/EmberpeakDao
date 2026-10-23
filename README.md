# 烬山问道

Windows PC 单人离线、手绘国风 2D 横版修仙动作肉鸽。引擎 Godot 4.7.2 stable，GDScript，gl_compatibility。

当前交付为阶段3：第一地图六种敌人与六房间固定战斗路线。“开始新游戏”进入剑冢入口，“剑术训练场”保留阶段2木桩训练。四种小怪、裂甲山魈和镇山妖将具有不同AI／攻击模式，支持清场解锁、近门交互切换及Boss后回访祭坛。角色仍为明确标记的临时几何体，概念图通过资料卡查看；尚无正式动画。随机地图、装备、成长与游戏存档尚未实现，继续游戏禁用。

唯一设计基准：[完整开发方案](docs/GAME_DEVELOPMENT_PLAN.md)。[开发约定](AGENTS.md)、[阶段 1 报告](docs/PHASE_1_REPORT.md)、[阶段 2 报告](docs/PHASE_2_REPORT.md)、[阶段 3 验收报告](docs/PHASE_3_REPORT.md)。当前编号依用户最新指令，完成后等待阶段4。

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

## 无名剑冢固定路线

剑冢入口 → 残剑荒地（山魈幼体／腐甲尸兵）→ 断阶回廊（断刃游魂／灵弩傀儡）→ 裂甲山魈精英战房 → 灵脉祭坛 → 镇山妖将Boss房。普通攻击、移动、跳跃与闪避用下表按键。敌人上方及HUD显示生命、预警、收招和阶段；金色区域是预警，红色是攻击，收招期间可反击。

战斗房清场后红色实体门解除封锁，靠近右侧门按F前进，靠近左侧门按F返回；交互键可重绑。Boss被击败后从左门返回原祭坛，已清场房不重新刷怪或发奖励。中央祭坛附近按F可做测试休整恢复生命，当前没有资源记录、存档或突破。死亡后点击“重新开始路线”会重置本次路线，不读取永久档案。

“敌人资料卡”可查看附近存活敌人的完整概念板，图片不参与动作播放。山魈扑击、尸兵蓄力重劈、游魂快速双击、灵弩后撤射击；精英有甲减伤、60%增加砸地，Boss55%转阶段并新增连击及可跳过的地面冲击波。基础攻击不消耗真气；重击和真气仍未接入，精英破甲目前只有真实伤害接口，尚无玩家重击教学。

死亡奖励只发出带唯一来源的事件；Boss含“筑基灵髓”材料名，但没有背包到账、随机装备抽取或存档。所有既定生命／伤害、测试参数及缺失的奖励概率见[敌人数值表](docs/ENEMY_BALANCE.md)。六房是固定测试子集，不是完整八模板或随机地图。

## 训练场操作

A/D 加速移动，Space 跳跃；Shift 按朝向闪避150像素，0.20秒无敌，0.70秒冷却。J／世界空白左键普攻，完成一次动作后及时再次按下可衔接14／18／24三段伤害；没有自动连打或连段输入缓冲。攻击期间可闪避取消。靠近木桩攻击，青色矩形只在实际命中窗口显示；范围外挥击不扣木桩生命。

左上角“受击测试 −10”施加伤害和击退，“致死测试”进入死亡，“重新训练”真实重载整个训练场并恢复生命、位置、冷却和木桩。闪避无敌时测试伤害也会被拒绝。测试按钮是调试入口，无敌人 AI；此重开不处理资源保留或读档。移动加速、跳跃缓冲与离地容错是待手感评审的调试参数，详见 [阶段 2 计划](docs/PHASE_2_PLAN.md)。

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

当前移动、跳跃、普通攻击、闪避、交互和暂停已接入；交互用于房门与测试祭坛，重击、技能、药品尚无对应功能。物理手柄尚未实测；不同品牌的按钮图案可能不同。

## 代码与模块接入

| 位置 | 当前用途 |
|---|---|
| project.godot / default_bus_layout.tres | 工程入口、窗口、输入与音频总线 |
| scripts/managers/app.gd | 生命周期、场景切换、状态、暂停和日志 |
| scripts/managers/settings.gd | 设置校验、应用与独立持久化 |
| scenes/main/、scenes/ui/ | 主菜单、暂停、设置的场景入口与界面脚本 |
| scenes/world/game.tscn / scripts/world/game.gd | 默认六房路线及HUD、资料卡、暂停层；training_game.tscn继承场景保留训练模式 |
| scenes/rooms/、scripts/world/combat_room.gd、sword_route.gd | 六房碰撞、实体锁门、激活清场和回访；World/SwordRoute为房间，Actors/Player为持续角色 |
| scenes/enemies/、scripts/enemies/、resources/enemies/ | 共享敌人状态、六种行为、攻击参数、投射物、唯一死亡奖励事件 |
| assets/enemies/concepts/ | 原图字节副本与导入设置，仅供资料卡参考 |
| scenes/player/player.tscn / scripts/player/ | 角色碰撞、镜头、七状态、输入与参数类型 |
| resources/player/training_stats.tres | 主角参数；既定数值与临时调试参数来源见阶段 2 计划 |
| scripts/combat/damage.gd | 统一倍率、防御及整数伤害结算 |
| scripts/world/training_arena.gd、training_target.gd | 手工训练平台、边界与静止可击退木桩，无敌人 AI |
| scripts/ui/ui_style.gd、backdrop.gd | SystemFont 中文主题及程序绘制背景，无外部素材依赖 |
| tests/ | 实际物理战斗、真实菜单输入、设置文件和进程重启回归 |

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

测试会检查完整日志中的 SCRIPT ERROR、Parse Error、ERROR:，并检查结果标记，防止达到帧数上限却误报通过。当前日志及截图保存于 `builds/phase3/`（阶段1、2旧记录保留）；Godot 缓存在 `.godot/`，均不提交。

当前敌人测试47项、路线41项、问题回归6项，以及原主角战斗28项，均在无窗口和真实窗口各执行一次；框架与设置回归一并运行。窗口路线截图为 builds/phase3/room_0.png 至 room_5.png；本次资料卡实查截图为 boss_live.png。

本轮未验证正式角色动画、人工手感评价、Windows 独立导出、物理手柄、音频听感与后续游戏系统。没有使用空函数或假存档模拟这些功能。

## 动作素材样片（2026-10-23）

第一地图现有山魈概念图已用于制作扑击样片：7张不同透明姿势、8个播放帧槽；它尚未通过正式美术验收，未替换游戏中的临时敌人。正常／半速、逐帧及56像素高度对照预览：

```powershell
& 'E:\Godot\bin\godot.bat' --path . res://scenes/art/shan_xiao_pounce_preview.tscn
```

见[素材与提示词](assets/enemies/shan_xiao/validation/pounce_v1/README.md)、[实际检查报告](docs/ART_SAMPLE_REPORT.md)、[十项GitHub技能筛选结果](docs/ART_SKILLS_REVIEW.md)。本次仅美术样片制作，不启动阶段4。

## 山魈单房可试玩样板

主菜单点击“山魈美术样板”，可与已接入手绘动作的山魈实际战斗。A/D移动、Space跳跃、J或左键攻击、Shift闪避、Esc暂停（按键可重绑）；界面支持重新挑战、返回菜单和显示身体碰撞。

也可在Godot打开scenes/art/shan_xiao_art_room.tscn按F6，或执行：

```powershell
& 'E:\Godot\bin\godot.bat' --path . res://scenes/art/shan_xiao_art_room.tscn
```

该房使用1.5倍镜头验证山魈的待机、四姿势跑动、扑击、受击与倒下；保留原战斗数值与碰撞，主角／环境仍临时，原六房路线没有全局替换。源图、完整提示词与导入规则见[动作素材说明](assets/enemies/shan_xiao/playable_v1/README.md)，实际测试和已知视觉问题见[单房报告](docs/SHAN_XIAO_PLAYABLE_REPORT.md)。这是供您试玩审阅的候选，不代表所有角色正式动画完成。
