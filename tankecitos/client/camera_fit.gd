extends Camera2D
## Cámara que sigue a tu tanque: siempre queda en el centro de la pantalla.
## El zoom es el mismo en todos los mapas (el de la arena original), salvo en los
## mapas más chicos que eso, donde se ajusta para que quepan enteros.

# Zona visible por defecto: la arena original (2000x1000 más medio muro alrededor)
const BASE_VIEW := Vector2(2100, 1100)

## Nodo a seguir (la vista de tu tanque); client.gd lo actualiza. Mientras estás muerto
## la cámara se queda donde estaba.
var target: Node2D

var _view_size := BASE_VIEW


func _ready() -> void:
	# Procesar después de los TankView: si no, la cámara va un fotograma por detrás y tiembla
	process_priority = 100
	get_viewport().size_changed.connect(_fit)
	_fit()


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position


## client.gd lo llama al cargar cada mapa
func set_view_size(map_view_size: Vector2) -> void:
	_view_size = Vector2(minf(map_view_size.x, BASE_VIEW.x), minf(map_view_size.y, BASE_VIEW.y))
	_fit()


func _fit() -> void:
	var available := get_viewport_rect().size
	zoom = Vector2.ONE * minf(available.x / _view_size.x, available.y / _view_size.y)
