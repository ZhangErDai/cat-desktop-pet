extends Node2D

## 桌宠主场景协调器。
## 这里不再负责创建贴图、房间道具或球的细节，只负责把各个场景和脚本串起来。

## 启动诊断开关。
## 开发阶段保持为 true，方便确认主场景、贴图、摄像机和动画是否正常加载。
## 发布桌宠时改为 false，即可关闭这些调试输出。
const DEBUG_LOGS := true

const PET_STATS_SCRIPT = preload("res://scripts/core/pet_stats.gd")
const PET_SETTINGS = preload("res://resources/pet_settings.tres")
const DEFAULT_WALL_TEXTURE = preload("res://art/room/room_wall_back_room.png")
const CLEAN_WALL_TEXTURE = preload("res://art/room/room_wall_clean.png")
@onready var room: PetRoom = $Room
@onready var cat: CatBody = $Cat
@onready var cat_movement: CatMovement = $Cat/Movement
@onready var ball: PetBall = $Ball
@onready var camera: Camera2D = $Camera2D
@onready var play_ball: PlayBall = $PlayBall
@onready var interactions: PetInteractions = $PetInteractions
@onready var state_monitor: PetStateMonitor = $PetStateMonitor
@onready var settings_menu: SettingsMenu = $SettingsLayer/SettingsMenu

var pet_stats: PetStats
var pet_settings: PetSettings = PET_SETTINGS
## 保存 room.tscn 中原本的墙面资源，方便“当前墙面图片”恢复用户在场景里设置的图片。
var scene_wall_texture: Texture2D
var cat_name := "小橘"
var status_text := "小橘正在等你陪伴"
var ui_layer: CanvasLayer
var floating_hud: ColorRect
var status_label: Label
var coins_label: Label
var stat_labels: Dictionary = {}
var stat_bars: Dictionary = {}
var action_buttons: Array[Button] = []
var action_busy: bool = false
var idle_time: float = 0.0
var runtime_snapshot_logged: bool = false
var status_user_visible: bool = false
var status_action_visible: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	# 各个子场景已经在 scenes/main/desktop_pet.tscn 中实例化，这里只做初始化和信号连接。
	_debug_log("主场景 _ready 开始：scene=%s" % get_scene_file_path())
	_debug_log("视口=%s，窗口透明背景=%s" % [get_viewport_rect().size, get_viewport().transparent_bg])
	_debug_log("节点检查：Room=%s Cat=%s Ball=%s Camera2D=%s" % [room != null, cat != null, ball != null, camera != null])
	# 调试阶段使用不透明画布，确保房间背景在 Godot 的嵌入式运行窗口中可见。
	# 透明背景会让部分 macOS/Godot 嵌入式窗口只显示灰色占位区域，
	# 等桌宠画面和交互确认无误后，再把它改回 true 做无边框透明桌宠。
	get_viewport().transparent_bg = false
	rng.randomize()
	cat_name = pet_settings.cat_name
	pet_stats = PET_STATS_SCRIPT.new()
	pet_stats.configure_settings(pet_settings)
	cat_movement.configure_settings(pet_settings)
	cat_movement.configure_collision(room.collision_rules)
	interactions.configure_stats(pet_stats)
	interactions.configure_settings(pet_settings)
	play_ball.configure_settings(pet_settings)
	state_monitor.configure_settings(pet_settings)
	interactions.busy_changed.connect(_on_interaction_busy_changed)
	interactions.status_changed.connect(_on_interaction_status_changed)
	interactions.status_visibility_changed.connect(_set_action_status_visible)
	# 场景出生点如果与沙发重叠，会自动移动到最近的可行走位置。
	cat.position = room.get_safe_spawn_position(cat.position, cat)
	_debug_log("猫咪出生位置=%s，可见=%s，动画=%s" % [cat.position, cat.visible, cat.animation])
	# 把房间真实边界传给球；球可以离开摄像机视野，但不能离开房间。
	ball.configure_room_bounds(0.0, room.room_size.x, room.floor_y)
	ball.visible = false
	settings_menu.status_visibility_changed.connect(_on_status_visibility_changed)
	settings_menu.cat_name_changed.connect(_on_cat_name_changed)
	settings_menu.background_mode_changed.connect(_on_background_mode_changed)
	settings_menu.background_image_selected.connect(_on_background_image_selected)
	settings_menu.background_color_changed.connect(_on_background_color_changed)
	settings_menu.set_status_visible(false)
	settings_menu.set_cat_name(cat_name)
	# 启动时尊重 room.tscn 的 WallImg 设置，不强制铺满或强制显示。
	var scene_wall := room.get_node_or_null("WallImg") as Sprite2D
	if scene_wall:
		scene_wall_texture = scene_wall.texture
	var initial_background_mode := "wall" if scene_wall and scene_wall.visible else "hidden"
	settings_menu.set_background_mode(initial_background_mode)
	# 不在启动时调用 _apply_background_mode：room.tscn 是场景的最终配置，
	# 这里仅同步设置菜单的选项，避免覆盖编辑器中保存的贴图、位置、缩放和可见性。
	_build_ui()
	_apply_status_visibility()
	_update_ui()
	_debug_log("主场景 _ready 完成")

func _process(delta: float) -> void:
	idle_time += delta
	if not _is_busy() and idle_time > 7.0 and not ball.visible:
		_start_free_walk()
	if camera and cat:
		# 摄像机跟随猫咪，长条房间会随着猫咪探索横向移动。
		camera.position = cat.position
	if not runtime_snapshot_logged:
		runtime_snapshot_logged = true
		_print_runtime_snapshot()
	_update_floating_hud_position()
	_update_ui()

func _build_ui() -> void:
	# HUD 使用半透明面板跟随猫咪，不再占用顶部白色区域。
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	floating_hud = ColorRect.new()
	floating_hud.size = Vector2(178, 118)
	floating_hud.color = Color(0.08, 0.07, 0.10, 0.62)
	floating_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(floating_hud)
	coins_label = Label.new()
	coins_label.position = Vector2(12, 8)
	coins_label.size = Vector2(150, 22)
	coins_label.add_theme_font_size_override("font_size", 16)
	coins_label.add_theme_color_override("font_color", Color("#ffe3a8"))
	floating_hud.add_child(coins_label)
	var stat_keys: Array[String] = ["活力", "心情", "健康", "体力"]
	var colors: Array[Color] = [Color("#ef9b62"), Color("#6fc4a0"), Color("#80afd8"), Color("#c298d6")]
	for i in range(stat_keys.size()):
		var key := stat_keys[i]
		var label := Label.new()
		label.position = Vector2(12, 34 + i * 19)
		label.size = Vector2(60, 18)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#fff5e7"))
		floating_hud.add_child(label)
		stat_labels[key] = label
		var bar := ProgressBar.new()
		bar.position = Vector2(72, 37 + i * 19)
		bar.size = Vector2(94, 10)
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _bar_style(Color(1, 1, 1, 0.18)))
		bar.add_theme_stylebox_override("fill", _bar_style(colors[i]))
		floating_hud.add_child(bar)
		stat_bars[key] = bar
	status_label = Label.new()
	status_label.position = Vector2(20, 388)
	status_label.size = Vector2(600, 28)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#7d4b4f"))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(status_label)
	var actions: Array[String] = ["喂食", "喝水", "陪玩", "猫咖打工", "休息"]
	for i in range(actions.size()):
		var button := Button.new()
		button.text = actions[i]
		button.position = Vector2(30 + i * 118, 430)
		button.size = Vector2(105, 30)
		button.pressed.connect(_on_action.bind(i))
		ui_layer.add_child(button)
		action_buttons.append(button)

func _update_floating_hud_position() -> void:
	if not floating_hud or not cat:
		return
	# 将世界坐标转换成屏幕坐标，让状态面板始终悬浮在猫咪上方。
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * cat.position
	var max_position := get_viewport_rect().size - floating_hud.size - Vector2(8, 8)
	floating_hud.position = Vector2(clampf(screen_position.x - 89.0, 8.0, max_position.x), clampf(screen_position.y - 142.0, 8.0, max_position.y))

func _on_action(action: int) -> void:
	idle_time = 0.0
	_debug_log("收到按钮操作：%s" % ["喂食", "喝水", "陪玩", "猫咖打工", "休息"][action])
	if not interactions.execute(action):
		_debug_log("交互请求未执行：action=%d main_busy=%s interaction_busy=%s play_ball=%s" % [action, action_busy, interactions.busy, play_ball.playing])

func _start_free_walk() -> void:
	idle_time = 0.0
	var target: Vector2 = room.get_random_walk_position(rng)
	var direction := "left" if target.x < cat.position.x else "right"
	_debug_log("[自动移动] 发起自由散步：from=%s target=%s distance=%.1f direction=%s" % [cat.position, target, cat.position.distance_to(target), direction])
	_move_cat_to(target, direction, func(): status_text = "%s正在房间里自由散步……" % cat_name, false, "walk")

func _move_cat_to(target: Vector2, direction: String, arrived: Callable, lock_buttons: bool = true, movement_mode: String = "walk") -> void:
	if _is_busy():
		_debug_log("移动请求被忽略：当前正在执行其他动作 target=%s mode=%s" % [target, movement_mode])
		return
	action_busy = true
	_set_buttons_disabled(lock_buttons)
	# CatMovement 负责走/跑选择，CatBody 负责 move_and_collide 和碰撞结果。
	_debug_log("移动请求交给物理猫咪：target=%s requested_mode=%s direction_hint=%s" % [target, movement_mode, direction])
	var accepted := cat_movement.move_to(target, movement_mode, func(reached: bool):
		action_busy = false
		_set_buttons_disabled(false)
		if reached:
			arrived.call()
		else:
			status_text = "%s被碰撞挡住了。" % cat_name
			_debug_log("猫咪没有到达目标：被 Godot 物理碰撞阻挡")
	)
	if not accepted:
		action_busy = false
		_set_buttons_disabled(false)
		_debug_log("移动请求未接受：猫咪当前已经在移动")


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if play_ball.handle_key(event):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# 只有没有被 Button、设置面板等 Control 控件处理的点击，才会进入这里。
	# 因此点击界面不会误触发猫咪移动，也不会触发家具碰撞。
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var world_mouse := get_global_mouse_position()
	_debug_log("[点击移动] 收到地面点击：screen=%s world=%s cat=%s" % [event.position, world_mouse, cat.position])
	if play_ball.handle_mouse_click(world_mouse):
		get_viewport().set_input_as_handled()
		return
	if _is_busy():
		return
	# 目标只限制在房间和猫咪可移动的高度范围内。
	# 墙体、家具是否挡路，不再由这里检查，而由 CharacterBody2D 的物理碰撞处理。
	var click_target: Vector2 = room.get_click_walk_target(world_mouse)
	if click_target.x < 0.0:
		status_text = "这里不在房间的可行走范围内。"
		_debug_log("[点击移动] 被限制：world_target=%s 超出房间边界" % world_mouse)
		return
	var direction := "left" if click_target.x < cat.position.x else "right"
	_debug_log("[点击移动] 目标有效：raw_world=%s final_target=%s distance=%.1f direction=%s" % [world_mouse, click_target, cat.position.distance_to(click_target), direction])
	_move_cat_to(click_target, direction, func(): status_text = "%s走到这里啦！" % cat_name, false, "walk")

func _set_buttons_disabled(disabled: bool) -> void:
	for button in action_buttons:
		button.disabled = disabled

func _is_busy() -> bool:
	# 主场景、交互分类器和陪玩控制器可能分别处于忙碌状态。
	# 统一判断，避免陪玩过程中自动散步或普通点击移动抢占猫咪控制权。
	return action_busy or (interactions != null and interactions.busy) or (play_ball != null and play_ball.playing)

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _update_ui() -> void:
	if not status_label or not pet_stats:
		return
	status_label.text = status_text
	coins_label.text = "猫币  %04d" % pet_stats.coins
	for key in stat_labels:
		var value: float = float(pet_stats.values[key])
		stat_labels[key].text = "%s %d" % [key, int(value)]
		stat_bars[key].value = value

func _on_status_visibility_changed(should_show: bool) -> void:
	# 设置菜单和右上角快捷按钮都会通过这个信号改变“用户手动显示”状态。
	status_user_visible = should_show
	_debug_log("状态属性显示设置：%s" % ("显示" if should_show else "隐藏"))
	_apply_status_visibility()

func _on_interaction_busy_changed(busy: bool) -> void:
	action_busy = busy
	# 陪玩期间按钮保持可用，新的喂食/喝水请求可以通过 PetInteractions 打断陪玩。
	_set_buttons_disabled(busy and not play_ball.playing)
	_debug_log("交互忙碌状态：%s" % ("执行中" if busy else "空闲"))

func _on_interaction_status_changed(text: String) -> void:
	if text.begins_with("太累"):
		status_text = text
	else:
		status_text = "%s%s" % [cat_name, text]
	_debug_log("交互状态：%s" % text)

func _on_cat_name_changed(new_name: String) -> void:
	# 名字由设置菜单维护，主场景只同步运行时提示文字和悬浮信息。
	cat_name = new_name if not new_name.is_empty() else "小橘"
	pet_settings.cat_name = cat_name
	status_text = "%s准备好陪伴你啦！" % cat_name
	_debug_log("猫咪名字更新：%s" % cat_name)
	_update_ui()

func _on_background_mode_changed(mode: String) -> void:
	# 设置菜单只发出用户选择，主场景负责把选择应用到 Room 的 Sprite2D 节点。
	_apply_background_mode(mode)

func _on_background_color_changed(color: Color) -> void:
	var background_color := room.get_node_or_null("BackgroundColor") as Polygon2D
	if background_color:
		background_color.color = Color(color.r, color.g, color.b, 1.0)

func _on_background_image_selected(path: String) -> void:
	# FileDialog 返回的是用户电脑上的绝对路径，ImageTexture 只在运行期间使用该图片。
	_debug_log("收到背景图片选择：path=%s" % path)
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		status_text = "背景图片读取失败：%s" % path
		_debug_log("背景图片读取失败：error=%s path=%s" % [error, path])
		return
	_debug_log("背景图片读取成功：size=%s format=%s" % [image.get_size(), image.get_format()])
	var wall := room.get_node_or_null("WallImg") as Sprite2D
	if wall == null:
		_debug_log("背景图片应用失败：Room/WallImg 节点不存在")
		return
	# 自定义背景只修改 Room/WallImg 的 texture 属性。
	# 不修改 visible、position、scale，也不触碰 FloorImg、BackgroundColor 或碰撞体。
	wall.texture = ImageTexture.create_from_image(image)
	_debug_log("自定义背景图片已应用：texture_size=%s visible=%s position=%s scale=%s" % [
		wall.texture.get_size(), wall.visible, wall.position, wall.scale
	])

func _apply_background_mode(mode: String) -> void:
	# 墙面图片根据模式显示或隐藏；背景色层不在这里被修改。
	# 当前模式只替换 WallImg.texture，不自动修改 WallImg 的位置和缩放。
	var wall := room.get_node_or_null("WallImg") as Sprite2D
	if wall == null:
		return
	match mode:
		"hidden", "blank":
			wall.visible = false
		"wall":
			# 恢复 room.tscn 中保存的当前墙面图片；没有时才使用默认墙面。
			wall.texture = scene_wall_texture if scene_wall_texture else DEFAULT_WALL_TEXTURE
			wall.visible = true
		"clean_wall":
			wall.texture = CLEAN_WALL_TEXTURE
			wall.visible = true
		"custom":
			# 自定义模式不替换贴图，只显示当前 WallImg.texture。
			wall.visible = true
		_:
			wall.visible = false
	_debug_log("背景墙应用完成：mode=%s visible=%s" % [mode, wall.visible])

func _set_action_status_visible(should_show: bool) -> void:
	# 喂食或喝水的临时显示不改变用户在设置中选择的默认状态。
	status_action_visible = should_show
	_apply_status_visibility()

func _apply_status_visibility() -> void:
	if stat_labels.is_empty() or stat_bars.is_empty():
		return
	var should_show := status_user_visible or status_action_visible
	# 信息面板包括猫币、活力、心情、健康和体力，统一显示或隐藏。
	if coins_label:
		coins_label.visible = should_show
	for key in ["活力", "心情", "健康", "体力"]:
		stat_labels[key].visible = should_show
		stat_bars[key].visible = should_show
	# 隐藏整组信息时收缩悬浮面板；显示时恢复猫币和四项状态属性。
	if floating_hud:
		floating_hud.visible = should_show
		floating_hud.size.y = 118.0
	_update_floating_hud_position()

func _print_runtime_snapshot() -> void:
	# 延迟一帧打印，确认场景实例化和摄像机跟随逻辑都已经执行完成。
	var floor_sprite := room.get_node_or_null("FloorImg") as Sprite2D
	if floor_sprite == null:
		floor_sprite = room.get_node_or_null("Floor") as Sprite2D
	var sofa := room.get_node_or_null("Sofa") as Sprite2D
	_debug_log("运行快照：cat_pos=%s cat_visible=%s cat_modulate=%s camera_pos=%s camera_global=%s camera_enabled=%s" % [
		cat.position, cat.visible, cat.modulate, camera.position, camera.global_position, camera.enabled
	])
	_debug_log("画布变换=%s，视口=%s" % [get_viewport().get_canvas_transform(), get_viewport_rect().size])
	if floor_sprite and floor_sprite.texture:
		_debug_log("地板检查：visible=%s position=%s scale=%s texture_size=%s z=%d" % [floor_sprite.visible, floor_sprite.position, floor_sprite.scale, floor_sprite.texture.get_size(), floor_sprite.z_index])
	else:
		_debug_log("地板检查失败：FloorImg/Floor 节点或 texture 为空")
	if sofa and sofa.texture:
		_debug_log("沙发检查：visible=%s position=%s texture_size=%s" % [sofa.visible, sofa.position, sofa.texture.get_size()])
	else:
		_debug_log("沙发检查失败：Sofa 节点或 texture 为空")

func _debug_log(message: String) -> void:
	if DEBUG_LOGS:
		print("[桌宠调试] %s" % message)
