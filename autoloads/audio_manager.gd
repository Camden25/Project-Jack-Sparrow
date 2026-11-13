extends Node

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var _music_player: AudioStreamPlayer

func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		push_error("AudioManager.play_sfx requires an AudioStream.")
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		push_error("AudioManager.play_music requires an AudioStream.")
		return
	if _music_player.stream == stream and _music_player.playing:
		return

	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_music_player.stream = null

func set_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Audio bus '%s' does not exist." % bus_name)
		return

	var clamped_volume := clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_linear(bus_index, maxf(clamped_volume, 0.0001))
	AudioServer.set_bus_mute(bus_index, clamped_volume == 0.0)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	var bus_index := AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
