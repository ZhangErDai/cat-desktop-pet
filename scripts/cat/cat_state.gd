class_name CatState
extends Node

## 猫咪当前行为状态的唯一来源。
##
## 状态名称集中在这里，移动、交互、玩球和监测模块只负责切换或读取状态，
## 不再各自维护一套互不相同的字符串。

signal state_changed(previous: String, current: String)

const IDLE := "idle"
const MOVING := "moving"
const RUNNING := "running"
const EATING := "eating"
const DRINKING := "drinking"
const PLAYING := "playing"
const CHASING := "chasing"
const WORKING := "working"
const RESTING := "resting"

var current_state: String = IDLE

func set_state(next_state: String) -> void:
	if next_state.is_empty() or current_state == next_state:
		return
	var previous := current_state
	current_state = next_state
	print("[桌宠调试] [猫咪状态] %s -> %s" % [previous, current_state])
	state_changed.emit(previous, current_state)

func is_idle() -> bool:
	return current_state == IDLE

func is_busy() -> bool:
	return not is_idle()
