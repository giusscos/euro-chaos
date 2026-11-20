class_name GarageScreen
extends CanvasLayer
## Buy and pick vehicles. Rows are built from the catalog; ratings come from
## each vehicle's stats.

signal closed
signal vehicle_selected(id: StringName)

@onready var _root: Control = %Root
@onready var _money: Label = %MoneyLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _close: Button = %CloseButton

var _garage: Garage


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_close.pressed.connect(close)


func open(garage: Garage) -> void:
	_garage = garage
	_root.visible = true
	_refresh()
	_close.grab_focus()


func close() -> void:
	_root.visible = false
	closed.emit()


func is_open() -> bool:
	return _root.visible


func _refresh() -> void:
	_money.text = "€ %d" % GameState.money
	for child: Node in _rows.get_children():
		child.queue_free()
	var selected_id: StringName = _garage.selected().id
	for vehicle: VehicleDefinition in _garage.catalog.vehicles:
		_rows.add_child(_make_row(vehicle, selected_id))


func _make_row(vehicle: VehicleDefinition, selected_id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = vehicle.display_name
	title.add_theme_font_size_override(&"font_size", 32)
	info.add_child(title)
	var description := Label.new()
	description.text = vehicle.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(620, 0)
	description.modulate = Color(1, 1, 1, 0.75)
	description.add_theme_font_size_override(&"font_size", 20)
	info.add_child(description)
	var ratings: Dictionary = vehicle.ratings()
	var parts: PackedStringArray = []
	for key: String in ratings:
		parts.append("%s %s" % [key, DeliveryHud.stars_text(int(ratings[key]))])
	parts.append("Alleys: %s" % ("yes" if vehicle.fits_alleys else "no"))
	var stats_label := Label.new()
	stats_label.text = "   ".join(parts)
	stats_label.add_theme_font_size_override(&"font_size", 18)
	stats_label.modulate = Color(1, 0.88, 0.5)
	info.add_child(stats_label)
	row.add_child(info)
	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 0)
	if vehicle.id == selected_id:
		button.text = "Selected"
		button.disabled = true
	elif _garage.owns(vehicle.id):
		button.text = "Select"
		button.pressed.connect(func() -> void:
			_garage.select(vehicle.id)
			vehicle_selected.emit(vehicle.id)
			_refresh())
	else:
		button.text = "Buy  €%d" % vehicle.price
		button.disabled = GameState.money < vehicle.price
		button.pressed.connect(func() -> void:
			if _garage.buy(vehicle.id):
				AudioManager.play(&"deliver")
				_garage.select(vehicle.id)
				vehicle_selected.emit(vehicle.id)
			_refresh())
	row.add_child(button)
	return row
