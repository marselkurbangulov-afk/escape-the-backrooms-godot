extends Area3D

# Triggered when the player walks into a tile flagged as the "noclip"
# exit. Currently this just emits a global signal and shows a fade-out;
# Level 1 is a future stub.

var _triggered: bool = false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	GameState.trigger_noclip()
