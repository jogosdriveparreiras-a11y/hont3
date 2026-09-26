extends Node
class_name HotNSoundBus

const RATE := 22050
const CHANNELS := ["MUSIC", "SFX", "UI", "AMBIENCE"]
var levels: Dictionary = {"MASTER": 0.8, "MUSIC": 0.35, "SFX": 0.7, "UI": 0.55, "AMBIENCE": 0.18}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var cue_players: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var next_voice := 0

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	music.stream = _make_music()
	music.play()
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	ambience.stream = _make_ambience()
	ambience.play()
	for index in range(8):
		var voice := AudioStreamPlayer.new()
		voice.set_meta("channel", "SFX")
		cue_players.append(voice)
		add_child(voice)
	for id in ["hover", "select", "draw", "redraw", "cast", "hit", "block", "heal", "status", "death", "victory", "resist", "move"]:
		cues[id] = _synthesize(id)
	_apply_levels()

func _synthesize(id: String) -> AudioStreamWAV:
	var frequencies := {"hover": 480.0, "select": 610.0, "draw": 460.0, "redraw": 310.0, "cast": 390.0, "hit": 120.0, "block": 190.0, "heal": 720.0, "status": 350.0, "death": 95.0, "victory": 530.0, "resist": 260.0, "move": 330.0}
	var durations := {"hover": 0.055, "select": 0.11, "draw": 0.12, "redraw": 0.14, "cast": 0.18, "hit": 0.15, "block": 0.16, "heal": 0.30, "status": 0.18, "death": 0.42, "victory": 0.50, "resist": 0.14, "move": 0.13}
	var count := int(RATE * float(durations[id]))
	var frequency: float = frequencies[id]
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in range(count):
		var time := float(index) / float(RATE)
		var fade := pow(1.0 - float(index) / float(count), 2.0)
		var sweep := frequency * (1.0 - 0.3 * float(index) / float(count))
		var tone := sin(TAU * sweep * time) + 0.23 * sin(TAU * sweep * 1.97 * time)
		if id in ["hit", "block", "death"]: tone += 0.38 * sin(float(index * 73 % 101) * 1.4)
		var sample := clampi(roundi(tone * fade * 7800.0), -32768, 32767)
		pcm[index * 2] = sample & 255
		pcm[index * 2 + 1] = (sample >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = pcm
	return wav

func _make_ambience() -> AudioStreamWAV:
	var count := RATE * 2
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in range(count):
		var time := float(index) / float(RATE)
		var value := sin(TAU * 55.0 * time) * (0.55 + 0.25 * sin(TAU * 0.5 * time))
		var sample := roundi(value * 2800.0)
		pcm[index * 2] = sample & 255
		pcm[index * 2 + 1] = (sample >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav

func _make_music() -> AudioStreamWAV:
	# Four original phrases; the waveform and sounds are produced locally.
	var notes := [220.0, 261.63, 329.63, 261.63, 196.0, 246.94, 293.66, 246.94, 174.61, 220.0, 261.63, 220.0, 164.81, 196.0, 246.94, 196.0]
	var roots := [110.0, 98.0, 87.31, 82.41]
	var count := RATE * 8
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in range(count):
		var time := float(index) / float(RATE)
		var beat := mini(15, int(time * 2.0))
		var beat_time := fmod(time, 0.5)
		var envelope := minf(1.0, beat_time * 32.0) * pow(maxf(0.0, 1.0 - beat_time * 1.5), 2.0)
		var lead := (sin(TAU * notes[beat] * time) + 0.18 * sin(TAU * notes[beat] * 2.0 * time)) * envelope
		var root: float = roots[mini(3, int(time / 2.0))]
		var pad := 0.35 * sin(TAU * root * time) + 0.12 * sin(TAU * root * 1.5 * time)
		var edge := minf(1.0, minf(time, 8.0 - time) * 8.0)
		var sample := clampi(roundi((lead * 0.34 + pad * 0.4) * edge * 7500.0), -32768, 32767)
		pcm[index * 2] = sample & 255
		pcm[index * 2 + 1] = (sample >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav

func cue(id: String, channel: String = "SFX") -> void:
	if not cues.has(id) or cue_players.is_empty(): return
	var voice: AudioStreamPlayer = cue_players[next_voice % cue_players.size()]
	next_voice += 1
	voice.set_meta("channel", "UI" if channel == "UI" else "SFX")
	voice.stream = cues[id]
	voice.volume_db = _volume_db(str(voice.get_meta("channel")))
	voice.play()

func set_level(channel: String, level: float) -> void:
	if not levels.has(channel): return
	levels[channel] = clampf(level, 0.0, 1.0)
	_apply_levels()

func _volume_db(channel: String) -> float:
	var amplitude := float(levels.get("MASTER", 1.0)) * float(levels.get(channel, 1.0))
	return -80.0 if amplitude <= 0.0 else linear_to_db(amplitude)

func _apply_levels() -> void:
	music.volume_db = _volume_db("MUSIC")
	ambience.volume_db = _volume_db("AMBIENCE")
	for voice in cue_players:
		voice.volume_db = _volume_db(str(voice.get_meta("channel")))
