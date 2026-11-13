extends Control
class_name SettingsMenu

signal return_pressed

@onready var fullscreen_toggle: CheckButton = $CenterContainer/Panel/Margin/VBox/FullscreenToggle
@onready var sensitivity_slider: HSlider = $CenterContainer/Panel/Margin/VBox/SensitivityRow/SensitivitySlider
@onready var sensitivity_value: Label = $CenterContainer/Panel/Margin/VBox/SensitivityRow/SensitivityValue
@onready var master_slider: HSlider = $CenterContainer/Panel/Margin/VBox/MasterRow/MasterSlider
@onready var master_value: Label = $CenterContainer/Panel/Margin/VBox/MasterRow/MasterValue
@onready var music_slider: HSlider = $CenterContainer/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var music_value: Label = $CenterContainer/Panel/Margin/VBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $CenterContainer/Panel/Margin/VBox/SFXRow/SFXSlider
@onready var sfx_value: Label = $CenterContainer/Panel/Margin/VBox/SFXRow/SFXValue

func _ready() -> void:
	fullscreen_toggle.button_pressed = SettingsManager.is_fullscreen
	sensitivity_slider.value = SettingsManager.mouse_sensitivity_multiplier
	master_slider.value = SettingsManager.master_volume
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	_update_sensitivity_value(sensitivity_slider.value)
	_update_volume_value(master_value, master_slider.value)
	_update_volume_value(music_value, music_slider.value)
	_update_volume_value(sfx_value, sfx_slider.value)

	fullscreen_toggle.toggled.connect(SettingsManager.set_fullscreen)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity_multiplier(value)
	_update_sensitivity_value(value)

func _on_master_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)
	_update_volume_value(master_value, value)

func _on_music_volume_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)
	_update_volume_value(music_value, value)

func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)
	_update_volume_value(sfx_value, value)

func _update_sensitivity_value(value: float) -> void:
	sensitivity_value.text = "%d%%" % roundi(value * 100.0)

func _update_volume_value(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value * 100.0)

func _on_reset_button_pressed() -> void:
	fullscreen_toggle.button_pressed = false
	sensitivity_slider.value = SettingsManager.DEFAULT_SENSITIVITY
	master_slider.value = SettingsManager.DEFAULT_VOLUME
	music_slider.value = SettingsManager.DEFAULT_VOLUME
	sfx_slider.value = SettingsManager.DEFAULT_VOLUME
	SettingsManager.set_fullscreen(false)
	SettingsManager.set_mouse_sensitivity_multiplier(SettingsManager.DEFAULT_SENSITIVITY)
	SettingsManager.set_master_volume(SettingsManager.DEFAULT_VOLUME)
	SettingsManager.set_music_volume(SettingsManager.DEFAULT_VOLUME)
	SettingsManager.set_sfx_volume(SettingsManager.DEFAULT_VOLUME)
	_update_sensitivity_value(sensitivity_slider.value)
	_update_volume_value(master_value, master_slider.value)
	_update_volume_value(music_value, music_slider.value)
	_update_volume_value(sfx_value, sfx_slider.value)

func _on_back_button_pressed() -> void:
	return_pressed.emit()
