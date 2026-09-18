class_name PetBall
extends CharacterBody2D

## 玩具球控制器。
## 球只在地板平面内二维运动，碰撞由 CharacterBody2D + CollisionShape2D 处理。

signal stopped

@export var radius: float = 16.0
@export var floor_y: float = 440.0
@export var room_left: float = 24.0
@export var room_right: float = 1776.0
@export var kick_speed: float = 230.0
@export var max_roll_speed: float = 560.0
@export var rolling_friction: float = 90.0
var rolling: bool = false
var ball_rotation: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func configure_room_bounds(left: float, right: float, next_floor_y: float) -> void:
	# 房间场景统一传入边界，球不再依赖脚本里的固定房间尺寸。
	room_left = left
	room_right = right
	floor_y = next_floor_y
	position.x = clampf(position.x, room_left + radius, room_right - radius)
	position.y = floor_y

func place_on_floor(next_position: Vector2) -> void:
	# 生成时就先限制一次，避免球出生在房间外或贴到墙外。
	position = Vector2(clampf(next_position.x, room_left + radius, room_right - radius), floor_y)
	velocity = Vector2.ZERO
	rolling = false
	queue_redraw()

func stop() -> void:
	## 由 PlayBall 在结束或被打断时调用。
	velocity = Vector2.ZERO
	rolling = false
	queue_redraw()

func roll_randomly() -> void:
	# 每次点击随机选择二维方向，球不再只沿左右直线滚动。
	# y 方向代表地板平面上的上下移动，不是离开地面。
	var direction := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.72, 0.72))
	if direction.length_squared() < 0.05:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	if not rolling or velocity.length() < 8.0:
		velocity = direction * 330.0
	else:
		velocity = (velocity + direction * kick_speed).limit_length(max_roll_speed)
	rolling = true
	visible = true
	print("[桌宠调试] 球随机滚动：direction=%s speed=%.1f" % [direction, velocity.length()])

func roll_away_from(_cat_position: Vector2) -> void:
	# 兼容旧调用名；新的玩球逻辑使用 roll_randomly()。
	roll_randomly()

func contains_point(point: Vector2) -> bool:
	# 鼠标位置由主场景转换为全局坐标，因此这里也使用全局坐标比较。
	return global_position.distance_to(point) <= radius + 12.0

func _physics_process(delta: float) -> void:
	if not rolling:
		return
	# 球在地板平面内二维滚动；房间边界由 Godot 物理碰撞体处理。
	ball_rotation += velocity.x * delta * 0.045
	var collision := move_and_collide(velocity * delta)
	if collision:
		# 使用 Godot 提供的碰撞法线计算反射方向。
		# 斜边或角落的法线可能让反射结果几乎没有水平速度，
		# 因此增加水平反向保护，避免球贴在边界上持续重复碰撞。
		var normal := collision.get_normal()
		var incoming_speed := absf(velocity.x)
		var reflected := velocity.bounce(normal) * 0.85
		if absf(reflected.x) < 8.0 or sign(reflected.x) == sign(velocity.x):
			reflected.x = -sign(velocity.x) * maxf(incoming_speed * 0.85, 90.0)
		velocity = reflected
		# 轻微把球推离碰撞面，避免下一帧继续嵌在边界上。
		global_position += normal * 0.5
		position.x = clampf(position.x, room_left + radius, room_right - radius)
		print("[桌宠调试] 球发生物理碰撞：collider=%s normal=%s speed=%.1f velocity=%s" % [collision.get_collider().name, normal, velocity.length(), velocity])
	velocity = velocity.move_toward(Vector2.ZERO, rolling_friction * delta)
	if velocity.length() < 8.0:
		velocity = Vector2.ZERO
		rolling = false
		stopped.emit()
	queue_redraw()

func _draw() -> void:
	# 用带高光的圆形原型图表现滚动，旋转线会让滚动状态清晰可见。
	draw_circle(Vector2(0, 5), radius + 2.0, Color(0.12, 0.08, 0.10, 0.22))
	draw_circle(Vector2.ZERO, radius, Color("#ef7568"))
	draw_circle(Vector2(-5, -6), 4.0, Color("#ffe9a7"))
	var stripe_start: Vector2 = Vector2(cos(ball_rotation) * 8.0, sin(ball_rotation) * 8.0)
	var stripe_end: Vector2 = -stripe_start
	draw_line(stripe_start, stripe_end, Color("#b64e5e"), 3.0, false)
