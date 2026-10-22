# AGENTS.md — Godot 肉鸽项目工作约定

这个文件是给代码代理（Codex 等）看的工程约定。环境由 WorkBuddy 在 2026-10-22 搭好，引擎已装、命令行已通。

## 引擎与路径

- **Godot 4.7.2 stable**（官方 win64 构建），安装目录 `E:\Godot`
- 命令行入口 `godot`（已写入用户 PATH，指向 `E:\Godot\bin\godot.bat`，是**控制台版**，能打印 stdout/stderr）
- GUI 编辑器入口 `godot-editor`，或直接双击 `E:\Godot\Godot_v4.7.2-stable_win64.exe`
- 渲染后端默认 `gl_compatibility`（虚拟机/老显卡兼容性最好）
- 暂未安装导出模板（export templates）；需要打包 exe 时再补，不影响开发调试

## 常用命令（在项目根目录执行）

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

## 代码约定

- GDScript（不用 C#，当前引擎是非 .NET 版本）
- 目录：`scenes/` 场景、`scripts/` 脚本、`assets/` 素材；Godot 自动生成的 `.godot/` 不进版本库
- 中文注释 + 中文 UI 文案
- 中文字体用 `SystemFont`（`font_names` 取 `Microsoft YaHei UI` 等），**不要把系统字体文件复制进项目**（有授权问题）
- 随机地牢/掉落用固定 seed 的 `RandomNumberGenerator`，方便复现 bug
- 起步阶段不依赖外部美术素材，用 `_draw()` 或纯色 `ColorRect` 占位

## 版本控制

- 用 git 管理，建议 `.gitignore` 至少包含：`.godot/`、`*.translation`、`export_presets.cfg`（如需保密密钥）
