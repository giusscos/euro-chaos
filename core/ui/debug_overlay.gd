class_name DebugOverlay
extends CanvasLayer
## On-screen vehicle telemetry and controls help for test scenes.
## Toggle with the debug_toggle_overlay action (O / L3).

@export var vehicle: ArcadeVehicle
@export var visible_on_start: bool = true
@export_multiline var help_text: String = "\n".join([
	"W/S or ↑/↓  throttle / brake + reverse      (RT / LT)",
	"A/D or ←/→  steer                           (left stick)",
	"Space  handbrake   H  horn   R  reset upright",
	"Backspace  respawn   Tab  next vehicle   O  this overlay",
	"Mouse / right stick  look around   Esc / P  pause",
])

@onready var _panel: Control = %Panel
@onready var _stats_label: Label = %StatsLabel
@onready var _help_label: Label = %HelpLabel


func _ready() -> void:
	_panel.visible = visible_on_start
	_help_label.text = help_text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.DEBUG_TOGGLE_OVERLAY):
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var lines: PackedStringArray = ["%d FPS" % Engine.get_frames_per_second()]
	if vehicle != null and is_instance_valid(vehicle):
		var intent: VehicleIntent = vehicle.intent
		var flags: String = ""
		if intent.handbrake:
			flags += "  HANDBRAKE"
		if intent.horn:
			flags += "  HONK!"
		lines.append("Vehicle  %s" % vehicle.name)
		lines.append("Speed  %.0f km/h" % vehicle.get_speed_kmh())
		lines.append("Wheels  %d/%d on ground" % [vehicle.grounded_wheel_count, vehicle.wheels.size()])
		lines.append("Steer  %+.1f°" % rad_to_deg(vehicle.steer_angle))
		lines.append("Input  gas %.2f  brake %.2f  steer %+.2f%s" % [
			intent.throttle, intent.brake, intent.steer, flags])
	_stats_label.text = "\n".join(lines)
