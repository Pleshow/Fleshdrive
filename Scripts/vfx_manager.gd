extends Node


const PLAYER_COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/player_combat_vfx_atlas.png"
)
const ENEMY_COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/enemy_combat_vfx_atlas.png"
)
const BOSS_COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/boss_combat_vfx_atlas.png"
)
const FIRE_COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/fire_combat_vfx_atlas.png"
)
const TELEKINETIC_COMBAT_TEXTURE := preload(
	"res://Assets/vfx/fleshdrive/telekinetic_combat_vfx_atlas.png"
)
const PIXEL_EMISSIVE_SHADER: Shader = preload(
	"res://Shaders/pixel_emissive.gdshader"
)
const LIGHTNING_STRIKE_TEXTURES := [
	preload("res://Assets/vfx/licensed/lightning_pack/strike_01_blue.png"),
	preload("res://Assets/vfx/licensed/lightning_pack/strike_02_blue.png"),
	preload("res://Assets/vfx/licensed/lightning_pack/strike_03_blue.png"),
	preload("res://Assets/vfx/licensed/lightning_pack/strike_04_blue.png"),
	preload("res://Assets/vfx/licensed/lightning_pack/strike_05_blue.png"),
	preload("res://Assets/vfx/licensed/lightning_pack/strike_06_blue.png"),
]
const STATIC_STRIKE_TEXTURE := preload(
	"res://Assets/vfx/licensed/lightning_pack/static_05_purple.png"
)
const BALL_STRIKE_TEXTURE := preload(
	"res://Assets/vfx/licensed/lightning_pack/ball_06_red.png"
)
const FIRE_EXPLOSION_RING_TEXTURE := preload(
	"res://Assets/vfx/licensed/fire_explosions/explosion_ring.png"
)
const FIRE_EXPLOSION_SPIKED_TEXTURE := preload(
	"res://Assets/vfx/licensed/fire_explosions/explosion_spiked.png"
)
const FIRE_EXPLOSION_EMBERS_TEXTURE := preload(
	"res://Assets/vfx/licensed/fire_explosions/explosion_embers.png"
)
const FIREBALL_CREATION_TEXTURE := preload(
	"res://Assets/vfx/licensed/fireball/creation.png"
)
const FIREBALL_EXPLODE_TEXTURE := preload(
	"res://Assets/vfx/licensed/fireball/explode.png"
)
const BIG_SLASH_TEXTURE := preload(
	"res://Assets/vfx/licensed/slashes/big_slash.png"
)
const HORIZONTAL_SLASH_TEXTURE := preload(
	"res://Assets/vfx/licensed/slashes/horizontal_slash.png"
)
const PUNCH_IMPACT_TEXTURE := preload(
	"res://Assets/vfx/licensed/slashes/punch_impact.png"
)
const SMALL_SLASH_TEXTURE := preload(
	"res://Assets/vfx/licensed/slashes/small_slash.png"
)
const STATUS_BURN_TEXTURE := preload(
	"res://Assets/vfx/licensed/status/burneffect.png"
)
const STATUS_SHOCK_TEXTURE := preload(
	"res://Assets/vfx/licensed/status/shockeffect.png"
)
const STATUS_HEAL_TEXTURE := preload(
	"res://Assets/vfx/licensed/status/healeffect.png"
)
const STATUS_SHIELD_TEXTURE := preload(
	"res://Assets/vfx/licensed/status/shieldeffect.png"
)
const STATUS_HASTE_TEXTURE := preload(
	"res://Assets/vfx/licensed/status/hasteeffect.png"
)
const STATUS_POISON_TEXTURE := preload(
	"res://Assets/vfx/licensed/status/poisonbubble.png"
)
const FRAME_SIZE := Vector2i(256, 256)
const FRAME_COUNT := 4
const FROST_LIGHTNING_CHAIN := [
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx1/lightning_skill1_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx1/lightning_skill1_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx1/lightning_skill1_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx1/lightning_skill1_frame4.png",
]
const FROST_LIGHTNING_STRIKE := [
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx3/lightning_skill3_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx3/lightning_skill3_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx3/lightning_skill3_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx3/lightning_skill3_frame4.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx3/lightning_skill3_frame5.png",
]
const FROST_LIGHTNING_HEAVY_CHAIN := [
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx2/lightning_skill2_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx2/lightning_skill2_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx2/lightning_skill2_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx2/lightning_skill2_frame4.png",
]
const FROST_LIGHTNING_LANCE := [
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx4/lightning_skill4_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx4/lightning_skill4_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx4/lightning_skill4_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx4/lightning_skill4_frame4.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx4/lightning_skill4_frame5.png",
]
const FROST_LIGHTNING_NOVA := [
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx5/lightning_skill5_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx5/lightning_skill5_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx5/lightning_skill5_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx5/lightning_skill5_frame4.png",
]
const FROST_LIGHTNING_SCATTER := [
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame4.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame5.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame6.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame7.png",
	"res://Assets/vfx/licensed/frostwindz/lightning_vfx6/lightning_skill6_frame8.png",
]
const FROST_FIRE_IMPACT := [
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame4.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame5.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame6.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx1/FireMage_skill1_frame7.png",
]
const FROST_FIRE_PROJECTILE := [
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame4.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame5.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame6.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame7.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame8.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame9.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame10.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame11.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx2/FireMage_skill2_frame12.png",
]
const FROST_FIRE_RING := [
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame1.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame2.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame3.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame4.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame5.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame6.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame7.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame8.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame9.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame10.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame11.png",
	"res://Assets/vfx/licensed/frostwindz/fire_vfx3/FireMage_skill3_frame12.png",
]
const ELECTRIC_EFFECTS := [
	&"electric_impact",
	&"electric_chain_arc",
	&"electric_heavy_chain",
	&"arc_muzzle",
	&"electro_shock",
	&"electric_lance",
	&"storm_strike_01",
	&"storm_strike_02",
	&"storm_strike_03",
	&"storm_strike_04",
	&"storm_strike_05",
	&"storm_strike_06",
	&"static_strike",
	&"ball_lightning_burst",
]
const FIRE_EFFECTS := [
	&"fire_impact",
	&"fire_muzzle",
	&"inferno_ring",
	&"ashen_eruption",
	&"burning_ground",
	&"fire_explosion_ring",
	&"fire_explosion_spiked",
	&"fire_explosion_embers",
	&"fireball_creation",
	&"fireball_explode",
]
const TELEKINETIC_EFFECTS := [
	&"kinetic_impact",
	&"gravity_well",
	&"repulse_wave",
	&"neural_lance",
]

var electric_light_texture: Texture2D
var fire_light_texture: GradientTexture2D
var telekinetic_light_texture: GradientTexture2D
var frame_cache: Dictionary = {}
var pooled_sprites: Array[AnimatedSprite2D] = []
var active_sprites: Array[AnimatedSprite2D] = []
var pixel_vfx_material: ShaderMaterial
var pixel_electric_material: ShaderMaterial
const MAX_ACTIVE_EFFECTS: int = 72
const MAX_POOLED_EFFECTS: int = 40

const EFFECTS := {
	&"electric_impact": {
		"frames": FROST_LIGHTNING_NOVA,
		"fps": 22.0,
		"base_scale": 0.46,
	},
	&"electric_chain_arc": {
		"frames": FROST_LIGHTNING_CHAIN,
		"fps": 22.0,
		"base_scale": 0.40,
	},
	&"electric_heavy_chain": {
		"frames": FROST_LIGHTNING_HEAVY_CHAIN,
		"fps": 21.0,
		"base_scale": 0.42,
	},
	&"arc_muzzle": {
		"frames": FROST_LIGHTNING_SCATTER,
		"fps": 24.0,
		"base_scale": 0.44,
	},
	&"electro_shock": {
		"frames": FROST_LIGHTNING_STRIKE,
		"fps": 21.0,
		"base_scale": 0.40,
	},
	&"electric_lance": {
		"frames": FROST_LIGHTNING_LANCE,
		"fps": 21.0,
		"base_scale": 0.42,
	},
	&"storm_strike_01": {"texture": LIGHTNING_STRIKE_TEXTURES[0], "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 26.0, "base_scale": 0.66},
	&"storm_strike_02": {"texture": LIGHTNING_STRIKE_TEXTURES[1], "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 26.0, "base_scale": 0.66},
	&"storm_strike_03": {"texture": LIGHTNING_STRIKE_TEXTURES[2], "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 26.0, "base_scale": 0.66},
	&"storm_strike_04": {"texture": LIGHTNING_STRIKE_TEXTURES[3], "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 26.0, "base_scale": 0.66},
	&"storm_strike_05": {"texture": LIGHTNING_STRIKE_TEXTURES[4], "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 26.0, "base_scale": 0.66},
	&"storm_strike_06": {"texture": LIGHTNING_STRIKE_TEXTURES[5], "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 26.0, "base_scale": 0.66},
	&"static_strike": {"texture": STATIC_STRIKE_TEXTURE, "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 28.0, "base_scale": 0.70},
	&"ball_lightning_burst": {"texture": BALL_STRIKE_TEXTURE, "frame_size": Vector2i(128, 128), "frame_count": 48, "columns": 4, "fps": 30.0, "base_scale": 0.72},
	&"slash_circular": {
		"texture": PLAYER_COMBAT_TEXTURE,
		"row": 3,
		"fps": 18.0,
		"base_scale": 0.09,
	},
	&"fire_impact": {
		"frames": FROST_FIRE_IMPACT,
		"fps": 22.0,
		"base_scale": 0.58,
	},
	&"fire_muzzle": {
		"frames": FROST_FIRE_PROJECTILE,
		"fps": 24.0,
		"base_scale": 0.48,
	},
	&"inferno_ring": {
		"frames": FROST_FIRE_RING,
		"fps": 22.0,
		"base_scale": 0.74,
	},
	&"ashen_eruption": {
		"frames": FROST_FIRE_IMPACT,
		"fps": 20.0,
		"base_scale": 0.82,
	},
	&"burning_ground": {
		"frames": FROST_FIRE_RING,
		"fps": 17.0,
		"base_scale": 0.42,
	},
	&"fire_explosion_ring": {"texture": FIRE_EXPLOSION_RING_TEXTURE, "frame_size": Vector2i(128, 128), "frame_count": 8, "columns": 8, "fps": 22.0, "base_scale": 0.72},
	&"fire_explosion_spiked": {"texture": FIRE_EXPLOSION_SPIKED_TEXTURE, "frame_size": Vector2i(128, 128), "frame_count": 8, "columns": 8, "fps": 23.0, "base_scale": 0.74},
	&"fire_explosion_embers": {"texture": FIRE_EXPLOSION_EMBERS_TEXTURE, "frame_size": Vector2i(128, 128), "frame_count": 7, "columns": 7, "fps": 20.0, "base_scale": 0.76},
	&"fireball_creation": {"texture": FIREBALL_CREATION_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 14, "columns": 14, "fps": 25.0, "base_scale": 1.0},
	&"fireball_explode": {"texture": FIREBALL_EXPLODE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 7, "columns": 7, "fps": 24.0, "base_scale": 1.1},
	&"slash_heavy": {"texture": BIG_SLASH_TEXTURE, "frame_size": Vector2i(64, 48), "frame_count": 5, "columns": 5, "fps": 19.0, "base_scale": 1.55},
	&"slash_horizontal": {"texture": HORIZONTAL_SLASH_TEXTURE, "frame_size": Vector2i(64, 32), "frame_count": 5, "columns": 5, "fps": 21.0, "base_scale": 1.5},
	&"bite_impact": {"texture": PUNCH_IMPACT_TEXTURE, "frame_size": Vector2i(48, 32), "frame_count": 5, "columns": 5, "fps": 22.0, "base_scale": 1.45},
	&"slash_small": {"texture": SMALL_SLASH_TEXTURE, "frame_size": Vector2i(32, 48), "frame_count": 4, "columns": 4, "fps": 22.0, "base_scale": 1.25},
	&"status_burn": {"texture": STATUS_BURN_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 16, "columns": 4, "fps": 16.0, "base_scale": 0.9},
	&"status_shock": {"texture": STATUS_SHOCK_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 16, "columns": 4, "fps": 18.0, "base_scale": 0.9},
	&"status_heal": {"texture": STATUS_HEAL_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 16, "columns": 4, "fps": 17.0, "base_scale": 1.0},
	&"status_shield": {"texture": STATUS_SHIELD_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 16, "columns": 4, "fps": 17.0, "base_scale": 1.0},
	&"status_haste": {"texture": STATUS_HASTE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 16, "columns": 4, "fps": 19.0, "base_scale": 1.0},
	&"status_poison": {"texture": STATUS_POISON_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 16, "columns": 4, "fps": 16.0, "base_scale": 1.0},
	&"kinetic_impact": {
		"texture": TELEKINETIC_COMBAT_TEXTURE,
		"row": 0,
		"fps": 18.0,
		"base_scale": 0.27,
	},
	&"gravity_well": {
		"texture": TELEKINETIC_COMBAT_TEXTURE,
		"row": 1,
		"fps": 16.0,
		"base_scale": 0.34,
	},
	&"repulse_wave": {
		"texture": TELEKINETIC_COMBAT_TEXTURE,
		"row": 2,
		"fps": 18.0,
		"base_scale": 0.38,
	},
	&"neural_lance": {
		"texture": TELEKINETIC_COMBAT_TEXTURE,
		"row": 3,
		"fps": 20.0,
		"base_scale": 0.30,
	},
	&"spitter_impact": {
		"texture": ENEMY_COMBAT_TEXTURE,
		"row": 0,
		"fps": 18.0,
		"base_scale": 0.32,
	},
	&"acid_puddle": {
		"texture": ENEMY_COMBAT_TEXTURE,
		"row": 1,
		"fps": 8.0,
		"base_scale": 0.32,
	},
	&"enemy_death": {
		"texture": ENEMY_COMBAT_TEXTURE,
		"row": 2,
		"fps": 18.0,
		"base_scale": 0.32,
	},
	&"charger_impact": {
		"texture": ENEMY_COMBAT_TEXTURE,
		"row": 3,
		"fps": 20.0,
		"base_scale": 0.32,
	},
	&"boss_slam": {
		"texture": BOSS_COMBAT_TEXTURE,
		"row": 0,
		"fps": 18.0,
		"base_scale": 0.60,
	},
	&"boss_phase": {
		"texture": BOSS_COMBAT_TEXTURE,
		"row": 1,
		"fps": 16.0,
		"base_scale": 0.55,
	},
	&"boss_death": {
		"texture": BOSS_COMBAT_TEXTURE,
		"row": 2,
		"fps": 16.0,
		"base_scale": 0.65,
	},
	&"boss_charge_impact": {
		"texture": BOSS_COMBAT_TEXTURE,
		"row": 3,
		"fps": 20.0,
		"base_scale": 0.40,
	},
}


func play(
	effect_id: StringName,
	world_position: Vector2,
	effect_scale: float = 1.0,
	rotation_radians: float = 0.0
) -> AnimatedSprite2D:
	var effect_data: Dictionary = EFFECTS.get(effect_id, {})
	if effect_data.is_empty():
		push_warning("VisualEffects: Unknown effect: %s" % effect_id)
		return null
	var settings := get_tree().root.get_node_or_null("GameSettings")
	var intensity := float(settings.vfx_intensity) if settings != null else 1.0
	if intensity <= 0.01:
		return null
	var is_critical_readability_effect := effect_id in [
		&"boss_slam", &"boss_phase", &"boss_death", &"charger_impact",
		&"status_heal", &"electric_impact", &"electric_chain_arc",
		&"electro_shock", &"electric_heavy_chain", &"electric_lance",
		&"static_strike", &"ball_lightning_burst"
	] or String(effect_id).begins_with("storm_strike")
	if not is_critical_readability_effect and randf() > maxf(intensity, 0.22):
		return null

	_prune_invalid_effects()
	if active_sprites.size() >= MAX_ACTIVE_EFFECTS:
		return null
	var sprite := _acquire_effect_sprite()
	var readable_scale := _get_readable_effect_scale(effect_id, effect_scale)
	sprite.sprite_frames = _get_cached_animation(effect_id, effect_data)
	sprite.animation = &"play"
	sprite.global_position = world_position
	sprite.rotation = rotation_radians
	sprite.scale = (
		Vector2.ONE
		* readable_scale
		* float(effect_data["base_scale"])
		* lerpf(0.78, 1.0, intensity)
	)
	sprite.z_index = 20
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var minimalist_mode := MinimalistVisualProfile.is_active(get_tree())
	# Every effect uses a nearest-filtered, hard palette ramp. Non-minimalist
	# arenas retain an environmental electric flash, but its texture is a hard
	# three-band pixel mask instead of the old continuous radial gradient.
	sprite.material = _get_pixel_vfx_material(effect_id in ELECTRIC_EFFECTS)

	var container := get_tree().get_first_node_in_group("effects_container")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return null

	if sprite.get_parent() != container:
		if sprite.get_parent() == null:
			container.add_child(sprite)
		else:
			sprite.reparent(container)
	sprite.show()
	active_sprites.append(sprite)
	if not minimalist_mode and effect_id in ELECTRIC_EFFECTS:
		_play_electric_flash(
			container,
			world_position,
			readable_scale,
			effect_id
		)
	sprite.animation_finished.connect(
		_recycle_effect.bind(sprite),
		CONNECT_ONE_SHOT
	)
	sprite.play(&"play")
	return sprite


func _get_readable_effect_scale(effect_id: StringName, requested: float) -> float:
	var result := maxf(requested, 0.05)
	if effect_id not in ELECTRIC_EFFECTS:
		return result
	# Regular hits remain below roughly four enemy widths. Explicit keystone
	# activations use scale 4+ and retain their exceptional screen presence.
	if result >= 4.0:
		return minf(result, 5.2)
	if effect_id == &"electro_shock":
		return minf(result, 3.2)
	if String(effect_id).begins_with("storm_strike"):
		return minf(result, 1.35)
	return minf(result, 1.6)


func has_effect(effect_id: StringName) -> bool:
	return EFFECTS.has(effect_id)


func _get_pixel_vfx_material(force_electric_blue: bool) -> ShaderMaterial:
	if force_electric_blue:
		if pixel_electric_material == null:
			pixel_electric_material = ShaderMaterial.new()
			pixel_electric_material.shader = PIXEL_EMISSIVE_SHADER
			pixel_electric_material.set_shader_parameter("force_electric_blue", true)
		return pixel_electric_material
	if pixel_vfx_material == null:
		pixel_vfx_material = ShaderMaterial.new()
		pixel_vfx_material.shader = PIXEL_EMISSIVE_SHADER
	return pixel_vfx_material


func _get_cached_animation(
	effect_id: StringName,
	effect_data: Dictionary
) -> SpriteFrames:
	if frame_cache.has(effect_id):
		return frame_cache[effect_id] as SpriteFrames
	var frames := (
		_make_texture_animation(
			Array(effect_data["frames"]),
			float(effect_data["fps"])
		)
		if effect_data.has("frames")
		else (
			_make_grid_animation(
				effect_data["texture"],
				Vector2i(effect_data["frame_size"]),
				int(effect_data["frame_count"]),
				int(effect_data.get("columns", effect_data["frame_count"])),
				float(effect_data["fps"])
			)
			if effect_data.has("frame_size")
			else _make_atlas_animation(
				effect_data["texture"],
				int(effect_data["row"]),
				float(effect_data["fps"])
			)
		)
	)
	frame_cache[effect_id] = frames
	return frames


func _acquire_effect_sprite() -> AnimatedSprite2D:
	while not pooled_sprites.is_empty():
		var pooled: AnimatedSprite2D = pooled_sprites.pop_back() as AnimatedSprite2D
		if is_instance_valid(pooled):
			return pooled
	return AnimatedSprite2D.new()


func _recycle_effect(sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.stop()
	sprite.hide()
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.flip_h = false
	sprite.flip_v = false
	for transient_group in [&"thunder_vfx", &"kinetic_charge_vfx"]:
		if sprite.is_in_group(transient_group):
			sprite.remove_from_group(transient_group)
	if sprite.has_meta("autoattack_lightning"):
		sprite.remove_meta("autoattack_lightning")
	sprite.name = "PooledCombatVFX"
	sprite.process_mode = Node.PROCESS_MODE_INHERIT
	active_sprites.erase(sprite)
	if pooled_sprites.size() < MAX_POOLED_EFFECTS:
		pooled_sprites.append(sprite)
	else:
		sprite.queue_free()


func finish_active_effects_during_pause() -> void:
	# The death transition pauses gameplay immediately. Let effects already
	# spawned by the killing hit finish instead of freezing into the rebirth UI.
	for sprite in active_sprites:
		if is_instance_valid(sprite):
			sprite.process_mode = Node.PROCESS_MODE_ALWAYS


func clear_all() -> void:
	for sprite in active_sprites:
		if is_instance_valid(sprite):
			sprite.stop()
			sprite.queue_free()
	for sprite in pooled_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	active_sprites.clear()
	pooled_sprites.clear()
	for group_name in [&"electric_flash", &"fire_flash", &"telekinetic_flash"]:
		for light in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(light) and not light.is_queued_for_deletion():
				light.queue_free()


func _prune_invalid_effects() -> void:
	for index in range(active_sprites.size() - 1, -1, -1):
		if not is_instance_valid(active_sprites[index]):
			active_sprites.remove_at(index)
	for index in range(pooled_sprites.size() - 1, -1, -1):
		if not is_instance_valid(pooled_sprites[index]):
			pooled_sprites.remove_at(index)


func _play_electric_flash(
	container: Node,
	world_position: Vector2,
	effect_scale: float,
	effect_id: StringName
) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_light")):
		return
	var flash := PointLight2D.new()
	flash.name = "ElectricFlash"
	flash.color = Color("0ce6f2")
	flash.texture = _get_electric_light_texture()
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.shadow_enabled = false
	flash.energy = 0.92
	flash.texture_scale = clampf(0.30 * effect_scale, 0.24, 0.92)

	var duration := 0.16
	if effect_id == &"arc_muzzle":
		flash.energy = 1.8
		flash.texture_scale = clampf(0.3 * effect_scale, 0.24, 0.72)
		duration = 0.13
	elif effect_id == &"electric_chain_arc":
		flash.energy = 1.55
		flash.texture_scale = clampf(0.34 * effect_scale, 0.30, 0.84)
		duration = 0.18
	elif effect_id == &"electro_shock":
		flash.energy = 1.85
		flash.texture_scale = clampf(0.40 * effect_scale, 0.38, 1.12)
		duration = 0.2
	elif String(effect_id).begins_with("storm_strike"):
		flash.energy = 3.0
		flash.texture_scale = clampf(0.58 * effect_scale, 0.54, 1.7)
		duration = 0.28
	elif effect_id == &"static_strike":
		flash.color = Color("0098db")
		flash.energy = 2.75
		flash.texture_scale = clampf(0.54 * effect_scale, 0.48, 1.5)
		duration = 0.24
	elif effect_id == &"ball_lightning_burst":
		flash.color = Color("0ce6f2")
		flash.energy = 3.1
		flash.texture_scale = clampf(0.62 * effect_scale, 0.56, 1.8)
		duration = 0.26
	elif effect_id in [&"electric_heavy_chain", &"electric_lance"]:
		flash.energy = 2.8
		flash.texture_scale = clampf(0.5 * effect_scale, 0.44, 1.45)
		duration = 0.2

	container.add_child(flash)
	flash.global_position = world_position
	flash.add_to_group("electric_flash")
	flash.add_to_group("transient_lights")

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		flash,
		"energy",
		0.0,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		flash,
		"texture_scale",
		flash.texture_scale * 1.22,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(flash.queue_free)


func _get_electric_light_texture() -> Texture2D:
	if electric_light_texture != null:
		return electric_light_texture
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(32):
		for x in range(32):
			var ring := maxi(absi(x - 15), absi(y - 15))
			if ring <= 5:
				image.set_pixel(x, y, Color("0ce6f2"))
			elif ring <= 10 and (x + y) % 2 == 0:
				image.set_pixel(x, y, Color("0098db"))
			elif ring <= 14 and x % 2 == 0 and y % 2 == 0:
				image.set_pixel(x, y, Color("1e579c"))
	electric_light_texture = ImageTexture.create_from_image(image)
	return electric_light_texture


func _play_fire_flash(
	container: Node,
	world_position: Vector2,
	effect_scale: float,
	effect_id: StringName
) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_light")):
		return
	var flash := PointLight2D.new()
	flash.name = "FireFlash"
	flash.color = Color(1.0, 0.24, 0.055, 1.0)
	flash.texture = _get_fire_light_texture()
	flash.shadow_enabled = false
	flash.energy = 2.0
	flash.texture_scale = clampf(0.34 * effect_scale, 0.24, 1.35)
	var duration := 0.18
	if effect_id == &"fire_muzzle":
		flash.energy = 1.65
		duration = 0.13
	elif effect_id in [&"inferno_ring", &"ashen_eruption"]:
		flash.energy = 2.65
		flash.texture_scale = clampf(0.5 * effect_scale, 0.5, 1.65)
		duration = 0.24
	elif effect_id == &"burning_ground":
		flash.energy = 0.72
		duration = 0.32
	container.add_child(flash)
	flash.global_position = world_position
	flash.add_to_group("fire_flash")
	flash.add_to_group("transient_lights")
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		flash,
		"energy",
		0.0,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		flash,
		"texture_scale",
		flash.texture_scale * 1.18,
		duration
	)
	tween.chain().tween_callback(flash.queue_free)


func _get_fire_light_texture() -> GradientTexture2D:
	if fire_light_texture != null:
		return fire_light_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.86, 0.42, 1.0),
		Color(1.0, 0.24, 0.04, 0.76),
		Color(0.45, 0.045, 0.01, 0.24),
		Color(0.08, 0.005, 0.0, 0.0),
	])
	fire_light_texture = GradientTexture2D.new()
	fire_light_texture.gradient = gradient
	fire_light_texture.width = 256
	fire_light_texture.height = 256
	fire_light_texture.fill = GradientTexture2D.FILL_RADIAL
	fire_light_texture.fill_from = Vector2(0.5, 0.5)
	fire_light_texture.fill_to = Vector2(1.0, 0.5)
	return fire_light_texture


func _play_telekinetic_flash(
	container: Node,
	world_position: Vector2,
	effect_scale: float,
	effect_id: StringName
) -> void:
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if budget != null and not bool(budget.call("allow_light")):
		return
	var flash := PointLight2D.new()
	flash.name = "TelekineticFlash"
	flash.color = Color(0.72, 0.42, 1.0, 1.0)
	flash.texture = _get_telekinetic_light_texture()
	flash.shadow_enabled = false
	flash.energy = 1.9
	flash.texture_scale = clampf(0.34 * effect_scale, 0.24, 1.45)
	var duration := 0.18
	if effect_id in [&"gravity_well", &"repulse_wave"]:
		flash.energy = 2.5
		flash.texture_scale = clampf(0.48 * effect_scale, 0.45, 1.7)
		duration = 0.25
	container.add_child(flash)
	flash.global_position = world_position
	flash.add_to_group("telekinetic_flash")
	flash.add_to_group("transient_lights")
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "energy", 0.0, duration)
	tween.tween_property(
		flash,
		"texture_scale",
		flash.texture_scale * 1.2,
		duration
	)
	tween.chain().tween_callback(flash.queue_free)


func _get_telekinetic_light_texture() -> GradientTexture2D:
	if telekinetic_light_texture != null:
		return telekinetic_light_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.36, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.94, 1.0, 1.0),
		Color(0.64, 0.3, 1.0, 0.76),
		Color(0.24, 0.05, 0.56, 0.24),
		Color(0.04, 0.0, 0.12, 0.0),
	])
	telekinetic_light_texture = GradientTexture2D.new()
	telekinetic_light_texture.gradient = gradient
	telekinetic_light_texture.width = 256
	telekinetic_light_texture.height = 256
	telekinetic_light_texture.fill = GradientTexture2D.FILL_RADIAL
	telekinetic_light_texture.fill_from = Vector2(0.5, 0.5)
	telekinetic_light_texture.fill_to = Vector2(1.0, 0.5)
	return telekinetic_light_texture


func _make_atlas_animation(
	texture: Texture2D,
	row: int,
	fps: float
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_loop(&"play", false)
	frames.set_animation_speed(&"play", fps)
	var inset := 3 if texture == FIRE_COMBAT_TEXTURE else 0

	for frame_index in range(FRAME_COUNT):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(
			frame_index * FRAME_SIZE.x + inset,
			row * FRAME_SIZE.y + inset,
			FRAME_SIZE.x - inset * 2,
			FRAME_SIZE.y - inset * 2
		)
		frames.add_frame(&"play", frame)
	return frames


func _make_texture_animation(
	texture_paths: Array,
	fps: float
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_loop(&"play", false)
	frames.set_animation_speed(&"play", fps)
	for texture_path in texture_paths:
		var texture := load(String(texture_path)) as Texture2D
		if texture != null:
			frames.add_frame(&"play", texture)
	return frames


func _make_grid_animation(
	texture: Texture2D,
	frame_size: Vector2i,
	frame_count: int,
	columns: int,
	fps: float
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_loop(&"play", false)
	frames.set_animation_speed(&"play", fps)
	var safe_columns := maxi(columns, 1)
	for frame_index in range(frame_count):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(
			(frame_index % safe_columns) * frame_size.x,
			(frame_index / safe_columns) * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		frames.add_frame(&"play", frame)
	return frames
