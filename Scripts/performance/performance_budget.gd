extends Node


var rolling_frame_ms: float = 16.67
var peak_frame_ms: float = 16.67
var degraded_quality: bool = false
var overload_seconds: float = 0.0
var peak_counts: Dictionary = {
	"enemies": 0,
	"enemy_projectiles": 0,
	"player_projectiles": 0,
	"vfx": 0,
	"lights": 0,
	"damage_numbers": 0,
}


func _process(delta: float) -> void:
	var frame_ms := delta * 1000.0
	rolling_frame_ms = lerpf(rolling_frame_ms, frame_ms, 0.06)
	peak_frame_ms = maxf(peak_frame_ms, frame_ms)
	var threshold := _budget("degrade_frame_ms", 25.0)
	if degraded_quality:
		degraded_quality = rolling_frame_ms > threshold * 0.82
	else:
		degraded_quality = rolling_frame_ms > threshold
	overload_seconds = (
		overload_seconds + delta
		if rolling_frame_ms > threshold
		else maxf(overload_seconds - delta * 0.5, 0.0)
	)
	peak_counts["enemies"] = maxi(
		int(peak_counts["enemies"]),
		get_tree().get_nodes_in_group("enemies").size()
	)
	peak_counts["enemy_projectiles"] = maxi(
		int(peak_counts["enemy_projectiles"]),
		get_tree().get_nodes_in_group("enemy_projectiles").size()
	)
	peak_counts["player_projectiles"] = maxi(
		int(peak_counts["player_projectiles"]),
		get_tree().get_nodes_in_group("player_projectiles").size()
	)
	peak_counts["lights"] = maxi(
		int(peak_counts["lights"]),
		_count_runtime_lights()
	)
	peak_counts["damage_numbers"] = maxi(
		int(peak_counts["damage_numbers"]),
		get_tree().get_nodes_in_group("damage_numbers").size()
	)


func allow_enemy() -> bool:
	return get_tree().get_nodes_in_group("enemies").size() < int(
		_budget("enemies", 73.0)
	)


func allow_enemy_projectile() -> bool:
	return get_tree().get_nodes_in_group("enemy_projectiles").size() < int(
		_budget("enemy_projectiles", 84.0)
	)


func allow_player_projectile() -> bool:
	return get_tree().get_nodes_in_group("player_projectiles").size() < int(
		_budget("player_projectiles", 72.0)
	)


func allow_effect() -> bool:
	var visual_effects := get_tree().root.get_node_or_null("VisualEffects")
	if visual_effects == null:
		return true
	var active_sprites: Array = Array(visual_effects.get("active_sprites"))
	var active_count := active_sprites.size()
	peak_counts["vfx"] = maxi(int(peak_counts["vfx"]), active_count)
	var budget := int(_budget("vfx", 72.0))
	if degraded_quality:
		budget = int(float(budget) * 0.62)
	return active_count < budget


func allow_light() -> bool:
	var limit := int(_budget("runtime_lights", 20.0))
	if degraded_quality:
		limit = maxi(int(limit * 0.5), 4)
	return _count_runtime_lights() < limit


func allow_damage_number() -> bool:
	var limit := int(_budget("damage_numbers", 28.0))
	if degraded_quality:
		limit = maxi(int(limit * 0.55), 8)
	return get_tree().get_nodes_in_group("damage_numbers").size() < limit


func get_spawn_pressure_scale() -> float:
	if overload_seconds > 1.5:
		return 0.62
	if degraded_quality:
		return 0.82
	return 1.0


func get_pool_limit(_scene_path: String, fallback: int = 64) -> int:
	return int(_budget("pooled_per_scene", float(fallback)))


func get_quality_scale() -> float:
	return 0.62 if degraded_quality else 1.0


func get_snapshot() -> Dictionary:
	return {
		"rolling_frame_ms": rolling_frame_ms,
		"peak_frame_ms": peak_frame_ms,
		"overload_seconds": overload_seconds,
		"degraded_quality": degraded_quality,
		"peaks": peak_counts.duplicate(true),
	}


func _budget(key: String, fallback: float) -> float:
	var database := get_tree().root.get_node_or_null("BalanceDatabase")
	if database == null:
		return fallback
	return float(database.call("get_budget", key, fallback))


func reset_peaks() -> void:
	peak_frame_ms = rolling_frame_ms
	overload_seconds = 0.0
	for key in peak_counts:
		peak_counts[key] = 0


func _count_runtime_lights() -> int:
	return (
		get_tree().get_nodes_in_group("electric_flash").size()
		+ get_tree().get_nodes_in_group("fire_flash").size()
		+ get_tree().get_nodes_in_group("telekinetic_flash").size()
		+ get_tree().get_nodes_in_group("projectile_light").size()
	)
