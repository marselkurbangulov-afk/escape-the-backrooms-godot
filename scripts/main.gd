extends Node

# Composes the world: spawns the level, places the player at its
# PlayerSpawn marker, and starts the ambient buzz generator.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LEVEL_0_SCENE := preload("res://scenes/levels/level_0.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const BUZZ_SCRIPT := preload("res://scripts/buzz_generator.gd")


func _ready() -> void:
	GameState.reset()

	var level := LEVEL_0_SCENE.instantiate()
	add_child(level)

	# Wait one frame so the level can finish building its grid + spawn marker.
	await get_tree().process_frame

	var player := PLAYER_SCENE.instantiate()
	var spawn: Node3D = level.get_node_or_null("PlayerSpawn")
	if spawn != null:
		player.position = spawn.global_position
	else:
		player.position = Vector3(48, 1, 48)
	add_child(player)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)

	var buzz := AudioStreamPlayer.new()
	buzz.set_script(BUZZ_SCRIPT)
	buzz.name = "AmbientBuzz"
	add_child(buzz)
