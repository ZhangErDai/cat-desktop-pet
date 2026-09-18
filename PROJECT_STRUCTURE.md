# 桌面猫咪项目简介与模块职责

本项目是一个 Godot 4 桌面猫咪原型。设计目标是：场景和碰撞尽量在 Godot 编辑器中配置，脚本只负责执行逻辑；不同功能拆分成小模块，通过清晰的调用关系协作，便于学习、调试和后续扩展。

## 当前目录

```text
scenes/
  main/desktop_pet.tscn       # 启动场景，实例化所有模块
  cat/cat.tscn                # 猫咪物理节点、动画节点、碰撞形状和模块节点
  cat/cat_animations.tres     # Godot SpriteFrames 动画资源
  room/room.tscn              # 墙、地板、FloorCollision 和 FloorWalkableArea
  ball/ball.tscn              # 玩具球 CharacterBody2D 和 CollisionShape2D
  ui/settings_menu.tscn       # 设置面板

scripts/
  main/desktop_pet.gd         # 主场景协调器：连接模块、按钮、镜头和输入
  cat/cat_body.gd             # CharacterBody2D 的真实物理移动
  cat/cat_movement.gd         # 猫咪移动封装：走、跑、自动选速度、移动打断
  cat/cat_state.gd            # 猫咪当前状态常量和状态切换信号
  cat/cat_animator.gd         # 只负责把动画资源播放出来
  interactions/play_ball.gd   # 玩球流程：生成球、点击球、追球和抓到球
  interactions/pet_interactions.gd # 吃饭、喝水、玩球、工作、休息的入口和打断
  room/room.gd                # 房间场景协调器和兼容代理
  room/room_collision.gd     # 房间区域判断、生成点判断和物理碰撞预判
  ball/ball.gd                # 球的滚动、摩擦、Godot 碰撞反弹和停止
  core/pet_stats.gd           # 活力、心情、健康、体力和猫币的数据结算
  core/pet_settings.gd        # 全部固定规则和数值的集中配置
  core/pet_state_monitor.gd   # 定时读取猫咪状态；空闲行为扩展点

resources/
  pet_settings.tres           # PetSettings 的 Resource 实例

art/
  cat/                        # 猫咪 SpriteSheet
  room/                       # 墙面、地板和房间素材
  props/                      # 家具素材
```

## 模块职责

### 1. CatState：猫咪状态的唯一来源

`scripts/cat/cat_state.gd` 集中定义：

```text
idle      等待
moving    走路
running   跑步
eating    吃饭
drinking  喝水
playing   陪玩流程
chasing   追球
working   工作
resting   休息
```

其他模块不再各自保存一套状态字符串。状态变化会发出 `state_changed` 信号并打印日志，`PetStateMonitor` 可以定时读取 `current_state`。

### 2. PetSettings：集中保存可调整数值

`resources/pet_settings.tres` 使用 `scripts/core/pet_settings.gd`。猫咪名字、走路速度、跑步速度、追球抓取距离、交互位置、初始状态值、动作结算值和监测间隔都集中在这里。

以后设置界面要开放这些选项时，只修改 `PetSettings` 的字段，再由对应模块读取，不把数值散落在多个脚本里。

### 3. CatMovement 与 CatBody

调用链是：

```text
desktop_pet / PlayBall / PetInteractions
		↓ 请求目标位置
CatMovement
		↓ 选择 walk / run / auto，并检查 RoomCollision 区域
CatBody(CharacterBody2D)
		↓ velocity + move_and_collide()
Godot Physics 碰撞体
```

`CatMovement` 不直接改 `position`。`CatBody` 使用 Godot 的 `CharacterBody2D.move_and_collide()`，所以墙、地板边界和家具碰撞由场景里的 `CollisionShape2D`/`CollisionPolygon2D` 决定。

### 4. PlayBall：只负责玩球流程

玩球过程如下：

1. `PetInteractions` 调用 `PlayBall.start_play()`。
2. `PlayBall` 在猫咪附近、摄像机可见范围或整个可行走区域内选择安全生成点。
3. 用户点击球时，`PlayBall` 调用 `Ball.roll_randomly()`，球在地板平面内随机二维滚动。
4. `PlayBall` 调用 `CatMovement.auto_to(ball.global_position)` 追球；球再次被点击时，调用 `retarget_to()` 更新正在移动中的目标。
5. 球滚动、摩擦和反弹由 `ball.gd` 处理，球不能离开 `RoomCollision`/地板边界。
6. 猫咪距离球达到 `ball_catch_distance` 后，球隐藏并发出 `finished(true)`。

新的吃饭、喝水等交互到来时，`PetInteractions.force_stop_current_action()` 会使玩球停止、球隐藏、移动取消、猫咪回到 `idle`。

### 5. PetInteractions：动作入口和打断总控

`execute(action)` 是吃饭、喝水、陪玩、工作、休息的统一入口。它负责：

- 设置 busy 状态；
- 让 `CatMovement` 把猫咪移动到目标位置；
- 调用 `CatBody` 播放动作动画；
- 调用 `PetStats` 结算数值；
- 通过 `force_stop_current_action()` 结束当前动作并回到等待状态。

它不负责球的滚动，也不负责底层物理碰撞。

### 6. RoomCollision：区域判断和碰撞判断

这里明确分成两类方法：

- 区域判断：`is_inside_walkable_area()`、`get_click_walk_target()`、`get_spawn_position()`、`get_random_walkable_position()`；主要服务于点击目标、猫咪生成和球生成。
- 碰撞判断：`is_spawn_position_valid()`、`would_collide_at()`、`get_collisions_at()`；使用 Godot `PhysicsDirectSpaceState2D` 预判物体放到目标位置时是否会碰撞。

真正移动时仍由 `CatBody` 和 `PetBall` 调用 Godot Physics，不在 RoomCollision 中手动修改物体坐标。

### 7. PetStateMonitor：定时监测扩展点

`PetStateMonitor` 每隔 `PetSettings.monitor_interval` 秒读取猫咪状态，并记录当前是移动、动作、玩球还是空闲。现在空闲时只记录，不执行行为；以后可以在 `_on_timer_timeout()` 的注释位置增加自动散步、休息或状态衰减等功能。

## 一个完整示例：点击球

```text
桌面输入
  → desktop_pet.gd
  → PlayBall.handle_mouse_click()
  → PetBall.roll_randomly()
  → PlayBall._request_chase()
  → CatMovement.auto_to() / retarget_to()
  → CatBody.start_move_to()
  → CharacterBody2D.move_and_collide()
  → 到达球 / 发生碰撞 / 被强制打断
```

每个模块都会使用带模块名的 `[桌宠调试]` 日志，排查时可以根据前缀判断请求经过了哪一层。

## 学习和修改建议

- 想调整猫咪走跑速度：修改 `resources/pet_settings.tres` 对应的 `PetSettings` 属性，或在设置模块中修改同一份资源。
- 想调整房间可走区域：打开 `scenes/room/room.tscn`，编辑 `FloorWalkableArea/CollisionPolygon2D`。
- 想调整真实阻挡：在 `room.tscn` 中编辑 `FloorCollision`、家具 `StaticBody2D` 的碰撞形状。
- 想改变动画帧：编辑 `scenes/cat/cat_animations.tres`，不要把帧数据写进移动脚本。
- 想添加空闲行为：先观察 `CatState` 和 `PetStateMonitor` 的日志，再在监测器中调用已有模块。
