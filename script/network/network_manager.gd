extends Node

signal host_created
signal peer_created
signal network_server_disconnected

var is_hosting_game : bool
var _port = 8890
var active_game_id : String
var _current_host_oid = ""
var network_statuses : Dictionary[int, int]

func get_player_count() -> int:
	return network_statuses.keys().size()

@rpc("any_peer", "call_local")
func set_network_status(network_id : int, status : int):
	if !NetworkManager.is_hosting_game:
		return
	network_statuses[network_id] = status

@rpc("any_peer", "call_local")
func get_network_status(network_id : int) -> int:
	return network_statuses[network_id]

@rpc("any_peer", "call_local")
func register_network_id(network_id : int) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	NetworkManager.network_statuses[network_id] = 0
	print("Number of players in lobby: %s" % get_player_count())

@rpc("any_peer", "call_local")
func unregister_network_id(network_id : int) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	if !NetworkManager.network_statuses.has(network_id):
		return
	NetworkManager.network_statuses.erase(network_id)
	print("Number of players in lobby: %s" % get_player_count())

func start_network_signals():
	print("Noray network ready!")
	if is_hosting_game:
		setup_host_noray_connection_signals()
	else:
		setup_client_noray_connection_signals()

# Hosting Noray - entry point
func create_server_peer(host_ip : String):
	print("Create Noray server peer")
	await _register_with_noray(host_ip)
	_start_noray_host()
	
# Joining Noray as client - entry point
func create_client_peer(host_ip : String, game_id : String):
	print("create Noray client peer")
	
	# Stash the game id (oid)
	_current_host_oid = game_id
	await _register_with_noray(host_ip)
	
	setup_client_enet_connection_signals()
	
	Noray.connect_nat(game_id)


func _register_with_noray(host_ip: String):
	print("Register with Noray hosted at: %s" % host_ip)
	var err = OK
	
	# connect to Noray
	err = await Noray.connect_to_host(host_ip, _port)
	if err != OK:
		print("Failed to connect to Noray for registration at %s:%s" % [host_ip, _port, err])
		return err
		
	# Register host
	Noray.register_host()
	await Noray.on_pid
	
	# Capture game_id to display on host-peer for sharing with others
	print("Noray oid/gameId: %s" % Noray.oid)
	NetworkManager.active_game_id = Noray.oid
	
	# Register remove address
	err = await Noray.register_remote()
	if err != OK:
		print("Failed to register remote %s" % err)
		return err
	
	print("Finished Noray registration")

func _start_noray_host():
	print("Starting Noray host")
	var err = OK
	
	var noray_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	err = noray_network_peer.create_server(Noray.local_port)
	multiplayer.multiplayer_peer = noray_network_peer
	
	if err != OK:
		print("Failed to listen on port %s with error: %s" % [Noray.local_port, err])
	
	host_created.emit()


func _handle_noray_client_connect(address: String, port: int) -> Error:
	print("Noray host handle connect: %s:%s" % [address, port])
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var err = await PacketHandshake.over_enet(peer.host, address, port)
	
	if err != OK:
		print("Noray packet handshake failed %s" % err)
		return err
	
	return OK


func _handle_nat_connect(address: String, port: int) -> Error:
	print("Attempting to connect client via NAT: %s:%s" % [address, port])
	var err = await _handle_connect(address, port)
	if err != OK:
		print("NAT connection failed from client, trying Relay instead...")
		Noray.connect_relay(_current_host_oid)
		return OK
	else:
		print("NAT punchthrough successful!")
	return err
	
func _handle_relay_connect(address: String, port: int) -> Error:
	print("Attempting to connect client via Relay: %s:%s" % [address, port])
	return await _handle_connect(address, port)

func _handle_connect(address: String, port: int) -> Error:
	print("Client handle connect to %s:%s, Noray.localport: %s" % [address, port, Noray.local_port])
	
	# Do a handshake
	var udp = PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)
	
	var err = await PacketHandshake.over_packet_peer(udp, 8)
	udp.close()
	
	if err != OK:
		print("Client packet handshake failed %s" % err)
		return err
		
	# Connect to host
	var peer = ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
	
	if err != OK:
		print("Create client failed %s" % err)
		return err
		
	multiplayer.multiplayer_peer = peer
	peer_created.emit()
	return OK


# Noray connection signals
func setup_host_noray_connection_signals():
	Noray.on_connect_nat.connect(_handle_noray_client_connect)
	Noray.on_connect_relay.connect(_handle_noray_client_connect)

func setup_client_noray_connection_signals():
	Noray.on_connect_nat.connect(_handle_nat_connect)
	Noray.on_connect_relay.connect(_handle_relay_connect)

# Client signals 
func setup_client_enet_connection_signals():
	multiplayer.server_disconnected.connect(_noray_server_disconnected)

func _noray_server_disconnected():
	print("Noray server disconnected")
	network_server_disconnected.emit()
