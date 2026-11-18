extends Node
## Session state shared by every scene (autoload "GameState").
## Persistence is SaveManager's job (Phase 1); this only holds live values.

signal money_changed(amount: int)

var active_minigame_id: StringName = &""

var money: int = 0:
	set(value):
		if value == money:
			return
		money = value
		money_changed.emit(money)


func add_money(amount: int) -> void:
	money += amount
