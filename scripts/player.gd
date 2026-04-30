extends CharacterBody3D

# First-person player controller.
# Emulates the feel of Escape the Backrooms: walk, sprint with stamina,
# crouch, head-bob, and damp-carpet footsteps.

const WALK_SPEED: float = 3.2
const SPRINT_SPEED: float = 5.6
const CROUCH_SPEED: float = 1.6
const ACCEL: float = 12.0
const FRICTION: float = 14.0
const JUMP_VELOCITY: float = 5.0
const MOUSE_SENSITIVITY: float = 0.0022
const STAND_HEIGHT: float = 1.7
const CROUCH_HEIGHT: float = 1.0
const HEADBOB_FREQ: float = 9.0
const HEADBOB_AMP: float = 0.06
const STAMINA_DRAIN: float = 18.0
const STAMINA_REGEN: float = 12.0
const FOOTSTEP_INTERVAL_WALK: float = 0.55
const FOOTSTEP_INTERVAL_SPRINT: float = 0.38
const FOOTSTEP_INTERVAL_CROUCH: float = 0.85

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var stand_collider: CollisionShape3D = $StandCollider
@onready var crouch_collider: CollisionShape3D = $CrouchCollider
@onready var ceiling_check: ShapeCast3D = $CeilingCheck
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer

var _bob_time: float = 0.0
var _is_crouching: bool = false
var _footstep_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 20.0)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -1.4, 1.4)
	elif event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)


func _physics_process(delta: float) -> void:
	_handle_crouch()
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_handle_headbob(delta)
	_handle_footsteps(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		velocity.y = JUMP_VELOCITY


func _handle_crouch() -> void:
	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch == _is_crouching:
		return
	# Block stand if something is overhead.
	if not want_crouch and ceiling_check.is_colliding():
		return
	_is_crouching = want_crouch
	stand_collider.disabled = want_crouch
	crouch_collider.disabled = not want_crouch
	var target_y: float = CROUCH_HEIGHT if want_crouch else STAND_HEIGHT
	var tween := create_tween()
	tween.tween_property(head, "position:y", target_y, 0.15)


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_speed: float = WALK_SPEED
	var sprinting := (
		Input.is_action_pressed("sprint")
		and not _is_crouching
		and GameState.stamina > 0.0
		and input_dir.length() > 0.1
	)
	if _is_crouching:
		target_speed = CROUCH_SPEED
	elif sprinting:
		target_speed = SPRINT_SPEED

	if sprinting:
		GameState.stamina -= STAMINA_DRAIN * delta
	else:
		GameState.stamina += STAMINA_REGEN * delta

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var desired := direction * target_speed
	if direction.length_squared() > 0.0:
		horizontal = horizontal.move_toward(desired, ACCEL * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, FRICTION * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _handle_headbob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.5 and is_on_floor():
		_bob_time += delta * HEADBOB_FREQ * (horizontal_speed / WALK_SPEED)
		var bob_offset := Vector3(
			cos(_bob_time * 0.5) * HEADBOB_AMP * 0.5,
			abs(sin(_bob_time)) * HEADBOB_AMP,
			0.0
		)
		camera.position = camera.position.lerp(bob_offset, delta * 8.0)
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 6.0)


func _handle_footsteps(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.5 or not is_on_floor():
		_footstep_timer = 0.0
		return
	var interval: float = FOOTSTEP_INTERVAL_WALK
	if _is_crouching:
		interval = FOOTSTEP_INTERVAL_CROUCH
	elif Input.is_action_pressed("sprint") and GameState.stamina > 0.0:
		interval = FOOTSTEP_INTERVAL_SPRINT
	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		footstep_player.pitch_scale = randf_range(0.92, 1.08)
		footstep_player.volume_db = randf_range(-6.0, -2.0)
		footstep_player.play_step()
