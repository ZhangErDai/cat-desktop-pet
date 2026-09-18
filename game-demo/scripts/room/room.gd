class_name PetRoom
extends Node2D

## 房间场景协调器。
##
## 图片、FloorCollision、FloorWalkableArea 和家具碰撞体都保存在 room.tscn。
## 区域判断统一交给 RoomCollision；这里保留简短代理，方便其他系统调用 Room。

@export var room_size := Vector2(2450.0, 820.0)
@export var floor_y: float = 700.0
@export var walkable_top: float = 610.0
@export var walkable_bottom: float = 748.0
@export var furniture_enabled: bool = false

@onready var collision_rules: RoomCollision = $RoomCollision

func _ready() -> void:
	collision_rules.configure(room_size, floor_y, walkable_top, walkable_bottom)
	_apply_furniture_visibility()
	var floor_sprite := _get_floor_sprite()
	var sofa := get_node_or_null("Sofa") as Sprite2D
	var sofa_collision := get_node_or_null("SofaCollision/CollisionShape2D") as CollisionShape2D
	print("[桌宠调试] 房间 _ready：size=%s floor_y=%.1f walkable_y=%.1f～%.1f" % [room_size, floor_y, walkable_top, walkable_bottom])
	print("[桌宠调试] 家具状态：沙发和猫窝=%s" % ("显示并启用碰撞" if furniture_enabled else "隐藏并禁用碰撞"))
	print("[桌宠调试] 房间节点：FloorImg=%s FloorCollision=%s FloorWalkableArea=%s Sofa=%s SofaCollision=%s CatBedCollision=%s" % [
		floor_sprite != null,
		get_node_or_null("FloorCollision") != null,
		get_node_or_null("FloorWalkableArea/CollisionPolygon2D") != null,
		sofa != null,
		sofa_collision != null,
		get_node_or_null("CatBedCollision/CollisionShape2D") != null,
	])
	if floor_sprite and floor_sprite.texture:
		print("[桌宠调试] 地板贴图：visible=%s position=%s scale=%s size=%s z=%d" % [
			floor_sprite.visible, floor_sprite.position, floor_sprite.scale, floor_sprite.texture.get_size(), floor_sprite.z_index
		])
	else:
		print("[桌宠调试] 地板贴图异常：节点存在=%s texture存在=%s" % [floor_sprite != null, floor_sprite != null and floor_sprite.texture != null])

func _get_floor_sprite() -> Sprite2D:
	var floor_img := get_node_or_null("FloorImg") as Sprite2D
	if floor_img:
		return floor_img
	return get_node_or_null("Floor") as Sprite2D

func is_walkable_position(candidate: Vector2, _padding: float = 34.0) -> bool:
	return collision_rules.is_inside_walkable_area(candidate)

func get_click_walk_target(click_position: Vector2) -> Vector2:
	return collision_rules.get_click_walk_target(click_position)

func get_safe_spawn_position(preferred: Vector2, moving_body: CollisionObject2D = null) -> Vector2:
	return collision_rules.get_spawn_position(preferred, moving_body)

func get_random_walk_position(random: RandomNumberGenerator) -> Vector2:
	return collision_rules.get_random_walkable_position(random)

func _apply_furniture_visibility() -> void:
	var sofa := get_node_or_null("Sofa") as Sprite2D
	var cat_bed := get_node_or_null("CatBed") as Sprite2D
	var sofa_shape := get_node_or_null("SofaCollision/CollisionShape2D") as CollisionShape2D
	var cat_bed_shape := get_node_or_null("CatBedCollision/CollisionShape2D") as CollisionShape2D
	if sofa:
		sofa.visible = furniture_enabled
	if cat_bed:
		cat_bed.visible = furniture_enabled
	if sofa_shape:
		sofa_shape.disabled = not furniture_enabled
	if cat_bed_shape:
		cat_bed_shape.disabled = not furniture_enabled
