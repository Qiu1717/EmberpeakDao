# 现有美术素材接入计划与记录

2026-10-23。用户要求将现有美术全部接入，角色动作和场景建筑随后处理。基准为GAME_DEVELOPMENT_PLAN.md及现有美术规范，承接主角静态接入分支。

## 范围与实施选择

26张原始图：主角1、敌人6、NPC 5、武器装备6、场景8，实际均RGB，带底色或完整画面。原文件和用户移动位置保留，不覆盖、不重命名。旧失败动作图集不当作有效动画接入。

- 六种敌人进入真实战斗：山魈复用已完成的动作候选；其余五种通过内置imagegen从原设定图提取透明单姿势，不制作新动作。保留生命、伤害、碰撞、前摇、无敌和掉落事件配置。
- 六房间使用对应场景图作静态背景；菜单和训练采用单幅入口图。总氛围图为多画面总览板，与旧碑奇遇图均可在图鉴查看，不伪造新事件房。画中建筑／台阶没有新增碰撞，现有地面、平台与门继续明确显示，分层建筑和匹配地形留待后续。
- NPC／武器装备尚无对应玩法，统一加入游戏内美术图鉴；不新增交易、任务、换装、长枪战斗或存档空壳。图鉴同样能查看全部主角、敌人、场景原图。
- 在当前工作目录建立codex/all-art-integration分支承接现有主角成果，方便直接运行用户新放入的素材；原有未跟踪文档与素材移动不擅自提交。新增运行素材采用另存副本并记录来源哈希。

## 文件职责与步骤

- [x] 素材清点与来源：assets/art_catalog.json登记26张原图；assets/npcs/concepts、assets/equipment/concepts、assets/backgrounds/nameless_tomb存放字节一致副本，保留原图；五种敌人另存assets/enemies/static_v1，记录提示词、来源、alpha与锚点。
- [x] 先运行tests/test_all_art.gd，确认实际失败于缺少图鉴／素材接入；再创建scripts/art/art_catalog.gd及scripts/art/enemy_static_visual.gd，修改Enemy接入表现，并移除样板房重复挂载。
- [x] scripts/ui/backdrop.gd接入真实背景；scripts/world/game.gd随房间更新背景和当前状态说明，物理地形不变。
- [x] scenes/art/art_gallery.tscn、scripts/art/art_gallery.gd提供分类浏览、完整图查看和返回；scripts/managers/app.gd及主菜单提供入口。
- [x] 专项实际验证26图可加载、六房映射、敌人精灵／锚点／翻转、分类浏览、返回菜单；运行现有工程回归并记录实际窗口截图。tests/run_checks.ps1纳入专项。
- [x] 更新README、美术规范与素材记录，写实际检查结果、未完成项；核对有限范围版本文件，不自动进入阶段4。

## 验收

全部26张有效原图有运行中的可见入口；六房背景随切换改变；所有六种战斗敌人有真实美术，五张静态图明确不是完整动作；NPC和装备明确仅美术资料，不假装可交易或装备。原素材哈希不变、既定数值不变；所有未执行测试标未验证。完整回归若因旧菜单间歇失败中断，保留失败记录并单独补测余项，不称全绿。

## 实际检查与修正

环境为Godot 4.7.2 stable、Compatibility渲染。本轮没有安装软件、插件或依赖，没有更改完整设计方案、project.godot或任何resources数值表。

1. RED日志builds/all_art/red.log实际失败于素材清单不存在。初次加载还发现原主角目录有.gdignore，已采用assets/characters/shen_jin/concepts/reference.png的字节一致副本，不移除原目录忽略设置。
2. 初版94项断言虽打印通过，完整日志仍含图鉴说明Label重复add_child错误；因此初版不计作无错误通过。删除重复挂载，并让测试驱动实际分类控件、补测主菜单入口与返回按钮连接，更新为96项。
3. 最终headless-final.log及window-final.log均退出0、96项通过，且完整日志无SCRIPT ERROR／Parse Error／ERROR。实际查看三房、NPC、装备和场景图鉴截图。总氛围原图是多画面总览板，窗口QA后改为仅图鉴展示；菜单默认改用单幅入口图，重新解析背景脚本并运行窗口96项，完整日志无错误。
4. 完整tests/run_checks.ps1 -Windowed实际退出0，记录在builds/all_art/regression-final.log：导入、36份GDScript逐脚本解析、主场景启动，以及下表各套件通过。本轮未再次出现旧菜单的间歇点击失败；没有为此修改旧菜单测试或宣称该历史间歇问题已经根治。
5. 再次扫描磁盘全部原图，与清单source集合完全一致。26个原图SHA256及其运行副本逐项相同；五个透明源PNG与工具返回文件字节一致，参考原图哈希一致，RGBA实际alpha包含0。五次内置imagegen请求均完成，实际提示词与来源保存在static_v1。
6. 独立只读审查已完成：复核26图来源哈希、图鉴连接、截图、六房映射、敌人镜像与脚底、共享山魈挂载，未发现有证据的阻断或重要问题。审查没有修改文件或重复启动图形测试；其结论不包含正式动作、美术最终满意度或Windows发布。

| 检查 | 无窗口 | 实际窗口 |
|---|---|---|
| 框架／菜单 | 24项通过；暂停菜单退出另24项通过 | 24项通过 |
| 基础战斗 | 28项通过 | 28项通过 |
| 山魈美术单房 | 24项通过 | 24项通过 |
| 主角静态美术 | 20项通过 | 20项通过 |
| 本轮现有美术 | 96项通过 | 96项通过 |
| 六敌人／Boss | 47项通过 | 47项通过 |
| 六房路线 | 41项通过 | 41项通过 |
| 敌人回归 | 6项通过 | 6项通过 |
| 设置 | 6项通过，跨进程写入／读取通过 | 10项通过，运行器恢复用户设置原字节 |

builds/all_art/中main_menu、broken_swords、elite_den、general_hall、gallery_0至gallery_2为实际窗口视口截图，不是生成的游戏效果图。builds不入版本库。窗口后最后一步仅切换默认背景选图，已单独解析与窗口专项复核；六房映射、战斗和UI逻辑未改。

## 文件变更用途

| 文件／目录 | 用途 |
|---|---|
| assets/art_catalog.json | 26图分类、名称、运行路径、原始来源、SHA256与展示说明 |
| assets/characters/shen_jin/concepts/reference.png及.import | 原主角三视图的运行展示副本 |
| assets/npcs/concepts、assets/equipment/concepts、assets/backgrounds/nameless_tomb及.import | 5张NPC、6张装备、8张场景的字节一致运行副本 |
| assets/enemies/concepts/*.png.import | 既有敌人原图的1024缩图与mipmaps；PNG原字节不改 |
| assets/enemies/static_v1 | 五张RGBA静态图、512原生导入配置、完整提示词、来源、像素检查、脚底／朝向manifest和说明 |
| scripts/art/art_catalog.gd及.uid | 简单只读素材查找，不包含NPC／装备玩法 |
| scripts/art/enemy_static_visual.gd及.uid、scripts/enemies/enemy.gd | 共享敌人美术挂载、实际状态着色、双方向脚底；碰撞与战斗不改 |
| scripts/art/shan_xiao_art_room.gd | 复用共享敌人Visual，移除重复挂载，更新背景状态说明 |
| scripts/ui/backdrop.gd、scripts/world/game.gd | 静态图按比例覆盖视口、六房背景切换、可通行区域说明 |
| scripts/art/art_gallery.gd及.uid、scenes/art/art_gallery.tscn | 图鉴分类、完整原图预览、菜单返回 |
| scripts/managers/app.gd、scripts/ui/main_menu.gd | 图鉴入口与MENU状态切换，不启动新探索或伪造存档 |
| tests/test_all_art.gd及.uid、tests/run_checks.ps1 | 96项实际专项与原回归接入 |
| README、ART_DIRECTION、TECH_DESIGN、TEST_PLAN、ART_PRODUCTION_TRACKER及本记录 | 当前交付、技术边界、验证结果与后续待办 |

## 未完成／未验证

- 本轮完成静态素材接入；主角及其余五种敌人的完整动作尚未制作。山魈仍为原有简化候选，不能称全角色动画验收通过。
- 新透明图留白没有全部达到提示词的50像素，尸兵底部约8像素、傀儡顶部3／底部1、Boss右侧约3像素；轮廓、边缘、细节漂移和不对称镜像仍需正式美术复核，详见static_v1/README.md。
- 六房背景没有拆层，画中石阶与真实平台不完全对齐；物理地面／平台／门仍用明确标线。建筑、前景遮挡、视差、装饰碰撞和正式地图美术留待下一项。
- NPC仅图鉴展示，无对话／任务／商店；装备仅造型展示，未实现换装、图中技能或长枪战斗；旧碑图未新增事件房。方案NPC小满尚无原图，不生成替代。
- 最终审美、全部动作手感、长时性能、Windows独立导出／发布仍未验证。没有将本轮素材接入等同阶段4、正式存档或最终美术交付。
