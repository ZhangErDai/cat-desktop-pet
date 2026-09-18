class_name CatTail
extends Node2D

## 独立的尾巴动画。
##
## 尾巴不再完全依赖身体贴图：移动时会根据方向和步伐左右摆动，
## 停下时会缓慢回弹，形成“跟随身体惯性”的效果。

var direction: String = "front"
var is_walking: bool = false
var motion_time: float = 0.0
var tail_strength: float = 1.0

func set_motion(next_direction: String, walking: bool) -> void:
	direction = next_direction
	is_walking = walking
	queue_redraw()

func _process(delta: float) -> void:
	motion_time += delta
	queue_redraw()

func _draw() -> void:
	# 这里使用多段粗线模拟像素尾巴，后续可以替换成独立尾巴 SpriteSheet。
	var side := -1.0 if direction == "left" else 1.0
	var walk_sway := sin(motion_time * 12.0) if is_walking else sin(motion_time * 2.2) * 0.25
	var lift := sin(motion_time * 6.0 + 0.8) * 4.0
	var points := PackedVector2Array()
	if direction == "front" or direction == "back":
		# 正面/背面尾巴在身体后方上下摆动，同时左右偏移。
		# 坐标按 318×309 的原图像素计算，父节点会统一缩放到桌宠大小。
		points.append(Vector2(0, -8))
		points.append(Vector2(walk_sway * 18.0, -52 + lift * 0.2))
		points.append(Vector2(-walk_sway * 22.0, -104 + lift * 0.45))
		points.append(Vector2(walk_sway * 15.0, -145 + lift))
	else:
		# 侧面尾巴从后腿位置伸出，摆动幅度更大。
		points.append(Vector2(-side * 76.0, -4))
		points.append(Vector2(-side * (118.0 + walk_sway * 18.0), -48 + lift * 0.2))
		points.append(Vector2(-side * (138.0 - walk_sway * 22.0), -99 + lift * 0.5))
		points.append(Vector2(-side * (108.0 + walk_sway * 16.0), -145 + lift))
	if points.size() < 2:
		return
	# 深色描边 + 橘色主体 + 高光，保持与猫咪像素素材一致。
	draw_polyline(points, Color("#3a2630"), 18.0, false)
	draw_polyline(points, Color("#d66d2f"), 13.0, false)
	for i in range(1, points.size()):
		if i % 2 == 0:
			draw_line(points[i - 1], points[i], Color("#f3a24d"), 4.0, false)
