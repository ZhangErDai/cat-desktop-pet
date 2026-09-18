class_name RoomCollision
extends Node

## 房间区域与碰撞判断模块。
##
## 区域判断：只根据 FloorWalkableArea/CollisionPolygon2D 判断点是否在房间可行走区域。
## 碰撞判断：使用 Godot PhysicsDirectSpaceState2D 预判移动物体的碰撞。
## 真正移动时，仍由 CatBody、PetBall 调用 move_and_collide() 处理碰撞响应。

const DEBUG_LOGS := true

var room_size := Vector2(2450.0, 820.0)
var floor_y: float = 700.0
var walkable_top: float = 610.0
var walkable_bottom: float = 748.0

func configure(next_room_size: Vector2, next_floor_y: float, next_walkable_top: float, next_walkable_bottom: float) -> void:
	room_size = next_room_size
	floor_y = next_floor_y
	walkable_top = next_walkable_top
	walkable_bottom = next_walkable_bottom
	_debug_log("模块配置完成：room_size=%s floor_y=%.1f walkable_y=%.1f～%.1f" % [room_size, floor_y, walkable_top, walkable_bottom])

# -----------------------------------------------------------------------------
# 区域判断：负责地板区域、物体生成、动物生成
# -----------------------------------------------------------------------------

func is_inside_walkable_area(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _get_walkable_polygon())

func get_nearest_walkable_position(point: Vector2) -> Vector2:
	if is_inside_walkable_area(point):
		return point

	var polygon := _get_walkable_polygon()
	var nearest := polygon[0]
	var nearest_distance := INF
	for i in range(polygon.size()):
		var start := polygon[i]
		var end := polygon[(i + 1) % polygon.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(point, start, end)
		var distance := point.distance_squared_to(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	_debug_log("区域吸附：输入=%s 最近可行走点=%s" % [point, nearest])
	return nearest

func get_click_walk_target(click_position: Vector2) -> Vector2:
	var target := get_nearest_walkable_position(click_position)
	_debug_log("点击区域判断：click=%s target=%s inside=%s" % [click_position, target, is_inside_walkable_area(click_position)])
	return target

func get_spawn_position(preferred: Vector2, moving_body: CollisionObject2D = null) -> Vector2:
	var region_position := get_nearest_walkable_position(preferred)
	if moving_body == null or is_spawn_position_valid(moving_body, region_position):
		_debug_log("生成位置通过：preferred=%s position=%s body=%s" % [preferred, region_position, moving_body != null])
		return region_position

	# 优先在首选位置附近搜索，避免物体生成在房间另一侧。
	for distance in [48.0, 96.0, 144.0, 192.0]:
		for direction in [-1.0, 1.0]:
			var candidate := get_nearest_walkable_position(region_position + Vector2(distance * direction, 0.0))
			if is_spawn_position_valid(moving_body, candidate):
				_debug_log("生成位置避开碰撞体：preferred=%s position=%s" % [preferred, candidate])
				return candidate

	_debug_log("生成位置未找到完全安全点，使用区域边界点：position=%s" % region_position)
	return region_position

func get_random_walkable_position(random: RandomNumberGenerator) -> Vector2:
	var polygon := _get_walkable_polygon()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	for i in range(40):
		var candidate := Vector2(random.randf_range(bounds.position.x, bounds.end.x), random.randf_range(bounds.position.y, bounds.end.y))
		if is_inside_walkable_area(candidate):
			_debug_log("随机区域目标通过：target=%s" % candidate)
			return candidate
	var fallback := get_nearest_walkable_position(Vector2(360.0, floor_y))
	_debug_log("随机区域采样失败，使用备用点：target=%s" % fallback)
	return fallback

# -----------------------------------------------------------------------------
# 碰撞判断：负责预判可移动物体放到目标位置时是否会碰撞
# -----------------------------------------------------------------------------

func is_spawn_position_valid(moving_body: CollisionObject2D, target_position: Vector2) -> bool:
	if moving_body == null:
		_debug_log("碰撞判断失败：moving_body 为空")
		return false
	if not is_inside_walkable_area(target_position):
		return false
	return not would_collide_at(moving_body, target_position)

func would_collide_at(moving_body: CollisionObject2D, target_position: Vector2) -> bool:
	var collisions := get_collisions_at(moving_body, target_position)
	if not collisions.is_empty():
		_debug_log("预判碰撞：body=%s target=%s collider_count=%d" % [moving_body.name, target_position, collisions.size()])
	return not collisions.is_empty()

func get_collisions_at(moving_body: CollisionObject2D, target_position: Vector2) -> Array[Dictionary]:
	var collision_shape := _get_collision_shape(moving_body)
	if collision_shape == null or collision_shape.shape == null:
		_debug_log("碰撞判断失败：物体没有有效 CollisionShape2D body=%s" % moving_body.name)
		return []

	var room_node := get_parent() as Node2D
	if room_node == null:
		return []

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	var target_transform := collision_shape.global_transform
	target_transform.origin += target_position - moving_body.global_position
	query.transform = target_transform
	query.collision_mask = moving_body.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [moving_body.get_rid()]
	return room_node.get_world_2d().direct_space_state.intersect_shape(query, 8)

# 兼容旧调用名称，新的代码优先使用 is_inside_walkable_area。
func is_walkable_position(candidate: Vector2, _padding: float = 34.0) -> bool:
	return is_inside_walkable_area(candidate)

func get_safe_spawn_position(preferred: Vector2, moving_body: CollisionObject2D = null) -> Vector2:
	return get_spawn_position(preferred, moving_body)

func _get_collision_shape(moving_body: CollisionObject2D) -> CollisionShape2D:
	for child in moving_body.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null

func _get_walkable_polygon() -> PackedVector2Array:
	var room_node := get_parent()
	var polygon_node := room_node.get_node_or_null("FloorWalkableArea/CollisionPolygon2D") as CollisionPolygon2D
	if polygon_node and polygon_node.polygon.size() >= 3:
		return polygon_node.polygon
	return PackedVector2Array([
		Vector2(70.0, walkable_top),
		Vector2(room_size.x - 70.0, walkable_top),
		Vector2(room_size.x - 70.0, walkable_bottom),
		Vector2(70.0, walkable_bottom),
	])

func _debug_log(message: String) -> void:
	if DEBUG_LOGS:
		print("[桌宠调试] [房间碰撞] %s" % message)
