class_name ProcContext
extends RefCounted


static var _next_cast_id: int = 1

var cast_id: int
var root_cast_id: int
var generation: int = 0
var max_generation: int = 0
var visited_targets: Dictionary = {}
var proc_counts: Dictionary = {}


func _init(limit: int = 0) -> void:
	cast_id = _next_cast_id
	_next_cast_id += 1
	root_cast_id = cast_id
	max_generation = maxi(limit, 0)


func fork() -> ProcContext:
	var child := ProcContext.new(max_generation)
	child.root_cast_id = root_cast_id
	child.generation = generation + 1
	child.visited_targets = visited_targets
	child.proc_counts = proc_counts
	return child


func can_fork() -> bool:
	return generation < max_generation


func visit(target: Object) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var target_id := target.get_instance_id()
	if visited_targets.has(target_id):
		return false
	visited_targets[target_id] = true
	return true


func allow_proc(proc_id: StringName, limit: int) -> bool:
	var count := int(proc_counts.get(proc_id, 0))
	if count >= maxi(limit, 0):
		return false
	proc_counts[proc_id] = count + 1
	return true
