extends SceneTree
func _initialize() -> void:
	var bad := 0
	for k in IconData.SHAPES:
		var i := 0
		for s in IconData.SHAPES[k]:
			if s[0] == "f":
				var flat: Array = s[1]
				var pts := PackedVector2Array()
				for j in range(0, flat.size(), 2):
					pts.append(Vector2(flat[j], flat[j + 1]))
				if Geometry2D.triangulate_polygon(pts).is_empty():
					print("BAD ", k, " shape ", i, " points ", pts.size())
					bad += 1
			i += 1
	print("bad polygons: ", bad)
	quit()
