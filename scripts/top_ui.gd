extends TextureRect

@onready var score_label = $MarginContainer/HBoxContainer/score_label
@onready var counter_label = $MarginContainer/HBoxContainer/counter_label
@onready var objective_label = $MarginContainer/HBoxContainer/HBoxContainer/objective_label

var current_score = 0
var current_count = 0

func _ready():
	var font = load("res://assets/fonts/Kenney Blocks.ttf")
	var settings = LabelSettings.new()
	settings.font = font
	settings.font_size = 22
	settings.font_color = Color(0.08, 0.08, 0.08, 1)
	objective_label.label_settings = settings

func update_score(nuevo_puntaje: int) -> void:
	current_score = nuevo_puntaje
	score_label.text = str(current_score)

func update_counter(restantes: int) -> void:
	current_count = restantes
	counter_label.text = str(current_count)

func update_game_over(_won: bool) -> void:
	pass

func update_objective_progress(current: int, target: int) -> void:
	if objective_label:
		objective_label.text = objective_label.text.split(":")[0] + ": " + str(current) + "/" + str(target)

func set_level_info(config: Dictionary) -> void:
	if objective_label == null:
		return
	var obj_tipo = config.get("objetivo_tipo", -1)
	match obj_tipo:
		LevelConfig.Objetivo.PUNTAJE:
			var meta = config.get("objetivo_valor", 0)
			objective_label.text = "Meta: " + str(meta) + " pts"
		LevelConfig.Objetivo.RECOLECTAR_COLOR:
			var color = config.get("objetivo_color", "")
			var meta = config.get("objetivo_valor", 0)
			objective_label.text = color + ": 0/" + str(meta)
		_:
			objective_label.text = ""
