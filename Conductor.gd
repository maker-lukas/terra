extends AudioStreamPlayer
class_name Conductor

signal beat(number: int)

@export var bpm: float = 174.0
## Seconds from the start of the audio file to beat 0.
@export var first_beat_offset: float = 0.0

var song_position: float = 0.0
var song_beat: float = 0.0
var _last_beat: int = -1

func _process(_delta: float) -> void:
	if not playing:
		return
	
	song_position = get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() - first_beat_offset
	song_beat = song_position / (60.0 / bpm)
	# floori so the intro (negative beats) doesn't count as beat 0,
	# and a loop so no beat signal is skipped after a lag spike.
	while floori(song_beat) > _last_beat:
		_last_beat += 1
		beat.emit(_last_beat)
