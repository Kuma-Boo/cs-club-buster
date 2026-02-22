extends Node

@export var animator : AnimationPlayer
@export var game_id_line : LineEdit

@onready var GAME_SCENE = preload("res://scene/mode/online.tscn")
var player_count : int = 1

func _ready() -> void:
	NetworkManager.host_created.connect(connected)
	NetworkManager.peer_created.connect(connected)
	NetworkManager.network_server_disconnected.connect(network_disconnected)

func connected() -> void:
	if NetworkManager.is_hosting_game:
		if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
			# Leverage the peer connected signal to trigger the player spawn
			multiplayer.peer_connected.connect(_peer_connected)
			# Handle the disconnect signal here so we have access to what needs cleaned up in game.
			multiplayer.peer_disconnected.connect(_peer_disconnected)
		
		NetworkManager.register_network_id(1) # Register the host
	game_id_line.text = NetworkManager.active_game_id
	animator.play("game-created")

func network_disconnected() -> void:
	NetworkManager.network_statuses.clear()
	animator.play("RESET")

func _on_host_pressed() -> void:
	NetworkManager.is_hosting_game = true
	NetworkManager.start_network_signals()
	animator.play("connecting")
	NetworkManager.create_server_peer("tomfol.io")

func _on_join_pressed() -> void:
	NetworkManager.is_hosting_game = false
	NetworkManager.start_network_signals()
	animator.play("connecting")
	NetworkManager.create_client_peer("tomfol.io", game_id_line.text)

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(game_id_line.text)
	animator.play("copied")

func _on_start_pressed() -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	rpc("start_game")

@rpc("authority", "call_local")
func start_game() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)

func _peer_connected(network_id: int):
	print("Peer connected: %s" % network_id)
	NetworkManager.register_network_id(network_id)
	if NetworkManager.is_hosting_game && NetworkManager.get_player_count() != 1:
		animator.play("ready")

func _peer_disconnected(network_id: int):
	print("Peer disconnected: %s" % network_id)
	NetworkManager.unregister_network_id(network_id)
	animator.play("waiting")
