## StarContainer — draws the scrolling stars for MainMenu.
## Attached to the StarContainer Node2D in MainMenu.tscn.
extends Node2D

func _draw() -> void:
	var parent = get_parent() as Control
	if parent == null:
		return
	if not parent.has_method("_scroll_stars"):
		return
	for s in parent._stars:
		var col := Color(s["brightness"], s["brightness"], s["brightness"], 1.0)
		draw_circle(s["pos"], s["size"], col)
