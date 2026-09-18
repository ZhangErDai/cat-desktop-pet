class_name CatBody
extends CharacterBody2D

## 猫咪物理移动控制器。
##
## CharacterBody2D 负责真实的碰撞移动，CatAnimator 只负责动画帧。
## 这样墙体、家具和上下边界由 Godot Physics 处理，动画不会影响碰撞判断。

@export var stop_distance: float = 5.0

@onready var animator: CatAnimator = $Visual

var target_position: Vector2
var moving: bool = false
var movement_speed: float = 0.0
var movement_direction: String = "front"
var movement_callback: Callable

## 提供给主场景读取的动画名称，方便启动日志和调试器观察。
var animation: String:
	get:
		return animator.animation if animator else ""

func _ready() -> void:
	print("[桌宠调试] 猫咪物理节点已加载：CharacterBody2D collision_shape=%s mask=%d" % [
		get_node_or_null("CollisionShape2D") != null,
		collision_mask,
	])

func start_move_to(target: Vector2, requested_mode: String, walk_speed: float, run_speed: float, run_threshold: float, on_arrived: Callable) -> void:
	# 开始一次物理移动，真正的位置变化在 _physics_process 中通过 move_and_collide 完成。
	target_position = target
	movement_callback = on_arrived
	var distance := global_position.distance_to(target_position)
	var actual_mode := requested_mode
	if requested_mode == "auto":
		# 自动模式下，超过主场景设定的距离才跑步；短距离继续走路。
		actual_mode = "run" if distance >= run_threshold else "walk"
	movement_speed = run_speed if actual_mode == "run" else walk_speed
	movement_direction = _get_animation_direction(target_position - global_position)
	if actual_mode == "run":
		animator.play_run(movement_direction)
	else:
		animator.play_walk(movement_direction)
	moving = true
	print("[桌宠调试] 猫咪物理移动：target=%s mode=%s speed=%.1f direction=%s" % [target_position, actual_mode, movement_speed, movement_direction])

func _physics_process(delta: float) -> void:
	if not moving:
		velocity = Vector2.ZERO
		return
	var offset := target_position - global_position
	if offset.length() <= stop_distance:
		_finish_movement(true)
		return
	velocity = offset.normalized() * movement_speed
	var collision := move_and_collide(velocity * delta)
	if collision:
		# Godot 已经把 CharacterBody2D 移动到碰撞点，不再穿过墙或家具。
		print("[桌宠调试] 猫咪发生物理碰撞：collider=%s normal=%s" % [collision.get_collider().name, collision.get_normal()])
		_finish_movement(false)
		return
	if global_position.distance_to(target_position) <= stop_distance:
		_finish_movement(true)

func cancel_move() -> void:
	## 外部动作需要打断猫咪时调用，仍然经过统一的结束流程。
	if not moving:
		return
	print("[桌宠调试] 猫咪物理移动被外部强制停止：position=%s target=%s" % [global_position, target_position])
	_finish_movement(false)

func _finish_movement(reached: bool) -> void:
	moving = false
	velocity = Vector2.ZERO
	animator.play_idle()
	if reached:
		print("[桌宠调试] [移动完成] 猫咪到达目标：position=%s target=%s" % [global_position, target_position])
	else:
		print("[桌宠调试] [移动中断] 猫咪被碰撞阻挡：position=%s target=%s" % [global_position, target_position])
	if movement_callback.is_valid():
		movement_callback.call(reached)
	movement_callback = Callable()

func _get_animation_direction(offset: Vector2) -> String:
	# 4 方向动画中，水平移动优先显示左右，垂直移动显示前后。
	if absf(offset.x) >= absf(offset.y):
		return "left" if offset.x < 0.0 else "right"
	return "back" if offset.y < 0.0 else "front"

func play_idle() -> void:
	animator.play_idle()

func play_eat() -> void:
	animator.play_eat()

func play_drink() -> void:
	animator.play_drink()

func play_bed_action() -> void:
	animator.play_bed_action()
