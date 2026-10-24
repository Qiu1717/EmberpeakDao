# 阶段5跨进程持久化与失败事务整合测试

日期：2026-10-24。测试脚本：`tests/test_phase5_persistence.gd`。使用真实工程Autoload、真实奖励、SaveFile与完整语义校验；未改生产代码、runner或GDD。本记录仅代表列出的无窗口用例，不代替阶段5整体验收。

## 隔离与运行

脚本必须接收环境变量`EMBERPEAK_SAVE_PATH`，且值必须为`user://phase5_persistence_<本轮唯一ID>/save.json`，含`..`或不符合前后缀的路径会退出1。未提供变量时不执行测试动作，不会创建或覆盖正式游戏档。Autoload的常规初始化发生在脚本动作之前，因此回归调用方必须在启动Godot之前设置变量。

`--write`、`--read`和`--after-death`必须使用同一完整私有路径，依次各启动一次Godot进程。`--failures`使用另一个全新私有目录。进程间期望值保存于同测试目录的`expectations.json`，包括上个进程PID、完整档案、探索状态、装备实例及候选；用例检查三个PID不同。

```powershell
$testId = [guid]::NewGuid().ToString('N')
$env:EMBERPEAK_SAVE_PATH = "user://phase5_persistence_$testId/save.json"
foreach ($mode in @('--write', '--read', '--after-death')) {
    & 'E:/Godot/bin/godot.bat' --headless --path . --max-fps 120 --quit-after 5000 --script res://tests/test_phase5_persistence.gd -- $mode
    if ($LASTEXITCODE -ne 0) { throw "持久化用例失败：$mode" }
}
$env:EMBERPEAK_SAVE_PATH = "user://phase5_persistence_${testId}_failures/save.json"
& 'E:/Godot/bin/godot.bat' --headless --path . --max-fps 120 --quit-after 5000 --script res://tests/test_phase5_persistence.gd -- --failures
```

进程退出码之外，仍须扫描`ERROR:`、`SCRIPT ERROR`、`Parse Error`并确认对应成功标记。测试保留独立档案与期望值供检查；不删除、迁移或覆盖用户已有存档。

## 实际结果

引擎：`4.7.2.stable.official.ed1daf0bf`。以下模式均实际退出0，无错误输出；共77项断言，含环境与夹具断言。

| 模式 | 实际进程PID | 断言数 | 成功标记 | 日志 |
| --- | --- | --- | --- | --- |
| write | 8320 | 18 | PERSIST_WRITE_OK | builds/phase5/persistence-write.log |
| read | 28904 | 21 | PERSIST_READ_OK | builds/phase5/persistence-read.log |
| after-death | 31204 | 11 | PERSIST_AFTER_DEATH_OK | builds/phase5/persistence-after-death.log |
| failures | 3860 | 27 | PERSIST_FAILURES_OK | builds/phase5/persistence-failures.log |

三进程连续路径：`user://phase5_persistence_20261024_1792818343461/save.json`。失败事务独立路径：`user://phase5_persistence_20261024_1792818248865_failures/save.json`。

### 跨进程存取与死亡

- 写入进程从零文件首启。真实Boss奖励120灵气触发40与60连续消耗，炼气后期保留20；祭坛记录20灵气、80灵石与一份筑基灵髓。
- 装备真实掉落的破山长枪，不登记蓝图；缓存未选三选一，并选择另一强化。额外领取尸兵奖励，保存但不记录新增10灵气与5灵石。
- 新进程由Session读取磁盘，经App继续原run_id与祭坛，恢复访问、清场、完整装备、材料、强化及完整随机流状态。同来源候选不重抽、不推进随机流；重放已领奖来源不增加任何资源或实物。
- 真实100000点受击触发死亡。清除未记录资源、材料、强化和装备实物，丢失摘要匹配实际余额；永久后期、20灵气、80灵石与已记录材料保留，磁盘run_snapshot为null。
- 第三个进程确认死亡仍不可继续。新探索继承后期属性（108生命、1.04伤害倍率），只给基础剑；未登记蓝图的长枪实物不免费继承，旧局奖励及强化不继承。

### 保存失败与重试

- 先在真实私有路径建立有效快照，再令Session.store指向同私有目录下的真实目录目标；无mock或测试钩子。
- 奖励达到120灵气门槛，保存失败不发布候选境界、不增加属性、不扣资源，磁盘仍是失败前完整事务；Session与探索反馈明确失败。
- 恢复原存储并重试，成功成长至后期剩20；再次结算不重复扣款，也不产生多余成功提交。
- 祭坛记录后前往真实图中的商店，消费20已记录灵石。实际重新读档余额为60、商品售罄；再次购买拒绝且不二次扣款。
- 保存活跃快照后再次注入真实写失败，以真实受击死亡。局内内容立即清理；pending_death为true，继续不可用，App新局和返回菜单均被阻止。磁盘旧快照仍存在，因此反馈明确死亡保存尚未成功。
- 恢复存储并调用正式死亡重试，成功将磁盘快照置null；保留已扣消费及永久状态，然后才允许开启干净新局。

## 调试证据与边界

首次read执行出现四项深字典相等断言失败，日志保留于`builds/phase5/persistence-read-fixture-type-red.log`。来源是JSON夹具数字为float、生产恢复的计数为int，Godot深字典相等区分该类型；双方经相同JSON往返后，重新以全新路径运行write/read/after-death，全部通过。未因此修改生产数据或降低余额、材料、RNG字符串、装备实例与候选内容的检查。

本测试为了隔离战斗时长，通过真实奖励接口发放测试奖励，并调用现有房间装载接口切到祭坛／商店；不证明自然通关、路线可达性或战斗平衡。商店扣费验证包含同进程真实重新读档，未另用独立进程复现该单一消费步骤。未执行强制中断／断电、画面手感、Windows发布或全项目回归；本任务未运行import或安装依赖。

## 根代理整合追加验证

最终独立审查发现死亡写失败后关闭面板会失去唯一重试入口。根代理在close统一入口增加pending_death门禁，并隐藏关闭按钮；追加直接关闭与真实Esc两项红绿回归，故障恢复后通过RetryDeath按钮回调完成持久化。当前failures为29项，write/read/after-death仍为18/21/11，总计79项。窗口故障流程另实际29项通过，日志death-panel-window.log。全部最终结果以PHASE_5_REPORT.md和统一runner证据为准；以上77项为子任务初次交付记录。
