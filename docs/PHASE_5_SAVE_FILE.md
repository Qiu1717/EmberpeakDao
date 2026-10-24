# 阶段5独立存档文件模块

日期：2026-10-24。实际文件：`scripts/save/save_file.gd`、`tests/test_save_file.gd`。这里只描述文件存取，不代表阶段5整体验收。

## 实际API与封套

```gdscript
var storage = load("res://scripts/save/save_file.gd").new(path, validator)
var loaded: Dictionary = storage.load_save()
var saved: Dictionary = storage.commit(envelope)
```

- `new(path: String, validator: Callable = Callable())`：不读写文件。`path`由调用方指定，不内置正式存档路径；可选validator接收完整封套并返回bool，应只做校验。
- `load_save()`：固定返回`accepted/message/status/data`。missing的accepted为true、data为null；loaded/recovered为true、data为完整封套；corrupt/incompatible为false、data为null。recovered的中文message包含备份revision。只读，不重写或删除原件。
- `commit(data: Dictionary)`：返回`accepted/message`。仅最终主档替换成功后返回true；失败提供中文提示。
- v1封套必须含`save_version=1`、正整数`revision`、字典`profile`、字典或null的`run_snapshot`。revision限于JSON安全整数范围；读回封套的版本号和revision转换为int。业务字段、ID关系、RNG字符串及完整档案／探索语义由validator验证。
- 未识别正整数版本视为incompatible；尚无历史版本或迁移实现，不静默解释为v1。

| status | 含义 |
| --- | --- |
| missing | 主档与备份都不存在；孤立临时文件不算存档 |
| loaded | 主档通过封套及调用方语义校验 |
| recovered | 主档缺失或损坏，备份通过相同完整校验 |
| corrupt | 主备均无可用封套或无法读取 |
| incompatible | 需要读取的主档或备份版本不受支持，禁止降级 |

主档有效时读取主档，不以备份中的提交编号覆盖主档。保存前额外检查主档与备份，不覆盖任何未知版本；现有主备均损坏时拒绝保存，不自动创建新档覆盖原件。

## 写入与恢复协议

1. 验证候选完整封套及调用方语义。
2. 将JSON写入`path.tmp`，flush、close后重新读取，验证内容和完整语义。
3. 当前主档有效时，将原主档完整内容写入`path.bak.tmp`，同样flush、close并复读校验，再rename为`path.bak`。此前主档一直存在。
4. 当前主档损坏而备份有效时，不用损坏内容轮换备份。
5. rename已校验的`path.tmp`为主档。替换失败返回失败，保留上一有效提交供主档／备份读取。

Windows边界：Godot的覆盖rename会先移除目标，再移动源文件，不能宣称系统级无间隙原子替换。本模块在替换主档前先完成有效备份，若中断导致主档缺失则读取备份。完整封套避免永久档案与局内快照分别写成功，但恢复备份可能回退一份提交。此实现不引入PowerShell、原生扩展或第三方依赖。[Godot官方Windows实现](https://github.com/godotengine/godot/blob/master/drivers/windows/dir_access_windows.cpp)

恢复出的旧活跃探索不等于仍可继续。死亡失效、旧局拒绝和结算防重必须由Session处理，不由文件层宣称永不回滚。flush与备份测试也不代表已经验证断电后的物理磁盘持久性。

## 实际红绿证据

运行引擎：Godot `4.7.2.stable.official.ed1daf0bf`。命令：

```powershell
& 'E:/Godot/bin/godot.bat' --headless --path . --quit-after 120 --script res://tests/test_save_file.gd
```

- 红测：先创建测试脚本，生产脚本不存在；实际退出1，输出`FAIL: 独立存档模块存在，首次读取可执行`，无解析错误。
- 首次实现绿测：实际退出0，`SAVE_FILE_CHECKS_PASSED=148`。
- 增加真实Windows主档／备份占用句柄的替换失败验证后：实际退出0，`SAVE_FILE_CHECKS_PASSED=156`，无`ERROR:`、`SCRIPT ERROR`或`Parse Error`。计数包含夹具建立断言，不等同于156个独立用例。
- 生产脚本与测试脚本分别执行`--headless --path . --check-only --script <脚本路径>`，均退出0且无错误输出。
- 测试仅在`user://phase5_test_<进程号>_<微秒>/`建立真实文件，递归清理前校验绝对路径边界，不触碰正式游戏存档。
- 已覆盖首启无档、整体往返与空快照、备份轮换、截断／缺字段／错误类型／非法revision、好备份恢复、损坏主不污染备份、主备都坏、未知版本不降级／不覆盖、调用方语义拒绝、无效候选不覆盖、父路径为文件、目录占用中间路径、真实Windows文件句柄导致替换失败、孤立tmp及中断临时写。

未执行：本子任务未运行全项目回归、import、UI／手感、强制断电、独立进程继续完整探索或发布验证；交由主阶段集成验收。不创建提交、不安装依赖。
