extends CanvasLayer

var open: bool = false

@onready var pause_panel: Control = $CenterContainer/PausePanel
@onready var settings_menu: SettingsMenu = $SettingsMenu

func _ready() -> void:
	open = false
	visible = false
	settings_menu.return_pressed.connect(_on_settings_return_pressed)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_set_open(not open)

func _on_resume_button_pressed() -> void:
	_set_open(false)

func _on_settings_button_pressed() -> void:
	pause_panel.hide()
	settings_menu.show()

func _on_settings_return_pressed() -> void:
	settings_menu.hide()
	pause_panel.show()

func _on_quit_button_pressed() -> void:
	_set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.disconnect_game()
	PlayerManager.hero_selections.clear()
	SceneManager.goto_scene("res://menus/scenes/lobby_ui.tscn")

func _set_open(is_open: bool) -> void:
	open = is_open
	visible = open
	settings_menu.hide()
	pause_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
