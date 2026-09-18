class_name PetStateMonitor
extends Node

## 猫咪状态定时监测器。
##
## 当前只负责固定时间读取并记录状态，空闲时的后续行为暂时留出扩展点，
## 不在这里直接执行散步、喂食或玩球，避免监测模块反过来接管业务逻辑。

const DEBUG_LOGS := true

@onready var timer: Timer = $Timer
@onready var cat_state: CatState = $"../Cat/State"
@onready var movement: CatMovement = $"../Cat/Movement"
@onready var interactions: PetInteractions = $"../PetInteractions"
@onready var play_ball: PlayBall = $"../PlayBall"

var last_state: String = ""
var monitor_interval: float = 1.0

func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	_debug_log("状态监测器启动：interval=%.1f 秒" % monitor_interval)

func configure_settings(settings: PetSettings) -> void:
	if settings == null:
		return
	monitor_interval = maxf(settings.monitor_interval, 0.1)
	if timer:
		timer.wait_time = monitor_interval
		if not timer.is_stopped():
			timer.start()
	_debug_log("状态监测器配置完成：interval=%.1f 秒" % monitor_interval)

func _on_timer_timeout() -> void:
	var current := _read_current_state()
	if current != last_state:
		last_state = current
		_debug_log("定时检查：current_state=%s moving=%s interaction_busy=%s playing_ball=%s" % [
			current,
		movement != null and movement.is_moving(),
		interactions != null and interactions.busy,
		play_ball != null and play_ball.playing,
		])
	# 后续可以在这里增加“空闲一段时间后的行为”，当前只观察不干预。

func _read_current_state() -> String:
	if cat_state:
		return cat_state.current_state
	if play_ball and play_ball.playing:
		return CatState.PLAYING
	if movement and movement.is_moving():
		return CatState.MOVING
	return CatState.IDLE

func _debug_log(message: String) -> void:
	if DEBUG_LOGS:
		print("[桌宠调试] [状态监测] %s" % message)
