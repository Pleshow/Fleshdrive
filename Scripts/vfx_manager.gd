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
const JUICE_LIGHTNING_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/lightning_radial.png"
)
const JUICE_DASH_SMOKE_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/dash_smoke.png"
)
const JUICE_SPAWN_SMOKE_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/spawn_smoke.png"
)
const JUICE_IMPACT_SMOKE_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/impact_smoke.png"
)
const JUICE_FIRE_BURST_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/fire_burst.png"
)
const JUICE_FIRE_SLASH_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/fire_slash.png"
)
const JUICE_ORGANIC_BURST_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/organic_burst.png"
)
const JUICE_TISSUE_DROPLETS_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/tissue_droplets.png"
)
const BALL_LIGHTNING_V1_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/ball_lightning_v1.png"
)
const PROJECTILE_LIGHTNING_V3_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/projectile_lightning_v3.png"
)
const KINETIC_LIGHTNING_V7_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/kinetic_lightning_v7.png"
)
const SHOCK_LIGHTNING_V9_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/shock_lightning_v9.png"
)
const DECOY_SMOKE_V9_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/decoy_smoke_v9.png"
)
const HOLY_HEAL_V3_TEXTURE := preload(
	"res://Assets/vfx/licensed/pixel_juice/holy_heal_v3.png"
)
const BLOOD_MEMORY_COIN_SPIN_TEXTURE := preload(
	"res://Assets/pickups/blood_memory_coin/gold_spin.png"
)
const BLOOD_MEMORY_COIN_COLLECT_TEXTURE := preload(
	"res://Assets/pickups/blood_memory_coin/gold_collect.png"
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
	&"electric_micro_hit",
	&"shock_proc",
	&"biomass_collect",
	&"ui_energy_confirm",
	&"organ_activation",
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
	&"ball_lightning_idle", &"ball_lightning_explosion",
	&"projectile_lightning", &"projectile_lightning_loop", &"kinetic_charge_lightning",
	&"shock_status", &"enemy_death_lightning", &"holy_heal",
]
const CRIMSON_EFFECTS := [
	&"generic_hit", &"heavy_hit", &"enemy_death_burst",
	&"tissue_droplets", &"fire_impact", &"magma_spear_impact",
	&"boss_slam", &"boss_death", &"organ_flesh_pulse",
]
const NEUTRAL_EFFECTS := [
	&"dash_smoke", &"dash_smoke_end", &"charge_dust",
	&"charger_impact", &"enemy_spawn", &"decoy_smoke",
]
# Purchased Pixel VFX sheets stay untouched so they can be palette-edited at
# source later. They render on a camera-following canvas above the global
# Ink-Crimson screen quantizer, but below gameplay UI.
const ORIGINAL_COLOR_EFFECTS := [
	&"ball_lightning_idle", &"ball_lightning_explosion",
	&"projectile_lightning", &"projectile_lightning_loop",
	&"kinetic_charge_lightning", &"shock_status", &"enemy_death_lightning",
	&"decoy_smoke", &"holy_heal",
	&"blood_memory_coin_spin", &"blood_memory_coin_collect",
	&"electric_impact", &"electric_micro_hit", &"shock_proc",
	&"biomass_collect", &"ui_energy_confirm", &"organ_activation",
	&"generic_hit", &"heavy_hit", &"dash_smoke", &"dash_smoke_end",
	&"charge_dust", &"enemy_spawn", &"enemy_death_burst",
	&"tissue_droplets", &"fire_impact", &"magma_spear_impact",
	&"organ_flesh_pulse", &"charger_impact", &"boss_slam", &"boss_death",
]
const FREQUENT_EFFECTS := [
	&"generic_hit", &"electric_micro_hit", &"biomass_collect",
	&"dash_smoke_end", &"tissue_droplets",
]
const NO_LIGHT_EFFECTS := [
	&"electric_micro_hit", &"shock_proc", &"biomass_collect",
	&"ui_energy_confirm", &"organ_activation", &"ball_lightning_idle",
	&"ball_lightning_explosion", &"projectile_lightning", &"projectile_lightning_loop",
	&"kinetic_charge_lightning", &"shock_status",
	&"enemy_death_lightning", &"holy_heal",
	&"blood_memory_coin_spin", &"blood_memory_coin_collect",
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
	&"gravity_well", &"gravity_well_loop",
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
var pixel_crimson_material: ShaderMaterial
var pixel_neutral_material: ShaderMaterial
var ui_layer: CanvasLayer
var original_color_world_layer: CanvasLayer
const MAX_ACTIVE_EFFECTS: int = 72
const MAX_POOLED_EFFECTS: int = 40

const EFFECTS := {
	&"blood_memory_coin_spin": {
		"texture": BLOOD_MEMORY_COIN_SPIN_TEXTURE,
		"frame_size": Vector2i(25, 25), "frame_count": 7, "columns": 7,
		"fps": 12.0, "base_scale": 1.0, "loop": true,
	},
	&"blood_memory_coin_collect": {
		"texture": BLOOD_MEMORY_COIN_COLLECT_TEXTURE,
		"frame_size": Vector2i(25, 25), "frame_count": 6, "columns": 6,
		"fps": 20.0, "base_scale": 1.0,
	},
	&"ball_lightning_idle": {
		"texture": BALL_LIGHTNING_V1_TEXTURE, "frame_size": Vector2i(64, 64),
		"start_frame": 4, "frame_count": 24, "columns": 6,
		"fps": 20.0, "base_scale": 1.0, "loop": true,
	},
	&"ball_lightning_explosion": {
		"texture": BALL_LIGHTNING_V1_TEXTURE, "frame_size": Vector2i(64, 64),
		"start_frame": 28, "frame_count": 6, "columns": 6,
		"fps": 20.0, "base_scale": 1.0,
	},
	&"projectile_lightning": {
		"texture": PROJECTILE_LIGHTNING_V3_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 27, "columns": 6, "fps": 36.0, "base_scale": 1.0,
	},
	&"projectile_lightning_loop": {
		"texture": PROJECTILE_LIGHTNING_V3_TEXTURE, "frame_size": Vector2i(64, 64),
		"start_frame": 7, "frame_count": 12, "columns": 6,
		"fps": 24.0, "base_scale": 1.0, "loop": true,
	},
	&"kinetic_charge_lightning": {
		"texture": KINETIC_LIGHTNING_V7_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 10, "columns": 4, "fps": 20.0,
		"base_scale": 1.0, "loop": true,
	},
	&"shock_status": {
		"texture": SHOCK_LIGHTNING_V9_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 10, "columns": 4, "fps": 16.667,
		"base_scale": 1.0, "loop": true,
	},
	&"enemy_death_lightning": {
		"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 8, "columns": 3, "fps": 20.0, "base_scale": 1.0,
	},
	&"decoy_smoke": {
		"texture": DECOY_SMOKE_V9_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 10, "columns": 4, "fps": 13.333, "base_scale": 1.0,
	},
	&"holy_heal": {
		"texture": HOLY_HEAL_V3_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 17, "columns": 5, "fps": 24.0, "base_scale": 1.0,
	},
	&"electric_impact": {
		"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 8, "columns": 3, "fps": 48.0, "base_scale": 1.0,
	},
	&"electric_micro_hit": {"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 5, "columns": 3, "fps": 52.0, "base_scale": 1.0},
	&"shock_proc": {"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 7, "columns": 3, "fps": 48.0, "base_scale": 1.0},
	&"biomass_collect": {"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 5, "columns": 3, "fps": 55.0, "base_scale": 1.0},
	&"ui_energy_confirm": {"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 7, "columns": 3, "fps": 48.0, "base_scale": 1.0},
	&"organ_activation": {"texture": JUICE_LIGHTNING_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 8, "columns": 3, "fps": 42.0, "base_scale": 1.0},
	&"generic_hit": {"texture": JUICE_IMPACT_SMOKE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 6, "columns": 3, "fps": 55.0, "base_scale": 1.0},
	&"heavy_hit": {"texture": JUICE_FIRE_BURST_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 8, "columns": 4, "fps": 45.0, "base_scale": 1.0},
	&"dash_smoke": {"texture": JUICE_DASH_SMOKE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 10, "columns": 4, "fps": 60.0, "base_scale": 1.0},
	&"dash_smoke_end": {"texture": JUICE_DASH_SMOKE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 7, "columns": 4, "fps": 60.0, "base_scale": 1.0},
	&"charge_dust": {"texture": JUICE_SPAWN_SMOKE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 7, "columns": 4, "fps": 48.0, "base_scale": 1.0},
	&"enemy_spawn": {"texture": JUICE_SPAWN_SMOKE_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 10, "columns": 4, "fps": 48.0, "base_scale": 1.0},
	&"enemy_death_burst": {"texture": JUICE_ORGANIC_BURST_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 12, "columns": 4, "fps": 45.0, "base_scale": 1.0},
	&"tissue_droplets": {"texture": JUICE_TISSUE_DROPLETS_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 12, "columns": 12, "fps": 50.0, "base_scale": 1.0},
	&"magma_spear_impact": {"texture": JUICE_FIRE_SLASH_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 10, "columns": 4, "fps": 48.0, "base_scale": 1.0},
	&"organ_flesh_pulse": {"texture": JUICE_ORGANIC_BURST_TEXTURE, "frame_size": Vector2i(64, 64), "frame_count": 10, "columns": 4, "fps": 40.0, "base_scale": 1.0},
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
		"texture": JUICE_FIRE_BURST_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 8, "columns": 4, "fps": 45.0, "base_scale": 1.0,
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
	&"gravity_well_loop": {
		"texture": TELEKINETIC_COMBAT_TEXTURE,
		"row": 1,
		"fps": 16.0,
		"base_scale": 0.34,
		"loop": true,
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
		"texture": JUICE_IMPACT_SMOKE_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 9, "columns": 3, "fps": 48.0, "base_scale": 1.0,
	},
	&"boss_slam": {
		"texture": JUICE_FIRE_BURST_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 10, "columns": 4, "fps": 32.0, "base_scale": 1.0,
	},
	&"boss_phase": {
		"texture": BOSS_COMBAT_TEXTURE,
		"row": 1,
		"fps": 16.0,
		"base_scale": 0.55,
	},
	&"boss_death": {
		"texture": JUICE_FIRE_BURST_TEXTURE, "frame_size": Vector2i(64, 64),
		"frame_count": 12, "columns": 4, "fps": 30.0, "base_scale": 1.0,
	},
	&"boss_charge_impact": {
		"texture": BOSS_COMBAT_TEXTURE,
		"row": 3,
		"fps": 20.0,
		"base_scale": 0.40,
	},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var detached: Array[AnimatedSprite2D] = []
	for sprite in active_sprites:
		if not is_instance_valid(sprite) or not sprite.has_meta("follow_target"):
			continue
		var target_ref := sprite.get_meta("follow_target") as WeakRef
		var target := target_ref.get_ref() as Node2D if target_ref != null else null
		if not is_instance_valid(target) or target.get("is_dead") == true:
			detached.append(sprite)
			continue
		var local_offset := Vector2(sprite.get_meta("follow_offset", Vector2.ZERO))
		sprite.global_position = target.to_global(local_offset)
		sprite.global_rotation = (
			target.global_rotation
			+ float(sprite.get_meta("follow_rotation", 0.0))
		)
	for sprite in detached:
		_recycle_effect(sprite)


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
	var budget := get_tree().root.get_node_or_null("PerformanceBudget")
	if (
		effect_id in FREQUENT_EFFECTS
		and budget != null
		and not bool(budget.call("allow_effect"))
	):
		return null
	var is_critical_readability_effect := effect_id in [
		&"boss_slam", &"boss_phase", &"boss_death", &"charger_impact",
		&"status_heal", &"holy_heal", &"generic_hit", &"heavy_hit", &"electric_impact", &"electric_chain_arc",
		&"electro_shock", &"electric_heavy_chain", &"electric_lance",
		&"static_strike", &"ball_lightning_burst", &"shock_status",
		&"kinetic_charge_lightning", &"ball_lightning_idle",
		&"ball_lightning_explosion", &"projectile_lightning",
		&"projectile_lightning_loop", &"enemy_death_lightning",
		&"decoy_smoke", &"holy_heal", &"blood_memory_coin_spin",
		&"blood_memory_coin_collect"
	] or String(effect_id).begins_with("storm_strike")
	if not is_critical_readability_effect and randf() > maxf(intensity, 0.22):
		return null

	_prune_invalid_effects()
	if active_sprites.size() >= MAX_ACTIVE_EFFECTS:
		return null
	var sprite := _acquire_effect_sprite()
	# Every activation receives a unique generation. Async trackers retain the
	# generation they started with, so a recycled sprite can never be moved by
	# a coroutine that belonged to its previous effect.
	var generation := int(sprite.get_meta("vfx_generation", 0)) + 1
	sprite.set_meta("vfx_generation", generation)
	var readable_scale := _get_readable_effect_scale(effect_id, effect_scale)
	sprite.sprite_frames = _get_cached_animation(effect_id, effect_data)
	sprite.set_meta("effect_id", effect_id)
	sprite.animation = &"play"
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.speed_scale = 1.0
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	sprite.offset = Vector2.ZERO
	sprite.centered = true
	sprite.flip_h = false
	sprite.flip_v = false
	sprite.z_as_relative = true
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
	# Purchased Pixel VFX keep their source colors. Project-authored effects
	# continue to use the hard functional palette ramps.
	sprite.material = (
		null
		if effect_id in ORIGINAL_COLOR_EFFECTS
		else _get_pixel_vfx_material(effect_id)
	)

	var container: Node = (
		_get_original_color_world_layer()
		if effect_id in ORIGINAL_COLOR_EFFECTS
		else get_tree().get_first_node_in_group("effects_container")
	)
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return null

	if sprite.get_parent() != container:
		if sprite.get_parent() == null:
			container.add_child(sprite)
		else:
			sprite.reparent(container)
	sprite.global_position = world_position
	sprite.show()
	active_sprites.append(sprite)
	if (
		not minimalist_mode
		and effect_id in ELECTRIC_EFFECTS
		and effect_id not in NO_LIGHT_EFFECTS
		and effect_id not in ORIGINAL_COLOR_EFFECTS
	):
		_play_electric_flash(
			container,
			world_position,
			readable_scale,
			effect_id
		)
	if not bool(effect_data.get("loop", false)):
		sprite.animation_finished.connect(
			_recycle_effect.bind(sprite),
			CONNECT_ONE_SHOT
		)
	sprite.play(&"play")
	return sprite


func play_attached(
	effect_id: StringName,
	parent: Node2D,
	local_position: Vector2 = Vector2.ZERO,
	effect_scale: float = 1.0,
	rotation_radians: float = 0.0
) -> AnimatedSprite2D:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var sprite := play(
		effect_id, parent.to_global(local_position), effect_scale, rotation_radians
	)
	if sprite == null:
		return null
	if effect_id in ORIGINAL_COLOR_EFFECTS:
		sprite.set_meta("follow_target", weakref(parent))
		sprite.set_meta("follow_offset", local_position)
		sprite.set_meta("follow_rotation", rotation_radians)
		sprite.global_position = parent.to_global(local_position)
		sprite.global_rotation = parent.global_rotation + rotation_radians
		return sprite
	sprite.reparent(parent, true)
	sprite.position = local_position
	sprite.rotation = rotation_radians
	return sprite


func stop_effect(sprite: AnimatedSprite2D) -> void:
	_recycle_effect(sprite)


func uses_original_colors(effect_id: StringName) -> bool:
	return effect_id in ORIGINAL_COLOR_EFFECTS


func get_effect_generation(sprite: AnimatedSprite2D) -> int:
	if not is_instance_valid(sprite):
		return -1
	return int(sprite.get_meta("vfx_generation", -1))


func _get_original_color_world_layer() -> CanvasLayer:
	if is_instance_valid(original_color_world_layer):
		return original_color_world_layer
	original_color_world_layer = CanvasLayer.new()
	original_color_world_layer.name = "OriginalColorWorldVFXLayer"
	original_color_world_layer.layer = 106
	original_color_world_layer.follow_viewport_enabled = true
	original_color_world_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(original_color_world_layer)
	return original_color_world_layer


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


func play_ui(
	effect_id: StringName,
	viewport_position: Vector2,
	effect_scale: float = 1.0,
	rotation_radians: float = 0.0
) -> AnimatedSprite2D:
	var sprite := play(effect_id, viewport_position, effect_scale, rotation_radians)
	if sprite == null:
		return null
	if ui_layer == null or not is_instance_valid(ui_layer):
		ui_layer = CanvasLayer.new()
		ui_layer.name = "PooledUIVFXLayer"
		ui_layer.layer = 250
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(ui_layer)
	if sprite.get_parent() != ui_layer:
		sprite.reparent(ui_layer)
	sprite.position = viewport_position
	sprite.z_index = 0
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	return sprite


func _get_pixel_vfx_material(effect: Variant) -> ShaderMaterial:
	# Keep the earlier boolean helper contract usable by visual-system tooling,
	# while runtime callers use the more precise effect identifier.
	var effect_id := (
		(&"electric_impact" if bool(effect) else &"generic_hit")
		if effect is bool
		else StringName(effect)
	)
	if effect_id in ELECTRIC_EFFECTS:
		if pixel_electric_material == null:
			pixel_electric_material = ShaderMaterial.new()
			pixel_electric_material.shader = PIXEL_EMISSIVE_SHADER
			pixel_electric_material.set_shader_parameter("force_electric_blue", true)
		return pixel_electric_material
	if effect_id in CRIMSON_EFFECTS:
		if pixel_crimson_material == null:
			pixel_crimson_material = ShaderMaterial.new()
			pixel_crimson_material.shader = PIXEL_EMISSIVE_SHADER
			pixel_crimson_material.set_shader_parameter("force_alert_red", true)
		return pixel_crimson_material
	if effect_id in NEUTRAL_EFFECTS:
		if pixel_neutral_material == null:
			pixel_neutral_material = ShaderMaterial.new()
			pixel_neutral_material.shader = PIXEL_EMISSIVE_SHADER
			pixel_neutral_material.set_shader_parameter("force_neutral_smoke", true)
		return pixel_neutral_material
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
				float(effect_data["fps"]),
				int(effect_data.get("start_frame", 0))
			)
			if effect_data.has("frame_size")
			else _make_atlas_animation(
				effect_data["texture"],
				int(effect_data["row"]),
				float(effect_data["fps"])
			)
		)
	)
	frames.set_animation_loop(&"play", bool(effect_data.get("loop", false)))
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
	sprite.set_meta(
		"vfx_generation",
		int(sprite.get_meta("vfx_generation", 0)) + 1
	)
	var recycle_callback := _recycle_effect.bind(sprite)
	if sprite.animation_finished.is_connected(recycle_callback):
		sprite.animation_finished.disconnect(recycle_callback)
	sprite.stop()
	sprite.hide()
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.offset = Vector2.ZERO
	sprite.speed_scale = 1.0
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.z_index = 0
	sprite.z_as_relative = true
	sprite.centered = true
	sprite.flip_h = false
	sprite.flip_v = false
	for transient_group in [&"thunder_vfx", &"kinetic_charge_vfx"]:
		if sprite.is_in_group(transient_group):
			sprite.remove_from_group(transient_group)
	if sprite.has_meta("autoattack_lightning"):
		sprite.remove_meta("autoattack_lightning")
	for follow_meta in ["follow_target", "follow_offset", "follow_rotation", "effect_id"]:
		if sprite.has_meta(follow_meta):
			sprite.remove_meta(follow_meta)
	sprite.name = "PooledCombatVFX"
	sprite.process_mode = Node.PROCESS_MODE_INHERIT
	active_sprites.erase(sprite)
	if pooled_sprites.size() < MAX_POOLED_EFFECTS:
		var container := get_tree().get_first_node_in_group("effects_container")
		if container == null:
			container = get_tree().current_scene
		if container != null and sprite.get_parent() != container:
			sprite.reparent(container)
		pooled_sprites.append(sprite)
	else:
		sprite.queue_free()


func finish_active_effects_during_pause() -> void:
	# The death transition pauses gameplay immediately. Let effects already
	# spawned by the killing hit finish, but remove persistent combat loops so
	# Ball Lightning and status auras cannot continue under refabrication.
	var persistent_effects: Array[AnimatedSprite2D] = []
	for sprite in active_sprites.duplicate():
		if is_instance_valid(sprite):
			if sprite.sprite_frames.get_animation_loop(&"play"):
				persistent_effects.append(sprite)
			else:
				sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	for sprite in persistent_effects:
		_recycle_effect(sprite)


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
	if ui_layer != null and is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = null


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
	fps: float,
	start_frame: int = 0
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_loop(&"play", false)
	frames.set_animation_speed(&"play", fps)
	var safe_columns := maxi(columns, 1)
	for relative_index in range(frame_count):
		var frame_index := start_frame + relative_index
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
