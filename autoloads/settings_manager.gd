extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SENSITIVITY := 1.0
const DEFAULT_VOLUME := 1.0

var mouse_sensitivity_multiplier: float = DEFAULT_SENSITIVITY
var is_fullscreen: bool = false
var master_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME

var _config := ConfigFile.new()

func _ready() -> void:
	var error := _config.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Could not load settings from %s (error %d)." % [SETTINGS_PATH, error])

	mouse_sensitivity_multiplier = clampf(
		float(_config.get_value("controls", "mouse_sensitivity", DEFAULT_SENSITIVITY)),
		0.1,
		3.0
	)
	is_fullscreen = bool(_config.get_value("display", "fullscreen", false))
	master_volume = clampf(float(_config.get_value("audio", "master", DEFAULT_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(_config.get_value("audio", "music", DEFAULT_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(_config.get_value("audio", "sfx", DEFAULT_VOLUME)), 0.0, 1.0)

	_apply_fullscreen()
	_apply_audio_settings()

func set_mouse_sensitivity_multiplier(value: float) -> void:
	mouse_sensitivity_multiplier = clampf(value, 0.1, 3.0)
	_save_settings()

func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	_apply_fullscreen()
	_save_settings()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume("Master", master_volume)
	_save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume("Music", music_volume)
	_save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume("SFX", sfx_volume)
	_save_settings()

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_audio_settings() -> void:
	AudioManager.set_bus_volume("Master", master_volume)
	AudioManager.set_bus_volume("Music", music_volume)
	AudioManager.set_bus_volume("SFX", sfx_volume)

func _save_settings() -> void:
	_config.set_value("controls", "mouse_sensitivity", mouse_sensitivity_multiplier)
	_config.set_value("display", "fullscreen", is_fullscreen)
	_config.set_value("audio", "master", master_volume)
	_config.set_value("audio", "music", music_volume)
	_config.set_value("audio", "sfx", sfx_volume)
	var error := _config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Could not save settings to %s (error %d)." % [SETTINGS_PATH, error])
