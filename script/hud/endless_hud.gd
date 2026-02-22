### Responsible for displaying the score and blocks cleared to the player.
class_name HUD extends Node

@export var time_label : Label
@export var score_label : Label
@export var level_label : Label
@export var block_label : Label
@export var bonus_label : Label
@export var bonus_animation_player : AnimationPlayer
var is_board_clear_bonus_active : bool

var is_processing_hud : bool
var score : int
var blocks_destroyed : int
const TIME_STRING : String = "%s:%s.%s"

func _process(_delta : float) -> void:
	if !is_processing_hud:
		return
	process_time()

## Millisecond component of the time.
var ms : float
## Second component of the time.
var seconds : int
## Minute component of the time.
var minutes : int
## Updates the time and labels.
func process_time() -> void:
	ms += get_process_delta_time() * 1000
	if ms >= 1000:
		ms -= 1000
		seconds += 1
	if seconds >= 60:
		seconds -= 60
		minutes += 1
	time_label.text = TIME_STRING % [str("%02d" % minutes), str("%02d" % seconds), str("%03d" % ms)]

func start_game(_board : GameBoard) -> void:
	is_processing_hud = true

func end_game(_board : GameBoard) -> void:
	is_processing_hud = false

#################
#####Signals#####
#################
## Chain String format
const CHAIN_STRING : String = "%s CHAIN!"
## Updates the number of blocks destroyed.
func on_blocks_destroyed(block_count : int, chain_count : int) -> void:
	blocks_destroyed += block_count
	block_label.text = str("%02d" % blocks_destroyed)
	var score_amount = (100 * block_count) * chain_count
	if is_board_clear_bonus_active:
		score_amount *= 2
	score += score_amount
	score_label.text = str("%08d" % score)
	if chain_count > 1 or is_board_clear_bonus_active:
		# Play chain animations
		var bonus_string : String = CHAIN_STRING % chain_count
		if is_board_clear_bonus_active:
			bonus_string += " (x2)"
		play_bonus(bonus_string)

func set_level(level : int) -> void:
	level_label.text = str("%02d" % (level + 1))
	play_bonus("SPEED UP!")

## Plays the bonus animation
func play_bonus(message : String) -> void:
	bonus_label.text = message
	bonus_animation_player.seek(0.0)
	bonus_animation_player.play("bonus")

## Called whenever a chain is ended.
func on_chain_ended() -> void:
	if bonus_animation_player.is_playing() || bonus_animation_player.assigned_animation != "bonus":
		return
	is_board_clear_bonus_active = false
	bonus_animation_player.play("bonus-end")

func on_board_cleared() -> void:
	play_bonus("BOARD CLEARED")
	is_board_clear_bonus_active = true
