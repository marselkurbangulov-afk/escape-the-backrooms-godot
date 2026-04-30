extends CanvasLayer

# Pause / settings menu. Opens on `pause` (Esc), pauses the tree, frees
# the mouse, and exposes a master volume slider that persists between
# runs via a ConfigFile in user://settings.cfg.

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "audio"
const KEY_VOLUME := "master_volume"

@onready var root: Control = $Root
@onready var volume_slider: HSlider = $Root/CenterContainer/Panel/Margin/VBox/VolumeRow/VolumeSlider
@onready var volume_label: Label = $Root/CenterContainer/Panel/Margin/VBox/VolumeRow/VolumeValue
@onready var resume_button: Button = $Root/CenterContainer/Panel/Margin/VBox/ResumeButton
@onready var quit_button: Button = $Root/CenterContainer/Panel/Margin/VBox/QuitButton

var _master_bus_idx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root.visible = false
	_master_bus_idx = AudioServer.get_bus_index("Master")
	var stored: float = _load_volume()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = stored
	_apply_volume(stored)
	volume_slider.value_changed.connect(_on_volume_changed)
	resume_button.pressed.connect(_close)
	quit_button.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if root.visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func _close() -> void:
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_save_volume(value)


func _apply_volume(linear: float) -> void:
	volume_label.text = "%d%%" % int(round(linear * 100.0))
	if linear <= 0.0001:
		AudioServer.set_bus_mute(_master_bus_idx, true)
	else:
		AudioServer.set_bus_mute(_master_bus_idx, false)
		AudioServer.set_bus_volume_db(_master_bus_idx, linear_to_db(linear))


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()


func _load_volume() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return 0.8
	return float(cfg.get_value(SECTION, KEY_VOLUME, 0.8))


func _save_volume(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # ignore error if file doesn't exist yet
	cfg.set_value(SECTION, KEY_VOLUME, value)
	cfg.save(CONFIG_PATH)
