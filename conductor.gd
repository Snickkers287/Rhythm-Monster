extends AudioStreamPlayer

@export var bpm = 162 
var beat := 0.0

func _process(_delta: float) -> void:
	if playing:
		beat = get_playback_position() * bpm / 60.0
