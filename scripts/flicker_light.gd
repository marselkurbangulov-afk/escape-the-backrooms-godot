extends Node3D

# Flickering fluorescent light. Most of the time it stays on; occasionally
# it strobes briefly to sell the Backrooms vibe.

const BASE_ENERGY: float = 1.4
const FLICKER_CHANCE_PER_SECOND: float = 0.05
const STROBE_FRAMES: int = 6

var _light: OmniLight3D
var _fixture: MeshInstance3D
var _flicker_remaining: int = 0


func _ready() -> void:
	for child in get_children():
		if child is OmniLight3D:
			_light = child
		elif child is MeshInstance3D:
			_fixture = child
	# Stagger flicker timing so they don't all blink in unison.
	set_physics_process(false)
	var t := Timer.new()
	t.wait_time = randf_range(0.08, 0.16)
	t.one_shot = false
	t.timeout.connect(_tick)
	add_child(t)
	t.start()


func _tick() -> void:
	if _light == null:
		return
	if _flicker_remaining > 0:
		_flicker_remaining -= 1
		var on: bool = (_flicker_remaining % 2) == 0
		_light.light_energy = BASE_ENERGY if on else 0.0
		if _fixture and _fixture.material_override is StandardMaterial3D:
			(_fixture.material_override as StandardMaterial3D).emission_energy_multiplier = (
				1.6 if on else 0.05
			)
		return

	if randf() < FLICKER_CHANCE_PER_SECOND * 0.12:
		_flicker_remaining = STROBE_FRAMES + (randi() % 6)
	else:
		# Tiny constant noise on energy so the lighting feels alive.
		_light.light_energy = BASE_ENERGY + randf_range(-0.05, 0.05)
