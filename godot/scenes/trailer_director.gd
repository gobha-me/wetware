extends Node
## 6-Act Choreographed Trailer Director for "SUBJ #404: Doctrine of Attrition" (Step 3 / M10).
## Each act runs for 1500 frames @ 30 FPS (50.0s), totaling 9000 frames (300.0s / 5:00) across Acts 1..6.
## Acts 2, 4, and 5 embed the real C++23 simulation replays (shepherd.json, scorched_earth.json, three_way_clash.json).

var sector = null
var act: int = 1
var frame: int = 0
var snap_dir: String = "/tmp/wetware-m9-snaps"


func begin(sec: Node2D, act_num: int, snapshots_dir: String = "/tmp/wetware-m9-snaps") -> void:
	sector = sec
	act = clampi(act_num, 1, 6)
	snap_dir = snapshots_dir
	frame = 0
	sector.demo_reel_active = true
	_setup_act_opening()


func _setup_act_opening() -> void:
	match act:
		1:
			sector.set_focus_district(1)
			sector.set_hq_screen(1)
			sector.set_banner("ACT I // STRATEGIC MEGACITY 6-DISTRICT OVERVIEW & KOWLOON CONVOY AMBUSH")
		2:
			sector.set_hq_screen(0)
			sector.start_snapshot_replay("%s/shepherd.json" % snap_dir)
			if sector._replay != null:
				sector._replay.timer = 1.1
			sector.set_banner("ACT II // DOCTRINE 1: THE SHEPHERD — SHINJUKU BROADCAST SPIRE & CHIBA HUB")
		3:
			sector.set_focus_district(1)
			sector.set_hq_screen(2)
			sector.syndicate_treasury = 6800
			sector.salvage_units = 4
			sector.set_banner("ACT III // RIPPERDOC CYBER-SURGERY BAY & 3-PATH R&D / SALVAGE LAB")
		4:
			sector.set_hq_screen(0)
			sector.start_snapshot_replay("%s/scorched_earth.json" % snap_dir)
			if sector._replay != null:
				sector._replay.timer = 1.4
			sector.set_banner("ACT IV // DOCTRINE 2: SCORCHED EARTH — NEO-RUHR FOUNDRY & POWER SUB-GRID")
		5:
			sector.set_hq_screen(0)
			sector.start_snapshot_replay("%s/three_way_clash.json" % snap_dir)
			if sector._replay != null:
				sector._replay.timer = 1.2
			sector.set_banner("ACT V // STRESS TEST: 3-SYNDICATE 3-STRATUM CROSSFIRE & CRYO-THAW")
		6:
			sector.set_hq_screen(0)
			sector.set_focus_district(6)
			sector.set_tower_collapsed(false)
			sector.set_surrounding_blocks_collapsed(0)
			sector._select_operative(0)
			sector.set_camera_focus(Vector2(640, 340), 0.90)
			sector.set_banner("ACT VI // ZAIBATSU CLEARINGHOUSE ARCOLOGY ASSAULT & MEGACITY CONQUEST")


func _process(_delta: float) -> void:
	if sector == null:
		return
	frame += 1
	match act:
		1:
			_step_act_1(frame)
		2:
			_step_act_2(frame)
		3:
			_step_act_3(frame)
		4:
			_step_act_4(frame)
		5:
			_step_act_5(frame)
		6:
			_step_act_6(frame)
	sector._request_overlay_redraw()


func _step_act_1(f: int) -> void:
	# 1..360 (0:00..0:12): Tour all 6 districts on the Strategic Megacity Map [G]
	if f in [50, 100, 150, 200, 250, 300]:
		var did := 1 + (f / 50) % 6
		sector.set_focus_district(did)
		sector._hq_screens.status_toast = "SCANNING DISTRICT %d // %s // ORGAN: %s" % [
			did, sector.focus_district_name, sector.focus_organ_name
		]
		sector._hq_screens.queue_redraw()
	elif f == 340:
		sector.set_focus_district(1)
		sector._hq_screens.status_toast = "DEPLOYING 4-AGENT CYBORG SQUAD TO DISTRICT 1 // KOWLOON BIO-FOUNDRY"
		sector._hq_screens.queue_redraw()
	elif f == 361:
		sector.set_hq_screen(0)
		sector._select_operative(1)
		sector.active_weapon_index = 0
		sector._update_operative_card()
		sector.move_target_pos = Vector2(512, 434)
		sector.has_move_target = true
		sector._cam_target_pos = Vector2(545, 415)
		sector._cam_target_zoom = 1.02
		sector.set_banner("ACT I // KOWLOON STREET DEPLOYMENT, PROXIMITY CUTAWAY & LIMO AMBUSH")
	elif f > 361 and f < 900:
		var limo := sector.get_node_or_null("ExecutiveArmoredLimo") as Sprite2D
		if limo and not sector.convoy_intercepted:
			limo.position += Vector2(0.28, 0.14)
		var null_op := sector.get_node_or_null("OperativeNull3") as Sprite2D
		if null_op and f < 620:
			var nd := Vector2(-0.35, 0.22)
			null_op.position += nd
			sector._update_sprite_facing(null_op, nd)
		if f in [440, 510, 580, 640]:
			sector._fire_active_weapon_at(Vector2(498, 474))
		if f == 520:
			sector.active_weapon_index = 1
			sector._update_operative_card()
		if f == 640:
			sector._intercept_executive_convoy()
		if f == 700:
			sector._select_operative(2)
			sector.move_target_pos = Vector2(656, 430)
			sector.has_move_target = true
			sector._cam_target_pos = Vector2(665, 410)
			sector._cam_target_zoom = 0.96
		if f in [760, 840]:
			sector._trigger_persuadertron_wave()
	elif f == 960:
		sector.set_banner("ACT I // 3-STRATUM VERTICAL SLICE: UNDER-GRID BLACKOUT & SPIRE VAULT")
		sector._select_operative(3)
		sector.move_target_pos = Vector2(464, 520)
		sector.has_move_target = true
		sector._cam_target_pos = Vector2(485, 490)
		sector._cam_target_zoom = 1.0
	elif f in [1050, 1120]:
		sector._fire_active_weapon_at(Vector2(360, 528))
		if f == 1120:
			sector._toggle_transformer_sabotage()
	elif f == 1220:
		sector._select_operative(0)
		sector.overclock_active = true
		sector._refresh_hud()
		sector.move_target_pos = Vector2(452, 190)
		sector.has_move_target = true
		sector._cam_target_pos = Vector2(540, 235)
		sector._cam_target_zoom = 0.95
	elif f in [1320, 1400]:
		sector._fire_active_weapon_at(Vector2(348, 188))
		if f == 1400:
			sector._loot_monorail_wreck()


func _clear_replay_state() -> void:
	if sector._replay != null:
		sector._replay.queue_free()
		sector._replay = null
	for r_entry in sector._rival_operatives:
		var rn: Node = r_entry.get("node")
		if rn != null:
			rn.queue_free()
	sector._rival_operatives.clear()
	for n in ["CorpSecGuard1", "CorpSecGuard2", "MegacityCivilian1", "MegacityCivilian2", "ExecutiveArmoredLimo"]:
		var node := sector.get_node_or_null(n) as CanvasItem
		if node != null:
			node.visible = true
	for op_name in sector.OPERATIVE_NODES:
		var op := sector.get_node_or_null(op_name) as CanvasItem
		if op != null:
			op.visible = true
	sector.replay_objectives_text = ""


func _step_act_2(f: int) -> void:
	# 1..960: Authoritative C++ Shepherd Replay in District 2 (Shinjuku Broadcast Spire)
	if f < 960 and sector._replay != null:
		if f % 2 == 0:
			sector._replay.timer += 0.016
	elif f == 960:
		_clear_replay_state()
		sector.set_focus_district(3)
		sector.set_tower_collapsed(false)
		sector._select_operative(1)
		sector._apply_stratum_cutaway(sector.Stratum.STREET)
		sector._cam_target_pos = Vector2(640, 335)
		sector._cam_target_zoom = 0.88
		sector.set_banner("ACT II // DISTRICT 3: CHIBA MONORAIL TRANSIT HUB — VIADUCT BREACH")
	elif f == 1120:
		sector.active_weapon_index = 2
		sector._update_operative_card()
		sector._fire_active_weapon_at(Vector2(640, 292))
	elif f == 1240:
		sector.active_weapon_index = 3
		sector.satellite_strike_timer = 0.75
		sector._fire_active_weapon_at(Vector2(640, 292))
		sector.set_tower_collapsed(true)
	elif f == 1380:
		sector.set_tower_collapsed(false)


func _step_act_3(f: int) -> void:
	# 1..750: Ripperdoc Cyber-Surgery & Cryo-Stasis Bay [U]
	if f < 750:
		if f in [90, 180, 270, 360, 450, 540]:
			sector._hq_screens.selected_organ_slot = (sector._hq_screens.selected_organ_slot + 1) % 6
			sector._hq_screens.upgrade_selected_organ()
		if f in [210, 420, 600]:
			sector._select_operative((sector.selected_operative + 1) % 4)
		if f == 660:
			sector._hq_screens.thaw_cryo_replacement()
	elif f == 750:
		# 750..1500: Symmetric 3-Path R&D & Field-Salvage Reverse-Engineering Lab [K]
		sector.set_hq_screen(3)
		sector.set_banner("ACT III // 3-PATH HYBRID TECH PROGRESSION: HQ R&D, -65% ORGAN & +50% SALVAGE")
	elif f > 750:
		if f in [840, 920]:
			sector._hq_screens.fund_selected_blueprint()
		elif f == 1020:
			sector._hq_screens.reverse_engineer_salvage_unit()
		elif f == 1120:
			sector._hq_screens.selected_blueprint_idx = 1
			sector._hq_screens.fund_selected_blueprint()
		elif f == 1220:
			sector._hq_screens.reverse_engineer_salvage_unit()
		elif f == 1320:
			sector._hq_screens.selected_blueprint_idx = 2
			sector._hq_screens.equip_salvage_unit()
		elif f == 1420:
			sector._hq_screens.selected_blueprint_idx = 3
			sector._hq_screens.reverse_engineer_salvage_unit()


func _step_act_4(f: int) -> void:
	# 1..960: Authoritative C++ Scorched Earth Replay in District 4 (Neo-Ruhr Heavy Ordinance Foundry)
	if f < 960 and sector._replay != null:
		if f % 2 == 0:
			sector._replay.timer += 0.022
	elif f == 960:
		_clear_replay_state()
		sector.set_focus_district(5)
		sector.set_tower_collapsed(false)
		sector.set_surrounding_blocks_collapsed(0)
		sector._select_operative(1)
		sector._apply_stratum_cutaway(sector.Stratum.STREET)
		sector._cam_target_pos = Vector2(640, 335)
		sector._cam_target_zoom = 0.86
		sector.set_banner("ACT IV // DISTRICT 5: MID-LEVELS POWER SUB-GRID — TESLA COIL OVERLOAD")
	elif f == 1120:
		sector._toggle_transformer_sabotage()
		sector._fire_active_weapon_at(Vector2(580, 310))
	elif f == 1260:
		sector.active_weapon_index = 3
		sector.satellite_strike_timer = 0.75
		sector._fire_active_weapon_at(Vector2(640, 292))
		sector.set_tower_collapsed(true)
		sector.set_surrounding_blocks_collapsed(4)


func _step_act_5(f: int) -> void:
	# 1..1500: Authoritative C++ 3-Syndicate 3-Stratum Clash Replay in District 1
	if sector._replay != null and f % 2 == 0:
		sector._replay.timer += 0.015
	if f == 420:
		sector._apply_stratum_cutaway(sector.Stratum.SPIRE)
	elif f == 620:
		sector._apply_stratum_cutaway(sector.Stratum.STREET)
	elif f == 980:
		sector._apply_stratum_cutaway(sector.Stratum.UNDER_GRID)
	elif f == 1120:
		sector._apply_stratum_cutaway(sector.Stratum.STREET)


func _step_act_6(f: int) -> void:
	# 1..960: Climax Assault on District 6 (Zaibatsu Clearinghouse Arcology Pyramid)
	if f == 60:
		sector._select_operative(2)
		sector.move_target_pos = Vector2(580, 390)
		sector.has_move_target = true
		sector._trigger_persuadertron_wave()
	elif f == 180:
		sector._select_operative(1)
		sector.overclock_active = true
		sector._refresh_hud()
		sector.active_weapon_index = 2
		sector._fire_active_weapon_at(Vector2(640, 292))
	elif f in [300, 420]:
		sector._fire_active_weapon_at(Vector2(620, 285))
		sector.set_surrounding_blocks_collapsed(3 if f == 300 else 6)
	elif f == 540:
		sector.active_weapon_index = 3
		sector._update_operative_card()
		sector.satellite_strike_timer = 0.75
		sector._fire_active_weapon_at(Vector2(640, 292))
		sector.set_tower_collapsed(true)
		sector.set_surrounding_blocks_collapsed(10)
		sector.set_banner("ACT VI // ZAIBATSU CLEARINGHOUSE PYRAMID DECAPITATED — ARCOLOGY RUBBLE")
	elif f == 960:
		# 960..1500: Final Megacity Conquest Overview Map [G]
		for d in sector._hq_screens.districts_state:
			d["owner"] = 1
		sector._hq_screens.districts_state[3]["rubble"] = true
		sector._hq_screens.districts_state[5]["rubble"] = true
		sector.syndicate_treasury = 14850
		sector._hq_screens.status_toast = "SUBJ #404 // DOCTRINE OF ATTRITION COMPLETE // ALL 6 MEGACITY DISTRICTS UNDER EUROCORP CONTROL"
		sector.set_hq_screen(1)
		sector.set_banner("FINALE // EUROCORP MEGACITY HEGEMONY — DETERMINISTIC DIGEST VERIFIED")
	elif f in [1080, 1180, 1280, 1380]:
		var did := 1 + ((f - 980) / 100) % 6
		sector.set_focus_district(did)
