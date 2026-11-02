extends Node
## Prueba de lógica de combate sin red: disparo, recarga, daño, muerte,
## reaparición, protección y pared delante del cañón.
## Ejecutar:  godot --headless --path . res://tests/combat_test.tscn

const ARENA := preload("res://maps/Arena.tscn")
const TANK_SCENE := preload("res://server/ServerTank.tscn")
const BULLET_SCENE := preload("res://server/ServerBullet.tscn")

var _failures := 0
var _bullets_fired := 0
var _respawn_requests := 0


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	world.add_child(ARENA.instantiate())

	var shooter := _make_tank(world, 10, 0)
	var target := _make_tank(world, 20, 1)
	await _ticks(3)
	shooter.spawn(Vector2(-400, -400))
	target.spawn(Vector2(400, -400))
	await _ticks(3)

	# 1. Un tanque protegido absorbe la bala sin daño
	shooter.protection_left = 0.0
	shooter.request_fire(0.0)
	await _seconds(1.8)
	_check(_bullets_fired == 1, "shooter fired one bullet")
	_check(target.hp == GameConfig.TANK_MAX_HP, "protected target takes no damage")

	# 2. Sin protección, la bala daña
	target.protection_left = 0.0
	await _seconds(GameConfig.FIRE_COOLDOWN)
	shooter.request_fire(0.0)
	await _seconds(1.8)
	_check(_bullets_fired == 2, "second bullet after cooldown")
	_check(target.hp == GameConfig.TANK_MAX_HP - 1, "unprotected target loses 1 hp (hp=%d)" % target.hp)

	# 3. La recarga bloquea disparos seguidos
	var before := _bullets_fired
	await _seconds(GameConfig.FIRE_COOLDOWN)
	shooter.request_fire(0.0)
	shooter.request_fire(0.0)
	await _ticks(3)
	_check(_bullets_fired == before + 1, "cooldown blocks the second immediate shot")

	# 4. Muerte, tanque sin colisión y reaparición
	target.take_damage(100)
	_check(not target.alive, "target dies at 0 hp")
	await _ticks(3)
	_check(target._shape.disabled, "dead tank has collision disabled")
	var requests_before := _respawn_requests
	await _seconds(GameConfig.RESPAWN_TIME + 0.2)
	_check(_respawn_requests > requests_before, "respawn is requested after RESPAWN_TIME")
	_check(target.alive and target.hp == GameConfig.TANK_MAX_HP, "tank respawns alive with full hp")
	_check(target.protection_left > 0.0, "respawned tank is protected")

	# 5. Disparar cancela la protección propia
	target.request_fire(PI)
	await _ticks(3)
	_check(target.protection_left == 0.0, "firing cancels spawn protection")

	# 6. Con una pared pegada al cañón no sale bala
	var blocked := _make_tank(world, 30, 2)
	await _ticks(3)
	blocked.spawn(Vector2(0, -440))
	await _ticks(3)
	var count := _bullets_fired
	blocked.request_fire(-PI / 2.0)
	await _ticks(3)
	_check(_bullets_fired == count, "no bullet is created inside a wall")

	# 7. Input inválido se ignora y el input caduca
	blocked.apply_input(Vector2(NAN, 0), 0.0)
	_check(blocked._move_input == Vector2.ZERO, "NaN input is rejected")
	blocked.apply_input(Vector2(5, 0), 0.0)
	_check(blocked._move_input.length() <= 1.0001, "move input is clamped to length 1")
	await _seconds(GameConfig.INPUT_TIMEOUT + 0.2)
	_check(blocked._move_input == Vector2.ZERO, "stale input times out")


func _make_tank(parent: Node, id: int, slot: int) -> ServerTank:
	var tank := TANK_SCENE.instantiate() as ServerTank
	tank.peer_id = id
	tank.slot = slot
	tank.bullet_requested.connect(_on_bullet_requested)
	tank.respawn_requested.connect(_on_respawn_requested)
	parent.add_child(tank)
	return tank


func _on_bullet_requested(tank: ServerTank, origin: Vector2, direction: Vector2) -> void:
	_bullets_fired += 1
	var bullet := BULLET_SCENE.instantiate() as ServerBullet
	bullet.owner_id = tank.peer_id
	bullet.owner_slot = tank.slot
	tank.get_parent().add_child(bullet)
	bullet.launch(origin, direction)


func _on_respawn_requested(tank: ServerTank) -> void:
	_respawn_requests += 1
	tank.spawn(Vector2(400, -400))


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await _ticks(int(ceil(seconds * Engine.physics_ticks_per_second)))


func _check(condition: bool, label: String) -> void:
	print(("  ok    " if condition else "  FAIL  "), label)
	if not condition:
		_failures += 1
