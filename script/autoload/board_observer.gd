## Manages boards in a competitive game.
extends Node

## List of all currently active game boards.
var active_boards : Array

## The callable for when a board gets filled.
func get_board_filled_callable() -> Callable:
	return Callable.create(self, "on_board_filled")

## Registers a game board.
func register_game_board(board) -> void:
	active_boards.append(board)
	if !board.is_connected("board_filled", get_board_filled_callable()):
		board.connect("board_filled", get_board_filled_callable(), CONNECT_ONE_SHOT)

func unregister_game_board(board) -> void:
	if !active_boards.has(board):
		return
	if board.is_connected("board_filled", get_board_filled_callable()):
		board.disconnect("board_filled", get_board_filled_callable())
	active_boards.remove_at(active_boards.find(board))

func on_board_filled(board) -> void:
	unregister_game_board(board)
	if active_boards.size() == 1:
		active_boards.get(0).results.win()
		unregister_game_board(active_boards.get(0))
	ResultMenu.instance.show_menu_with_delay(0.5)
