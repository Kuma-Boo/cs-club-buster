extends Node

signal speed_changed(index : int) 

@export var board : GameBoard
@export var speed_amounts : Array[float]
@export var speed_thresholds : Array[int]
var speed_index : int
var current_line_count : int

func  recieve_lines(amount : int, _chain : int) -> void:
	current_line_count += amount
	
	while (speed_index < speed_thresholds.size() && current_line_count >= speed_thresholds[speed_index]):
		board.movement_interval = speed_amounts[speed_index]
		speed_index += 1;
		emit_signal("speed_changed", speed_index)
