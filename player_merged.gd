extends CharacterBody2D
## Merged player + wall controller.
##
## Attach this to the root of player.tscn (it already has CoyoteTimer,
## JumpBufferTimer, HeadNudges, LedgeHop and WallRay as children).
##
## Movement, gravity, jump buffer, coyote time, head nudges and ledge hops are
## taken from player.gd. Wall slide, wall jump and climbing are taken from
## wall.gd, with these fixes:
##   - the wall ray is long enough to leave the player's collider
##   - the ray is force-updated instead of reading last frame's result
##   - walls are detected by hit normal, not by "collider is TileMapLayer"
##   - climbing has its own binding, so it no longer fights the Jump key
##   - the wall-slide is a clamped speed instead of an instant velocity
##   - the climb exit pushes toward the wall correctly

@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var wall_ray: RayCast2D = $WallRay

# --- player stats -------------------------------------------------------------
@export var jump_height: float = -230.0
@export var max_speed: float = 80.0
@export var acceleration: float = 8.0
@export var friction: float = 10.0

# --- wall / climb tuning ------------------------------------------------------
@export_group("Wall & Climb")
## Must be longer than the player's half-width (7 px), or the ray never
## leaves the player's own collider and can never touch a wall.
@export var wall_ray_length: float = 7.5
@export var wall_jump_push_force: float = 100.0
@export var wall_jump_lock_time: float = 0.05
@export var wall_contact_coyote_time: float = 0.2
@export var wall_slide_speed: float = 8.5
@export var climb_speed: float = 26.5
@export var climb_stamina_max: float = 3.5
@export var climb_stamina_drain: float = 2.5
@export var climb_exit_boost: Vector2 = Vector2(100.0, -100.0)
## Missing actions fall back to "Up" and then "ui_accept".
@export var climb_action: StringName = &"Climb"

const gravity_normal: float = 12.0
const max_gravity: float = 14.5

var gravity: float = gravity_normal
var coyote_time_activated: bool = false

var wall_coyote: float = 0.0
var wall_jump_lock: float = 0.0
var look_dir: int = 1  # input facing, used to aim the wall ray
var wall_dir: int = 1  # direction toward the wall
var is_climbing: bool = false
var stamina: float = 0.0

var _climb_binding: StringName = &""


func _ready() -> void:
	for child in $HeadNudges.get_children():
		child.add_exception(self)
	for child in $LedgeHop.get_children():
		child.add_exception(self)

	stamina = climb_stamina_max
	wall_ray.target_position.x = wall_ray_length * look_dir

	if InputMap.has_action(climb_action):
		_climb_binding = climb_action
	elif InputMap.has_action(&"Up"):
		_climb_binding = &"Up"
		push_warning("Action '%s' not found, climbing on 'Up'." % climb_action)
	else:
		_climb_binding = &"ui_accept"


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("Left", "Right")

	# --- coyote time (player.gd) --------------------------------------------
	if is_on_floor():
		coyote_time_activated = false
		coyote_timer.stop()
	elif coyote_timer.is_stopped() and not coyote_time_activated:
		coyote_timer.start()
		coyote_time_activated = true

	# --- wall sensor --------------------------------------------------------
	if direction != 0.0:
		look_dir = int(signf(direction))
	wall_ray.target_position.x = wall_ray_length * look_dir
	wall_ray.force_raycast_update()

	var wall_normal := Vector2.ZERO
	var on_wall := false
	if wall_ray.is_colliding():
		wall_normal = wall_ray.get_collision_normal()
		# only near-vertical surfaces count, so floors and ceilings are ignored
		on_wall = absf(wall_normal.x) > 0.7
		if on_wall:
			wall_dir = int(-signf(wall_normal.x))

	var on_wall_in_air: bool = on_wall and not is_on_floor()

	# --- horizontal movement (player.gd, kept) ------------------------------
	if not is_climbing:
		wall_jump_lock = maxf(wall_jump_lock - delta, 0.0)
		var velocity_weight: float = delta * (acceleration if direction else friction)
		# while locked, leave the wall-jump push alone
		var lock_mod: float = 0.0 if wall_jump_lock > 0.0 else 1.0
		velocity.x = lerp(velocity.x, direction * max_speed, velocity_weight * lock_mod)

	# --- wall contact / coyote ---------------------------------------------
	if on_wall_in_air:
		wall_coyote = wall_contact_coyote_time
	else:
		wall_coyote = maxf(wall_coyote - delta, 0.0)

	# --- jump: buffered (player.gd), wall jump takes priority ---------------
	if Input.is_action_just_pressed("Jump") and jump_buffer_timer.is_stopped():
		jump_buffer_timer.start()

	if not jump_buffer_timer.is_stopped():
		if wall_coyote > 0.0 and not is_on_floor():
			velocity.y = jump_height
			velocity.x = -wall_dir * wall_jump_push_force
			wall_jump_lock = wall_jump_lock_time
			wall_coyote = 0.0
			is_climbing = false
			jump_buffer_timer.stop()
		elif is_on_floor() or not coyote_timer.is_stopped():
			velocity.y = jump_height
			coyote_timer.stop()
			coyote_time_activated = true
			jump_buffer_timer.stop()

	# --- climbing -----------------------------------------------------------
	var climb_held: bool = Input.is_action_pressed(_climb_binding)
	var y_input := Input.get_axis("Up", "Down")

	if is_climbing:
		# let go when the wall, the stamina or the input runs out
		if not on_wall or stamina <= 0.0 or not (climb_held or y_input != 0.0):
			# climbed over the lip: hop up and onto the wall
			if not on_wall and not is_on_floor():
				velocity.x = wall_dir * climb_exit_boost.x
				velocity.y = climb_exit_boost.y
			is_climbing = false
	elif on_wall_in_air and velocity.y >= 0.0 and climb_held and stamina > 0.0:
		# grab only while falling (or hanging), never mid-jump
		is_climbing = true
		wall_jump_lock = 0.0

	# --- vertical -----------------------------------------------------------
	if is_climbing:
		var velocity_weight_y: float = 1.0 - exp(-(acceleration if y_input else friction) * delta)
		velocity.y = lerp(velocity.y, y_input * climb_speed, velocity_weight_y)
		stamina -= delta * (climb_stamina_drain if y_input else 1.0)
	elif on_wall_in_air and velocity.y > 0.0 and (climb_held or _pressing_into_wall(direction)):
		# wall slide: accelerate down, but clamp to a slow speed
		velocity.y = minf(velocity.y + gravity_normal, wall_slide_speed)
	else:
		# variable jump height (player.gd)
		if Input.is_action_just_released("Jump") or is_on_ceiling():
			velocity.y *= 0.5

		if is_on_floor():
			gravity = lerp(gravity, gravity_normal, 12.0 * delta)
		else:
			gravity = lerp(gravity, max_gravity, 12.0 * delta)

		velocity.y += gravity

	if is_on_floor():
		stamina = climb_stamina_max

	# --- head nudge (player.gd, unchanged) ----------------------------------
	if velocity.y < jump_height / 2.0:
		var head_collision: Array = [%LeftHeadNudge.is_colliding(), %LeftHeadNudge2.is_colliding(), %RightHeadNudge.is_colliding(), %RightHeadNudge2.is_colliding()]

		if head_collision.count(true) == 1:
			if head_collision[0]:
				global_position.x += 1.75
			if head_collision[2]:
				global_position.x -= 1.75

	# --- ledge hop (player.gd, unchanged) -----------------------------------
	if velocity.y > -30 and velocity.y < -5 and abs(velocity.x) > 3:
		if %LeftLedgeHop.is_colliding() and not %LeftLedgeHop2.is_colliding() and velocity.x < 0:
			velocity.y += jump_height / 3.25
		if %RightLedgeHop.is_colliding() and not %RightLedgeHop2.is_colliding() and velocity.x > 0:
			velocity.y += jump_height / 3.25

	move_and_slide()


func _pressing_into_wall(direction: float) -> bool:
	return direction != 0.0 and int(signf(direction)) == wall_dir
