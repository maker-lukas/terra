extends CharacterBody2D

@onready var jump_buffer_timer: Timer = $JumpBufferTimer

## The song's Conductor. Speed and jump are tuned to its BPM.
@export var conductor: Conductor

@export_group("Beat timing")
## Distance travelled per beat. Obstacle on beat N goes at x = N * pixels_per_beat.
@export var pixels_per_beat: float = 86.0
## Air time of a fully held jump, in beats (take-off to landing at the same height).
@export var jump_air_beats: float = 1.0
## Peak height of a fully held jump, in pixels.
@export var jump_height: float = 50.0
## Upward speed kept when Jump is released early. A tap lasts jump_air_beats * this.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5

# Calculated from the values above in _ready().
var speed: float
var jump_velocity: float
var gravity: float


func _ready() -> void:
	var bpm: float = conductor.bpm if conductor else 174.0
	var seconds_per_beat := 60.0 / bpm
	var rise_time := jump_air_beats * seconds_per_beat / 2.0
	
	speed = pixels_per_beat / seconds_per_beat
	gravity = 2.0 * jump_height / (rise_time * rise_time)
	jump_velocity = -gravity * rise_time


func _physics_process(delta: float) -> void:
	
	velocity.x = speed
	velocity.y += gravity * delta
	
	if Input.is_action_just_pressed("Jump"):
		jump_buffer_timer.start()
	
	if not jump_buffer_timer.is_stopped() and is_on_floor():
		velocity.y = jump_velocity
		jump_buffer_timer.stop()
	
		if not Input.is_action_pressed("Jump"):
			velocity.y *= jump_cut_multiplier
	
	# elif: a jump that was already cut above must not be cut a second time
	elif Input.is_action_just_released("Jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	
	
	move_and_slide()
