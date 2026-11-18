extends Node
## Session state shared by every scene (autoload "GameState").
## Persistence is SaveManager's job (Phase 1); this only holds live values.

signal money_changed(amount: int)
signal chaos_changed(amount: int)

var active_minigame_id: StringName = &""

var money: int = 0:
	set(value):
		if value == money:
			return
		money = value
		money_changed.emit(money)


## Mayhem caused this session (props, pedestrians...). Feeds police heat later.
var chaos: int = 0:
	set(value):
		if value == chaos:
			return
		chaos = value
		chaos_changed.emit(chaos)


func add_money(amount: int) -> void:
	money += amount


func add_chaos(amount: int) -> void:
	chaos += amount
