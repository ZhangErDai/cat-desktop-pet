class_name PetInteractions
extends Node

## 猫咪交互分类控制器。
##
## 喂食、喝水、陪玩、工作和休息都从这里进入；
## 猫咪怎么走由 CatMovement 负责，球怎么滚由 PlayBall 负责。

signal busy_changed(busy: bool)
signal status_changed(text: String)
signal status_visibility_changed(visible: bool)

const DEBUG_LOGS := true

@onready var cat: CatBody = $"../Cat"
@onready var movement: CatMovement = $"../Cat/Movement"
@onready var play_ball: PlayBall = $"../PlayBall"
@onready var cat_state: CatState = $"../Cat/State"

var pet_stats: PetStats
var settings: PetSettings
var busy: bool = false
var action_generation: int = 0
var interrupting: bool = false

func configure_stats(stats: PetStats) -> void:
	pet_stats = stats

func configure_settings(config: PetSettings) -> void:
	settings = config
	_debug_log("交互模块已连接集中配置")

func _ready() -> void:
	play_ball.started.connect(_on_play_started)
	play_ball.finished.connect(_on_play_finished)
	play_ball.cancelled.connect(_on_play_cancelled)
	play_ball.status_changed.connect(_on_play_status_changed)

func execute(action: int) -> bool:
	if busy:
		# 新的交互可以打断正在进行的陪玩或动作；所有模块通过这个入口收尾。
		_debug_log("收到新交互，先打断当前动作：current_busy=%s action=%d" % [busy, action])
		force_stop_current_action("新的交互请求")
	_debug_log("收到交互请求：action=%d" % action)
	match action:
		0:
			_feed()
		1:
			_drink()
		2:
			_start_play()
		3:
			_work()
		4:
			_rest()
		_:
			return false
	return true

func _feed() -> void:
	_set_busy(true)
	status_visibility_changed.emit(true)
	_debug_log("开始喂食：target=%s" % _food_position())
	_move_to_action(_food_position(), "喂食位置被挡住了", func():
		pet_stats.feed()
		_run_action("eat", 1.6, "吃饱啦！健康和活力都增加了")
	)

func _drink() -> void:
	_set_busy(true)
	status_visibility_changed.emit(true)
	_debug_log("开始喝水：target=%s" % _water_position())
	_move_to_action(_water_position(), "喝水位置被挡住了", func():
		pet_stats.drink()
		_run_action("drink", 1.6, "喝足水啦！")
	)

func _start_play() -> void:
	_set_busy(true)
	_debug_log("开始陪玩：交给 PlayBall")
	if not play_ball.start_play():
		_debug_log("陪玩未启动：PlayBall 当前已经在进行中")
		_finish_failed("陪玩当前正在进行")

func _work() -> void:
	if not pet_stats.can_work():
		_debug_log("猫咖打工被拒绝：体力不足")
		status_changed.emit("太累了，先去猫窝休息一下吧")
		return
	_set_busy(true)
	_debug_log("开始猫咖打工：target=%s" % _desk_position())
	_move_to_action(_desk_position(), "书桌位置被挡住了", func():
		pet_stats.work()
		if cat_state:
			cat_state.set_state(CatState.WORKING)
		_finish_success("在书桌前工作完成，获得 25 猫币")
	)

func _rest() -> void:
	_set_busy(true)
	_debug_log("开始休息：target=%s" % _bed_position())
	_move_to_action(_bed_position(), "猫窝位置被挡住了", func():
		_run_action("bed", 2.4, "休息完成，恢复 25 点体力")
	)

func _move_to_action(target: Vector2, blocked_text: String, on_reached: Callable) -> void:
	var accepted := movement.walk_to(target, func(reached: bool):
		if interrupting:
			return
		if not reached:
			_finish_failed(blocked_text)
			return
		on_reached.call()
	)
	if not accepted:
		_debug_log("交互移动请求未接受：target=%s" % target)
		_finish_failed("猫咪当前正在移动")

func _run_action(animation_name: String, duration: float, finished_text: String) -> void:
	_debug_log("开始动作动画：name=%s duration=%.1f" % [animation_name, duration])
	if animation_name == "eat":
		if cat_state:
			cat_state.set_state(CatState.EATING)
		cat.play_eat()
		status_changed.emit("正在吃东西……")
	elif animation_name == "drink":
		if cat_state:
			cat_state.set_state(CatState.DRINKING)
		cat.play_drink()
		status_changed.emit("正在喝水……")
	else:
		if cat_state:
			cat_state.set_state(CatState.RESTING)
		cat.play_bed_action()
		status_changed.emit("正在猫窝里休息……")
	action_generation += 1
	var generation := action_generation
	get_tree().create_timer(duration).timeout.connect(func():
		if generation != action_generation or interrupting:
			return
		cat.play_idle()
		status_visibility_changed.emit(false)
		_finish_success(finished_text)
	)

func _on_play_started() -> void:
	status_changed.emit("点击地板上的球，猫咪会跑过去追它！")

func _on_play_status_changed(text: String) -> void:
	status_changed.emit(text)

func _on_play_finished(caught: bool) -> void:
	_debug_log("PlayBall 流程结束：caught=%s" % caught)
	if caught:
		pet_stats.play()
		_finish_success("抓到球啦！心情增加 12 点")
	else:
		_finish_failed("陪玩结束")

func _on_play_cancelled(reason: String) -> void:
	if interrupting:
		return
	_debug_log("收到 PlayBall 取消信号：reason=%s" % reason)
	_finish_failed("陪玩被打断")

func force_stop_current_action(reason: String = "外部强制停止") -> void:
	## 任何外部系统都通过这里让猫咪回到等待状态。
	## action_generation 让已经排队的动作计时器失效，避免打断后旧回调再次结算。
	var had_action := busy or movement.is_moving() or play_ball.playing
	if not had_action:
		return
	_debug_log("强制结束当前动作：reason=%s" % reason)
	action_generation += 1
	interrupting = true
	play_ball.cancel(reason)
	movement.cancel_move()
	cat.play_idle()
	if cat_state:
		cat_state.set_state(CatState.IDLE)
	interrupting = false
	status_visibility_changed.emit(false)
	_finish_failed("当前动作已结束，猫咪回到等待状态")

func _set_busy(value: bool) -> void:
	busy = value
	_debug_log("交互 busy=%s" % busy)
	busy_changed.emit(busy)

func _finish_success(text: String) -> void:
	if cat_state:
		cat_state.set_state(CatState.IDLE)
	_set_busy(false)
	status_changed.emit(text)

func _finish_failed(text: String) -> void:
	if cat_state:
		cat_state.set_state(CatState.IDLE)
	cat.play_idle()
	status_visibility_changed.emit(false)
	_set_busy(false)
	status_changed.emit(text)

func _debug_log(message: String) -> void:
	if DEBUG_LOGS:
		print("[桌宠调试] [猫咪交互] %s" % message)

func _food_position() -> Vector2:
	return settings.food_position if settings else Vector2(260, 688)

func _water_position() -> Vector2:
	return settings.water_position if settings else Vector2(390, 688)

func _desk_position() -> Vector2:
	return settings.desk_position if settings else Vector2(1100, 700)

func _bed_position() -> Vector2:
	return settings.bed_position if settings else Vector2(1500, 700)
