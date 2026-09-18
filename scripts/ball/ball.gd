class_name PetBall
extends CharacterBody2D

## 玩具球控制器。
## 球只在地板上水平运动，碰撞由 CharacterBody2D + CollisionShape2D 处理。

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

func roll_away_from(cat_position: Vector2) -> void:
	# 球沿地板水平滚动，不再在空中漂移。
	# 如果球已经在滚动，继续点击会追加推动力，而不是重置成固定速度。
	var direction: float = sign(position.x - cat_position.x)
	if direction == 0.0:
		direction = 1.0
	if absf(velocity.x) < 8.0 or sign(velocity.x) != direction:
		velocity.x = direction * 330.0
	else:
		velocity.x = clampf(velocity.x + direction * kick_speed, -max_roll_speed, max_roll_speed)
	velocity.y = 0.0
	rolling = true
	visible = true
	print("[桌宠调试] 球受到推动：direction=%s speed=%.1f" % ["左" if direction < 0.0 else "右", absf(velocity.x)])

func contains_point(point: Vector2) -> bool:
	# 鼠标位置由主场景转换为全局坐标，因此这里也使用全局坐标比较。
	return global_position.distance_to(point) <= radius + 12.0

func _physics_process(delta: float) -> void:
	if not rolling:
		return
	# 球保持在地板滚动线；左右墙体和家具碰撞体仍由 Godot 物理引擎处理。
	velocity.y = 0.0
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
		velocity.y = 0.0
		position.y = floor_y
		position.x = clampf(position.x, room_left + radius, room_right - radius)
		print("[桌宠调试] 球发生物理碰撞：collider=%s normal=%s speed=%.1f direction=%s" % [collision.get_collider().name, normal, absf(velocity.x), "左" if velocity.x < 0.0 else "右"])
	velocity.x = move_toward(velocity.x, 0.0, rolling_friction * delta)
	if absf(velocity.x) < 8.0:
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
