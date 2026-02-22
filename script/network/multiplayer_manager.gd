class_name MultiplayerManager
extends Node

# The bulk of this script is for the authority (host/server).

@export var _player_spawn_parent: HBoxContainer

var _multiplayer_scene = preload("res://scene/object/game_board.tscn")
var _players_in_game: Dictionary = {}
var is_initialized : bool

func _ready() -> void:
	rpc("_on_peer_ready", multiplayer.get_unique_id())

func _process(_delta: float) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	if is_initialized:
		return
	
	attempt_initialization()

func attempt_initialization() -> void:
	for i in NetworkManager.network_statuses.keys():
		if NetworkManager.network_statuses[i] != 1:
			return
	
	is_initialized = true
	initialize_players()

func initialize_players() -> void:
	for id in NetworkManager.network_statuses.keys():
		rpc("_add_player_to_game", id)

@rpc("any_peer", "call_local")
func _on_peer_ready(network_id) -> void:
	if !NetworkManager.is_hosting_game:
		return
	NetworkManager.set_network_status(network_id, 1)

@rpc("authority", "call_local", "unreliable_ordered")
func _add_player_to_game(network_id: int):
	print("Adding player to game: %s" % network_id)
	
	if _players_in_game.get(network_id) == null:
		var player_to_add = _multiplayer_scene.instantiate()
		player_to_add.name = str(network_id)
		
		connect_signals(player_to_add)
		_players_in_game[network_id] = player_to_add
		_player_spawn_parent.add_child(player_to_add)
		player_to_add.set_multiplayer_authority(network_id)
	else:
		print("Warning! Attempted to add existing player to game: %s" % network_id)

func _remove_player_from_game(network_id: int):
	if is_multiplayer_authority():
		print("Removing player from game: %s" % network_id)
		if _players_in_game.has(network_id):
			var player_to_remove = _players_in_game[network_id]
			if player_to_remove:
				player_to_remove.queue_free()
				_players_in_game.erase(network_id)

func connect_signals(board : GameBoard) -> void:
	for key in _players_in_game.keys():
		_players_in_game[key].connect("blocks_sent", Callable.create(board, "recieve_penalty_blocks"))
		board.connect("blocks_sent", Callable.create(_players_in_game[key], "recieve_penalty_blocks"))
