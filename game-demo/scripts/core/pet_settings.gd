class_name PetSettings
extends Resource

## 桌宠的集中配置。
##
## 这些是“规则和数值”，不是具体执行逻辑。未来设置菜单只需要修改这个资源，
## CatMovement、PlayBall、PetStats 和监测器就能读取同一份配置。

@export_category("猫咪")
@export var cat_name: String = "小橘"
@export var walk_speed: float = 230.0
@export var run_speed: float = 420.0
@export var run_distance_threshold: float = 260.0

@export_category("玩球")
@export var ball_catch_distance: float = 58.0

@export_category("交互位置")
@export var food_position: Vector2 = Vector2(260, 688)
@export var water_position: Vector2 = Vector2(390, 688)
@export var desk_position: Vector2 = Vector2(1100, 700)
@export var bed_position: Vector2 = Vector2(1500, 700)

@export_category("状态初始值")
@export var initial_vitality: float = 72.0
@export var initial_mood: float = 80.0
@export var initial_health: float = 92.0
@export var initial_stamina: float = 68.0
@export var initial_coins: int = 120
@export var minimum_work_stamina: float = 15.0

@export_category("状态结算")
@export var feed_health_gain: float = 5.0
@export var feed_vitality_gain: float = 4.0
@export var feed_stamina_cost: float = 2.0
@export var drink_health_gain: float = 3.0
@export var drink_vitality_gain: float = 2.0
@export var play_mood_gain: float = 12.0
@export var play_stamina_cost: float = 5.0
@export var work_coins_gain: int = 25
@export var work_stamina_cost: float = 18.0
@export var work_mood_cost: float = 3.0
@export var rest_stamina_gain: float = 25.0
@export var rest_mood_gain: float = 2.0

@export_category("监测")
@export var monitor_interval: float = 1.0
