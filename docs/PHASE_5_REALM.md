# 阶段5首图境界账本

日期：2026-10-24。范围：独立境界 Resource、永久档案账本及回归测试；主程事务、死亡和实际文件存取由 Session 协调。本模块不安装依赖、不生成第二地图成长、不读写用户存档。

## 本轮配置与授权

用户已确认沿用小境界灵气满后自动突破，大境界在祭坛手动确认；允许下表作为待平衡测试配置。门槛是本阶段的消耗量，不是累计经验等级。

| 境界 | 阶段灵气消耗 | 最大生命 | 攻击倍率 | 真气上限 | 突破材料 |
|---|---:|---:|---:|---:|---|
| 炼气初期 | 40 | 100 | 1.00 | 60 | 无 |
| 炼气中期 | 60 | 104 | 1.02 | 64 | 无 |
| 炼气后期 | 80 | 108 | 1.04 | 68 | 无 |
| 炼气圆满 | 100 | 112 | 1.06 | 72 | 筑基灵髓一份 |
| 筑基初期 | 0（首图到此停止） | 115 | 1.08 | 75 | 无后继配置 |

炼气初期60、筑基初期75真气沿用GDD第10节；中间小境界64／68／72属于本轮允许补充的待平衡参数。真气仅为战斗属性，不加入丹田灵气账本。筑基初期门槛0只表达首图暂无后继，不表示完整版境界封顶或化神封顶规则。成长门槛与小境界属性仍需后续平衡验证。

## 实际接口

- `RealmRules.current(realm, subrealm)`、`next(realm, subrealm)`：按境界编号返回完整阶段字典副本；未知、无效或未配置后继返回空字典。`realm` 为0炼气／1筑基，`subrealm` 为0初期至3圆满。
- `ProfileState.new(rules=null)`：默认加载首图配置。保存字段为 `realm`、`subrealm`、`banked_spirit`、`banked_stones`、`banked_materials`、`weapon_unlocks`、`blueprints`、`boss_kills`。
- `advance_minor(pending)`：返回 `accepted/pending/breakthroughs`，足量可连升至圆满；优先扣未记录灵气，再扣已记录灵气；突破名称为中文。不会跨大境界。
- `major_breakthrough(pending, pending_materials, at_altar)`：返回 `accepted/message/pending/materials`；依次验证合法资源、祭坛、圆满、后继配置、灵气和材料。成功扣阶段灵气与一份材料，材料也优先扣未记录部分。失败不改永久对象与入参。
- `record_resources(spirit, stones, materials)`：整体校验后转入已记录余额，返回布尔值，不额外执行突破。调用方须在同一成功事务中清除对应局内余额。
- `stats()`：返回当前配置副本；`to_dict()`：返回永久档案副本；`restore(data)`：全部校验通过后才替换本对象，失败不污染原状态。

上述成功方法会修改接收对象。Session 必须先对候选档案副本调用方法，保存完整永久档案和局内快照成功后再替换活跃对象；本模块不把内存方法成功宣称为写盘成功。

恢复接受JSON解析产生的有限、非负、无小数浮点数，规范化为整数；拒绝布尔、字符串、小数、负数、无穷和缺失字段。材料ID来自现有阶段4 Resource中的五种真实材料；武器解锁仅青锋旧剑／破山长枪。蓝图ID限定首图装备目录六项：`qing_feng`、`po_shan`、`qing_bu`、`can_jian`、`hui_ling`、`xuan_wen`；替劫符沿用局内消耗机制，不冒充穿戴蓝图。Boss进度仅允许首图真实Boss `mountain_general`。列表拒绝重复ID。

## 实际验证

运行环境：Godot 4.7.2 stable。命令：`E:\Godot\bin\godot.bat --headless --path . --script res://tests/test_progression.gd --quit-after 120`。

- 初始红测：目标账本未实现时，退出码1，明确报告“FAIL: 永久成长账本可执行”，无解析错误。
- 实现后绿测：`PROGRESSION_CHECKS_PASSED=78`，退出码0，无 `ERROR`／`SCRIPT ERROR`／`Parse Error`。
- 账本消费顺序敏感性核验：临时反转消费顺序后同一测试退出1，准确触发三个业务断言；已立即恢复正确实现，最终再次78项全部通过、退出0。
- `realm_rules.gd` 和 `profile_state.gd` 的 `--check-only` 均退出0，无解析错误。

已覆盖灵气不足、40+60+80连升、圆满不自动跨境、溢出、30已记录+25未记录消耗40后只剩15永久灵气、恢复不返还、记录后消费、祭坛／材料条件、优先消费两种账本、首图停止、未知配置、档案类型与ID校验、恢复失败不污染及返回值隔离。

未执行：主程保存失败事务、实际死亡后重开、跨进程游戏继续、窗口画面与手感、全套项目回归、Windows导出。这些由阶段5整合验证，不以独立账本测试冒充已通过。

## 完整快照语义边界

`scripts/save/snapshot_codec.gd` 提供 `static validate(data: Dictionary) -> bool`，校验版本1完整封套及其ProfileState、RunState、InventoryState。`run_snapshot=null`表示没有活跃探索；非空时必须具备run、inventory、current_id、visited、cleared_rooms、upgrade_pending、health、qi、enemies。

校验重建seed对应的原图，拒绝未知节点、非true标记、未访问当前房、未访问已清房及非法待选来源。待选必须属于已清战斗／精英／Boss房、有非空缓存候选且尚未领取。生命上限使用真实境界、穿戴装备和局内强化合计；真气上限使用境界和装备合计。每份掉落实物必须与库存中的同实例记录完全一致，额外库存只允许已解锁基础武器。

敌人生命限值取当前手工房间的实际 `enemy_data`，离树实例化读取后立即释放，不执行入场或死亡事件。未清房必须包含每个真实敌人源；已清房允许空敌人表；死亡0生命必须有相应已领敌人奖励标识。无效数据仅返回false，不写文件或发布恢复对象，不修改输入。

实际命令：`E:\Godot\bin\godot.bat --headless --path . --script res://tests/test_snapshot_codec.gd --quit-after 120`。初始模块缺失红测退出1；空候选仍挂待选标记的业务用例也先失败，再加入对应拒绝条件。最终 `SNAPSHOT_CODEC_CHECKS_PASSED=82`、退出0，无ERROR；校验器 `--check-only` 退出0。

覆盖真实入口／奖励实物、JSON往返、永久档案无探索、嵌套类型损坏、缺字段、未知节点、flags子集、非法生命真气、RNG字符串越界、境界不足的已穿装备、缺失或冒名实物、真实道袍与强化生命叠加、敌人源及死亡已领关系、缓存待选恢复。快照关系并不证明实际文件存取、界面继续或场景安全点恢复已验收，仍由Session整合验证。

当前RunState恢复要求材料数量为正数；Session接收突破返回的剩余材料时须清理0键，避免把已消费空余额误当成坏快照。地图flags应使用字符串下标保存；Godot字典点号新建键可能产生StringName，不能直接冒充JSON字符串键。

## 护甲与真实战斗继续回归

快照支持可选 `enemy_armor` 字典，键只能是当前房真实敌人源；值必须为有限非负数字且不超过对应 `EnemyData.armor_points`。坏类型、负数、越界、无穷、NaN与异房来源仅返回false。缺少该字段保留旧快照兼容；新捕获快照记录真实剩余护甲。独立测试先证实原实现错误接受11类坏护甲，再实现拒绝条件；最终 `SNAPSHOT_CODEC_CHECKS_PASSED=96`、退出0，无ERROR，codec语法检查退出0。合法裂甲山魈120生命、0护甲及55.5剩余护甲通过JSON往返校验。

新增 `tests/test_resume_combat.gd`，运行前为该进程设置唯一 `EMBERPEAK_SAVE_PATH=user://phase5_resume_combat_<timestamp>.json`，测试会验证该私有路径初始不存在，避免碰正式游戏存档。实际无窗口运行15项全部通过，退出0、无ERROR：

- 通过App真实新局与入口连接进入近战房，真实伤害杀死第一敌人、另一敌人剩55生命；额外奖励触发自动小境界保存，再实际返回菜单和继续。
- 继续只恢复剩余敌人，55生命准确；玩家保持已保存77生命和12.5真气，不额外治疗；种子、掉落与候选RNG、缓存候选均准确恢复；已死来源不能再领奖。
- 使用明确的安全点夹具挂载真实精英房与Boss房，通过完整存档事务和菜单继续，分别验证精英120生命／0护甲／第二阶段，以及Boss500生命／第二阶段；恢复直接设置状态，不重算护甲减伤或触发Boss入场受击拒绝。

该回归暂停角色和敌人物理以隔离战斗时序，精英和Boss采用状态夹具；不等同自然通关、战斗手感、窗口画面或完整发布验收。
