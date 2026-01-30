### Manages the controls and block positions of the board.
class_name GameBoard extends Control

## Emitted when the board starts processing.
signal board_started(board : GameBoard)
## Emitted when the board is filled.
signal board_filled(board : GameBoard)
## Alternative signal used for single player.
signal board_filled_no_ref()
## Emitted when the board was cleared.
signal board_cleared()
## Emitted when a chain is ended.
signal chain_ended()
## Emitted when a block is destroyed.
signal blocks_destroyed(block_count : int, chain : int)
## Emitted when blocks are sent to another player.
signal blocks_sent(block_count : int)

## Are we currently processing gameplay?
var is_processing_board : bool

## How fast blocks should fall.
@export var movement_interval : float = 0.5
@export var lose_on_fill : bool = true

@export_range(1, 4, 1) var board_index : int = 1
@export var input_manager : InputManager
@export var penalty_manager : PenaltyManager
@export var block_spawner : BlockSpawner
## Reference to the current block being moved.
@export var current_block : Block
## Reference to the board's result screen.
@export var results : BoardResults
## Reference to the next block coming up.
@export var preview_block : Block

## An array containing references to all blocks currently in the grid.
var block_array : Array[Block]

#########################
#####GODOT FUNCTIONS#####
#########################
func _ready() -> void:
	initialize_board()
	initialize_block_spawner()
	input_manager.player_index = board_index
	penalty_manager.initialize_penalty_block_spawn_positions(board_size.x)

func _enter_tree() -> void:
	BoardObserver.register_game_board(self)

func _exit_tree() -> void:
	BoardObserver.unregister_game_board(self)

func _process(_delta: float) -> void:
	if !is_processing_board:
		return
	
	if is_auto_dropping_blocks:
		process_auto_drops()
		return
	
	process_block_validity()
	process_block_rotation()
	process_horizontal_movement()
	process_vertical_movement()

##################################
#####INITIALIZATION FUNCTIONS#####
##################################
## How many spaces the board has.
@export var board_size : Vector2i
## How much to offset grid-based sprites.
var board_offset : Vector2
## The size of each block, in pixels.
const BOARD_INTERVAL : int = 64
## Initialize the board offsets and grid visuals.
func initialize_board() -> void:
	# Calculate board offset
	board_offset.x = BOARD_INTERVAL * 0.5
	board_offset.x -= (board_size.x / 2.0) * BOARD_INTERVAL
	board_offset.y = -(board_size.y - 1) * BOARD_INTERVAL
	# Set up internal array
	block_array.resize(board_size.x * board_size.y)
	preview_block.initialize_as_preview_block()

## Initialize the block spawner's position and internal grid data.
func initialize_block_spawner() -> void:
	var spawner_position : Vector2i
	@warning_ignore("integer_division")
	spawner_position.x = board_size.x / 2 # Place the spawner in the middle
	spawner_position.y = 0 # Keep the spawner in the game field
	block_spawner.initial_block_grid_position = spawner_position
	block_spawner.position = calculate_block_position(spawner_position)

###########################
#####PROCESS FUNCTIONS#####
###########################
## Tracks whether the board is currently processing auto-dropped blocks.
var is_auto_dropping_blocks : bool
## Tracks the number of chains performed.
var current_chain_count : int
## Tracks the number of blocks destroyed for this round.
var current_blocks_destroyed_count : int
## Tracks which blocks were moved by the board manager so we can play the correct animations.
var moved_blocks : Array[Block]
## Moves all the blocks downwards and checks for clears
func process_auto_drops() -> void:
	if is_destroying_blocks:
		# Animations are still active
		return
	
	if !is_zero_approx(vertical_timer):
		# Waiting for timer; return early
		vertical_timer = move_toward(vertical_timer, 0.0, get_process_delta_time())
		return
	
	var was_block_moved : bool = false # Tracks whether any blocks were moved this frame.
	for y in range(board_size.y - 1, -1, -1): # Process each row
		for x in board_size.x: # Process each column
			var block : Block = get_block_at_grid_position(Vector2i(x, y))
			if block == null:
				# Skip; there is no block
				continue
			
			if can_move_block(block, Vector2i.DOWN):
				if !moved_blocks.has(block):
					moved_blocks.append(block)
				was_block_moved = true
				move_block(block, Vector2i.DOWN)
			elif block.is_moving_visual_position():
				was_block_moved = true
			elif moved_blocks.has(block):
				finalize_block_position(block)
	
	if !was_block_moved:
		# Check block clears after we finished dropping all the blocks
		moved_blocks.clear()
		check_block_clears()

## Checks whether the current block exists, and spawns a new block as needed.
func process_block_validity() -> void:
	if current_block != null:
		# Block exists; return early
		return
	spawn_block()

## Rotates the block based on user input.
func process_block_rotation() -> void:
	var rotation_input : int = input_manager.get_rotation_axis()
	if rotation_input != 0:
		current_block.rotate_grid_direction(rotation_input)

## Processes horizontal movement for the current block.
func process_horizontal_movement() -> void:
	if input_manager.is_holding_down():
		# Disable horizontal movement when fast dropping
		return
	
	# Get input
	var input_direction : int = input_manager.get_movement_axis()
	if input_direction == 0:
		return
	
	# Calculate the target position
	var target_direction : Vector2i = Vector2i.RIGHT * input_direction
	if !can_move_block(current_block, target_direction):
		# Obstructed; don't move
		return
	
	# Move the current block
	move_block(current_block, target_direction)
	input_manager.use_movement_axis()

## Timer to track vertical movement. 
var vertical_timer : float
const FAST_DROP_INTERVAL : float = 0.02
## Moves the current block downwards, if possible.
func process_vertical_movement() -> void:
	if input_manager.is_dropping():
		# Force-drop the block
		while can_move_block(current_block, Vector2i.DOWN):
			move_block(current_block, Vector2i.DOWN)
		finalize_block_position(current_block)
		return
	
	if !is_zero_approx(vertical_timer):
		# Waiting for timer; return early
		vertical_timer = move_toward(vertical_timer, 0.0, get_process_delta_time())
		if input_manager.is_holding_down():
			# Fast dropping; reduce timer if possible
			vertical_timer = min(FAST_DROP_INTERVAL, vertical_timer)
		return
	
	if !can_move_block(current_block, Vector2i.DOWN):
		# Block landed on something; finalize block's position and spawn a new block
		finalize_block_position(current_block)
		return
	
	# Move block down
	move_block(current_block, Vector2i.DOWN)
	vertical_timer = movement_interval # Reset vertical timer

###########################
#####ONESHOT FUNCTIONS#####
###########################
## Sets processing to true.
func start_processing_board() -> void:
	is_processing_board = true
	preview_block.update_grid_rotation(Vector2i.ZERO)
	preview_block.set_value(block_spawner.get_next_block_value())
	preview_block.spawn_as_preview_block()
	emit_signal("board_started", self)

## Finalizes a block's position and direction.
func finalize_block_position(block : Block) -> void:
	vertical_timer = 0 # Reset vertical timer
	block.finish_drop() # Play animation
	var target_position : Vector2i = block.grid_position + block.grid_direction
	if is_invalid_grid_position(target_position):
		# Invalid position; return early (there's no way any block got cleared)
		block.update_grid_rotation(Vector2i.ZERO)
		if block == current_block:
			# Spawn a new block immediately
			spawn_block()
		return
	
	var next_block : Block = get_block_at_grid_position(target_position)
	if next_block != null && next_block.grid_direction == -block.grid_direction:
		# Prevent blocks from pointing at each other
		next_block.update_grid_rotation(Vector2i.ZERO)
	
	if block == current_block:
		check_block_clears()

const PENALTY_BLOCK_DELAY : float = 0.2
## Spawns a number of penalty blocks based on the penalty manager.
func spawn_penalty_blocks() -> void:
	vertical_timer = PENALTY_BLOCK_DELAY
	var blocks_spawned : int = 0
	penalty_manager.randomize_penalty_block_spawn_positions()
	for i in penalty_manager.penalty_block_count:
		var spawn_position : Vector2i = penalty_manager.get_block_spawn_position()
		if spawn_position == Vector2i.MAX:
			# No more space to spawn penalty blocks.
			break
		
		var visual_position : Vector2 = calculate_block_position(spawn_position)
		var new_block : Block = block_spawner.dequeue_block(Block.VALUE_ENUM.PENALTY, spawn_position, visual_position)
		set_block_at_grid_position(new_block.grid_position, new_block)
		blocks_spawned += 1
	penalty_manager.update_penalty_blocks(-blocks_spawned)
	is_auto_dropping_blocks = true

## Returns a free spot at the top of the board for penalty blocks.
func get_penalty_spawn_position() -> Vector2i:
	return Vector2i.MAX

## Spawns a block and resets timers.
func spawn_block() -> void:
	if !can_spawn_block():
		emit_signal("board_filled", self)
		emit_signal("board_filled_no_ref")
		if lose_on_fill:
			results.lose()
		return
	
	current_block = block_spawner.dequeue_normal_block(preview_block.value)
	preview_block.set_value(block_spawner.get_next_block_value())
	preview_block.spawn_as_preview_block()
	set_block_at_grid_position(current_block.grid_position, current_block)
	input_manager.use_movement_axis()
	vertical_timer = movement_interval

func stop_processing_board() -> void:
	is_processing_board = false

## Checks whether the block spawner's position is covered.
func can_spawn_block() -> bool:
	return get_block_at_grid_position(block_spawner.initial_block_grid_position) == null

const CHAIN_CLEAR_LENGTH = 4
## Checks whether blocks have been cleared.
func check_block_clears() -> void:
	var checked_blocks : Array[Block] # Tracks which blocks were checked this frame
	var cleared_blocks : Array[Block] # Tracks which blocks were cleared this frame
	var has_block_in_current_row : bool = true
	
	for y in range(board_size.y - 1, -1, -1): # Process each row
		has_block_in_current_row = false # Reset the flag before checking blocks
		for x in board_size.x: # Process each column
			var block : Block = get_block_at_grid_position(Vector2i(x, y))
			if block == null:
				# Skip; there is no block
				continue
			
			has_block_in_current_row = true
			if checked_blocks.has(block):
				# Skip; we've already processed this block
				continue
			
			# Calculate the chain and add blocks to appropriate arrays
			var chain : Array[Block] = calculate_chain(block)
			if chain.size() < CHAIN_CLEAR_LENGTH:
				add_blocks_to_array(checked_blocks, chain)
			elif add_blocks_to_array(cleared_blocks, chain):
				current_chain_count += 1
				penalty_manager.update_penalty_blocks(-1)
				if current_chain_count > 1:
					# Send some blocks
					emit_signal("blocks_sent", 1)
		
		# Check if we can end early
		if !has_block_in_current_row:
			# No more blocks to process; break early
			break
	
	if checked_blocks.size() == 0:
		# Board was empty
		emit_signal("board_cleared")
		emit_signal("blocks_sent", 1) # Send some blocks
	destroy_blocks(cleared_blocks)

func destroy_blocks(blocks : Array[Block]) -> void:
	current_blocks_destroyed_count += blocks.size()
	is_auto_dropping_blocks = blocks.size() != 0 # Update clearing flag
	if !is_auto_dropping_blocks:
		attempt_block_spawn()
		update_penalties()
		finish_chain()
		return
	
	if blocks.size() > CHAIN_CLEAR_LENGTH:
		# Send some blocks
		emit_signal("blocks_sent", blocks.size() - CHAIN_CLEAR_LENGTH)
	emit_signal("blocks_destroyed", blocks.size(), current_chain_count)
	is_destroying_blocks = true
	blocks.get(0).connect("block_destroyed", Callable.create(self, "on_blocks_destroyed"), CONNECT_ONE_SHOT + CONNECT_DEFERRED)
	for block in blocks:
		# Destroy all the cleared blocks
		block.destroy_block()
		set_block_at_grid_position(block.grid_position, null)

## Attempts to spawn a block to continue the game.
func attempt_block_spawn() -> void:
	if penalty_manager.has_penalty_blocks():
		if penalty_manager.drop_penalty_blocks_immediately:
			spawn_penalty_blocks()
			return
		else:
			penalty_manager.drop_penalty_blocks_immediately = true
	# Spawn a new block to continue the game
	spawn_block()

## Ends the current chain.
func finish_chain() -> void:
	if current_chain_count == 0:
		return
	
	# End the chain
	current_chain_count = 0
	emit_signal("chain_ended")

## Updates penalties based on the number of blocks destroyed.
func update_penalties() -> void:
	if current_chain_count != 0:
		if current_chain_count == 1 && current_blocks_destroyed_count == CHAIN_CLEAR_LENGTH:
			# Punish lame play
			penalty_manager.add_penalty_count()
		else:
			penalty_manager.reset_penalty_count()
	current_blocks_destroyed_count = 0

## Called when receiving penalty blocks from another player.
func recieve_penalty_blocks(count : int) -> void:
	penalty_manager.update_penalty_blocks(count)

## Tracks whether blocks are currently being destroyed.
var is_destroying_blocks : bool
## Called after all blocks have been destroyed.
func on_blocks_destroyed(_block : Block) -> void:
	is_destroying_blocks = false

## Adds blocks to a given array without duplicates.
func add_blocks_to_array(arr : Array[Block], append_arr : Array[Block]) -> int:
	# Tracks whether append_arr represents a new chain of blocks
	var is_new_chain : bool = true
	for block in append_arr:
		if arr.has(block): # Check for duplicates
			is_new_chain = false # Duplicate blocks means this is an extension of an existing chain
			continue
		arr.append(block)
	return is_new_chain

## Returns an array containing all the blocks in the chain (starting from the given block).
func calculate_chain(block : Block) -> Array[Block]:
	var chain : Array[Block] = [block]
	var next_block : Block = get_block_at_grid_position(block.grid_position + block.grid_direction)
	while next_block != null:
		if chain.has(next_block):
			# Cyclic chain; chain ended
			return chain
		if next_block.value != block.value:
			# Value mis-match; chain ended
			if chain.size() >= CHAIN_CLEAR_LENGTH && next_block.value == Block.VALUE_ENUM.PENALTY:
				# Allow penalty blocks to be destroyed
				chain.append(next_block)
			return chain
		chain.append(next_block)
		if next_block.grid_direction == Vector2i.ZERO: # End of the chain
			return chain
		next_block = get_block_at_grid_position(next_block.grid_position + next_block.grid_direction)
	return chain

###########################
#####UTILITY FUNCTIONS#####
###########################
## Calculates and returns the block's position (Vector2), given a grid position (Vector2i).
func calculate_block_position(pos : Vector2i) -> Vector2:
	var block_position : Vector2 = pos * BOARD_INTERVAL # Convert grid position to pixel positions
	block_position += board_offset # Add the board's offset
	return block_position

## Returns whether a block can be moved in a given direction or not 
func can_move_block(block : Block, direction : Vector2i) -> bool:
	var target_position : Vector2i = block.grid_position + direction
	if target_position.y >= board_size.y:
		# Trying to move through the floor
		return false
	
	if target_position.x < 0 || target_position.x >= board_size.x:
		# Trying to move through the walls
		return false
	
	# Block is only movable if there isn't a block in its path
	return get_block_at_grid_position(block.grid_position + direction) == null

## Moves a block in a given direction.
func move_block(block : Block, move_direction : Vector2i) -> void:
	# Remove block from internal array
	set_block_at_grid_position(block.grid_position, null)
	
	# Set the blocks target visual position
	block.grid_position += move_direction
	var target_position : Vector2 = calculate_block_position(block.grid_position)
	block.set_target_position(target_position)
	
	# Update internal array
	set_block_at_grid_position(block.grid_position, block)

## Returns the block at a given (x, y) position.
func get_block_at_grid_position(grid_pos : Vector2i) -> Block:
	if is_invalid_grid_position(grid_pos):
		return
	return block_array.get(grid_pos.x + (grid_pos.y * board_size.x))

## Sets the block at the given (x, y) position.
func set_block_at_grid_position(grid_pos : Vector2i, block : Block) -> void:
	if is_invalid_grid_position(grid_pos):
		return
	block_array.set(grid_pos.x + (grid_pos.y * board_size.x), block)

## Returns whether a grid position is invalid or not.
func is_invalid_grid_position(grid_pos : Vector2i) -> bool:
	return grid_pos.x < 0 || grid_pos.x >= board_size.x || grid_pos.y < 0 || grid_pos.y >= board_size.y
