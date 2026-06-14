extends Node2D

@export var color: String

var matched = false
var special_type: String = ""

func move(target):
	var move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_ELASTIC)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "position", target, 0.4)

func dim():
	$Sprite2D.modulate = Color(1, 1, 1, 0.5)

func set_special(type: String):
	special_type = type
	match type:
		"row":
			$Sprite2D.texture = load("res://assets/pieces/" + _color_to_display(color) + " Row.png")
		"column":
			$Sprite2D.texture = load("res://assets/pieces/" + _color_to_display(color) + " Column.png")
		"rainbow":
			$Sprite2D.texture = load("res://assets/pieces/Rainbow.png")

func clear_special():
	special_type = ""
	match color:
		"blue": $Sprite2D.texture = load("res://assets/pieces/Blue Piece.png")
		"green": $Sprite2D.texture = load("res://assets/pieces/Green Piece.png")
		"light_green": $Sprite2D.texture = load("res://assets/pieces/Light Green Piece.png")
		"pink": $Sprite2D.texture = load("res://assets/pieces/Pink Piece.png")
		"yellow": $Sprite2D.texture = load("res://assets/pieces/Yellow Piece.png")
		"orange": $Sprite2D.texture = load("res://assets/pieces/Orange Piece.png")

func _color_to_display(c: String) -> String:
	var words = c.split("_")
	var result = ""
	for w in words:
		result += w.capitalize() + " "
	return result.strip_edges()
