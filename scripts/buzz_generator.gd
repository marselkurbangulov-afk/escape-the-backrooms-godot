extends AudioStreamPlayer

# Procedurally generates the iconic 60Hz fluorescent-light hum.
# Mixes a 60 Hz fundamental with its harmonics plus a tiny bit of noise,
# then continually feeds samples to an AudioStreamGenerator.

const SAMPLE_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.5
const FUNDAMENTAL_HZ: float = 60.0

var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _phase2: float = 0.0
var _phase3: float = 0.0


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_LENGTH
	stream = _generator
	bus = "Master"
	volume_db = -18.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_fill()


func _process(_delta: float) -> void:
	if _playback != null:
		_fill()


func _fill() -> void:
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var inv_sr: float = 1.0 / SAMPLE_RATE
	for i in frames:
		_phase += FUNDAMENTAL_HZ * TAU * inv_sr
		_phase2 += FUNDAMENTAL_HZ * 2.0 * TAU * inv_sr
		_phase3 += FUNDAMENTAL_HZ * 3.0 * TAU * inv_sr
		if _phase > TAU:
			_phase -= TAU
		if _phase2 > TAU:
			_phase2 -= TAU
		if _phase3 > TAU:
			_phase3 -= TAU
		var s: float = (
			sin(_phase) * 0.6
			+ sin(_phase2) * 0.25
			+ sin(_phase3) * 0.1
			+ (randf() * 2.0 - 1.0) * 0.05
		)
		# Soft clip to keep things gentle.
		s = clamp(s * 0.5, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
