class_name CatMovement
extends Node

## 猫咪移动封装层。
##
## 这个脚本负责“想移动到哪里、使用走路还是跑步、移动结束后通知谁”。
## CatBody 只负责 CharacterBody2D 的速度和 move_and_collide 物理碰撞。

@onready var body: CatBody = get_parent() as CatBody
@onready var cat_state: CatState = get_parent().get_node_or_null("State") as CatState

var moving: bool = false
var target_position: Vector2
var room_collision: RoomCollision
var settings: PetSettings

const DEFAULT_WALK_SPEED := 230.0
const DEFAULT_RUN_SPEED := 420.0
const DEFAULT_RUN_DISTANCE_THRESHOLD := 260.0

func configure_settings(config: PetSettings) -> void:
	settings = config
	print("[桌宠调试] CatMovement 已连接集中配置：walk=%.1f run=%.1f threshold=%.1f" % [
		_get_walk_speed(), _get_run_speed(), _get_run_threshold()
	])

func configure_collision(rules: RoomCollision) -> void:
	room_collision = rules
	print("[桌宠调试] CatMovement 已连接房间碰撞判断：connected=%s" % (room_collision != null))

func move_to(target: Vector2, requested_mode: String = "walk", on_finished: Callable = Callable()) -> bool:
	# 一次只接受一个移动请求，避免点击移动和追球同时控制猫咪。
	if moving or body == null:
		return false
	if room_collision and not room_collision.is_inside_walkable_area(target):
		print("[桌宠调试] CatMovement 拒绝目标：目标不在房间可行走区域 target=%s" % target)
		return false
	moving = true
	target_position = target
	print("[桌宠调试] CatMovement 请求移动：target=%s mode=%s" % [target, requested_mode])
	var distance := body.global_position.distance_to(target)
	var actual_mode := requested_mode
	if requested_mode == "auto":
		actual_mode = "run" if distance >= _get_run_threshold() else "walk"
	if cat_state:
		cat_state.set_state(CatState.RUNNING if actual_mode == "run" else CatState.MOVING)
	body.start_move_to(target, requested_mode, _get_walk_speed(), _get_run_speed(), _get_run_threshold(), func(reached: bool):
		moving = false
		if cat_state:
			cat_state.set_state(CatState.IDLE)
		print("[桌宠调试] CatMovement 移动结束：reached=%s position=%s" % [reached, body.global_position])
		if on_finished.is_valid():
			on_finished.call(reached)
	)
	return true

func is_moving() -> bool:
	return moving

func walk_to(target: Vector2, on_finished: Callable = Callable()) -> bool:
	return move_to(target, "walk", on_finished)

func run_to(target: Vector2, on_finished: Callable = Callable()) -> bool:
	return move_to(target, "run", on_finished)

func auto_to(target: Vector2, on_finished: Callable = Callable()) -> bool:
	return move_to(target, "auto", on_finished)

func cancel_move() -> void:
	## 统一的移动打断入口，业务模块不直接操作 CatBody 的内部字段。
	if not moving:
		return
	print("[桌宠调试] CatMovement 请求强制停止")
	body.cancel_move()
	moving = false
	if cat_state:
		cat_state.set_state(CatState.IDLE)

func _get_walk_speed() -> float:
	return settings.walk_speed if settings else DEFAULT_WALK_SPEED

func _get_run_speed() -> float:
	return settings.run_speed if settings else DEFAULT_RUN_SPEED

func _get_run_threshold() -> float:
	return settings.run_distance_threshold if settings else DEFAULT_RUN_DISTANCE_THRESHOLD
