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
	if typeof(default_data) != TYPE_DICTIONARY or typeof(collapse_data) != TYPE_DICTIONARY:
		push_error("Failed to parse default or collapse snapshot JSON")
		quit(1)
		return

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

	# Verify M9: All 6 District City Organ Landmarks (intact & rubble) + surrounding block rubble
	var intact_node := sector.get_node_or_null("BioFoundryTowerIntact") as Sprite2D
	var rubble_node := sector.get_node_or_null("BioFoundryTowerRubble") as Sprite2D
	for did in range(1, 7):
		sector.set_focus_district(did)
		if sector.focus_district_id != did or sector.focus_organ_placeholder:
			push_error("District %d landmark failed to clear placeholder flag" % did)
			quit(1)
			return
		if intact_node == null or intact_node.texture == null or intact_node.texture.get_size() != Vector2(256, 288):
			push_error("District %d intact landmark texture missing or wrong dimensions" % did)
			quit(1)
			return
		if rubble_node == null or rubble_node.texture == null or rubble_node.texture.get_size() != Vector2(256, 288):
			push_error("District %d rubble landmark texture missing or wrong dimensions" % did)
			quit(1)
			return
	sector.set_focus_district(1)
	sector.set_surrounding_blocks_collapsed(3)
	var b1: Sprite2D = sector._city_buildings[1]
	if b1 == null or b1.texture == null or b1.texture.get_size() != Vector2(256, 256):
		push_error("city_block_rubble texture missing or wrong dimensions")
		quit(1)
		return
	sector.set_surrounding_blocks_collapsed(0)

	# Verify M9: All 3 Interactive Strategic HQ Screens (Megacity Map, Ripperdoc Bay, 3-Path R&D Lab)
	if sector._hq_screens == null:
		push_error("HqScreens node not initialized")
		quit(1)
		return
	for hq_mode in [1, 2, 3, 0]:
		sector.set_hq_screen(hq_mode)
		if sector.get_hq_screen() != hq_mode:
			push_error("Failed to switch HqScreen to mode %d" % hq_mode)
			quit(1)
			return
	sector.syndicate_treasury = 5000
	sector.salvage_units = 2
	if not sector._hq_screens.upgrade_selected_organ():
		push_error("Ripperdoc organ upgrade failed")
		quit(1)
		return
	if not sector._hq_screens.thaw_cryo_replacement():
		push_error("Ripperdoc cryo-vat thaw failed")
		quit(1)
		return
	if not sector._hq_screens.fund_selected_blueprint():
		push_error("R&D blueprint funding failed")
		quit(1)
		return
	if not sector._hq_screens.reverse_engineer_salvage_unit():
		push_error("Cryo-vault salvage +50% reverse-engineering failed")
		quit(1)
		return
	if not sector._hq_screens.equip_salvage_unit():
		push_error("Cryo-vault salvage direct equip failed")
		quit(1)
		return

	# Verify M11: 8-direction vehicle turntable mapping, 2:1 isometric road-lane alignment, traffic stepping & destruction
	var expected_dir_frames := [
		[Vector2(-2.0, -1.0), 0], # NW (-gx)
		[Vector2(-1.0, 0.0), 1],  # W
		[Vector2(-2.0, 1.0), 2],  # SW (+gy)
		[Vector2(0.0, 1.0), 3],   # S
		[Vector2(2.0, 1.0), 4],   # SE (+gx)
		[Vector2(1.0, 0.0), 5],   # E
		[Vector2(2.0, -1.0), 6],  # NE (-gy)
		[Vector2(0.0, -1.0), 7],  # N
	]
	for pair in expected_dir_frames:
		var got_frame: int = sector._vehicle_dir_to_frame(pair[0])
		if got_frame != int(pair[1]):
			push_error("_vehicle_dir_to_frame(%s) returned %d, expected %d" % [str(pair[0]), got_frame, int(pair[1])])
			quit(1)
			return
	for vehicle_node_name in all_18_vehicles:
		var vnode := sector.get_node_or_null(vehicle_node_name) as Sprite2D
		if vnode.frame % 2 != 0:
			push_error("Vehicle/prop node %s started on non-isometric frame %d" % [vehicle_node_name, vnode.frame])
			quit(1)
			return
	if sector._street_vehicles.size() != 7:
		push_error("Expected 7 active street traffic vehicles, got %d" % sector._street_vehicles.size())
		quit(1)
		return
	var interceptor := sector.get_node_or_null("CorpSecurityInterceptor") as Sprite2D
	var prev_interceptor_pos := interceptor.position
	sector._step_street_vehicles(0.5)
	if interceptor.position.distance_to(prev_interceptor_pos) < 5.0:
		push_error("Street vehicle traffic did not advance along road lane")
		quit(1)
		return
	if not sector._damage_street_vehicle_at(interceptor.position, 120):
		push_error("Failed to hit street vehicle at its world position")
		quit(1)
		return
	if not bool(sector._street_vehicles[1]["destroyed"]):
		push_error("Street vehicle was not marked destroyed after taking lethal damage")
		quit(1)
		return

	# Verify M12: Live C++23 command script dispatch and deterministic digest rolling
	var prev_digest: String = sector.last_digest
	if not sector.dispatch_live_cpp_command("raid:2:0;step_day:1", true):
		push_error("M12 dispatch_live_cpp_command failed")
		quit(1)
		return
	if sector.last_digest == prev_digest or sector._live_cpp_command_log.is_empty():
		push_error("M12 live command log / digest did not advance")
		quit(1)
		return

	# Verify M13: Playable 6-District Megacity Campaign Loop & Rival Counter-Raids
	sector.syndicate_treasury = 5000
	if not sector._hq_screens.raid_district(2, true):
		push_error("M13 raid_district failed")
		quit(1)
		return
	if not sector._hq_screens.advance_campaign_day():
		push_error("M13 advance_campaign_day failed")
		quit(1)
		return
	if sector._hq_screens.campaign_day < 2:
		push_error("M13 campaign_day did not advance")
		quit(1)
		return
	if not sector._hq_screens.rebuild_district_landmark(2):
		push_error("M13 rebuild_district_landmark failed")
		quit(1)
		return
	sector.set_focus_district(1)

	# Verify M14: Spatial Audio synthesis & Multi-Stage Building Structural Damage (INTACT -> DAMAGED -> RUBBLE)
	if sector._ambient_player == null or sector._sfx_player_2d == null:
		push_error("M14 spatial audio players not initialized")
		quit(1)
		return
	var prev_sfx_count: int = sector.sfx_play_count
	sector.play_sfx("gauss", Vector2(640, 292))
	if sector.sfx_play_count != prev_sfx_count + 1 or sector.last_played_sfx != "gauss":
		push_error("M14 play_sfx('gauss') did not register")
		quit(1)
		return
	sector.set_tower_collapsed(false)
	if sector.tower_damage_stage != 0 or sector.tower_structural_hp != 100:
		push_error("M14 tower failed to reset to stage 0 (INTACT, 100 HP)")
		quit(1)
		return
	sector.apply_tower_damage(50)
	if sector.tower_damage_stage != 1 or sector.tower_collapsed:
		push_error("M14 first 50-damage hit should put tower in stage 1 (DAMAGED), got %d" % sector.tower_damage_stage)
		quit(1)
		return
	sector.apply_tower_damage(50)
	if sector.tower_damage_stage != 2 or not sector.tower_collapsed:
		push_error("M14 second 50-damage hit should collapse tower to stage 2 (RUBBLE), got %d" % sector.tower_damage_stage)
		quit(1)
		return
	sector.set_tower_collapsed(false)

	# Verify M15: Multi-operative squad selection, cover mitigation, hostile AI return fire & salvage drops
	sector.select_full_squad()
	if sector.selected_squad_indices.size() != 4:
		push_error("M15 select_full_squad did not select all 4 operatives")
		quit(1)
		return
	if sector._hostile_defenders.size() != 3:
		push_error("M15 expected 3 hostile defenders, got %d" % sector._hostile_defenders.size())
		quit(1)
		return
	var barricade := sector.get_node_or_null("ConcreteRiotBarricade") as Node2D
	var op0 := sector.get_node_or_null("OperativeKestrel1") as Node2D
	var orig_op0_pos := op0.position
	op0.position = barricade.position + Vector2(12, 8)
	if not sector.is_operative_in_cover(0):
		push_error("M15 operative next to ConcreteRiotBarricade was not detected in cover")
		quit(1)
		return
	var cover_loss: int = sector.apply_operative_damage(0, 20)
	if cover_loss >= 10:
		push_error("M15 cover mitigation + armor did not reduce 20 incoming damage (lost %d HP)" % cover_loss)
		quit(1)
		return
	op0.position = orig_op0_pos
	sector.crowd_surge_active = false
	if not sector.step_hostile_combat_ai(1.0):
		push_error("M15 step_hostile_combat_ai did not trigger enemy return fire")
		quit(1)
		return
	var guard1 := sector.get_node_or_null("CorpSecGuard1") as Node2D
	var prev_drops: int = sector._salvage_drops.size()
	if not sector._damage_hostile_defender_at(guard1.position, 120):
		push_error("M15 _damage_hostile_defender_at failed to hit CorpSecGuard1")
		quit(1)
		return
	if bool(sector._hostile_defenders[0]["alive"]) or sector._salvage_drops.size() != prev_drops + 1:
		push_error("M15 lethal hit on CorpSecGuard1 did not mark dead and spawn salvage drop")
		quit(1)
		return

	# Verify M16: 6 distinct district sector topologies + Spinner insertion & extraction mission loop
	var seen_archetypes := {}
	var seen_lzs := {}
	for did in range(1, 7):
		sector.set_focus_district(did)
		seen_archetypes[sector.current_district_archetype] = true
		seen_lzs[str(sector.extraction_lz_pos)] = true
	if seen_archetypes.size() != 6 or seen_lzs.size() != 6:
		push_error("M16 expected 6 distinct district archetypes and LZ positions, got %d / %d" % [seen_archetypes.size(), seen_lzs.size()])
		quit(1)
		return
	sector.set_focus_district(1)
	sector.deploy_squad_at_spinner()
	if op0.position.distance_to(sector.extraction_lz_pos) > 5.0:
		push_error("M16 deploy_squad_at_spinner did not place Kestrel-1 at extraction_lz_pos")
		quit(1)
		return
	sector.transformer_sabotaged = true
	if not sector.is_extraction_ready():
		push_error("M16 extraction should be ready after primary objective completion")
		quit(1)
		return
	if not sector.extract_squad() or not sector.mission_extracted or sector.missions_completed < 1 or sector.get_hq_screen() != 1:
		push_error("M16 extract_squad failed to complete extraction and transition to HQ Megacity Map")
		quit(1)
		return
	sector.set_hq_screen(0)
	sector.transformer_sabotaged = false

	# Verify M17: Campaign Save/Load Persistence, Playable Defense Missions & Endgame Victory/Defeat
	var saved_digest: String = sector.last_digest
	var saved_treasury: int = sector.syndicate_treasury
	var tmp_save_path := "/tmp/wetware-m17-contract-save.json"
	if not sector.save_campaign(tmp_save_path):
		push_error("M17 save_campaign failed")
		quit(1)
		return
	sector.last_digest = "0x0000000000000000"
	sector.syndicate_treasury = 123
	if not sector.load_campaign(tmp_save_path):
		push_error("M17 load_campaign failed")
		quit(1)
		return
	if sector.last_digest != saved_digest or sector.syndicate_treasury != saved_treasury:
		push_error("M17 save/load round-trip did not preserve state_digest and syndicate_treasury")
		quit(1)
		return
	sector._hq_screens.pending_defense_district = 2
	if not sector._hq_screens.launch_defense_mission() or sector.focus_district_id != 2 or sector._hq_screens.pending_defense_district != 0:
		push_error("M17 launch_defense_mission failed to deploy squad to raided district")
		quit(1)
		return
	sector._hq_screens.pending_defense_district = 3
	if not sector._hq_screens.auto_resolve_defense_mission() or sector._hq_screens.pending_defense_district != 0:
		push_error("M17 auto_resolve_defense_mission failed")
		quit(1)
		return
	for did in range(1, 7):
		sector._hq_screens.raid_district(did, false)
	if sector._hq_screens.campaign_outcome != "VICTORY":
		push_error("M17 owning all 6 districts did not trigger VICTORY outcome, got %s" % sector._hq_screens.campaign_outcome)
		quit(1)
		return
	sector._hq_screens.districts_state[5]["owner"] = 2
	sector.syndicate_treasury = 0
	for op_i in range(4):
		sector.operative_downed[op_i] = true
	if sector._hq_screens.evaluate_campaign_endgame() != "DEFEAT":
		push_error("M17 bankrupt + wiped squad did not trigger DEFEAT outcome")
		quit(1)
		return
	sector.load_campaign(tmp_save_path)
	sector.set_focus_district(1)

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
