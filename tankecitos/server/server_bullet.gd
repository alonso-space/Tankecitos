class_name ServerBullet
extends CharacterBody2D
## Bala del servidor. Rebota en las paredes (y en tanques propios) y daña a
## cualquier tanque ajeno, igual que en el juego original.

var id := 0  # identificador para los snapshots (el cliente lo usa para seguir cada bala)
var owner_id := 0  # peer id del tanque que disparó
var owner_slot := 0

var _life := GameConfig.BULLET_LIFETIME


func launch(origin: Vector2, direction: Vector2) -> void:
	position = origin
	velocity = direction * GameConfig.BULLET_SPEED


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return

	var target := collision.get_collider() as ServerTank
	if target != null and target.alive and target.peer_id != owner_id:
		target.take_damage(GameConfig.BULLET_DAMAGE)  # él mismo ignora el daño si está protegido
		queue_free()
		return

	velocity = velocity.bounce(collision.get_normal()).normalized() * GameConfig.BULLET_SPEED
