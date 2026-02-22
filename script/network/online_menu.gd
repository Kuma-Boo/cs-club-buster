extends Node

@export var animator : AnimationPlayer
@export var game_id_line : LineEdit

func _ready() -> void:
	NetworkManager.host_created.connect(host_created)
	NetworkManager.network_server_disconnected.connect(network_disconnected)

func host_created() -> void:
	game_id_line.text = NetworkManager.current_game_id
	animator.play("game-created")

func network_disconnected() -> void:
	animator.play("RESET")

func _on_host_pressed() -> void:
	NetworkManager.is_host = true
	NetworkManager.start_network_signals()
	animator.play("connecting")
	NetworkManager.create_server_peer()

func _on_join_pressed() -> void:
	NetworkManager.is_host = false
	NetworkManager.start_network_signals()
	animator.play("connecting")
	NetworkManager.create_client_peer(game_id_line.text)

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(game_id_line.text)
	animator.play("copied")
