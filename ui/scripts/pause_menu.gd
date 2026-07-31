extends CanvasLayer

var open: bool = false

func _ready() -> void:
	open = false
	visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		open = not open
		visible = open
		if open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_button_pressed() -> void:
	open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_quit_button_pressed() -> void:
	get_tree().quit()
