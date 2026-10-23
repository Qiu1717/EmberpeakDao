# 角色动作帧运行约定

本轮表现接入读取现有角色状态，不更改移动速度、生命、伤害、攻击判定、闪避无敌、AI阶段或掉落结算。图集是少量独立关键姿势；单姿势的待机、跳跃、闪避等不代表完整正式动画。

## 文件与数据

- `scripts/art/actor_frame_visual.gd` 读取 `assets/animations/<actor>/manifest.json`，构建真正的 `AtlasTexture` 切片；不播放整张图集。
- `player_animation_visual.gd` 使用主角原有 `Artwork` 精灵，控制节点为 `ArtworkController`。
- `enemy_animation_visual.gd` 挂载在敌人原有 `Visual` 节点下。已有山魈继续使用 `shan_xiao_visual.gd` 和原独立帧。

manifest包含整图 `texture`、源图 `canvas`（也支持 `source_canvas`）、`native_facing`、待机源轮廓高度 `reference_height`、步距 `stride_distance`、`poses` 和 `clips`。每个pose含源图坐标 `region:[x,y,w,h]` 与切片局部脚底 `pivot:[x,y]`。clip为 `{pose,duration}` 数组。

生成图集并非严格等格。尸兵末行、游魂各行、精英行界和Boss局部武器按实际透明间隙设置可变region，不能改回简单hframes/vframes等分；PNG保持工具输出原字节。qa_pixels.json记录各选用区域的alpha轮廓、边距、像素哈希和整图哈希，辉光碎点与细节漂移仍是候选美术限制。

不同源姿势可能面向相反方向。pose可提供 `native_facing` 覆盖整图默认值；播放器在每次选帧后读取该值，将源朝向校准为角色真实 `facing`。这项校准只影响精灵镜像，不改变攻击或移动方向。

Godot可能缩小导入纹理。播放器分别计算横纵导入比例，换算切片与脚底，并以同一源轮廓比例显示所有姿势：主角56世界像素，敌人为既有 `body_size.y`。出剑、前倾、倒下时保留源姿势形状，不逐帧拉高至碰撞高度。左右朝向由 `sprite.scale.x` 表达；`Visual.scale` 保持默认值。

## 状态映射

主角移动按实际水平位移累计步距切换 `run`。攻击前摇使用 `attack_windup`，有效窗口按连击序号使用 `attack_1` 至 `attack_3`，之后使用 `attack_recover`；三个窗口完全读取现有stats。跳跃、闪避、受击、死亡分别读取真实状态，死亡使用独立表现时钟，因为既有死亡逻辑不增加 `action_time`。表现时钟随游戏暂停冻结。

敌人移动按实际步距切换；前摇、有效、收招分别读取 `TELEGRAPH`、`ATTACK`、`RECOVERY` 与AI时钟。普通敌人为 `telegraph/attack/recovery`，冲撞与砸地为 `alt_` 前缀。Boss按攻击ID选择 `slash_`、`charge_`、`leap_`、`wave_`，连续重斩在每次既有burst窗口重复slash；跳跃落地收招使用 `slam_recovery`。Boss转阶段使用 `phase`。受击与死亡按既有持续时间缩放clip，最后一帧保持至实体原有销毁时间。

专项检查可读取 `sprite`、`manifest`、`pivot`（导入后的局部像素）、`native_facing`、`animation_name`、`pose_name`、`frame_index`。`sync_pose()`仅根据真实状态重新选帧，不推进战斗逻辑。

## 验证边界

`tests/test_actor_animation.gd` 检查移动切片变化、三段攻击窗口、特殊状态、逐帧统一比例、左右脚底、敌人每种攻击的三个阶段、Boss转阶段与两姿势死亡。`tests/test_player_art.gd` 保留20项三入口检查，覆盖100生命、24×56碰撞、脚底、暂停、受击、死亡与重开。

语法检查不证明素材姿势有效，headless测试不证明动作可读或画面质量。素材像素、切片边界、实际尺寸与游戏截图由集成验收另行核对；实际执行结果记录在本轮交付报告中。
