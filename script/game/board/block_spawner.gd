### Responsible for adding blocks to a game board.
class_name BlockSpawner extends Node2D

## The current index to look up in the value queue.
var value_index : int = 0

@export var block_scene : PackedScene
@export var block_parent : Node
## The initial grid position for spawned blocks.
var initial_block_grid_position : Vector2i

## Queue of currently instanced (but inactive) blocks.
var block_pool : Array[Block]

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
	return_value = BlockValueGenerator.instance.get_value_at(value_index)
	value_index += 1
	
	if value_index >= BlockValueGenerator.instance.value_queue.size() - 1:
		BlockValueGenerator.instance.rpc("queue_block_value")
	return return_value

## Dequeues a block as a normal gameplay block.
func dequeue_normal_block(value : Block.VALUE_ENUM) -> Block:
	return dequeue_block(value, initial_block_grid_position, position)
