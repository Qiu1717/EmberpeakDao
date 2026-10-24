# Windows构建与验收说明

候选版本：0.1.0-rc.1。Godot 4.7.2.stable.official.ed1daf0bf，GDScript，Windows x86_64，GL Compatibility。启动场景为scenes/main/main_menu.tscn，默认1280×720、最小960×540，窗口／全屏／垂直同步仍由玩家设置控制。SVG图标使用主方案色板，为本轮基础工程图标，正式美术仍可替换。

## 当前实际阻塞

本机未找到匹配的Windows导出模板。实际--export-release已执行并失败，日志builds/phase7/export-windows.log明确指出缺失：

```
C:/Users/Q/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_debug_x86_64.exe
C:/Users/Q/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe
```

没有生成经验证的独立exe，不声称Windows发布成功。本轮没有安装或下载模板，不把编辑器exe改名当作导出结果。

## 模板到位后需要完成的操作

1. 用户允许后，从Godot官方渠道取得与当前4.7.2.stable完全匹配的导出模板；在编辑器“管理导出模板”安装或放入上述版本目录。不要为了现有模板更换引擎。
2. 在工程根目录执行下面的构建脚本，检查退出码、日志以及exe和同名pck同时存在。脚本失败不会宣布发布成功；也不会删除已有文件掩盖问题。

```powershell
pwsh -NoProfile -File scripts/tools/build_windows.ps1
```

3. 将builds/windows/EmberpeakDao.exe和EmberpeakDao.pck一起放到一个独立目录；不要只复制exe。当前设置不嵌入PCK。
4. 在没有project.godot／编辑器进程参与的该目录中双击exe，验证标题／图标、主菜单、设置／暂停／退出、移动／剑枪／重击／闪避／受击、NPC／商店／奖励／奇遇、Boss和祭坛流程。
5. 使用独立测试档验证保存、退出后重启继续、境界和材料消耗、死亡后永久保留、无重复奖励；测试人员不要用自己的正式存档做损坏试验。
6. 在导出exe上再次采样帧率、内存和长时运行；当前编辑器运行数据不能替代发布程序或其他目标硬件测试。
7. 记录版本、引擎、构建提交、SHA256、测试结果和已知问题；包含所用引擎及资产的相应许可说明后再制作可发布压缩包。本轮未生成“已验收发布包”。

## 导出配置与资源范围

export_presets.cfg中Windows Desktop、x86_64、分离PCK、不签名／不加密，无密钥。config/version为候选标识，不表示质量验收完成。当前项目只使用系统字体名称，不打包系统字体文件。Godot可根据SVG生成Windows图标，但本轮因缺模板尚未验证exe内嵌图标。

运行资源包含scenes、scripts、resources、assets，显式加入动态读取的manifest和图鉴JSON，并排除provenance／qa_pixels／generation_requests／generation_sources内部记录。测试、docs、builds、构建脚本、用户中文原始参考目录等排除；原始资源仍保留在工程中，不做删除清理。

资源包可在缺Windows模板时单独尝试：

```powershell
pwsh -NoProfile -File scripts/tools/build_windows.ps1 -PackOnly
```

PCK不是独立Windows程序。只有资源包实际运行后才能报告其资源检查通过；即便通过，也仍不能报告独立exe发布成功。完整结果见PHASE_7_REPORT.md。

本轮实际从builds/windows隔离目录，以现有引擎--main-pack加载PCK，并通过工程外部绝对路径调用tests/test_packaged_resources.gd，窗口／无窗口各48项通过；另包内完整流程59、战斗28、框架24项通过。不要从源码根目录判断包内排除范围，因为res访问仍可能回退到本机源文件，掩盖漏打包。

## 存档与操作

默认保存位置为%APPDATA%/EmberpeakDao/save_game.json，设置单独保存settings.cfg。已有存档被保留；开始新游戏表示新探索而非删除永久境界。资源快照与祭坛永久记录不同，未记录新增资源死亡仍丢失。详细操作见README和RELEASE_NOTES。

官方参考：[Windows导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)、[Windows图标](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html)。实际模板版本和可运行结果以本机日志为准，不据网页泛化为已通过。
