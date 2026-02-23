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

func unregister_all_boards() -> void:
	while active_boards.size() != 0:
		unregister_game_board(active_boards[0])

func on_board_filled(board) -> void:
	unregister_game_board(board)
	if active_boards.size() == 1:
		active_boards.get(0).results.rpc("win")
		unregister_game_board(active_boards.get(0))
		
		if NetworkManager.is_online && NetworkManager.is_hosting_game:
			for i in NetworkManager.network_statuses.keys():
				NetworkManager.set_network_status(i, 0)
	
	if !NetworkManager.is_online || NetworkManager.is_hosting_game:
		ResultMenu.instance.show_menu_with_delay(0.5)
