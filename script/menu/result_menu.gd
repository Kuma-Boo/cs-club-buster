class_name ResultMenu extends Control

static var instance : ResultMenu

@export var animator : AnimationPlayer
@export var continue_option : Control
var is_processing_menu : bool
var current_selection : int = 0
var previous_input_sign : int
var activation_timer : float
var use_activation_timer : bool
var is_pause_menu : bool
var allow_pausing : bool = true

func _enter_tree() -> void:
	instance = self
	activation_timer = 0

func _exit_tree() -> void:
	get_tree().paused = false

func _process(_delta: float) -> void:
	if !is_processing_menu:
		if use_activation_timer:
			activation_timer = move_toward(activation_timer, 0, get_process_delta_time())
			if is_zero_approx(activation_timer):
				show_menu()
		
		if allow_pausing && Input.is_action_just_pressed("pause"):
			is_pause_menu = true
			show_menu()
		return
	
	var input_sign : int = sign(Input.get_axis("ui_up", "ui_down"))
	if input_sign != previous_input_sign:
		previous_input_sign = input_sign
		current_selection += input_sign
		current_selection = clamp(current_selection, 0, 2)
		if !is_pause_menu:
			current_selection = max(current_selection, 1)
		animator.play("select-" + str(current_selection))
	
	if Input.is_action_just_pressed("ui_accept"):
		if current_selection == 0:
			animator.play("hide")
		else:
			animator.play("select")
		is_processing_menu = false

func show_menu_with_delay(time : float) -> void:
	activation_timer = time
	use_activation_timer = true

func show_menu() -> void:
	continue_option.visible = is_pause_menu;
	current_selection = 0 if is_pause_menu else 1
	animator.play("RESET")
	animator.advance(0.0)
	animator.play("select-" + str(current_selection))
	animator.advance(0.0)
	animator.play("show")
	allow_pausing = false
	use_activation_timer = false
	get_tree().paused = true

func on_menu_shown() -> void:
	is_processing_menu = true

func unpause() -> void:
	is_pause_menu = false
	allow_pausing = true
	get_tree().paused = false

func load_scenes() -> void:
	if current_selection == 1:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("uid://58q5jdrm3e8w") # Load the main menu
