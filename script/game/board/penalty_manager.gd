## Manages penalties to punish players who play too boring.
class_name PenaltyManager extends Node

@export var animation_player : AnimationPlayer
@export var penalty_icons : Array[Control]

## Should the penalty blocks drop immediately?
var drop_penalty_blocks_immediately : bool

## Number of lame plays performed.
var penalty_counter : int = 0
var penalty_severity : int = 1
## Number of lame plays allowed before we dump bricks on the player.
const MAX_PENALTY_INTERVAL = 4

func _ready() -> void:
	for i in penalty_icons.size():
		penalty_icons.get(i).visible = 0

## Called when the player does an overly safe play.
func add_penalty_count() -> void:
	penalty_counter += 1
	if penalty_counter == MAX_PENALTY_INTERVAL:
		update_penalty_blocks(penalty_severity)
		penalty_counter = 0
		penalty_severity += 1

## Resets the penalty counter and the penalty severity.
func reset_penalty_count() -> void:
	penalty_counter = 0
	penalty_severity = 1

## List of blocks that will be dropped after the turn ends.
var penalty_block_count : int
## Determines the x-positions in which penalty blocks are spawned.
var penalty_block_spawn_positions : Array[int]

## Creates the penalty block spawn position array based on a size.
func initialize_penalty_block_spawn_positions(size : int) -> void:
	penalty_block_spawn_positions.resize(size)
	for i in penalty_block_spawn_positions.size():
		penalty_block_spawn_positions.set(i, i)
	randomize_penalty_block_spawn_positions()

## Shuffles the order of random block spawns.
func randomize_penalty_block_spawn_positions() -> void:
	penalty_block_position_index = 0
	penalty_block_spawn_positions.shuffle()

## Tracks the index of the penalty block's spawn positions.
var penalty_block_position_index : int
## Returns the position to spawn a block in, then increments the count
func get_block_spawn_position() -> Vector2i:
	var return_value : Vector2i = Vector2i.MAX
	if penalty_block_position_index < penalty_block_spawn_positions.size():
		return_value = Vector2i.RIGHT * penalty_block_spawn_positions.get(penalty_block_position_index)
		penalty_block_position_index += 1
	return return_value

## Updates the number of penalty blocks queued to fall.
func update_penalty_blocks(amount : int) -> void:
	drop_penalty_blocks_immediately = amount > 0
	penalty_block_count += amount
	penalty_block_count = clamp(penalty_block_count, 0, get_max_penalty_count())
	animation_player.seek(0.0)
	animation_player.play("show")
	for i in penalty_icons.size():
		penalty_icons.get(i).visible = penalty_block_count > i

## Returns the maximum number of penalties that can be held at once.
func get_max_penalty_count() -> int:
	return penalty_icons.size()

## Returns whether there are blocks in the penalty queue or not.
func has_penalty_blocks() -> bool:
	return penalty_block_count != 0
