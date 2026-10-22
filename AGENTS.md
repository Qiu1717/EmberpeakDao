# AGENTS.md — Godot 肉鸽项目工作约定

这个文件是给代码代理（Codex 等）看的工程约定。环境由 WorkBuddy 在 2026-10-22 搭好，引擎已装、命令行已通。

## 项目目标与设计基准

- 《烬山问道》是单人离线、Windows PC、手绘国风 2D 横版修仙动作肉鸽游戏，使用 Godot 4.x 与 GDScript。
- 唯一游戏设计基准为 [docs/GAME_DEVELOPMENT_PLAN.md](docs/GAME_DEVELOPMENT_PLAN.md)。其余文档只细化该方案，不另定玩法；发现冲突先记录于 [阶段 0 报告](docs/PHASE_0_PLAN.md)，未经用户确认不改核心规则。
- 首版范围：一名主角、青锋旧剑和破山长枪、四种普通敌人、裂甲山魈、镇山妖将、无名剑冢八个模板、一个祭坛，以及炼气至筑基的完整探索与死亡循环。五区域属于后续扩展。
- 大境界有初期、中期、后期、圆满四个小境界；小境界满灵气自动突破，大境界在祭坛消耗对应 Boss 材料。突破扣阶段灵气、保留溢出。死亡清除未记录资源和局内强化，保留已完成境界、已记录且未消耗资源、武器解锁和登记蓝图。
- 成长灵气与技能真气分开；不得重新建立一套与方案冲突的经验／永久修为计数。
- 始终用简体中文；面向用户的回复以“少爷，”开头，称呼用户为“少爷”，使用“您”。代码标识符、命令和专有名词保留原文。

## 阶段式执行与修改边界

- 当前按用户最新指令执行阶段 1：工程框架（对应原路线图阶段 2）。仅菜单、场景切换、暂停、输入、基础设置、应用状态与日志；完成后立即停止，等待用户阶段 2 指令。美术验证不因此被视为通过，后续编号与范围以用户新指令为准。
- 每阶段先列目标、预计文件和验收标准，依 [WORKFLOW.md](docs/WORKFLOW.md) 的输入、输出和门禁执行；未通过不得进入下一阶段。
- 不提前创建角色控制、AI、武器战斗、地图生成或存档空壳，不能用空函数、假数据或文档中的接口名冒充实现。
- 修改前阅读已有有效文件，做最小增量修改；不无关重构、不覆盖完整方案、不删除现有素材或代码。保留用户的外部新增文件。
- 不擅自更换引擎、安装软件、插件、依赖或导出模板。素材制作也须在指定阶段范围内进行。
- 数值不明确时记录待验证项与截止阶段；示例测试数字不能当成平衡配置。临时强化触发方式等未决项不得擅自实现。

## 引擎与路径

- **Godot 4.7.2 stable**（官方 win64 构建），安装目录 `E:\Godot`
- 命令行入口 `godot`（已写入用户 PATH，指向 `E:\Godot\bin\godot.bat`，是**控制台版**，能打印 stdout/stderr）
- GUI 编辑器入口 `godot-editor`，或直接双击 `E:\Godot\Godot_v4.7.2-stable_win64.exe`
- 渲染后端默认 `gl_compatibility`（虚拟机/老显卡兼容性最好）
- 暂未安装导出模板（export templates）；需要打包 exe 时再补，不影响开发调试
- 2026-10-22 实测版本：`4.7.2.stable.official.ed1daf0bf`。当前代理会话 PATH 未识别 godot／godot-editor，使用现有入口绝对路径即可，无需重装；默认用户模板目录为空，Windows 导出尚未验证。

## 常用命令（在项目根目录执行）

以下命令仅在 project.godot 和对应脚本实际存在后执行。阶段 0 只有版本与帮助查询，不运行导入或编辑器，以免生成缓存。当前 PowerShell 可用 `& 'E:\Godot\bin\godot.bat'` 替代下列 `godot`。

```bash
godot --headless --path . --import                              # 首次打开或新增资源后导入
godot --headless --path . --quit-after 120                      # 无窗口跑 120 帧后退出
godot --headless --path . --check-only --script res://scripts/x.gd   # 单脚本语法检查
godot --headless --path .                                       # 跑主场景（脚本里 get_tree().quit() 可自退）
```

## 验证要求（重要）

- `--headless --import` 遇到脚本解析错误**也可能返回 0**，所以不能只看退出码，必须检查输出里是否出现 `SCRIPT ERROR` / `Parse Error`。
- `--check-only` 有解析错误时**返回码为 1**，可以作为硬门禁，适合脚本化。
- 改完场景/脚本后至少跑一次 `--headless --path .`，确认无 `ERROR:` 输出。
- 实际运行应有退出条件（如 `--quit-after 120`），避免无限挂起；同时记录日志和未覆盖范围。无窗口运行不证明画面、手感或发布通过。
- 按 [TEST_PLAN.md](docs/TEST_PLAN.md) 覆盖战斗、境界、装备、死亡、存档、地图和 Windows 发布。未执行一律标注“未执行／未验证”；不能将列出的用例当成通过结果。
- 没有 project.godot 时明确报告无法执行项目运行验证，不能创建临时游戏工程来冒充已有工程通过。

## 代码约定

- GDScript（不用 C#，当前引擎是非 .NET 版本）
- 目录：`scenes/` 场景、`scripts/` 脚本、`assets/` 素材；Godot 自动生成的 `.godot/` 不进版本库
- `resources/` 放武器、敌人、境界、装备、词条、事件等 Resource 配置；`tests/` 放实际测试；`docs/` 放方案与技术、美术、工作流、测试文档。按需创建，不为阶段 0 建立空游戏模块。
- 中文注释 + 中文 UI 文案
- 中文字体用 `SystemFont`（`font_names` 取 `Microsoft YaHei UI` 等），**不要把系统字体文件复制进项目**（有授权问题）
- 随机地牢/掉落用固定 seed 的 `RandomNumberGenerator`，方便复现 bug
- 上条固定 seed 用于调试与回归；正常新探索记录实际 seed，死亡后开启新探索生成新 seed，继续探索恢复 RNG 状态，不重新抽取已保存结果。
- 起步阶段不依赖外部美术素材，用 `_draw()` 或纯色 `ColorRect` 占位

## 版本控制

- 用 git 管理，建议 `.gitignore` 至少包含：`.godot/`、`*.translation`、`export_presets.cfg`（如需保密密钥）
- 已关联用户授权仓库 `https://github.com/Qiu1717/EmberpeakDao`；保存有限范围的提交，可沿用授权同步版本，不强制推送或覆盖远端历史。敏感导出配置不提交。
