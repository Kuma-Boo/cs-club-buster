class_name ResultMenu extends Control

static var instance : ResultMenu

@export var animator : AnimationPlayer
var is_processing_menu : bool
var current_selection : int = 0
var previous_input_sign : int
var activation_timer : float

func _enter_tree() -> void:
	instance = self

func _process(_delta: float) -> void:
	if !is_processing_menu:
		if !is_zero_approx(activation_timer):
			activation_timer = move_toward(activation_timer, 0, get_process_delta_time())
			if is_zero_approx(activation_timer):
				show_menu()
		return
	
	var input_sign : int = sign(Input.get_axis("ui_up", "ui_down"))
	if input_sign != previous_input_sign:
		previous_input_sign = input_sign
		current_selection += input_sign
		current_selection = clamp(current_selection, 0, 1)
		animator.play("select-" + str(current_selection))
	
	if Input.is_action_just_pressed("ui_accept"):
		animator.play("select")
		is_processing_menu = false

func show_menu_with_delay(time : float) -> void:
	activation_timer = time

func show_menu() -> void:
	animator.play("show")

func on_menu_shown() -> void:
	is_processing_menu = true

func load_scenes() -> void:
	if current_selection == 0:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("uid://58q5jdrm3e8w") # Load the main menu
