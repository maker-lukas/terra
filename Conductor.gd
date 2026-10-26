extends AudioStreamPlayer
class_name Conductor

signal beat(number: int)

@export var bpm: float = 174.0
@export var first_beat_offset: float = 0.0
@export var metronome: bool = false
@export var beats_per_bar: int = 4

var song_position: float = 0.0
var song_beat: float = 0.0
var _last_beat: int = -1
var _last_click: int = -1
var _click_player: AudioStreamPlayer
var _click: AudioStreamWAV
var _bar_click: AudioStreamWAV


func _ready() -> void:
	_click_player = AudioStreamPlayer.new()
	add_child(_click_player)
	_click = _make_click(1000.0)
	_bar_click = _make_click(1600.0)


func _process(_delta: float) -> void:
	if not playing:
		return
	
	song_position = get_song_position()
	song_beat = song_position / (60.0 / bpm)
	while floori(song_beat) > _last_beat:
		_last_beat += 1
		beat.emit(_last_beat)
	
	if metronome:
		var click_beat := floori((song_position + AudioServer.get_output_latency()) / (60.0 / bpm))
		if click_beat > _last_click:
			_last_click = click_beat
			_click_player.stream = _bar_click if click_beat % beats_per_bar == 0 else _click
			_click_player.play()


func get_song_position() -> float:
	return get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() - first_beat_offset


func _make_click(frequency: float) -> AudioStreamWAV:
	var mix_rate := 44100
	var length := int(mix_rate * 0.03)
	var data := PackedByteArray()
	data.resize(length * 2)
	for i in length:
		var fade := 1.0 - float(i) / length
		var sample := sin(TAU * frequency * i / mix_rate) * fade * 0.8
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav
