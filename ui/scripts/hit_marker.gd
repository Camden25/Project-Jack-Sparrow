extends Control

var lifetime: float = 0.2

func _ready() -> void:
	$Timer.start(lifetime)

func destroy() -> void:
	queue_free()

func _on_timer_timeout() -> void:
	destroy()
