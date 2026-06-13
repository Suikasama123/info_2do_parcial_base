extends Node2D

# state machine
enum {WAIT, MOVE}
var state

# grid
@export var width: int
@export var height: int
@export var x_start: int
@export var y_start: int
@export var offset: int
@export var y_offset: int

# piece array
var possible_pieces = [
	preload("res://scenes/blue_piece.tscn"),
	preload("res://scenes/green_piece.tscn"),
	preload("res://scenes/light_green_piece.tscn"),
	preload("res://scenes/pink_piece.tscn"),
	preload("res://scenes/yellow_piece.tscn"),
	preload("res://scenes/orange_piece.tscn"),
]
# current pieces in scene
var all_pieces = []

# swap back
var piece_one = null
var piece_two = null
var last_place = Vector2.ZERO
var last_direction = Vector2.ZERO
var move_checked = false

# touch variables
var first_touch = Vector2.ZERO
var final_touch = Vector2.ZERO
var is_controlling = false

# === Temporizadores del ciclo destruir → colapsar → rellenar ===
# Son nodos hijos de "grid"; el editor conecta sus señales "timeout" a este script.
@onready var destroy_timer: Timer = $destroy_timer
@onready var collapse_timer: Timer = $collapse_timer
@onready var refill_timer: Timer = $refill_timer

# === PUNTAJE (B1) y CONTADOR (B2) ===
# Contrato sugerido para comunicarte con el HUD (top_ui.gd). No es obligatorio usar
# señales, pero ayuda a mantener la UI desacoplada de la lógica del tablero:
#   signal score_changed(nuevo_puntaje: int)
#   signal counter_changed(restantes: int)        # movimientos o segundos, tú decides
#   signal game_finished(gano: bool)
# TODO (PARCIAL · B1/B2): declara aquí el puntaje y el contador (y sus señales, si las usas).

signal score_changed(new_score: int)
var score: int = 0

# === B2: CONTADOR de movimientos ===
signal counter_changed(remaining: int)
var moves_remaining: int = 20

# === B3: Game finished ===
signal game_finished(won: bool)

# === M1: Sistema de niveles ===
signal objective_progress(current: int, target: int)
var current_level: int = 0
var level_config: Dictionary = {}
var collected_pieces: Dictionary = {}

# === M4: Persistencia ===
var best_score: int = 0

# === B4: Sonidos ===
var snd_swap: AudioStreamPlayer
var snd_match: AudioStreamPlayer
var snd_invalid: AudioStreamPlayer
var snd_special: AudioStreamPlayer
var snd_victory: AudioStreamPlayer
var snd_gameover: AudioStreamPlayer

# === M3: Piezas especiales pendientes de crear ===
var pending_specials: Array = []

# === Combo (cascada) ===
var combo_count: int = 0

# === UI overlay para game over ===
var game_over_overlay: CanvasLayer = null

func _ready():
	state = MOVE
	randomize()
	all_pieces = make_2d_array()
	_init_sounds()
	_load_progress()
	_load_level()
	spawn_pieces()
	call_deferred("_connect_ui")

func _init_sounds():
	snd_swap = AudioStreamPlayer.new()
	snd_swap.stream = load("res://assets/sounds/Match 3 Sounds/Sounds/1.ogg")
	add_child(snd_swap)

	snd_match = AudioStreamPlayer.new()
	snd_match.stream = load("res://assets/sounds/Match 3 Sounds/Sounds/3.ogg")
	add_child(snd_match)

	snd_invalid = AudioStreamPlayer.new()
	snd_invalid.stream = load("res://assets/sounds/Match 3 Sounds/Sounds/4.ogg")
	add_child(snd_invalid)

	snd_special = AudioStreamPlayer.new()
	snd_special.stream = load("res://assets/sounds/Match 3 Sounds/Sounds/5.ogg")
	add_child(snd_special)

	snd_victory = AudioStreamPlayer.new()
	snd_victory.stream = load("res://assets/sounds/Match 3 Sounds/Sounds/7.ogg")
	add_child(snd_victory)

	snd_gameover = AudioStreamPlayer.new()
	snd_gameover.stream = load("res://assets/sounds/Match 3 Sounds/Sounds/6.ogg")
	add_child(snd_gameover)

func _connect_ui():
	var ui = get_parent().get_node("top_ui")
	if ui:
		score_changed.connect(ui.update_score)
		counter_changed.connect(ui.update_counter)
		game_finished.connect(ui.update_game_over)
		objective_progress.connect(ui.update_objective_progress)
		ui.set_level_info(level_config)

func _load_progress():
	var save_path = "user://save_game.json"
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err == OK:
			current_level = json.data.get("current_level", 0)
			best_score = json.data.get("best_score", 0)

func _save_progress():
	var save_data = {
		"current_level": current_level,
		"best_score": best_score,
	}
	var file = FileAccess.open("user://save_game.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()

func _load_level():
	level_config = LevelConfig.get_level(current_level)
	moves_remaining = level_config["limite_movimientos"]
	collected_pieces = {}
	combo_count = 0
	score = 0

func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start - offset * row
	return Vector2(new_x, new_y)

func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)

func in_grid(column, row):
	return column >= 0 and column < width and row >= 0 and row < height

	
func spawn_pieces():
	for i in width:
		for j in height:
			# random number
			var rand = randi_range(0, possible_pieces.size() - 1)
			# instance 
			var piece = possible_pieces[rand].instantiate()
			# repeat until no matches
			var max_loops = 100
			var loops = 0
			while (match_at(i, j, piece.color) and loops < max_loops):
				rand = randi_range(0, possible_pieces.size() - 1)
				loops += 1
				piece = possible_pieces[rand].instantiate()
			add_child(piece)
			piece.position = grid_to_pixel(i, j)
			# fill array with pieces
			all_pieces[i][j] = piece

func match_at(i, j, color):
	# check left
	if i > 1:
		if all_pieces[i - 1][j] != null and all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].color == color and all_pieces[i - 2][j].color == color:
				return true
	# check down
	if j> 1:
		if all_pieces[i][j - 1] != null and all_pieces[i][j - 2] != null:
			if all_pieces[i][j - 1].color == color and all_pieces[i][j - 2].color == color:
				return true
	return false

func touch_input():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = pixel_to_grid(mouse_pos.x, mouse_pos.y)
	if Input.is_action_just_pressed("ui_touch") and in_grid(grid_pos.x, grid_pos.y):
		first_touch = grid_pos
		is_controlling = true
		
	# release button
	if Input.is_action_just_released("ui_touch") and in_grid(grid_pos.x, grid_pos.y) and is_controlling:
		is_controlling = false
		final_touch = grid_pos
		touch_difference(first_touch, final_touch)

func swap_pieces(column, row, direction: Vector2, play_snd: bool = true):
	var first_piece = all_pieces[column][row]
	var other_piece = all_pieces[column + direction.x][row + direction.y]
	if first_piece == null or other_piece == null:
		return
	state = WAIT
	store_info(first_piece, other_piece, Vector2(column, row), direction)
	all_pieces[column][row] = other_piece
	all_pieces[column + direction.x][row + direction.y] = first_piece
	first_piece.move(grid_to_pixel(column + direction.x, row + direction.y))
	other_piece.move(grid_to_pixel(column, row))

	if play_snd:
		snd_swap.play()

	if first_piece.special_type != "" or other_piece.special_type != "":
		combo_count = 0
		_activate_specials(first_piece, other_piece)
	elif not move_checked:
		find_matches()

func store_info(first_piece, other_piece, place, direction):
	piece_one = first_piece
	piece_two = other_piece
	last_place = place
	last_direction = direction

func swap_back():
	if piece_one != null and piece_two != null:
		snd_invalid.play()
		swap_pieces(last_place.x, last_place.y, last_direction, false)
	state = MOVE
	move_checked = false

func touch_difference(grid_1, grid_2):
	var difference = grid_2 - grid_1
	# should move x or y?
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(1, 0))
		elif difference.x < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(-1, 0))
	if abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, 1))
		elif difference.y < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, -1))

func _process(delta):
	if state == MOVE:
		touch_input()

func find_matches():
	# TODO (PARCIAL · M3): aquí es donde se decide qué piezas forman cada combinación.
	# Para crear piezas especiales necesitas conocer el LARGO de cada línea: una de 4
	# genera una pieza de línea (fila/columna) y una de 5 una bomba de color. El chequeo
	# actual solo mira el "centro" de tríos; probablemente tengas que recorrer las
	# líneas completas para distinguir combinaciones de 3, 4 y 5.
	
		pending_specials = []
	var matched_positions: Array = []
	var horizontal_lines: Array = []
	var vertical_lines: Array = []

	for j in height:
		var i = 0
		while i < width:
			if all_pieces[i][j] != null:
				var current_color = all_pieces[i][j].color
				var line_length = 1
				var k = i + 1
				while k < width and all_pieces[k][j] != null and all_pieces[k][j].color == current_color:
					line_length += 1
					k += 1
				if line_length >= 3:
					horizontal_lines.append({"start": Vector2i(i, j), "length": line_length})
					for m in range(i, i + line_length):
						var pos = Vector2i(m, j)
						if not _pos_in_array(pos, matched_positions):
							matched_positions.append(pos)
				i = k
			else:
				i += 1

	for i in width:
		var j = 0
		while j < height:
			if all_pieces[i][j] != null:
				var current_color = all_pieces[i][j].color
				var line_length = 1
				var k = j + 1
				while k < height and all_pieces[i][k] != null and all_pieces[i][k].color == current_color:
					line_length += 1
					k += 1
				if line_length >= 3:
					vertical_lines.append({"start": Vector2i(i, j), "length": line_length})
					for m in range(j, j + line_length):
						var pos = Vector2i(i, m)
						if not _pos_in_array(pos, matched_positions):
							matched_positions.append(pos)
				j = k
			else:
				j += 1

	for line in horizontal_lines:
		if line.length >= 5:
			var pos = Vector2i(line.start.x + 2, line.start.y)
			if not _special_at_pos(pos):
				pending_specials.append({"pos": pos, "type": "rainbow"})
		elif line.length == 4:
			var pos = Vector2i(line.start.x + 1, line.start.y)
			if not _special_at_pos(pos):
				pending_specials.append({"pos": pos, "type": "row"})

	for line in vertical_lines:
		if line.length >= 5:
			var pos = Vector2i(line.start.x, line.start.y + 2)
			if not _special_at_pos(pos):
				pending_specials.append({"pos": pos, "type": "rainbow"})
			else:
				_upgrade_special(pos, "rainbow")
		elif line.length == 4:
			var pos = Vector2i(line.start.x, line.start.y + 1)
			if not _special_at_pos(pos):
				pending_specials.append({"pos": pos, "type": "column"})
			else:
				_upgrade_special(pos, "column")

	for pos in matched_positions:
		if all_pieces[pos.x][pos.y] != null:
			all_pieces[pos.x][pos.y].matched = true
			all_pieces[pos.x][pos.y].dim()

	for special in pending_specials:
		var piece = all_pieces[special.pos.x][special.pos.y]
		if piece != null:
			piece.matched = false
			piece.set_special(special.type)

	destroy_timer.start()

func _pos_in_array(pos: Vector2i, array: Array) -> bool:
	for p in array:
		if p == pos:
			return true
	return false

func _special_at_pos(pos: Vector2i) -> bool:
	for s in pending_specials:
		if s.pos == pos:
			return true
	return false

func _upgrade_special(pos: Vector2i, new_type: String):
	for s in pending_specials:
		if s.pos == pos:
			s.type = new_type
			return
	
func destroy_matched():
	var was_matched = false
	var match_count = 0
	for i in width:
		for j in height:
			if all_pieces[i][j] != null and all_pieces[i][j].matched:
				was_matched = true
				match_count += 1
				var piece = all_pieces[i][j]
				if level_config.get("objetivo_tipo", -1) == LevelConfig.Objetivo.RECOLECTAR_COLOR:
					var obj_color = level_config.get("objetivo_color", "")
					if piece.color == obj_color:
						if not collected_pieces.has(piece.color):
							collected_pieces[piece.color] = 0
						collected_pieces[piece.color] += 1
				piece.queue_free()
				all_pieces[i][j] = null

	if was_matched:
		var points = match_count * 50
		var multiplier = 1.0 + combo_count * 0.5
		score += int(points * multiplier)
		score_changed.emit(score)
		_consume_move()
		if level_config.get("objetivo_tipo", -1) == LevelConfig.Objetivo.RECOLECTAR_COLOR:
			var obj_color = level_config.get("objetivo_color", "")
			var count = collected_pieces.get(obj_color, 0)
			var target = level_config.get("objetivo_valor", 0)
			objective_progress.emit(count, target)

	if pending_specials.size() > 0:
		snd_special.play()
	elif was_matched:
		snd_match.play()

	move_checked = true
	if was_matched:
		collapse_timer.start()
	else:
		combo_count = 0
		if state == WAIT:
			swap_back()

func collapse_columns():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				# look above
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						all_pieces[i][k].move(grid_to_pixel(i, j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	refill_timer.start()

func refill_columns():
	
	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				# random number
				var rand = randi_range(0, possible_pieces.size() - 1)
				# instance 
				var piece = possible_pieces[rand].instantiate()
				# repeat until no matches
				var max_loops = 100
				var loops = 0
				while (match_at(i, j, piece.color) and loops < max_loops):
					rand = randi_range(0, possible_pieces.size() - 1)
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.position = grid_to_pixel(i, j - y_offset)
				piece.move(grid_to_pixel(i, j))
				# fill array with pieces
				all_pieces[i][j] = piece
				
	check_after_refill()

func check_after_refill():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null and match_at(i, j, all_pieces[i][j].color):
				combo_count += 1
				find_matches()
				destroy_timer.start()
				return

	combo_count = 0
	_check_level_objective()
	_check_board_lock()
	state = MOVE
	move_checked = false

func _on_destroy_timer_timeout():
	destroy_matched()

func _on_collapse_timer_timeout():
	collapse_columns()

func _on_refill_timer_timeout():
	refill_columns()
	
func game_over():
	state = WAIT
	# TODO (PARCIAL · B3): muestra la pantalla final (victoria o derrota), detén la
	# entrada del jugador y ofrece reiniciar la partida. Emite game_finished(gano).
	# TODO (PARCIAL · M4): guarda el progreso (nivel alcanzado) y el mejor puntaje
	# en disco (user://) para conservarlos entre sesiones.

# TODO (PARCIAL · M2): funciones sugeridas para detectar el bloqueo del tablero.
# func hay_jugadas_validas() -> bool:
# func rebarajar() -> void:
