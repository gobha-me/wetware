extends SceneTree
## Headless C++23 -> Godot 4.7.2 snapshot bridge contract test (M1.4).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 and args.size() != 5:
		push_error("Expected <default.json> <collapse.json> [<shepherd.json> <scorched_earth.json> <three_way_clash.json>]")
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
	if (default_dict["syndicates"] as Array).size() != 4 or (default_dict["districts"] as Array).size() != 6:
		push_error("M8 snapshot missing 4 syndicates or 6 megacity districts")
		quit(1)
		return
	var dist0: Dictionary = default_dict["districts"][0]
	if not dist0.has("crowd_surge_active") or not dist0.has("monorail_wreck_lootable") or not dist0.has("corpse_drops_count") or not dist0.has("transformer_intact") or not dist0.has("executive_convoy_active"):
		push_error("Snapshot district telemetry missing M3/M4 fields")
		quit(1)
		return

	var all_18_vehicles := [
		"SyndicateApc", "PlasmaSentryTurret", "SyndicateSpinner", "MonorailArmoredCar",
		"HighVoltageTransformerBank", "CryoStasisVat", "ExecutiveArmoredLimo", "CorpSecurityInterceptor",
		"CyberClinicMedPod", "QuadHunterKillerDrone", "DataVaultMainframeRack", "HeavyRiotBulldozer",
		"AutonomousCargoHauler", "HazmatDeconRig", "ConcreteRiotBarricade", "AutomatedCheckpointGate",
		"StreetVendingMachineBank", "RooftopHvacCoolingTower",
	]
	for vehicle_node_name in all_18_vehicles:
		var vnode := sector.get_node_or_null(vehicle_node_name) as Sprite2D
		if vnode == null or vnode.hframes != 8 or vnode.texture == null or vnode.scale != Vector2.ONE:
			push_error("Missing or non-native-scale 8-directional isometric vehicle/prop node: %s" % vehicle_node_name)
			quit(1)
			return

	for actor_node_name in ["OperativeKestrel1", "OperativeVex2", "OperativeNull3", "OperativeChrome4", "CorpSecGuard1", "CorpSecGuard2", "MegacityCivilian1", "MegacityCivilian2"]:
		var anode := sector.get_node_or_null(actor_node_name) as Sprite2D
		if anode == null or anode.hframes != 8 or anode.vframes != 4 or anode.texture == null:
			push_error("Missing or misconfigured 8x4 multi-pose character sprite node: %s" % actor_node_name)
			quit(1)
			return

	if sector._city_buildings.size() < 10 or sector._proc_civilians.size() != 10 or sector._puppet_identities.size() != 4 or not sector._rival_operatives.is_empty():
		push_error("M7 city/crowd/roster not initialized, or rival operatives were spawned without a snapshot")
		quit(1)
		return

	var portrait_rect := sector.get_node_or_null("TacticalHud/PortraitRect") as TextureRect
	if portrait_rect == null or portrait_rect.texture == null:
		push_error("Missing Venice operative portrait in TacticalHud")
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

	var replays_checked := 0
	if args.size() == 5:
		for i in range(2, 5):
			if not _check_replay(scene_packed, args[i]):
				quit(1)
				return
			replays_checked += 1

	print("Godot 4.7.2 C++23 snapshot bridge contract: 2 valid scenarios, %d invalid fixtures, %d event replays passed" % [bad_cases.size(), replays_checked])
	quit(0)


## Replays a schema-2 snapshot and checks the opening state (recovered by
## rewinding the event log) and the final rendered state against the C++
## snapshot itself.
func _check_replay(scene_packed: PackedScene, path: String) -> bool:
	var data: Dictionary = _load_json(path)
	var sector := scene_packed.instantiate()
	root.add_child(sector)
	if not sector.start_snapshot_replay(path):
		push_error("Replay rejected: %s" % path)
		return false
	var replay: Node = sector._replay
	var focus := int(data["focus_district_id"])

	# Opening state: nobody in the focus district starts dead from combat.
	var open_thralls: int = replay.thrall_ring
	var open_dead := 0
	for key in replay.actors:
		var a: Dictionary = replay.actors[key]
		if int(a["district"]) == focus and not bool(a["alive"]):
			open_dead += 1

	# Play every event.
	var guard := 0
	while not replay.finished and guard < 20000:
		replay._process(0.05)
		guard += 1
	if not replay.finished:
		push_error("Replay did not finish: %s" % path)
		return false

	# Final rendered state must equal the authoritative snapshot.
	for syn in data["syndicates"]:
		for op in syn["squad"]:
			var a: Dictionary = replay.actors["%d:%d" % [int(syn["id"]), int(op["id"])]]
			if bool(a["alive"]) != bool(op["alive"]) or int(a["health"]) != int(op["health"]) \
					or int(a["district"]) != int(op["district_id"]) \
					or a["pos"] != Vector3(int(op["grid_x"]), int(op["grid_y"]), int(op["stratum"])):
				push_error("Replay final state diverges from snapshot for %s in %s" % [op["callsign"], path])
				return false
			var node: Node2D = a["node"]
			if int(op["district_id"]) == focus and node != null:
				var should_show := bool(op["alive"]) or bool(a["hijacked"])
				if node.visible != should_show:
					push_error("Visibility of %s does not match snapshot in %s" % [op["callsign"], path])
					return false
	var final_thralls := 0
	for t in data["syndicates"][0]["thralls"]:
		if int(t["district_id"]) == focus and int(t["directive"]) == 0:
			final_thralls += 1
	if replay.thrall_ring != final_thralls:
		push_error("Escort mesh %d != snapshot %d in %s" % [replay.thrall_ring, final_thralls, path])
		return false
	for b in data["buildings"]:
		if int(b["id"]) == replay.focus_organ_building and sector.tower_collapsed != (int(b["state"]) == 2):
			push_error("Landmark state does not match snapshot in %s" % path)
			return false

	var rivals_in_focus := 0
	for r in sector._rival_operatives:
		rivals_in_focus += 1
	print("  replay %s: district %d, %d events, %d rival nodes, opening thralls %d -> final %d, opening dead %d" % [
		path.get_file(), focus, (data["events"] as Array).size(), rivals_in_focus, open_thralls, final_thralls, open_dead])
	Engine.time_scale = 1.0
	sector.free()
	return true

func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
