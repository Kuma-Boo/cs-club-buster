### Responsible for spawning blocks values and keeping them synced across the network.
class_name BlockValueGenerator extends Node

static var instance : BlockValueGenerator

signal initialized

## The list of numbers, shared across players.
var value_queue : Array[Block.VALUE_ENUM]
## Chance to get 0.
var zero_chance : float = 0.5
var is_initialized : bool

func _enter_tree() -> void:
	instance = self

func _process(_delta : float) -> void:
	if is_initialized:
		return
	
	if NetworkManager.is_online && !NetworkManager.is_hosting_game:
		return
	
	for i in NetworkManager.network_statuses.keys():
		if NetworkManager.network_statuses[i] != 1:
			# A different scene is still loading
			return
	
	for i in range(5):
		rpc("queue_block_value")
	
	is_initialized = true
	initialized.emit()

func _exit_tree() -> void:
	if value_queue.size() != 0:
		value_queue.clear()

@rpc("any_peer", "call_local")
func queue_block_value() -> void:
	if NetworkManager.is_online && !NetworkManager.is_hosting_game:
		return
	
	var return_value : Block.VALUE_ENUM
	return_value = Block.VALUE_ENUM.ZERO if randf() < zero_chance else Block.VALUE_ENUM.ONE
	zero_chance += -0.1 if return_value == Block.VALUE_ENUM.ZERO else 0.1
	zero_chance = clamp(zero_chance, 0, 1)
	rpc("queue_value", return_value)

func get_value_at(index : int) -> Block.VALUE_ENUM:
	return value_queue.get(index)

@rpc("authority", "call_local", "unreliable_ordered")
func queue_value(value : Block.VALUE_ENUM) -> void:
	value_queue.append(value) # Add to queue for other players
