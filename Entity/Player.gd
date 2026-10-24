extends CharacterBody2D

@onready var Sprite = $Sprite
@onready var Collision = $Collision
@onready var Animation = $Animation

const RunSpeed = 150
const Acceleration = 40
const Gravity = 300
const JumpVelocity = -150
const MaxJumps = 1

var moveSpeed = RunSpeed
var moveDirectionX = 0
var jumps = 0
var facing = 1

var keyUp = false
var keyDown = false
var keyLeft = false
var keyRight = false
var keyJump = false
var keyJumpPressed = false

func _ready():
	pass

func _physics_process(delta: float) -> void:
	
	GetInputStates()

	move_and_slide()


func GetInputStates():
	KeyUp = Input.is_action_pressed("KeyUp")
	KeyDown = Input.is_action_pressed("KeyJump")
	KeyLeft = Input.is_action_pressed("KeyLeft")
	KeyRight = Input.is_action_pressed("KeyRight")
	KeyJump = Input.is_action_pressed("KeyJump")
	keyJumpPressed = Input.is_action_just_pressed("KeyJump")
	
	if (KeyRight): facing = 1
	if (KeyLeft): facing = -1


func HorizontalMovement():
	moveDirectionX = Input.get_axis("keyLeft", "keyRight")
