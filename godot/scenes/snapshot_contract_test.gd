extends SceneTree
## Headless C++23 -> Godot 4.7.2 snapshot bridge contract test (M1.4).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected 2 snapshot paths: <default.json> <collapse.json>")
		quit(1)
		return

	var default_data: Variant = _load_json(args[0])
	var collapse_data: Variant = _load_json(args[1])

	var scene_packed := load("res://scenes/vertical_slice.tscn") as PackedScene
	if scene_packed == null:
		push_error("Failed to load vertical_slice.tscn")
		quit(1)
		return

	var sector := scene_packed.instantiate()
	root.add_child(sector)

	if not sector.apply_snapshot(default_data):
		push_error("Valid default C++23 snapshot rejected")
		quit(1)
		return

	var kestrel := sector.get_node("OperativeKestrel1")
	if int(kestrel.get_meta("stratum")) != 2 or sector.tower_collapsed:
		push_error("Default snapshot state mismatch")
		quit(1)
		return

	if not sector.apply_snapshot(collapse_data):
		push_error("Valid collapse C++23 snapshot rejected")
		quit(1)
		return

	if not sector.tower_collapsed or int(kestrel.get_meta("stratum")) != 1 or not sector.overclock_active:
		push_error("Collapse + Overclock C++23 snapshot did not update Godot presentation state")
		quit(1)
		return

	var hud_label := sector.get_node("TacticalHud/HudTelemetryLabel") as Label
	if hud_label == null or not hud_label.text.contains("BIO-FOUNDRY: RUBBLE") or not hud_label.text.contains("OVERCLOCK 0.25x"):
		push_error("TacticalHud label did not reflect authoritative C++23 collapse/overclock state")
		quit(1)
		return

	var default_dict := default_data as Dictionary
	var dist0: Dictionary = default_dict["districts"][0]
	if not dist0.has("crowd_surge_active") or not dist0.has("monorail_wreck_lootable") or not dist0.has("corpse_drops_count"):
		push_error("Snapshot district telemetry missing M3 fields")
		quit(1)
		return

	for vehicle_node_name in ["SyndicateApc", "PlasmaSentryTurret", "SyndicateSpinner", "MonorailArmoredCar"]:
		var vnode := sector.get_node_or_null(vehicle_node_name) as Sprite2D
		if vnode == null or vnode.hframes != 8 or vnode.texture == null:
			push_error("Missing or misconfigured 8-directional isometric vehicle/turret node: %s" % vehicle_node_name)
			quit(1)
			return

	# Reject malformed / adversarial snapshots
	var bad_cases: Array = [
		null,
		{},
		{"schema_version": 99},
	]
	var bad_digest: Dictionary = (default_data as Dictionary).duplicate(true)
	bad_digest["state_digest"] = 12345
	bad_cases.append(bad_digest)

	var bad_stratum: Dictionary = (default_data as Dictionary).duplicate(true)
	bad_stratum["syndicates"][0]["squad"][0]["stratum"] = 99
	bad_cases.append(bad_stratum)

	for bad in bad_cases:
		if sector.valid_snapshot(bad):
			push_error("Invalid snapshot accepted by Godot consumer")
			quit(1)
			return

	Engine.time_scale = 1.0
	sector.free()
	print("Godot 4.7.2 C++23 snapshot bridge contract: 2 valid scenarios and %d invalid fixtures passed" % bad_cases.size())
	quit(0)

func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
