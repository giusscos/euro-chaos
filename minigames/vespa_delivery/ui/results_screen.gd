class_name ResultsScreen
extends CanvasLayer
## End-of-shift summary: every delivery, earnings, best shift.

signal again_pressed
signal menu_pressed

@onready var _root: Control = %Root
@onready var _rating: Label = %RatingLabel
@onready var _lines: VBoxContainer = %Lines
@onready var _total: Label = %TotalLabel
@onready var _best: Label = %BestLabel
@onready var _again: Button = %AgainButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_again.pressed.connect(func() -> void: again_pressed.emit())
	_menu.pressed.connect(func() -> void: menu_pressed.emit())


func show_results(results: Array[DeliveryResult], earned: int, best: int, is_new_best: bool) -> void:
	for child: Node in _lines.get_children():
		child.queue_free()
	var star_total: int = 0
	for result: DeliveryResult in results:
		star_total += result.stars
		var line := Label.new()
		line.text = "%s   %s   €%d" % [_place_name(result), DeliveryHud.stars_text(result.stars), result.total()]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lines.add_child(line)
	var average: int = roundi(float(star_total) / maxi(results.size(), 1))
	_rating.text = DeliveryHud.stars_text(average)
	_total.text = "Earned this shift: €%d" % earned
	_best.text = "New best shift!" if is_new_best else "Best shift: €%d" % best
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_again.grab_focus()


func _place_name(result: DeliveryResult) -> String:
	var mission: MissionData = result.mission
	return mission.title if mission != null else "?"
