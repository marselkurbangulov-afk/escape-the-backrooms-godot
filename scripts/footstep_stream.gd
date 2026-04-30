extends AudioStreamPlayer3D

# Procedural footstep generator on damp carpet.
# Each call to play() generates a short noise burst with a low-pass envelope.

const SAMPLE_RATE: float = 22050.0
const STEP_DURATION: float = 0.18

var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _samples_remaining: int = 0
var _t: float = 0.0
var _seed_offset: float = 0.0


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = 0.25
	stream = _generator
	max_distance = 12.0
	unit_size = 1.0
	autoplay = false


func play_step() -> void:
	if _generator == null:
		return
	play(0.0)
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_samples_remaining = int(STEP_DURATION * SAMPLE_RATE)
	_t = 0.0
	_seed_offset = randf() * 1000.0
	_fill_burst()


func _process(_delta: float) -> void:
	if _samples_remaining > 0 and _playback != null:
		_fill_burst()


func _fill_burst() -> void:
	if _playback == null:
		return
	var frames: int = min(_playback.get_frames_available(), _samples_remaining)
	if frames <= 0:
		return
	var inv_sr: float = 1.0 / SAMPLE_RATE
	# Simple one-pole low-pass to soften the noise (carpet is dull).
	var prev: float = 0.0
	for _i in frames:
		var env: float = exp(-_t * 22.0)  # Fast decay.
		var noise: float = randf() * 2.0 - 1.0
		# Add a small thud body using a damped sine ~120Hz.
		var thud: float = sin((_t + _seed_offset) * 120.0 * TAU) * exp(-_t * 30.0) * 0.4
		var raw: float = noise * env * 0.6 + thud
		# Low-pass filter (alpha ~ 0.18 cuts highs, simulating damp carpet).
		prev = prev + 0.18 * (raw - prev)
		var s: float = clamp(prev * 0.7, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
		_t += inv_sr
		_samples_remaining -= 1
