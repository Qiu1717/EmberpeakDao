# 动作素材任务：GitHub技能筛选与安装记录

日期2026-10-23。用户授权检查指定技能并自行决定下载有用部分。仅安装技能文档及其随附资源，不安装引擎、DCC软件、项目插件或运行依赖，不运行第三方install.sh／install.ps1／npx自动脚本，不引入新账号或付费服务。本次素材工作不启动阶段4游戏功能开发。

名称未附作者时存在多个同名候选，下面记录实际核实的仓库；不冒充唯一原链接。链接为原仓库或原技能文件，不以搜索结果作为事实来源。

|用户列出的名称|实际核实来源|判断与处理|
|---|---|---|
|game-studios|[Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)，[Codex移植候选](https://github.com/DocJlm/Codex-Game-Studios)|完整工作室流程，asset-spec依赖Claude目录、hook和多角色上下文；本项目已有方案与阶段门，不整包安装，不覆盖AGENTS或重建GDD|
|gamedev-agent-skill|[minhhoit/gamedev-agent-skills](https://github.com/minhhoit/gamedev-agent-skills/tree/main/skills/disciplines/create-game-assets)|匹配的复数名称仓库；选装create-game-assets，用于素材清单、造型锁定、透明／尺寸／预览验收；已有godot-animation保留不覆盖|
|unreal-skill|[EpicGames Unreal技能](https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin/blob/main/skills/unreal-skill/SKILL.md)|面向UE编辑器Agent Skill及unreal-mcp注册，非Godot动作绘制；不安装|
|unity-skills|[Besty0728/Unity-Skills](https://github.com/Besty0728/Unity-Skills)|Unity编辑器自动化，当前Godot工程不使用；不安装|
|scenario-game-assets|[scenario-labs/skills](https://github.com/scenario-labs/skills/tree/main/skills/scenario-game-assets)|依赖Scenario MCP及其账户／模型执行服务；动作序列另属scenario-sprite-animation。当前未连接Scenario，无需为本轮额外接入；不安装，使用已可用内置imagegen|
|novel-to-game|[zenstory-ai/novel-to-game](https://github.com/zenstory-ai/novel-to-game)|小说改编与证据驱动交付流程；本项目已有完整原创GDD，本次非改编任务；不安装|
|godotprompter|[jame581/GodotPrompter](https://github.com/jame581/GodotPrompter)|Godot4.x技能框架；只选装独立assets-pipeline及目录内引用资料，不引入整套框架或覆盖已有动画技能|
|unreal-engine-skill|[quodsoler/unreal-engine-skills](https://github.com/quodsoler/unreal-engine-skills)|可核实的同类候选，侧重UE C++／动画系统等，不适合当前Godot二维素材制作；不安装|
|game-ui-design-workflow|[guiguiyan930-source/game-ui-design-workflow](https://github.com/guiguiyan930-source/game-ui-design-workflow)|选装game-ui-specification，供后续正式UI规范使用；本轮不重做UI或另建冲突的视觉基准，仍以ART_DIRECTION.md为准|
|blender-skill|[thanhdongnguyen/Blender-Skill](https://github.com/thanhdongnguyen/Blender-Skill)|Blender CLI三维制作路线，需要本地Blender；本轮直接手绘二维逐帧，不新增三维工具链；不安装|

## 已安装的三个技能

- create-game-assets：固定提交 b105e1cf617adf0b68ed98790a716bbb60993179，Apache-2.0；实际读取并应用造型参照、少量同族素材、PNG检查及实际尺寸预览流程。
- assets-pipeline：固定提交 6da498d17031e7c1d8d518e27a148ea440d90341，MIT；读取Godot源文件／导入缓存分离、Texture及Resource接入约定。
- game-ui-specification：固定提交 1ec604638dd1a27198576206eb3e47632725a078，MIT；已安装供以后UI阶段使用，本轮仅核对适用范围，不将UI重设计冒充已实施。

安装路径均在C:/Users/Q/.codex/skills/，未拷贝入游戏运行工程。使用既有系统skill-installer的install-skill-from-github.py，以明确子目录和固定提交下载。本轮已按绝对路径读取，不以文件下载完成推断应用技能列表已刷新。完整文件数、入口SHA256与来源见ART_SKILLS_INSTALLATION.json。

技能提供工作方法，不会凭空提供绘画模型、账户额度、三维绑定或合格动作。Raster资料建议的脚本归一化，仍受当前工具规则约束：本轮绘制／修改图片使用内置imagegen；Python仅检查像素／alpha和原样复制，不改画面。本次采用逐张真实姿势、原始PNG与可回放样片，最终以视觉与技术检查结果决定是否进入正式目录。
