extends CharacterBody2D

@export var speed: float = 250.0
@export var jump_velocity: float = -350.0
@export var gravity: float = 1200.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5


func _physics_process(delta: float) -> void:
	
	velocity.x = speed
	velocity.y += gravity * delta
		
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_velocity
		
	if Input.is_action_just_released("Jump") and velocity.y <0.0:
		velocity.y *= jump_cut_multiplier
	
	move_and_slide()
