class_name LevelConfig
extends Resource

enum Objetivo { PUNTAJE, RECOLECTAR_COLOR }

@export var nombre: String = "Nivel 1"
@export var objetivo_tipo: Objetivo = Objetivo.PUNTAJE
@export var objetivo_valor: int = 1000
@export var objetivo_color: String = "blue"
@export var limite_movimientos: int = 20
@export var limite_segundos: int = 0
@export var colores_disponibles: Array[String] = [
	"blue", "green", "light_green", "pink", "yellow", "orange",
]

static func get_level_count() -> int:
	var i = 0
	while FileAccess.file_exists("res://levels/level_%d.json" % i):
		i += 1
	return max(i, 1)

static func get_level(index: int) -> Dictionary:
	var path = "res://levels/level_%d.json" % index
	if not FileAccess.file_exists(path):
		path = "res://levels/level_0.json"
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.data
	# Castear explícitamente para evitar que JSON devuelva floats en lugar de ints
	return {
		"nombre": str(data.get("nombre", "Nivel")),
		"objetivo_tipo": int(data.get("objetivo_tipo", 0)),
		"objetivo_valor": int(data.get("objetivo_valor", 1000)),
		"objetivo_color": str(data.get("objetivo_color", "")),
		"limite_movimientos": int(data.get("limite_movimientos", 20)),
		"limite_segundos": int(data.get("limite_segundos", 0)),
		"colores": data.get("colores", ["blue", "green", "light_green", "pink", "yellow", "orange"]),
	}