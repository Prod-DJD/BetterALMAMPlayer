## A drawn instrument icon (see [Icons]) that can be clicked.
class_name IconView
extends Control

signal clicked

var kind := "generic":
	set(v):
		kind = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()

func _init(size_px := 30.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.14 if selected else 0.07)
	bg.set_corner_radius_all(7)
	bg.anti_aliasing = true
	if selected:
		bg.border_color = tint
		bg.set_border_width_all(2)
	draw_style_box(bg, r)
	Icons.draw(self, kind, r.grow(-size.x * 0.17), tint)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
