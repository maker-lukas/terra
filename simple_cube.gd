extends CharacterBody2D
## Geometry Dash style cube — step 2.
##
## What this does:
##   - always runs right
##   - Space jumps, and HOLDING Space keeps jumping on every landing (GD style)
##   - optional variable jump height: release early to cut the jump short
##   - touching anything in the group "hazard" reloads the scene instantly
##
## Scene setup:
##   Player (CharacterBody2D)  <- this script
##   ├── CollisionShape2D
##   └── Hurtbox (Area2D)      <- NEW: give it its own CollisionShape2D
##                               roughly the same size as the cube
##
## For each obstacle: select it, open the Node tab -> Groups -> add "hazard".
##
## Units: velocity is pixels per SECOND, gravity is pixels per second².
## Jump height   = jump_velocity² / (2 * gravity)
## Jump air time = 2 * abs(jump_velocity) / gravity
## Jump distance = speed * air_time
##
## With variable_jump on and jump_cut 0.5, releasing immediately gives you
## half the air time (0.5 × v means 0.5 × air time) and a quarter of the
## height, because height depends on velocity squared.

@export var speed: float = 250.0
@export var jump_velocity: float = -350.0
@export var gravity: float = 1200.0

@export_group("Jump feel")
## Release Jump early to shorten the jump. Set false for fixed GD-style jumps.
@export var variable_jump: bool = true
## 0.5 = tap gives half the air time of a full jump. 1.0 = no cut.
@export var jump_cut: float = 0.5

@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")

var is_dead: bool = false


func _ready() -> void:
	# Connect the signal in code so you don't have to do it in the editor.
	if hurtbox != null:
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	else:
		push_warning("Add an Area2D named 'Hurtbox' under the player to enable death.")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. always move forward
	velocity.x = speed

	# 2. accelerate downward
	velocity.y += gravity * delta

	# 3. jump. is_action_pressed (not just_pressed) means holding the button
	#    makes the cube jump again the moment it lands — that is GD behaviour.
	if Input.is_action_pressed("Jump") and is_on_floor():
		velocity.y = jump_velocity

	# 4. apply velocity and resolve collisions
	move_and_slide()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	# The floor is also a physics body, so only react to the hazard group.
	if is_dead or not body.is_in_group("hazard"):
		return
	die()


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	print("dead")

	# The hurtbox signal arrives during a physics callback, and reloading a
	# scene there is illegal. call_deferred waits until the frame is over.
	get_tree().reload_current_scene.call_deferred()
