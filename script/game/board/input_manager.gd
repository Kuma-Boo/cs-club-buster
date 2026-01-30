## Manages inputs.
class_name InputManager extends Node

# The index of the player. Set from a Game Board.
var player_index : int
# The current movement axis being held.
var movement_axis : int
# The current rotation axis being held.
var rotation_axis : int

func get_player_prefix() -> String:
	return "p%s_" % player_index

func _process(_delta : float) -> void:
	process_movement_axis()
	# Update rotation axis
	if Input.is_action_just_pressed(get_player_prefix() + "rotate_clockwise"):
		rotation_axis = 1
	elif Input.is_action_just_pressed(get_player_prefix() + "rotate_counterclockwise"):
		rotation_axis = -1

## Tracks whether the repeated input is the first one or not.
var is_holding_horizontal : bool
## Timer to track repeating inputs.
var horizontal_timer : float
## How long to wait for the first repeated input.
const INITIAL_INPUT_INTERVAL = 0.2
## How long to wait for repeated inputs.
const REPEAT_INPUT_INTERVAL = 0.06
func process_movement_axis() -> void:
	movement_axis = 0
	# Get input
	var input_direction : int = sign(Input.get_axis(get_player_prefix() + "move_left", get_player_prefix() + "move_right"))
	if input_direction == 0: # No input; reset timers and return early
		is_holding_horizontal = false
		horizontal_timer = 0.0
		return
	
	if !is_zero_approx(horizontal_timer): # Wait for timers to finish
		horizontal_timer = move_toward(horizontal_timer, 0.0, get_process_delta_time())
		return
	movement_axis = input_direction

## Updates the movement axis timers.
func use_movement_axis() -> void:
	# Update timers
	horizontal_timer = REPEAT_INPUT_INTERVAL if is_holding_horizontal else INITIAL_INPUT_INTERVAL
	is_holding_horizontal = true

## Returns (and resets) movement_axis.
func get_movement_axis() -> int:
	return movement_axis

## Returns whether the player is holding down.
func is_holding_down() -> bool:
	return Input.is_action_pressed(get_player_prefix() + "move_down")

## Returns whether the player is dropping a block or not.
func is_dropping() -> bool:
	return Input.is_action_just_pressed(get_player_prefix() + "drop")

## Returns (and resets) rotation_axis.
func get_rotation_axis() -> int:
	var return_value : int = rotation_axis
	rotation_axis = 0
	return return_value
