### Responsible for spawning blocks and keeping them synced across the network.
class_name BlockSpawner extends Node2D

## The list of numbers, shared across players.
static var value_queue : Array[Block.VALUE_ENUM]
## Chance to get 0.
static var zero_chance : float = 0.5
## The current index to look up in the value queue.
var value_index : int = 0

@export var block_scene : PackedScene
@export var block_parent : Node
## The initial grid position for spawned blocks.
var initial_block_grid_position : Vector2i

## Queue of currently instanced (but inactive) blocks.
var block_pool : Array[Block]

func _exit_tree() -> void:
	if value_queue.size() != 0:
		value_queue.clear()

## Creates a new block and adds it to the block pool.
func generate_block() -> void:
	var new_block : Block = block_scene.instantiate()
	new_block.connect("block_destroyed", Callable.create(self, "enqueue_block"))
	block_parent.add_child(new_block) # Blocks are parented to the game board (not the spawner)
	enqueue_block(new_block)

## Enqueues a block into the block pool.
func enqueue_block(new_block : Block) -> void:
	new_block.visible = false
	new_block.process_mode = PROCESS_MODE_DISABLED # Hide/disable the block
	block_pool.append(new_block) # Enqueue new block

## Returns the next block in the queue.
func dequeue_block(type : Block.VALUE_ENUM, grid_position : Vector2i, visual_position : Vector2) -> Block:
	if block_pool.is_empty():
		generate_block()
	
	var new_block = block_pool.get(0)
	block_pool.remove_at(0)
	new_block.visible = true
	new_block.process_mode = PROCESS_MODE_INHERIT
	
	new_block.set_value(type)
	new_block.spawn(grid_position, visual_position) # Respawn the block
	return new_block

## Returns the next block in the sequence.
func get_next_block_value() -> Block.VALUE_ENUM:
	var return_value : Block.VALUE_ENUM
	if value_index < value_queue.size():
		return_value = value_queue.get(value_index)
		value_index += 1
		return return_value
	
	return_value = Block.VALUE_ENUM.ZERO if randf() < zero_chance else Block.VALUE_ENUM.ONE
	value_index += 1
	value_queue.append(return_value) # Add to queue for other players
	if return_value == Block.VALUE_ENUM.ZERO:
		zero_chance -= 0.1
	else:
		zero_chance += 0.1
	zero_chance = clamp(zero_chance, 0, 1)
	return return_value

## Dequeues a block as a normal gameplay block.
func dequeue_normal_block(value : Block.VALUE_ENUM) -> Block:
	return dequeue_block(value, initial_block_grid_position, position)
