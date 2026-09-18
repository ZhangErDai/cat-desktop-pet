class_name PlayBall
extends Node

## 陪玩控制器。
##
## 负责陪玩的完整流程：生成球、识别点击、推动球、请求 CatMovement 追球，
## 以及判断猫咪是否真正靠近球。球本身的物理滚动仍由 ball.gd 负责。

signal started
signal finished(caught: bool)
signal cancelled(reason: String)
signal status_changed(text: String)

@onready var room: PetRoom = $"../Room"
@onready var collision_rules: RoomCollision = $"../Room/RoomCollision"
@onready var cat: CatBody = $"../Cat"
@onready var movement: CatMovement = $"../Cat/Movement"
@onready var ball: PetBall = $"../Ball"
@onready var camera: Camera2D = $"../Camera2D"
@onready var cat_state: CatState = $"../Cat/State"

var playing: bool = false
var chasing: bool = false
var rng := RandomNumberGenerator.new()
var settings: PetSettings

func _ready() -> void:
	rng.randomize()

func configure_settings(config: PetSettings) -> void:
	settings = config
	print("[桌宠调试] PlayBall 已连接集中配置：catch_distance=%.1f" % _get_catch_distance())

func start_play() -> bool:
	if playing:
		return false
	var spawn := _get_spawn_position()
	ball.place_on_floor(spawn)
	ball.visible = true
	playing = true
	chasing = false
	if cat_state:
		cat_state.set_state(CatState.PLAYING)
	started.emit()
	status_changed.emit("点击地板上的球，猫咪会跑过去追它！")
	print("[桌宠调试] 陪玩开始：球生成位置=%s 猫咪位置=%s" % [ball.global_position, cat.global_position])
	return true

func handle_mouse_click(world_position: Vector2) -> bool:
	if not playing or not ball.visible or not ball.contains_point(world_position):
		return false
	ball.roll_away_from(cat.global_position)
	status_changed.emit("球在地板上滚动，猫咪继续追过去啦！")
	if not chasing:
		chasing = true
		if cat_state:
			cat_state.set_state(CatState.CHASING)
		get_tree().create_timer(0.55).timeout.connect(_request_chase)
	print("[桌宠调试] 陪玩点击球：ball=%s click=%s" % [ball.global_position, world_position])
	print("[桌宠调试] 陪玩追球状态：playing=%s chasing=%s" % [playing, chasing])
	return true

func handle_key(event: InputEventKey) -> bool:
	if not playing or not ball.visible or not event.pressed or event.echo:
		return false
	var key_index := int(event.keycode) - int(KEY_1)
	if key_index < 0 or key_index >= 5:
		return false
	ball.roll_away_from(cat.global_position)
	status_changed.emit("啪！球被推远了，猫咪继续追逐中！")
	print("[桌宠调试] 陪玩快捷键推动球：key=%s" % event.keycode)
	return true

func _request_chase() -> void:
	if not playing or not chasing or not ball.visible:
		print("[桌宠调试] 陪玩追球请求跳过：playing=%s chasing=%s ball_visible=%s" % [playing, chasing, ball.visible])
		return
	if cat.global_position.distance_to(ball.global_position) <= _get_catch_distance():
		print("[桌宠调试] 陪玩追球判定成功：猫咪已经接近球")
		_finish_chase(true)
		return
	var accepted := movement.auto_to(ball.global_position, _on_cat_move_finished)
	if not accepted:
		# 如果猫咪刚完成上一段移动，下一帧再请求，避免丢失追球请求。
		print("[桌宠调试] 陪玩追球请求暂缓：CatMovement 当前正在移动")
		get_tree().create_timer(0.05).timeout.connect(_request_chase)
		return
	print("[桌宠调试] 陪玩追球：猫咪=%s 球=%s" % [cat.global_position, ball.global_position])

func _on_cat_move_finished(_reached: bool) -> void:
	if not playing or not chasing:
		return
	# 无论是到达目标还是被碰撞中断，都重新读取球的当前位置。
	# 这样球继续滚动或猫咪撞到边界后，不会永久停止追球。
	_request_chase()

func _finish_chase(caught: bool) -> void:
	chasing = false
	playing = false
	ball.stop()
	if caught:
		ball.visible = false
		ball.velocity = Vector2.ZERO
		ball.rolling = false
		status_changed.emit("猫咪抓到球啦！心情增加 12 点")
	else:
		status_changed.emit("陪玩结束")
	finished.emit(caught)
	if cat_state:
		cat_state.set_state(CatState.IDLE)

func cancel(reason: String = "被其他动作打断") -> void:
	## 供交互总控调用的强制结束入口。
	if not playing:
		return
	_debug_log("陪玩被强制结束：reason=%s" % reason)
	playing = false
	chasing = false
	ball.stop()
	ball.visible = false
	if cat_state:
		cat_state.set_state(CatState.IDLE)
	cancelled.emit(reason)
	status_changed.emit("陪玩已中断")

func _get_spawn_position() -> Vector2:
	# 第一优先级：猫咪附近，并且位于 FloorWalkableArea 内。
	var near_cat_xs := [cat.position.x + 90.0, cat.position.x - 90.0, cat.position.x]
	for near_x in near_cat_xs:
		var candidate := Vector2(clampf(near_x, 90.0, room.room_size.x - 90.0), room.floor_y)
		if _is_valid_spawn(candidate):
			return candidate

	# 第二优先级：摄像机可见范围内，并且位于 FloorWalkableArea 内。
	var half_view_width := get_viewport().get_visible_rect().size.x * 0.5 / camera.zoom.x
	var margin := ball.radius + 34.0
	var min_x := maxf(90.0, camera.global_position.x - half_view_width + margin)
	var max_x := minf(room.room_size.x - 90.0, camera.global_position.x + half_view_width - margin)
	if max_x >= min_x:
		for i in range(24):
			var visible_candidate := Vector2(rng.randf_range(min_x, max_x), room.floor_y)
			if _is_valid_spawn(visible_candidate):
				return visible_candidate

	# 最后扫描整条 floor_y，保证生成点仍在多边形内。
	for x in range(0, int(room.room_size.x) + 1, 12):
		var safe_candidate := Vector2(float(x), room.floor_y)
		if _is_valid_spawn(safe_candidate):
			return safe_candidate
	var fallback := collision_rules.get_safe_spawn_position(Vector2(room.room_size.x * 0.5, room.floor_y), ball)
	print("[桌宠调试] 陪玩生成点使用碰撞规则备用点：position=%s" % fallback)
	return fallback

func _is_valid_spawn(candidate: Vector2) -> bool:
	return collision_rules.is_spawn_position_valid(ball, candidate)

func _get_catch_distance() -> float:
	return settings.ball_catch_distance if settings else 58.0

func _debug_log(message: String) -> void:
	print("[桌宠调试] [陪玩] %s" % message)
