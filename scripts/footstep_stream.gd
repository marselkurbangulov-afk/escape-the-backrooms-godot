extends AudioStreamPlayer3D

# Procedural footstep generator on damp carpet.
# Carpet absorbs high frequencies, so the result is a soft, muffled "shoosh"
# with almost no transient click - mostly low/mid noise rolling off quickly.

const SAMPLE_RATE: float = 22050.0
const STEP_DURATION: float = 0.26

var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _samples_remaining: int = 0
var _t: float = 0.0
var _seed_offset: float = 0.0
# Two-stage low-pass state (cascaded one-pole filters give a steeper rolloff).
var _lp1: float = 0.0
var _lp2: float = 0.0


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = 0.35
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
	_lp1 = 0.0
	_lp2 = 0.0
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
	# Soft attack envelope (no sharp click) and a slow shoosh decay.
	for _i in frames:
		var attack: float = 1.0 - exp(-_t * 80.0)        # rises in ~12ms
		var decay: float = exp(-_t * 11.0)               # rolls off over ~250ms
		var env: float = attack * decay
		var noise: float = randf() * 2.0 - 1.0
		# Very subtle low body (thumb of the foot pressing fibers down).
		var body: float = sin((_t + _seed_offset) * 90.0 * TAU) * exp(-_t * 22.0) * 0.18
		var raw: float = noise * env * 0.55 + body * env
		# Cascaded one-pole LPF (alpha 0.10): cuts most highs, leaving a "fff" shoosh.
		_lp1 += 0.10 * (raw - _lp1)
		_lp2 += 0.10 * (_lp1 - _lp2)
		var s: float = clamp(_lp2 * 0.9, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
		_t += inv_sr
		_samples_remaining -= 1
