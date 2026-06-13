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
@onready var destroy_timer: Timer = $destroy_timer
@onready var collapse_timer: Timer = $collapse_timer
@onready var refill_timer: Timer = $refill_timer

# === B1: PUNTaje ===
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
			var rand = randi_range(0, possible_pieces.size() - 1)
			var piece = possible_pieces[rand].instantiate()
			var max_loops = 100
			var loops = 0
			while (match_at(i, j, piece.color) and loops < max_loops):
				rand = randi_range(0, possible_pieces.size() - 1)
				loops += 1
				piece = possible_pieces[rand].instantiate()
			add_child(piece)
			piece.position = grid_to_pixel(i, j)
			all_pieces[i][j] = piece

func match_at(i, j, color):
	if i > 1:
		if all_pieces[i - 1][j] != null and all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].color == color and all_pieces[i - 2][j].color == color:
				return true
	if j > 1:
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

func _process(_delta):
	if state == MOVE:
		touch_input()

# ============================================================
# M3: Detección de combinaciones con soporte para 4 y 5 en línea
# ============================================================
func find_matches():
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

# ============================================================
# B1: Destruir piezas combinadas + puntaje
# ============================================================
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
				var rand = randi_range(0, possible_pieces.size() - 1)
				var piece = possible_pieces[rand].instantiate()
				var max_loops = 100
				var loops = 0
				while (match_at(i, j, piece.color) and loops < max_loops):
					rand = randi_range(0, possible_pieces.size() - 1)
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.position = grid_to_pixel(i, j - y_offset)
				piece.move(grid_to_pixel(i, j))
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

# ============================================================
# M1: Verificar objetivo del nivel
# ============================================================
func _check_level_objective():
	var obj_tipo = level_config.get("objetivo_tipo", -1)
	var obj_valor = level_config.get("objetivo_valor", 0)
	var won = false

	match obj_tipo:
		LevelConfig.Objetivo.PUNTAJE:
			won = score >= obj_valor
		LevelConfig.Objetivo.RECOLECTAR_COLOR:
			var count = collected_pieces.get(level_config.get("objetivo_color", ""), 0)
			won = count >= obj_valor

	if won:
		_on_level_won()
	elif moves_remaining <= 0:
		_on_level_lost()

func _on_level_won():
	if score > best_score:
		best_score = score
	current_level += 1
	if current_level >= LevelConfig.get_level_count():
		current_level = 0
	_save_progress()
	game_finished.emit(true)
	snd_victory.play()
	_show_game_over(true)

func _on_level_lost():
	if score > best_score:
		best_score = score
	_save_progress()
	game_finished.emit(false)
	snd_gameover.play()
	_show_game_over(false)

# ============================================================
# B2: Consumir jugada
# ============================================================
func _consume_move():
	if moves_remaining > 0:
		moves_remaining -= 1
		counter_changed.emit(moves_remaining)

# ============================================================
# M3: Activar piezas especiales
# ============================================================
func _activate_specials(piece_a, piece_b):
	var type_a = piece_a.special_type
	var type_b = piece_b.special_type

	if type_a != "" and type_b != "":
		_combine_specials(piece_a, piece_b)
	elif type_a != "":
		_use_special(piece_a, piece_b)
	else:
		_use_special(piece_b, piece_a)

	piece_a.matched = true
	piece_a.dim()
	piece_b.matched = true
	piece_b.dim()

	move_checked = true
	destroy_timer.start()

func _use_special(special_piece, target_piece):
	match special_piece.special_type:
		"row":
			var r = _get_piece_row(special_piece)
			if r >= 0:
				for i in width:
					if all_pieces[i][r] != null:
						all_pieces[i][r].matched = true
						all_pieces[i][r].dim()
		"column":
			var c = _get_piece_col(special_piece)
			if c >= 0:
				for j in height:
					if all_pieces[c][j] != null:
						all_pieces[c][j].matched = true
						all_pieces[c][j].dim()
		"rainbow":
			var target_color = target_piece.color
			for i in width:
				for j in height:
					if all_pieces[i][j] != null and all_pieces[i][j].color == target_color:
						all_pieces[i][j].matched = true
						all_pieces[i][j].dim()

func _combine_specials(piece_a, piece_b):
	_use_special(piece_a, piece_b)
	_use_special(piece_b, piece_a)

func _get_piece_row(piece: Node2D) -> int:
	for j in height:
		for i in width:
			if all_pieces[i][j] == piece:
				return j
	return -1

func _get_piece_col(piece: Node2D) -> int:
	for i in width:
		for j in height:
			if all_pieces[i][j] == piece:
				return i
	return -1

# ============================================================
# M2: Detección de bloqueo + rebarajado
# ============================================================
func _check_board_lock():
	if not _hay_jugadas_validas():
		_rebarajar()

func _hay_jugadas_validas() -> bool:
	for i in width:
		for j in height:
			if i < width - 1:
				_swap_in_array(i, j, i + 1, j)
				var has_match = _board_has_match()
				_swap_in_array(i, j, i + 1, j)
				if has_match:
					return true
			if j < height - 1:
				_swap_in_array(i, j, i, j + 1)
				var has_match = _board_has_match()
				_swap_in_array(i, j, i, j + 1)
				if has_match:
					return true
	return false

func _swap_in_array(c1, r1, c2, r2):
	var temp = all_pieces[c1][r1]
	all_pieces[c1][r1] = all_pieces[c2][r2]
	all_pieces[c2][r2] = temp

func _board_has_match() -> bool:
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				var c = all_pieces[i][j].color
				if i > 1 and all_pieces[i-1][j] != null and all_pieces[i-2][j] != null:
					if all_pieces[i-1][j].color == c and all_pieces[i-2][j].color == c:
						return true
				if j > 1 and all_pieces[i][j-1] != null and all_pieces[i][j-2] != null:
					if all_pieces[i][j-1].color == c and all_pieces[i][j-2].color == c:
						return true
	return false

func _rebarajar():
	var all_pcs: Array = []
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				all_pcs.append(all_pieces[i][j])

	var max_attempts = 100
	for attempt in max_attempts:
		all_pcs.shuffle()
		var idx = 0
		for i in width:
			for j in height:
				all_pieces[i][j] = all_pcs[idx]
				all_pieces[i][j].position = grid_to_pixel(i, j)
				idx += 1
		if _hay_jugadas_validas():
			return

# ============================================================
# B3: Game Over overlay + reinicio
# ============================================================
func _show_game_over(won: bool):
	state = WAIT

	game_over_overlay = CanvasLayer.new()
	game_over_overlay.layer = 10

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_overlay.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -150
	vbox.offset_right = 150
	vbox.offset_top = -120
	vbox.offset_bottom = 120
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	game_over_overlay.add_child(vbox)

	var title = Label.new()
	title.text = "¡Victoria!" if won else "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var score_lbl = Label.new()
	score_lbl.text = "Puntaje: " + str(score)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(score_lbl)

	if level_config.get("objetivo_tipo", -1) == LevelConfig.Objetivo.RECOLECTAR_COLOR:
		var obj_color = level_config.get("objetivo_color", "")
		var count = collected_pieces.get(obj_color, 0)
		var obj_valor = level_config.get("objetivo_valor", 0)
		var obj_lbl = Label.new()
		obj_lbl.text = obj_color + ": " + str(count) + " / " + str(obj_valor)
		obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obj_lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(obj_lbl)

	var restart_btn = Button.new()
	restart_btn.text = "Reiniciar"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)

	var next_btn = Button.new()
	next_btn.text = "Siguiente Nivel"
	next_btn.custom_minimum_size = Vector2(200, 50)
	next_btn.visible = won
	next_btn.pressed.connect(_on_next_level_pressed)
	vbox.add_child(next_btn)

	add_child(game_over_overlay)

func _on_restart_pressed():
	if game_over_overlay:
		game_over_overlay.queue_free()
		game_over_overlay = null
	score = 0
	combo_count = 0
	_load_level()
	_clear_board()
	spawn_pieces()
	state = MOVE
	score_changed.emit(score)
	counter_changed.emit(moves_remaining)
	if get_parent().get_node_or_null("top_ui"):
		get_parent().get_node("top_ui").set_level_info(level_config)

func _on_next_level_pressed():
	if game_over_overlay:
		game_over_overlay.queue_free()
		game_over_overlay = null
	score = 0
	combo_count = 0
	_load_level()
	_clear_board()
	spawn_pieces()
	state = MOVE
	score_changed.emit(score)
	counter_changed.emit(moves_remaining)
	if get_parent().get_node_or_null("top_ui"):
		get_parent().get_node("top_ui").set_level_info(level_config)

func _clear_board():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				all_pieces[i][j].queue_free()
				all_pieces[i][j] = null

func _on_destroy_timer_timeout():
	destroy_matched()

func _on_collapse_timer_timeout():
	collapse_columns()

func _on_refill_timer_timeout():
	refill_columns()

func game_over():
	state = WAIT
	_show_game_over(false)
