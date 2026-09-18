class_name SettingsMenu
extends Control

## 桌宠右上角设置菜单。
##
## 这个脚本只负责设置界面的显示和选项转发，不直接修改猫咪属性。
## 主场景通过 stamina_visibility_changed 信号决定是否显示体力条，
## 以后可以在这里继续增加音量、窗口置顶、开机启动等设置。

signal status_visibility_changed(should_show: bool)
signal cat_name_changed(new_name: String)
signal background_mode_changed(mode: String)
signal background_image_selected(path: String)
signal background_color_changed(color: Color)

@onready var settings_button: TextureButton = $SettingsButton
@onready var quick_stamina_button: Button = $QuickStaminaButton
@onready var settings_panel: ColorRect = $SettingsPanel
@onready var status_option: CheckButton = $SettingsPanel/StatusOption
@onready var cat_name_input: LineEdit = $SettingsPanel/CatNameInput
@onready var save_name_button: Button = $SettingsPanel/SaveNameButton
@onready var background_mode_option: OptionButton = $SettingsPanel/BackgroundModeOption
@onready var background_color_button: ColorPickerButton = $SettingsPanel/BackgroundColorButton
@onready var choose_background_button: Button = $SettingsPanel/ChooseBackgroundButton
@onready var background_file_dialog: FileDialog = $BackgroundFileDialog
@onready var close_button: Button = $SettingsPanel/CloseButton

var status_visible: bool = false
var background_mode: String = "wall"

func _ready() -> void:
	# 设置面板默认关闭，状态属性默认隐藏。
	settings_panel.visible = false
	status_option.set_pressed_no_signal(status_visible)
	settings_button.pressed.connect(_toggle_settings_panel)
	quick_stamina_button.pressed.connect(_toggle_status_visibility)
	status_option.toggled.connect(_on_status_option_toggled)
	save_name_button.pressed.connect(_save_cat_name)
	background_mode_option.item_selected.connect(_on_background_mode_selected)
	background_color_button.color_changed.connect(_on_background_color_changed)
	choose_background_button.pressed.connect(_open_background_file_dialog)
	background_file_dialog.file_selected.connect(_on_background_file_selected)
	close_button.pressed.connect(_close_settings_panel)
	_setup_background_options()
	_update_quick_button_text()
	print("[桌宠调试] 设置菜单已加载：状态属性默认显示=%s" % status_visible)

func set_status_visible(should_show: bool) -> void:
	# 主场景初始化或其他系统需要同步设置时调用这个方法。
	status_visible = should_show
	status_option.set_pressed_no_signal(status_visible)
	_update_quick_button_text()
	status_visibility_changed.emit(status_visible)

func set_cat_name(new_name: String) -> void:
	# 主场景初始化或读档后调用，用于同步设置面板里的名字输入框。
	cat_name_input.text = new_name

func set_background_mode(new_mode: String) -> void:
	# 主场景初始化背景墙时调用，避免设置菜单和实际场景显示不一致。
	background_mode = new_mode
	for index in range(background_mode_option.item_count):
		if background_mode_option.get_item_metadata(index) == new_mode:
			background_mode_option.select(index)
			return

func _setup_background_options() -> void:
	# 这些选项只描述“显示方式”；真正的贴图切换由主场景完成。
	background_mode_option.clear()
	background_mode_option.add_item("隐藏背景墙")
	background_mode_option.set_item_metadata(0, "hidden")
	background_mode_option.add_item("纯色空白")
	background_mode_option.set_item_metadata(1, "blank")
	background_mode_option.add_item("当前墙面图片")
	background_mode_option.set_item_metadata(2, "wall")
	background_mode_option.add_item("干净墙面图片")
	background_mode_option.set_item_metadata(3, "clean_wall")
	background_mode_option.add_item("自定义图片")
	background_mode_option.set_item_metadata(4, "custom")
	background_mode_option.select(2)

func _save_cat_name() -> void:
	var new_name := cat_name_input.text.strip_edges()
	if new_name.is_empty():
		new_name = "小橘"
	cat_name_input.text = new_name
	cat_name_changed.emit(new_name)
	print("[桌宠调试] 猫咪名字已设置：%s" % new_name)

func _toggle_settings_panel() -> void:
	settings_panel.visible = not settings_panel.visible
	print("[桌宠调试] 设置面板：%s" % ("打开" if settings_panel.visible else "关闭"))

func _close_settings_panel() -> void:
	settings_panel.visible = false

func _on_background_mode_selected(index: int) -> void:
	background_mode = str(background_mode_option.get_item_metadata(index))
	background_mode_changed.emit(background_mode)
	print("[桌宠调试] 背景墙模式已设置：%s" % background_mode)

func _on_background_color_changed(color: Color) -> void:
	background_color_changed.emit(color)

func _open_background_file_dialog() -> void:
	background_file_dialog.popup_centered_ratio(0.75)

func _on_background_file_selected(path: String) -> void:
	background_image_selected.emit(path)
	print("[桌宠调试] 用户选择背景图片：%s" % path)

func _toggle_status_visibility() -> void:
	set_status_visible(not status_visible)

func _on_status_option_toggled(should_show: bool) -> void:
	# 设置面板中的复选框和右上角快捷按钮共用同一套状态。
	if should_show == status_visible:
		_update_quick_button_text()
		return
	set_status_visible(should_show)

func _update_quick_button_text() -> void:
	quick_stamina_button.text = "状态：开" if status_visible else "状态：关"
	quick_stamina_button.tooltip_text = "点击切换猫币、活力、心情、健康和体力的显示/隐藏"
	settings_button.tooltip_text = "打开桌宠设置"
