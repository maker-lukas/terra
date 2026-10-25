extends CharacterBody2D

@onready var WallRay: RayCast2D = $WallRay

const jump_height: float = -165.5
const max_speed: float = 64.5
const acceleration: float = 18.5
const friction: float = 22.5

const gravity_normal: float = 14.5
const gravity_wall: float = 8.5
const wall_jump_push_force: float = 100.0

var wall_cantact_coyote: float = 0.0
const wall_contact_coyote_time: float = 0.2

var wall_jump_lock: float = 0.0
const wall_jump_lock_time: float =  0.05

var look_dir_x: int = 1

const climb_speed: float = 26.5
const climb_exit_boost: Vector2 = Vector2(100, -100)
var is_climbing: bool = false

const stamina_amt: float = 3.5
const climb_stamina_drain: float = 2.5
var climb_stamina_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if velocity.x:
		WallRay.target_position.x = 7.25 * sign(velocity.x)
	var on_wall: bool = WallRay.is_colliding() and WallRay.get_collider() is TileMapLayer
	var on_wall_in_air: bool = on_wall and not is_on_floor()

	var x_input: float = Input.get_axis("Left", "Right")
	if not is_climbing:
		if wall_jump_lock > 0.0:
			wall_jump_lock -= delta
		var velocity_weight_x: float = 1.0 - exp( -(acceleration if x_input else friction) * delta)
		var weight_mod: float = 0.5 if wall_jump_lock > 0.0 else 1.0
		velocity.x = lerp(velocity.x, x_input * max_speed, velocity_weight_x * weight_mod)

		if on_wall_in_air and velocity.y > 0:
			wall_cantact_coyote = wall_contact_coyote_time
			look_dir_x = int(-WallRay.get_collision_normal().x)

			if x_input or Input.is_action_pressed("ui_accept"):
				velocity.y = gravity_wall
			else:
				velocity.y += gravity_normal
		else:
			if wall_cantact_coyote >  0.0:
				wall_cantact_coyote -= delta
			velocity.y += gravity_normal

		if (is_on_floor() or wall_cantact_coyote > 0.0) and Input.is_action_just_pressed("Jump"):
			velocity.y = jump_height
			if wall_cantact_coyote > 0.0 and not is_on_floor():
				velocity.x = -look_dir_x * wall_jump_push_force
				wall_jump_lock = wall_jump_lock_time

	if wall_cantact_coyote > 0.0 or is_climbing:
		if Input.is_action_pressed("ui_accept") and climb_stamina_timer > 0.0 and on_wall_in_air:
			is_climbing = true
			wall_jump_lock = 0.0
	
			var y_input: float = Input.get_axis("Up", "Down")
			var velocity_weight_y: float = 1.0 - exp( -(acceleration if y_input else friction) * delta)
			velocity.y = lerp(velocity.y, y_input * climb_speed, velocity_weight_y)
	
			var drain_rate: float = climb_stamina_drain if y_input else 1.0
			climb_stamina_timer -= delta * drain_rate
		else:
			if not on_wall and not is_on_floor() and is_climbing:
				velocity.y = climb_exit_boost.x * look_dir_x
			is_climbing = false
	
	if is_on_floor():
		climb_stamina_timer = stamina_amt
	
	move_and_slide()
