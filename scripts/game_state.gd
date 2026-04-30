extends Node

# Global game state autoload.
# Tracks sanity, current level, and emits signals consumed by the HUD.

signal sanity_changed(new_value: float)
signal stamina_changed(new_value: float)
signal level_changed(level_name: String)
signal noclip_triggered

const MAX_SANITY: float = 100.0
const MAX_STAMINA: float = 100.0

var sanity: float = MAX_SANITY:
	set(value):
		sanity = clamp(value, 0.0, MAX_SANITY)
		sanity_changed.emit(sanity)

var stamina: float = MAX_STAMINA:
	set(value):
		stamina = clamp(value, 0.0, MAX_STAMINA)
		stamina_changed.emit(stamina)

var current_level: String = "level_0"


func reset() -> void:
	sanity = MAX_SANITY
	stamina = MAX_STAMINA


func trigger_noclip() -> void:
	noclip_triggered.emit()
