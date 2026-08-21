extends SceneTree


var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failures += 1
	push_error("FAIL: " + message)


func _run() -> void:
	var flow := root.get_node_or_null("GameFlow")
	_check(flow != null, "GameFlow is available")
	if flow == null:
		quit(1)
		return
	flow.call("force_state", &"PLAYING", false)
	_check(
		bool(flow.call("request_state", &"PLAYING", &"DYING")) and paused,
		"The killing frame immediately pauses combat"
	)
	_check(
		bool(flow.call("request_state", &"DYING", &"REBIRTH")) and paused,
		"Refabrication keeps combat fully paused"
	)
	_check(
		bool(flow.call("request_state", &"REBIRTH", &"GAME_OVER")) and paused,
		"The final game-over overlay cannot resume background combat"
	)
	flow.call("force_state", &"PLAYING", false)
	_check(not paused, "Starting a new run explicitly resumes the tree")
	if failures == 0:
		print("DEATH REFABRICATION PAUSE TEST PASSED")
	quit(1 if failures > 0 else 0)
