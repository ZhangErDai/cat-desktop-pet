# Godot 桌面猫咪

这是一个使用 Godot 4 制作的桌面猫咪互动原型。猫咪可以在房间地板上移动、吃饭、喝水、休息、工作和玩球。

项目的设计原则是：场景、动画帧和碰撞尽量通过 Godot 编辑器配置，脚本只负责执行逻辑；不同功能拆分模块，通过职责调用，方便学习和后续扩展。

## 运行项目

1. 使用 Godot 4.7 或兼容版本打开本目录。
2. 打开 `project.godot`。
3. 按 Godot 的运行项目按钮，或使用快捷键运行主场景。
4. 项目默认启动场景是：

```text
scenes/main/desktop_pet.tscn
```

## 当前功能

- 猫咪使用 Godot `CharacterBody2D` 进行物理移动。
- 猫咪支持走路、跑步和自动选择移动速度。
- 鼠标点击地板可以让猫咪移动。
- 房间通过 `FloorWalkableArea/CollisionPolygon2D` 定义可行走区域。
- 墙体和地板边界通过 Godot 碰撞节点限制移动范围。
- 玩球时球会在镜头内生成。
- 点击球后猫咪会追逐球，追到后球会消失。
- 玩球期间可以通过其他交互打断。
- 吃饭、喝水、玩球、工作和休息都有独立日志。
- 状态面板可以显示猫币和猫咪状态属性。
- 设置面板支持猫咪名字和背景相关设置。

## 目录结构

```text
game-demo/
├── art/                         # 猫咪、房间、家具和界面素材
├── resources/
│   └── pet_settings.tres        # 集中配置资源
├── scenes/
│   ├── main/desktop_pet.tscn    # 项目主场景
│   ├── cat/cat.tscn             # 猫咪场景
│   ├── room/room.tscn           # 房间和碰撞场景
│   ├── ball/ball.tscn           # 玩具球场景
│   └── ui/settings_menu.tscn    # 设置界面
├── scripts/
│   ├── main/desktop_pet.gd      # 主场景协调器
│   ├── cat/                     # 猫咪物理、移动、状态和动画
│   ├── interactions/            # 交互和玩球逻辑
│   ├── room/                    # 房间和碰撞判断
│   ├── ball/                    # 球的移动和反弹
│   ├── core/                    # 状态数据、统一配置和定时监测
│   └── ui/                      # 设置界面逻辑
├── PROJECT_STRUCTURE.md         # 模块职责和学习说明
└── project.godot                # Godot 项目配置
```

## 核心模块

### `CatBody`

文件：`scripts/cat/cat_body.gd`

继承 `CharacterBody2D`，负责调用 Godot 物理移动：

```text
velocity + move_and_collide()
```

它不负责决定猫咪为什么移动，也不负责交互业务。

### `CatMovement`

文件：`scripts/cat/cat_movement.gd`

负责封装猫咪移动：

- 走路；
- 跑步；
- 根据距离自动选择走或跑；
- 调用 `RoomCollision` 检查目标区域；
- 强制停止移动。

### `CatState`

文件：`scripts/cat/cat_state.gd`

统一保存猫咪当前状态，包括：

```text
idle / moving / running / eating / drinking
playing / chasing / working / resting
```

### `PlayBall`

文件：`scripts/interactions/play_ball.gd`

负责完整的玩球流程：

```text
生成球 → 点击球 → 球滚动 → 调用 CatMovement 追球 → 猫咪抓到球
```

球本身的滚动和物理反弹由 `scripts/ball/ball.gd` 负责。

### `PetInteractions`

文件：`scripts/interactions/pet_interactions.gd`

负责吃饭、喝水、陪玩、工作和休息的统一入口，并处理动作打断。

例如新的喝水请求到来时，会：

```text
结束当前动作 → 停止猫咪移动 → 播放喝水动画 → 结算状态数值
```

### `RoomCollision`

文件：`scripts/room/room_collision.gd`

分为两类功能：

- 区域判断：猫咪和球是否在地板可行走区域内；
- 碰撞判断：物体放到目标位置时是否会与 Godot 碰撞体重叠。

真实移动仍由 `CharacterBody2D` 和 Godot Physics 完成。

### `PetSettings`

文件：`scripts/core/pet_settings.gd`

资源：`resources/pet_settings.tres`

集中保存：

- 猫咪名字；
- 走路和跑步速度；
- 追球抓取距离；
- 吃饭、喝水、工作和休息的位置；
- 初始活力、心情、健康、体力和猫币；
- 各种动作的数值结算；
- 状态监测间隔。

以后可以直接在 Godot 检查器中修改资源属性，或者让设置菜单修改同一份配置。

## Godot 编辑器中的常用修改

### 修改猫咪动画帧

打开：

```text
scenes/cat/cat_animations.tres
```

在 SpriteFrames 编辑器中修改动画名称、帧图片和播放速度。移动脚本不会保存动画帧。

### 修改可行走区域

打开：

```text
scenes/room/room.tscn
```

选择：

```text
Room
└── FloorWalkableArea
    └── CollisionPolygon2D
```

编辑多边形边界即可改变猫咪和球允许生成、移动的区域。

### 修改真实碰撞边界

在 `room.tscn` 中编辑：

```text
FloorCollision
├── TopEdge
├── RightEdge
├── BottomEdge
└── LeftEdge
```

这些节点使用 Godot 的 `CollisionShape2D`，负责阻挡猫咪和球。

### 修改猫咪碰撞形状

打开：

```text
scenes/cat/cat.tscn
```

选择：

```text
Cat
└── CollisionShape2D
```

在检查器中调整形状和位置。动画图片大小不会自动改变物理碰撞形状。

## 调试日志

运行游戏后，在 Godot 底部的“输出”面板查看日志。常见日志前缀：

```text
[桌宠调试] [猫咪状态]    # 状态切换
[桌宠调试] [猫咪交互]    # 吃饭、喝水、休息等动作
[桌宠调试] [陪玩]        # 生成球、点击球和追球
[桌宠调试] [房间碰撞]    # 区域和碰撞判断
[桌宠调试] [状态监测]    # 定时读取猫咪状态
```

## 更完整的架构说明

请阅读 [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)，其中包含模块调用链、职责边界和后续扩展建议。
