class_name PetStats
extends RefCounted

## 猫咪状态和猫币的公共数据类。
## 主场景、交互按钮和未来的社区系统都可以通过这个类读写数据。

signal changed

var values: Dictionary = {}
var coins: int = 0
var settings: PetSettings

func _init() -> void:
	# 没有配置资源时仍保留可用的默认值，方便单独测试这个数据类。
	values = {"活力": 72.0, "心情": 80.0, "健康": 92.0, "体力": 68.0}
	coins = 120

func configure_settings(config: PetSettings) -> void:
	settings = config
	if settings == null:
		return
	values = {
		"活力": settings.initial_vitality,
		"心情": settings.initial_mood,
		"健康": settings.initial_health,
		"体力": settings.initial_stamina,
	}
	coins = settings.initial_coins
	print("[桌宠调试] PetStats 已加载集中配置：values=%s coins=%d" % [values, coins])

func change_stat(key: String, amount: float) -> void:
	# 通用状态修改方法：统一限制在 0~100，避免按钮或未来社区功能把数值改出范围。
	if not values.has(key):
		return
	values[key] = clampf(float(values[key]) + amount, 0.0, 100.0)
	changed.emit()

func can_work() -> bool:
	# 猫咖打工的最低体力门槛，主场景据此决定是否允许进入工作动作。
	var minimum := settings.minimum_work_stamina if settings else 15.0
	return float(values["体力"]) >= minimum

func feed() -> void:
	# 喂食完成后的结算：健康 +5、活力 +4，消耗体力 -2。
	# 具体“走到食盆”和“播放吃饭动画”由桌宠主场景负责，这里只处理数值。
	change_stat("健康", settings.feed_health_gain if settings else 5.0)
	change_stat("活力", settings.feed_vitality_gain if settings else 4.0)
	change_stat("体力", -(settings.feed_stamina_cost if settings else 2.0))

func drink() -> void:
	# 喝水完成后的结算：健康 +3、活力 +2，不消耗体力。
	# 主场景在猫咪到达水盆后调用此方法，同时播放 drink 动画。
	# 将数值结算和动画分开，未来更换动画或增加喝水道具时不需要改这里。
	change_stat("健康", settings.drink_health_gain if settings else 3.0)
	change_stat("活力", settings.drink_vitality_gain if settings else 2.0)

func play() -> void:
	# 陪玩完成后的结算：心情 +12，追球会消耗体力 -5。
	# 球的滚动、碰撞和猫咪追逐过程由 ball.gd 与主场景分别负责。
	change_stat("心情", settings.play_mood_gain if settings else 12.0)
	change_stat("体力", -(settings.play_stamina_cost if settings else 5.0))

func work() -> void:
	# 猫咖打工完成后的结算：获得 25 猫币，体力 -18，心情 -3。
	# can_work() 已经在进入工作前检查最低体力，这里只负责最终发放奖励。
	coins += settings.work_coins_gain if settings else 25
	change_stat("体力", -(settings.work_stamina_cost if settings else 18.0))
	change_stat("心情", -(settings.work_mood_cost if settings else 3.0))

func rest() -> void:
	# 猫窝休息完成后的结算：体力 +25、心情 +2。
	# 猫窝踩窝/睡觉动画由 CatAnimator 播放，动画结束后才调用本方法。
	change_stat("体力", settings.rest_stamina_gain if settings else 25.0)
	change_stat("心情", settings.rest_mood_gain if settings else 2.0)
