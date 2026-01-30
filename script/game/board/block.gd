class_name Block extends Node2D
### Represents a block in the grid.

## Emitted when the block is fully cleared and ready to be re-queued.
signal block_destroyed(block : Block)

## Reference to the block's animation player.
@export var block_anim_player : AnimationPlayer
## Reference to the rotation animation player.
@export var direction_anim_player : AnimationPlayer
@export var direction_root : Node2D

## The block's current position on the board.
var grid_position : Vector2i
## The block's link direction. Defaults to UP.
var grid_direction : Vector2i = Vector2i.UP

## The block's value.
var value : VALUE_ENUM = VALUE_ENUM.ZERO
## An enum containing all possible values.
enum VALUE_ENUM {
	ZERO,
	ONE,
	PENALTY,
	COUNT
}

@export var visual_smoothing_curve : Curve
@export var visual_smoothing_speed : float
## The position from which visual smoothing starts at.
var initial_visual_position : Vector2
## The position to which visual smoothing ends at.
var target_visual_position : Vector2
## The linear ratio between the visual's initial position and target position.
var visual_smoothing_linear : float

## Changes the block's current value and updates its animation.
func set_value(new_value : VALUE_ENUM) -> void:
	value = new_value
	block_anim_player.play("RESET")
	block_anim_player.advance(0.0)
	
	if value == VALUE_ENUM.ZERO:
		block_anim_player.play("zero")
	elif value == VALUE_ENUM.ONE:
		block_anim_player.play("one")
	else:
		block_anim_player.play("penalty")
	block_anim_player.advance(0.0)

## Moves the block to the given position.
func spawn(grid_pos : Vector2i, visual_pos : Vector2) -> void:
	grid_position = grid_pos
	initial_visual_position = visual_pos
	target_visual_position = visual_pos
	position = visual_pos
	block_anim_player.play("spawn")
	
	if value != VALUE_ENUM.PENALTY:
		update_grid_rotation(Vector2i.UP)
	else:
		grid_direction = Vector2i.ZERO
		direction_anim_player.play("hide")
		direction_anim_player.advance(0.0)

## Spawns the block as a preview block.
func spawn_as_preview_block() -> void:
	block_anim_player.play("spawn")
	block_anim_player.advance(0.0)
	direction_anim_player.play("hide")
	direction_anim_player.advance(0.0)

## Initializes the block as a preview block.
func initialize_as_preview_block() -> void:
	block_anim_player.play("spawn-preview")
	direction_anim_player.play("hide")
	direction_anim_player.advance(0.0)

## Rotates the block's grid direction clockwise (1) or counter-clockwise (-1).
func rotate_grid_direction(direction : int) -> void:
	update_grid_rotation((grid_direction as Vector2).rotated(PI * 0.5 * direction).round() as Vector2i)

## Updates the visual direction.
func update_grid_rotation(direction : Vector2i) -> void:
	grid_direction = direction
	if direction == Vector2i.ZERO:
		direction_anim_player.play("remove-direction")
		return
	
	direction_root.rotation = (direction as Vector2).angle()
	direction_anim_player.seek(0.0)
	direction_anim_player.play("change-direction")

func _process(_delta: float) -> void:
	process_visual_position()

## Moves the block's visual position to its target visual position.
func process_visual_position() -> void:
	visual_smoothing_linear = move_toward(visual_smoothing_linear, 1.0, visual_smoothing_speed * get_process_delta_time())
	var t : float = visual_smoothing_curve.sample(visual_smoothing_linear)
	position = initial_visual_position.lerp(target_visual_position, t)

## Sets the block's visual target position.
func set_target_position(pos : Vector2) -> void:
	initial_visual_position = position
	target_visual_position = pos
	visual_smoothing_linear = 0.0
	block_anim_player.seek(0.0)
	block_anim_player.play("jiggle")

## Returns whether the block's visuals are moving.
func is_moving_visual_position() -> bool:
	return !position.is_equal_approx(target_visual_position)

## Called when the block hits the ground.
func finish_drop() -> void:
	block_anim_player.play("drop")

## Called when the block is destroyed.
func destroy_block() -> void:
	block_anim_player.play("destroy")
	direction_anim_player.play("remove-direction")

## Called from the animation player.
func on_block_destroyed() -> void:
	emit_signal("block_destroyed", self)
