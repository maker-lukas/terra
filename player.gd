extends CharacterBody2D

@onready var cayote_timer: Timer = $CayoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer

@export var jump_height: float = -230.0
@export var max_speed: float = 80.0

const max_gravity: float = 14.5
const acceleration: float = 8.0
const friction: float = 10.0

var gravity: float = 12.0
var cayote_time_activated: bool = false
 
func _ready() -> void:
	for child in $HeadNudges.get_children():
		child.add_exception(self)
	for child in $LedgeHop.get_children():
		child.add_exception(self)



func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("KeyLeft", "KeyRight")
	var velocity_weight: float = delta * (acceleration if direction else friction)

	velocity.x = lerp(velocity.x, direction * max_speed, velocity_weight)

	if is_on_floor():
		cayote_time_activated = false
		gravity = lerp(gravity, 12.0, 12.0 * delta)
	else:
		if cayote_timer.is_stopped() and not cayote_time_activated:
			cayote_timer.start()
			cayote_time_activated = true

		if Input.is_action_just_released("KeyJump") or is_on_ceiling():
			velocity.y *=  0.5

		gravity = lerp(gravity, max_gravity, 12.0 * delta)

	if Input.is_action_just_pressed("KeyJump"):
		if jump_buffer_timer.is_stopped():
			jump_buffer_timer.start()

	if not jump_buffer_timer.is_stopped() and (not cayote_timer.is_stopped() or is_on_floor()):
		velocity.y = jump_height
		jump_buffer_timer.stop()
		cayote_timer.stop()
		cayote_time_activated = true

	if velocity.y < jump_height/2.0:
		var head_collision: Array = [%LeftHeadNudge.is_colliding(), %LeftHeadNudge2.is_colliding(), %RightHeadNudge.is_colliding(), %RightHeadNudge2.is_colliding()]

		if head_collision.count(true) == 1:
			if head_collision[0]:
				global_position.x += 1.75
			if head_collision[2]:
				global_position.x -= 1.75

	if velocity.y > -30  and velocity.y < -5 and abs(velocity.x) > 3:
		if %LeftLedgeHop.is_colliding() and not %LeftLedgeHop2.is_colliding() and velocity.x < 0:
			velocity.y += jump_height/3.25
		if %RightLedgeHop.is_colliding() and not %RightLedgeHop2.is_colliding() and velocity.x > 0:
			velocity.y += jump_height/3.25


	velocity.y += gravity
	move_and_slide()
