extends Area2D

signal player_fell

@export var restart_delay: float = 0.4

var _triggered := false


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	player_fell.emit()
	_restart()

func _restart() -> void:
	await get_tree().create_timer(restart_delay).timeout
	get_tree().reload_current_scene()
