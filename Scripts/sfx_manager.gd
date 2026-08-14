extends Node


const PLAYER_POOL_SIZE: int = 24
const MIN_REPLAY_SECONDS := {
	&"enemy_hit": 0.045,
	&"biomass_pickup": 0.075,
	&"telekinetic_impact": 0.055,
	&"spitter_impact": 0.06,
	&"electric_chain_jump": 0.07,
	&"electric_impact_cue": 0.055,
}
const MAX_CONCURRENT := {
	&"enemy_hit": 4,
	&"biomass_pickup": 2,
	&"telekinetic_impact": 3,
	&"spitter_impact": 3,
	&"electric_chain_jump": 3,
	&"electric_impact_cue": 3,
}
const SOUND_LIBRARY: Dictionary = {
	&"ui_hover": preload("res://Assets/audio/sfx/ui_hover.wav"),
	&"ui_confirm": preload("res://Assets/audio/sfx/ui_confirm.wav"),
	&"ui_cancel": preload("res://Assets/audio/sfx/ui_cancel.wav"),
	&"card_reveal": preload("res://Assets/audio/sfx/card_reveal.wav"),
	&"card_select": preload("res://Assets/audio/sfx/card_select.wav"),
	&"organ_install": preload("res://Assets/audio/sfx/organ_install.wav"),
	&"raiju_attack": preload("res://Assets/audio/sfx/raiju_attack.wav"),
	&"raiju_attack_spark": preload("res://Assets/audio/sfx/raiju_attack_spark.wav"),
	&"electric_cast": preload("res://Assets/audio/sfx/raiju_attack.wav"),
	&"electric_chain_jump": preload("res://Assets/audio/sfx/raiju_attack_spark.wav"),
	&"electric_impact_cue": preload("res://Assets/audio/sfx/enemy_hit.wav"),
	&"capacitor_ready": preload("res://Assets/audio/sfx/level_up.wav"),
	&"elite_kill": preload("res://Assets/audio/sfx/charger_impact.wav"),
	&"raiju_dash": preload("res://Assets/audio/sfx/raiju_dash.wav"),
	&"raiju_land": preload("res://Assets/audio/sfx/raiju_land.wav"),
	&"telekinetic_cast": preload(
		"res://Assets/audio/sfx/telekinetic_cast.wav"
	),
	&"telekinetic_impact": preload(
		"res://Assets/audio/sfx/telekinetic_impact.wav"
	),
	&"telekinetic_pulse": preload(
		"res://Assets/audio/sfx/telekinetic_pulse.wav"
	),
	&"player_hurt": preload("res://Assets/audio/sfx/player_hurt.wav"),
	&"player_death": preload("res://Assets/audio/sfx/player_death.wav"),
	&"biomass_pickup": preload("res://Assets/audio/sfx/biomass_pickup.wav"),
	&"level_up": preload("res://Assets/audio/sfx/level_up.wav"),
	&"rush_warning": preload("res://Assets/audio/sfx/rush_warning.wav"),
	&"enemy_hit": preload("res://Assets/audio/sfx/enemy_hit.wav"),
	&"enemy_death": preload("res://Assets/audio/sfx/enemy_death.wav"),
	&"spitter_windup": preload("res://Assets/audio/sfx/spitter_windup.wav"),
	&"spitter_fire": preload("res://Assets/audio/sfx/spitter_fire.wav"),
	&"spitter_impact": preload("res://Assets/audio/sfx/spitter_impact.wav"),
	&"charger_windup": preload("res://Assets/audio/sfx/charger_windup.wav"),
	&"charger_charge": preload("res://Assets/audio/sfx/charger_charge.wav"),
	&"charger_impact": preload("res://Assets/audio/sfx/charger_impact.wav"),
	&"victory": preload("res://Assets/audio/sfx/victory.wav"),
	&"defeat": preload("res://Assets/audio/sfx/defeat.wav"),
}

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _play_counts: Dictionary = {}
var _last_play_msec: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for player_index in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%02d" % player_index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func play(
	sound_id: StringName,
	volume_db: float = 0.0,
	pitch_variation: float = 0.0,
	bus_name: StringName = &"SFX",
	priority: int = 0
) -> void:
	var stream := SOUND_LIBRARY.get(sound_id) as AudioStream
	if stream == null:
		push_warning("AudioEffects: Unknown sound: %s" % sound_id)
		return
	var now := Time.get_ticks_msec()
	var replay_ms := int(float(MIN_REPLAY_SECONDS.get(sound_id, 0.0)) * 1000.0)
	if priority <= 0 and now - int(_last_play_msec.get(sound_id, -100000)) < replay_ms:
		return
	var concurrent := 0
	for candidate in _players:
		if candidate.playing and candidate.get_meta("sound_id", &"") == sound_id:
			concurrent += 1
	if priority <= 0 and concurrent >= int(MAX_CONCURRENT.get(sound_id, 6)):
		return

	var player := _get_available_player()
	player.stop()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume_db
	player.pitch_scale = randf_range(
		1.0 - pitch_variation,
		1.0 + pitch_variation
	)
	player.set_meta("sound_id", sound_id)
	player.play()
	_last_play_msec[sound_id] = now
	_play_counts[sound_id] = get_play_count(sound_id) + 1


func play_ui(
	sound_id: StringName,
	volume_db: float = 0.0,
	pitch_variation: float = 0.0
) -> void:
	play(sound_id, volume_db, pitch_variation, &"UI")


func has_sound(sound_id: StringName) -> bool:
	return SOUND_LIBRARY.has(sound_id)


func get_play_count(sound_id: StringName) -> int:
	return int(_play_counts.get(sound_id, 0))


func clear_play_counts() -> void:
	_play_counts.clear()


func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player

	var player := _players[_next_player_index]
	_next_player_index = (
		_next_player_index + 1
	) % _players.size()
	return player
