# 阶段5实施计划：境界、装备与本地存档

日期：2026-10-24。设计基准：完整 GAME_DEVELOPMENT_PLAN.md；实施基线6417be9。当前状态：用户已回复确认全部三个问题，按以下范围正式执行，测试数值不冒充最终平衡。

## 目标、边界和待确认

- 已定永久／局内混合模型：境界、已记录且未消耗余额、解锁与蓝图属于永久档案；未记录资源、掉落实物、强化与探索属于可继续的局内快照，死亡清除后者。
- 已确认A：保留原规则，小境界满灵气自动突破，只有跨大境界必须祭坛手动确认。
- 已确认B：授权首图40/60/80/100门槛、100/104/108/112生命、1/1.02/1.04/1.06倍率作为待平衡配置；筑基初期115生命／1.08倍率沿用GDD，首图配置到此，不虚构后续区域成长。
- 已确认C：允许把长枪具体时长／距离／破甲量、真气恢复等缺项补为待平衡测试参数并验证实际效果。既定武器伤害、装备属性、品阶和境界要求不变。
- 沿用Godot4.7.2、GDScript和原手工房间；不安装依赖、不制作第二地图、不批量改美术。

## 文件与模块契约

1. `scripts/save/save_file.gd`：独立文件存取，版本化完整封套，临时写入／校验／原子替换／有效备份，错误返回中文message，不擅自清空或覆盖未知版本。`new(path, validator=Callable())`；`load_save() -> Dictionary` 返回accepted/message/status/data，status为missing/loaded/recovered/corrupt/incompatible；`commit(data:Dictionary) -> Dictionary`，失败不替换有效档案。测试仅使用独立测试路径。
2. `scripts/inventory/equipment_catalog.gd`、`resources/equipment/first_map_equipment.tres`：只配置GDD实际物品；`items`字典。物品含name、slot、tier（0..4）、required_realm（0..4）、rarity、effects、icon_path，武器含damage（三段数组）。不把品阶和稀有度混为一谈。缺失动作参数在确认后另接武器配置。
3. `scripts/inventory/inventory_state.gd`：实例实物与槽位；`new(catalog=null)`，`add_item(record)`、`equip(instance_id, realm)`、`unequip(slot)`返回accepted/message；`modifiers()`汇总真实装备属性；`to_dict()`和`restore(data)`校验实例／槽位，重复装卸不可叠加。基础解锁武器与掉落实物区分，死亡只保留解锁，实物清空。
4. 确认后新增 `scripts/progression/realm_rules.gd`／`profile_state.gd`／相关Resource：唯一丹田灵气账本、大小境界条件、消耗和属性。所有持久成长先验证候选事务保存，再发布为有效状态。
5. `scripts/managers/session.gd`：协调永久档案、探索快照和完整事务，不复制装备／境界公式。新局与继续分开；存档不可读时提示并保留原件，不自动覆盖；死亡使旧探索不可继续。
6. 现有 `run_state.gd`增加快照序列化／校验：完整RNG状态用十进制字符串避免JSON浮点精度损失，保存来源、候选、事件、库存、装备和剩余资源。路线保存清场、当前房、访问节点、生命与安全恢复点，不从命中帧恢复。
7. 增量修改App、主菜单、RogueRoute、Player和RunInterface：真实继续按钮、祭坛记录／保存／突破、背包栏位／详情／装卸、境界HUD、失败反馈，统一重算基础＋境界＋装备＋临时加成。

## 执行与验收

- [x] 只读核对现有工程、GDD、技术／美术／工作流／测试文档，记录缺项与冲突。
- [x] 存档文件与装备实例模块分别先跑红测，再做最小实现与真实文件／状态绿测。
- [x] 用户确定成长规则后创建生效境界资源，覆盖灵气不足、材料缺失、非祭坛、足量／溢出／消耗与保存失败不返还等条件。
- [x] 接入原有探索，验证所有奖励渠道的灵气、材料、装备均进入一致状态；已保存继续不能重抽候选或重领来源。
- [x] 实际验证低境界拒绝高阶装备、符合条件突破、装备真实属性／两武器不同判定、死亡清强化保境界、重启恢复以及异常存档不崩溃。
- [x] 独立进程验证正常存取、首次无档、损坏／不兼容／写失败；测试不碰用户正式档。
- [x] 运行本轮及旧回归，窗口验收、独立审查，更新PHASE_5_REPORT.md与运行文档；有限版本提交，停止等待阶段6。

本轮指定范围已验收，实际结果见PHASE_5_REPORT.md。更高阶境界、自然通关、正式美术和Windows发布等未执行项仍明确未验证。
