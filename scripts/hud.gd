extends CanvasLayer

# Minimalist HUD: stamina bar, sanity bar, fade-out on noclip trigger.

@onready var stamina_bar: ProgressBar = $Margin/VBox/Stamina
@onready var sanity_bar: ProgressBar = $Margin/VBox/Sanity
@onready var fader: ColorRect = $Fader
@onready var subtitle: Label = $Subtitle


func _ready() -> void:
	GameState.stamina_changed.connect(_on_stamina)
	GameState.sanity_changed.connect(_on_sanity)
	GameState.noclip_triggered.connect(_on_noclip)
	stamina_bar.value = GameState.stamina
	sanity_bar.value = GameState.sanity
	fader.modulate.a = 0.0
	subtitle.modulate.a = 0.0


func _on_stamina(value: float) -> void:
	stamina_bar.value = value


func _on_sanity(value: float) -> void:
	sanity_bar.value = value


func _on_noclip() -> void:
	subtitle.text = "You no-clipped through the wall.\nLevel 1: coming soon."
	var tween := create_tween()
	tween.tween_property(fader, "modulate:a", 1.0, 1.5)
	tween.parallel().tween_property(subtitle, "modulate:a", 1.0, 1.5)
