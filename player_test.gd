extends CharacterBody2D

@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var camera: Camera2D = $Camera2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var conductor: Conductor

@export_group("Beat timing")
@export var pixels_per_beat: float = 86.0
@export var jump_air_beats: float = 1.0
@export var jump_height: float = 50.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export var debug_print_jumps: bool = true

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


func _physics_process(delta: float) -> void:
	_update_beat_physics()
	
	velocity.x = _run_velocity()
	velocity.y += gravity * delta
	
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer.start()
	
	if not jump_buffer_timer.is_stopped() and is_on_floor():
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
	
	move_and_slide()
	camera.global_position.x = global_position.x
	
	if not is_on_floor():
		if animated_sprite.animation != "Jump":
			animated_sprite.play("Jump")
	elif absf(velocity.x) > 1.0:
		if animated_sprite.animation != "Run":
			animated_sprite.play("Run")
	else:
		if animated_sprite.animation != "Idle":
			animated_sprite.play("Idle")
	
	if _in_jump:
		_jump_air_time += delta
		_jump_peak = maxf(_jump_peak, _jump_start_y - global_position.y)
		if is_on_floor():
			_in_jump = false
			if debug_print_jumps:
				print("Jump: %.2f beats (%.2fs), %.0f px high" % [
					_jump_air_time / _seconds_per_beat, _jump_air_time, _jump_peak])
