class_name CatAnimator
extends AnimatedSprite2D

## 小橘的动画控制器。
##
## 这个脚本只负责“显示哪一帧”和“播放什么动作”，不处理喂食、金钱等游戏规则。
## 动画帧现在保存在 scenes/cat/cat_animations.tres，由 Godot 的 SpriteFrames 编辑器管理。
## 因此脚本只调用动画名称，不再运行时创建或切割 SpriteFrames。

var is_walking: bool = false
var is_running: bool = false
var current_direction: String = "front"
var base_scale := Vector2(0.19, 0.19)
var animation_time: float = 0.0

func _ready() -> void:
	# SpriteFrames 已经在 cat.tscn 中由 Godot 资源引用，这里只做检查和默认播放。
	if sprite_frames == null:
		push_error("猫咪 Visual 没有配置 SpriteFrames 资源，请检查 cat.tscn")
		return
	visible = true
	frame = 0
	print("[桌宠调试] 猫咪动画完成：animation=%s frame=%d idle帧数=%d walk_front帧数=%d eat帧数=%d" % [
		animation, frame, sprite_frames.get_frame_count("idle"), sprite_frames.get_frame_count("walk_front"), sprite_frames.get_frame_count("eat")
	])

func play_idle() -> void:
	is_walking = false
	is_running = false
	base_scale = Vector2(0.19, 0.19)
	animation_time = 0.0
	play("idle")

func play_walk(direction: String) -> void:
	is_walking = true
	is_running = false
	base_scale = Vector2(0.19, 0.19)
	current_direction = direction
	var animation_name := "walk_" + direction
	if sprite_frames.has_animation(animation_name):
		play(animation_name)

func play_run(direction: String) -> void:
	# 跑动是独立状态，不复用 walk 动画名称，也不会仅仅提高 walk 的播放速度。
	is_walking = false
	is_running = true
	base_scale = Vector2(0.19, 0.19)
	current_direction = direction
	var animation_name := "run_" + direction
	if sprite_frames.has_animation(animation_name):
		play(animation_name)

func play_eat() -> void:
	is_walking = false
	is_running = false
	# 吃饭图的单帧尺寸更大，稍微缩小后与走路猫咪保持同样的视觉大小。
	base_scale = Vector2(0.15, 0.15)
	play("eat")

func play_drink() -> void:
	is_walking = false
	is_running = false
	base_scale = Vector2(0.15, 0.15)
	play("drink")

func play_bed_action() -> void:
	# 休息先播放踩窝动作，之后循环轻微呼吸的睡觉动作。
	is_walking = false
	is_running = false
	base_scale = Vector2(0.15, 0.15)
	if sprite_frames.has_animation("knead") and sprite_frames.get_frame_count("knead") > 0:
		play("knead")
	else:
		play("sleep")

func _process(delta: float) -> void:
	# 逐帧素材之外再叠加很轻的身体起伏，让走路不再像“平移贴片”。
	animation_time += delta
	if is_running:
		# 跑动时身体压低并前倾，起伏幅度比走路更明显。
		var run_step := sin(animation_time * 20.0)
		scale = base_scale * Vector2(1.0 + run_step * 0.028, 1.0 - run_step * 0.035)
		rotation = sin(animation_time * 10.0) * 0.025
	elif is_walking:
		var walk_step := sin(animation_time * 14.0)
		scale = base_scale * Vector2(1.0 + walk_step * 0.014, 1.0 - walk_step * 0.010)
		rotation = sin(animation_time * 7.0) * 0.010
	else:
		var breathe := sin(animation_time * 3.0)
		scale = base_scale * Vector2(1.0 + breathe * 0.006, 1.0 - breathe * 0.006)
		rotation = 0.0
