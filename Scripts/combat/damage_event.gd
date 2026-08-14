class_name DamageEvent
extends RefCounted


enum DamageType {
	DIRECT,
	DAMAGE_OVER_TIME,
	CONTACT,
	PROJECTILE,
	EXPLOSION,
	ENVIRONMENT,
}

enum HitRole {
	PRIMARY,
	SECONDARY,
	STATUS_TICK,
	REFLECTED,
}

var amount: float = 0.0
var source: Node
var target: Node2D
var source_id: StringName = &"unclassified"
var affinity: StringName = &"physical"
var damage_type: DamageType = DamageType.DIRECT
var critical_chance: float = 0.0
var critical_multiplier: float = 1.5
var can_crit: bool = false
var knockback_direction: Vector2 = Vector2.ZERO
var knockback_strength: float = 0.0
var play_hit_sound: bool = true
var show_damage_number: bool = true
var heavy_feedback: bool = false
var tags: Array[StringName] = []
var status_effects: Array[Dictionary] = []
var metadata: Dictionary = {}
var hit_role: HitRole = HitRole.PRIMARY
var proc_context: ProcContext
var can_trigger_procs: bool = true


static func create(
	event_target: Node2D,
	event_amount: float,
	event_source: Node = null,
	event_source_id: StringName = &"unclassified",
	event_affinity: StringName = &"physical"
) -> DamageEvent:
	var event := DamageEvent.new()
	event.target = event_target
	event.amount = event_amount
	event.source = event_source
	event.source_id = event_source_id
	event.affinity = event_affinity
	return event


func with_knockback(direction: Vector2, strength: float) -> DamageEvent:
	knockback_direction = direction.normalized()
	knockback_strength = maxf(strength, 0.0)
	return self


func add_status(status_definition: Dictionary) -> DamageEvent:
	status_effects.append(status_definition.duplicate(true))
	return self


func has_tag(tag: StringName) -> bool:
	return tag in tags


func with_proc_context(context: ProcContext, role: HitRole = HitRole.PRIMARY) -> DamageEvent:
	proc_context = context
	hit_role = role
	return self
