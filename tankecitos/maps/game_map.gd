extends Node2D
## Datos de un mapa. Cada escena de mapa lleva este script en su raíz.
## El servidor lee de aquí la categoría (para elegir mapa según los jugadores)
## y los puntos de aparición; el cliente, el tamaño para encuadrar la cámara.
##
## Estructura esperada de la escena (todos los nodos son opcionales salvo los muros):
##   Background  suelo            Decor      adornos del suelo (sin colisión)
##   Walls       borde y muros    Obstacles  obstáculos (color propio, ver obstacle_color)
##   DecorTop    adornos por encima de los muros (sin colisión)

enum MapSize { MINI, SMALL, MEDIUM, LARGE }

## Jugadores máximos por categoría: MINI 1-4, SMALL 5-8, MEDIUM 9-12, LARGE 13-16
const CAPACITY: Array[int] = [4, 8, 12, 16]
## Grosor del borde (Wall.tscn mide 100x100)
const BORDER := 100.0

@export var display_name := ""
## Flag que clasifica el mapa; decide con cuántos jugadores se puede elegir
@export var size_category: MapSize = MapSize.SMALL
## Área jugable (sin contar el borde), centrada en (0, 0)
@export var play_size := Vector2(2000, 1000)
## Debe haber al menos CAPACITY[size_category] puntos, bien separados de los muros
@export var spawn_points := PackedVector2Array()
@export var wall_color := Color(0.5019608, 0.5019608, 0.5019608)
@export var obstacle_color := Color(0.5019608, 0.5019608, 0.5019608)


## Categoría que corresponde a esa cantidad de jugadores (0 jugadores cuenta como MINI)
static func size_for_players(player_count: int) -> MapSize:
	for size in CAPACITY.size():
		if player_count <= CAPACITY[size]:
			return size as MapSize
	return MapSize.LARGE


func capacity() -> int:
	return CAPACITY[size_category]


## Zona que debe ver la cámara: el área jugable más medio muro alrededor
func view_size() -> Vector2:
	return play_size + Vector2.ONE * BORDER


func _ready() -> void:
	_tint(get_node_or_null("Walls"), wall_color)
	_tint(get_node_or_null("Obstacles"), obstacle_color)


# Wall.tscn es gris; cada mapa lo pinta de su color sin necesitar un Wall por color
func _tint(container: Node, color: Color) -> void:
	if container == null:
		return
	for wall in container.get_children():
		var rect := wall.get_node_or_null("ColorRect") as ColorRect
		if rect != null:
			rect.color = color
