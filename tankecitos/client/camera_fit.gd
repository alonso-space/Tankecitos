extends Camera2D
## Ajusta el zoom para que todo el mapa quepa siempre en la ventana,
## sea un monitor, un teléfono o una ventana redimensionada.

# Zona a mostrar: el área jugable (2000x1000) más medio muro alrededor
const VIEW_SIZE := Vector2(2100, 1100)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var available := get_viewport_rect().size
	zoom = Vector2.ONE * minf(available.x / VIEW_SIZE.x, available.y / VIEW_SIZE.y)
