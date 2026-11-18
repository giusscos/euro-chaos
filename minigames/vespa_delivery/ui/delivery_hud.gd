class_name DeliveryHud
extends CanvasLayer
## Scooter Delivery HUD: current job, timer, cargo condition, money, shift
## progress, interaction prompt and pop-up messages.

@export var runner: MissionRunner
@export var cargo_monitor: CargoMonitor
## Distance to the objective is measured from here.
@export var player: Node3D
## Below this many seconds left the timer turns to the warning colour.
@export_range(0.0, 60.0, 0.5, "suffix:s") var warning_time: float = 10.0
@export var normal_color: Color = Color.WHITE
@export var warning_color: Color = Color(1.0, 0.75, 0.2)
@export var late_color: Color = Color(1.0, 0.35, 0.3)
@export var good_color: Color = Color(0.5, 1.0, 0.55)
## How long the cargo bar flashes red after a bump.
@export_range(0.0, 2.0, 0.05, "suffix:s") var damage_flash_time: float = 0.35

@onready var _title: Label = %TitleLabel
@onready var _customer: Label = %CustomerLabel
@onready var _objective: Label = %ObjectiveLabel
@onready var _speech: Label = %SpeechLabel
@onready var _timer_box: Control = %TimerBox
@onready var _timer: Label = %TimerLabel
@onready var _cargo_name: Label = %CargoLabel
@onready var _cargo_bar: ProgressBar = %CargoBar
@onready var _money: Label = %MoneyLabel
@onready var _shift: Label = %ShiftLabel
@onready var _chaos: Label = %ChaosLabel
@onready var _toast: Toast = %Toast

var _flash_left: float = 0.0


func _ready() -> void:
	_timer_box.visible = false
	_title.text = ""
	_customer.text = ""
	_objective.text = ""
	_speech.text = ""
	_set_money(GameState.money)
	GameState.money_changed.connect(_set_money)
	_set_chaos(GameState.chaos)
	GameState.chaos_changed.connect(_set_chaos)
	if runner != null:
		runner.mission_started.connect(_on_mission_started)
		runner.cargo_picked_up.connect(_on_cargo_picked_up)
		runner.became_late.connect(_on_became_late)
	if cargo_monitor != null:
		cargo_monitor.damaged.connect(_on_cargo_damaged)


func show_toast(message: String, color: Color = Color.WHITE, duration: float = -1.0) -> void:
	_toast.show_message(message, color, duration)


func set_shift_progress(done: int, total: int) -> void:
	_shift.text = "Delivery %d / %d" % [mini(done + 1, total), total] if done < total else "Shift complete"


func show_result(result: DeliveryResult) -> void:
	_timer_box.visible = false
	var mission: MissionData = result.mission
	match result.outcome:
		DeliveryResult.Outcome.DELIVERED:
			show_toast("+€%d   (tip €%d)\n%s" % [result.total(), result.tip, stars_text(result.stars)], good_color)
			_speech.text = "“%s”" % mission.success_line
		DeliveryResult.Outcome.LATE:
			show_toast("Late!  +€%d\n%s" % [result.total(), stars_text(result.stars)], warning_color)
			_speech.text = "“%s”" % mission.late_line
		DeliveryResult.Outcome.RUINED:
			show_toast("Order ruined!  €0", late_color)
			_speech.text = "“%s”" % mission.ruined_line
		DeliveryResult.Outcome.ABANDONED:
			show_toast("Order cancelled", late_color)
	_objective.text = ""


static func stars_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(5 - stars)


func _process(delta: float) -> void:
	if runner == null:
		return
	if runner.state != MissionRunner.State.IDLE and player != null:
		var distance: float = player.global_position.distance_to(runner.get_objective_position())
		var verb: String = "Pick up at" if runner.state == MissionRunner.State.TO_PICKUP else "Deliver to"
		_objective.text = "%s %s  ·  %d m" % [verb, runner.get_objective_name(), roundi(distance)]
	if runner.state == MissionRunner.State.DELIVERING:
		var left: float = runner.get_time_left()
		if runner.is_late:
			_timer.text = "LATE  +%.1f" % -left
			_timer.self_modulate = late_color
		else:
			_timer.text = "%d:%04.1f" % [floori(left / 60.0), fmod(left, 60.0)]
			_timer.self_modulate = warning_color if left < warning_time else normal_color
		if cargo_monitor != null:
			_cargo_bar.value = cargo_monitor.condition * 100.0
	_flash_left = maxf(_flash_left - delta, 0.0)
	_cargo_bar.self_modulate = late_color if _flash_left > 0.0 else Color.WHITE


func _on_mission_started(mission: MissionData) -> void:
	_title.text = mission.title
	_customer.text = mission.customer_name
	_speech.text = ""
	_timer_box.visible = false


func _on_cargo_picked_up(mission: MissionData) -> void:
	_speech.text = "“%s”" % mission.request_text
	_timer_box.visible = true
	_cargo_name.text = mission.cargo.display_name if mission.cargo != null else "Cargo"
	_cargo_bar.value = 100.0
	show_toast("Order up!  %s" % _cargo_name.text, good_color, 1.4)


func _on_became_late(_mission: MissionData) -> void:
	show_toast("Too slow! No tip now.", late_color, 1.6)


func _on_cargo_damaged(_amount: float, _condition: float) -> void:
	_flash_left = damage_flash_time


func _set_money(amount: int) -> void:
	_money.text = "€ %d" % amount


func _set_chaos(amount: int) -> void:
	_chaos.text = "Chaos %d" % amount
	_chaos.visible = amount > 0
