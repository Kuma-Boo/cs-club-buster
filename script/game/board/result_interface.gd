class_name BoardResults extends Control

signal on_win()
signal on_lose()

@export var result_label : Label
@export var result_animation_player : AnimationPlayer

func init() -> void:
	result_animation_player.play("init")

@rpc("any_peer", "call_local")
func lose() -> void:
	result_label.text = "OVERFLOW..."
	result_animation_player.play("lose")
	emit_signal("on_lose")

@rpc("any_peer", "call_local")
func win() -> void:
	result_label.text = "ALRIGHT!"
	result_animation_player.play("win")
	emit_signal("on_win")
