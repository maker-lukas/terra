extends CharacterBody2D

@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var slide_buffer_timer: Timer = $SlideBufferTimer
@onready var camera: Camera2D = $Camera2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var conductor: Conductor

@export_group("Slide")
@export var slide_min_beats: float = 0.5
@export var slide_max_beats: float = 1.5
@export_range(0.1, 1.0) var slide_collision_scale: float = 0.5

@export_group("Beat timing")
@export var pixels_per_beat: float = 86.0
@export var jump_air_beats: float = 1.0
@export var jump_height: float = 50.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export var debug_print_jumps: bool = true
@export var beats_per_run_cycle: float = 2.0

var speed: float
var jump_velocity: float
var gravity: float

const SYNC_STRENGTH: float = 10.0

var _start_x: float
var _seconds_per_beat: float
var _in_jump: bool = false
var _jump_air_time: float = 0.0
var _jump_start_y: float = 0.0
var _jump_peak: float = 0.0

var _sliding: bool = false
var _slide_time: float = 0.0
var _stand_size: Vector2
var _stand_pos: Vector2

func _run_velocity() -> float:
	if not conductor:
		return speed
	var song_time := conductor.get_song_position()
	if not conductor.playing or song_time < 0.0:
		return 0.0
	var target_x := _start_x + song_time * speed
	return speed + clampf((target_x - global_position.x) * SYNC_STRENGTH, -speed, speed)
  

func _update_beat_physics() -> void:
	var bpm: float = conductor.bpm if conductor else 174.0
	_seconds_per_beat = 60.0 / bpm
	var rise_time := jump_air_beats * _seconds_per_beat / 2.0
	
	speed = pixels_per_beat / _seconds_per_beat
	gravity = 2.0 * jump_height / (rise_time * rise_time)
	jump_velocity = -gravity * rise_time


func _ready() -> void:
	_start_x = global_position.x
	camera.top_level = true
	camera.global_position = global_position
	
	collision_shape.shape = collision_shape.shape.duplicate()
	_stand_size = (collision_shape.shape as RectangleShape2D).size
	_stand_pos = collision_shape.position


func _physics_process(delta: float) -> void:
	_update_beat_physics()
	
	velocity.x = _run_velocity()
	velocity.y += gravity * delta
	
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer.start()
	if Input.is_action_just_pressed("Slide"):
		slide_buffer_timer.start()
	
	var jumped := false
	
	if not jump_buffer_timer.is_stopped() and is_on_floor():
		if _sliding and _can_stand():
			_end_slide()
		velocity.y = jump_velocity
		jump_buffer_timer.stop()
		_in_jump = true
		_jump_air_time = 0.0
		_jump_start_y = global_position.y
		_jump_peak = 0.0
	
		if not Input.is_action_pressed("Jump"):
			velocity.y *= jump_cut_multiplier
	
	elif Input.is_action_just_released("Jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	
	if not jumped and not _sliding and is_on_floor() and _is_running() and not slide_buffer_timer.is_stopped():
		slide_buffer_timer.stop()
		_start_slide()
	
	if _sliding:
		_slide_time += delta
		if _slide_should_end() and _can_stand():
			_end_slide()
	
	move_and_slide()
	camera.global_position.x = global_position.x
	
	animated_sprite.speed_scale = 1.0
	
	if _sliding and is_on_floor():
		_play("Slide")
	elif not is_on_floor():
		_play("Jump")
	elif absf(velocity.x) > 1.0:
		if animated_sprite.animation != "Run":
			animated_sprite.play("Run")
			_align_run_to_beat()
		_sync_run_to_tempo()
	else:
		_play("Idle")
	
	
	if _in_jump:
		_jump_air_time += delta
		_jump_peak = maxf(_jump_peak, _jump_start_y - global_position.y)
		if is_on_floor():
			_in_jump = false
			if debug_print_jumps:
				print("Jump: %.2f beats (%.2fs), %.0f px high" % [
					_jump_air_time / _seconds_per_beat, _jump_air_time, _jump_peak])

func _play(anim: StringName) -> void:
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)

func _sync_run_to_tempo() -> void:
	var frames := animated_sprite.sprite_frames
	var natural_length := frames.get_frame_count("Run") / frames.get_animation_speed("Run")
	var wanted_length := beats_per_run_cycle * _seconds_per_beat
	animated_sprite.speed_scale = natural_length / wanted_length

func _align_run_to_beat() -> void:
	if not conductor:
		return
	var cycle := beats_per_run_cycle * _seconds_per_beat
	var phase := fposmod(conductor.get_song_position() / cycle, 1.0)
	var count := animated_sprite.sprite_frames.get_frame_count("Run")
	animated_sprite.frame = int(phase * count) % count
 
func _start_slide() -> void:
	_sliding = true
	_slide_time = 0.0
	var shape := collision_shape.shape as RectangleShape2D
	var new_height := _stand_size.y * slide_collision_scale
	shape.size.y = new_height
	collision_shape.position.y = _stand_pos.y + (_stand_size.y - new_height) / 2.0

func _end_slide() -> void:
	_sliding = false
	(collision_shape.shape as RectangleShape2D).size = _stand_size
	collision_shape.position = _stand_pos

func _can_stand() -> bool:
	var diff := _stand_size.y * (1.0 - slide_collision_scale)
	return not test_move(global_transform, Vector2(0, -diff))

func _slide_should_end() -> bool:
	var min_time := slide_min_beats * _seconds_per_beat
	var max_time := slide_max_beats * _seconds_per_beat
	if _slide_time >= max_time or not is_on_floor():
		return true
	return _slide_time >= min_time and not Input.is_action_pressed("Slide")

func _is_running() -> bool:
	return absf(velocity.x) > 1.0
