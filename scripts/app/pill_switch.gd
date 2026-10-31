## An on/off switch: a pill with a knob that slides across. Used to show or
## hide a track.
class_name PillSwitch
extends Control

signal toggled(on: bool)

const ACCENT := Color("f7b955")

var button_pressed := false
var _t := 0.0:
	set(v):
		_t = v
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(38, 22)
	size_flags_vertical = SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE # so the space bar keeps playing and pausing

## Sets it without announcing the change (and without sliding).
func set_pressed_no_signal(on: bool) -> void:
	button_pressed = on
	_t = 1.0 if on else 0.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		button_pressed = not button_pressed
		create_tween().tween_property(self, "_t", 1.0 if button_pressed else 0.0, 0.14) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggled.emit(button_pressed)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14).lerp(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.95), _t)
	track.set_corner_radius_all(int(size.y / 2.0))
	track.anti_aliasing = true
	draw_style_box(track, r)
	var knob_r := size.y / 2.0 - 3.0
	var x := lerpf(size.y / 2.0, size.x - size.y / 2.0, _t)
	draw_circle(Vector2(x, size.y / 2.0), knob_r, Color(1, 1, 1, 0.85).lerp(Color(0.12, 0.1, 0.08), _t), true, -1.0, true)
