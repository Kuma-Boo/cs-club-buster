extends Node

signal host_created
signal network_server_disconnected

var is_host : bool = false
var _port = 8890
var host_ip = "tomfol.io"
var current_game_id = ""

func start_network_signals():
	print("Noray network ready!")
	if is_host:
		setup_host_connection_signals()
	else:
		setup_client_connection_signals()

# Hosting Noray - entry point
func create_server_peer() -> void:
	print("Create Noray server peer")
	await _register_with_noray()
	_start_noray_host()

# Joining Noray as client - entry point
func create_client_peer(game_id : String):
	print("create Noray client peer")
	
	# Stash the game id (oid)
	current_game_id = game_id
	await _register_with_noray()
	
	setup_client_enet_connection_signals()
	
	Noray.connect_nat(game_id)

# Use this to kill the network connection and clean up for return to main menu
func disconnect_from_game():
	multiplayer.multiplayer_peer = null # Disconnect peer

func _register_with_noray():
	print("Register with Noray hosted at: %s" % host_ip)
	var err = OK
	
	# Connect to Noray
	err = await Noray.connect_to_host(host_ip, _port)
	if err != OK:
		print("Failed to connect to Noray for registration at %s:%s" % [host_ip, _port, err])
		return err
		
	# Register host
	Noray.register_host()
	await Noray.on_pid
	
	# Capture game_id to display on host-peer for sharing with others
	print("Noray oid/gameId: %s" % Noray.oid)
	current_game_id = Noray.oid
	host_created.emit()
	
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
		Noray.connect_relay(current_game_id)
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
	return OK

func setup_host_connection_signals() -> void:
	Noray.on_connect_nat.connect(_handle_noray_client_connect)
	Noray.on_connect_relay.connect(_handle_noray_client_connect)
	
func setup_client_connection_signals() -> void:
	Noray.on_connect_nat.connect(_handle_nat_connect)
	Noray.on_connect_relay.connect(_handle_relay_connect)

# Client signals 
func setup_client_enet_connection_signals():
	multiplayer.server_disconnected.connect(_noray_server_disconnected)

func _noray_server_disconnected():
	print("Noray server disconnected")
	network_server_disconnected.emit()
