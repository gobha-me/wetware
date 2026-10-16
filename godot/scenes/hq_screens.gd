extends Node
## Strategic HQ Screens for wetware (Step 2 / M9):
##   Mode 1 [G / F7]: Strategic Megacity 6-District Overview Map
##   Mode 2 [U / F8]: Ripperdoc Cyber-Surgery & Cryo-Stasis Bay
##   Mode 3 [K / F9]: R&D + Field-Salvage Reverse-Engineering Lab

enum ScreenMode {
	NONE = 0,
	MEGACITY_MAP = 1,
	RIPPERDOC_BAY = 2,
	RND_SALVAGE_LAB = 3,
}

const SYN_COLORS := {
	1: Color(0.22, 0.96, 1.0, 1.0),  # EuroCorp Cyan
	2: Color(1.0, 0.28, 0.35, 1.0),  # Zaibatsu Crimson
	3: Color(0.28, 0.98, 0.52, 1.0),  # Chiba Triad Emerald
	4: Color(1.0, 0.78, 0.22, 1.0),  # Omni-Directive Amber
}

const SYN_NAMES := {
	1: "EUROCORP SYNDICATE",
	2: "ZAIBATSU KAO",
	3: "CHIBA TRIAD",
	4: "OMNI-DIRECTIVE",
}

const SYN_SHORT := {
	1: "EUROCORP",
	2: "ZAIBATSU",
	3: "CHIBA TRIAD",
	4: "OMNI-DIRECTIVE",
}

const ORGAN_SLOT_NAMES := [
	"LEGS // MYOMER",
	"ARMS // GYRO-STAB",
	"CHEST // SUB-DERMAL",
	"EYES // THERMAL-OPTIC",
	"BRAIN // CORTICAL-MESH",
	"HEART // ADRENAL-PUMP",
]

const ORGAN_SLOT_EFFECTS := [
	"Sprint Velocity & Vertical Jump",
	"Recoil Dampening & Heavy Weapon Mount",
	"Ballistic Kinetic Absorption",
	"Thermal Wall-Penetration Sightline",
	"Persuadertron Neural-Mesh Bandwidth",
	"Overclock Strain Tolerance & BPM Cap",
]

var sector = null
var active_mode: int = ScreenMode.NONE
var selected_organ_slot: int = 0
var selected_blueprint_idx: int = 0
var status_toast: String = "HQ LINK ONLINE // SELECT DISTRICT, IMPLANT SLOT, OR R&D BLUEPRINT"

var layer: CanvasLayer = null
var draw_node: Node2D = null
var _landmark_intact_tex: Dictionary = {}
var _landmark_rubble_tex: Dictionary = {}

# Authoritative-mirrored state for interactive HQ inspection & manipulation
var districts_state: Array[Dictionary] = []
var syndicates_state: Array[Dictionary] = []
var operative_organs_tiers: Array = [
	[2, 2, 2, 3, 3, 2],
	[2, 3, 3, 2, 2, 2],
	[2, 2, 2, 3, 4, 2],
	[3, 3, 4, 2, 2, 3],
]
var operative_ipa: Array = [
	[0.82, 0.88, 0.65],
	[0.68, 0.76, 0.86],
	[0.94, 0.85, 0.58],
	[0.64, 0.72, 0.92],
]
var blueprints_state: Array[Dictionary] = []


func setup(sec: Node2D) -> void:
	sector = sec
	_init_default_state()
	_preload_landmark_textures()
	layer = CanvasLayer.new()
	layer.name = "HqScreenLayer"
	layer.layer = 12
	add_child(layer)
	draw_node = Node2D.new()
	draw_node.name = "HqScreenCanvas"
	layer.add_child(draw_node)
	draw_node.draw.connect(_draw_hq_screen)


func _preload_landmark_textures() -> void:
	var stems := {
		1: "biofoundry_tower",
		2: "broadcast_spire",
		3: "monorail_hub",
		4: "ordinance_foundry",
		5: "power_subgrid",
		6: "clearinghouse",
	}
	for did in stems:
		var s: String = stems[did]
		_landmark_intact_tex[did] = sector._load_tex("res://assets/tiles/%s_intact_albedo.png" % s)
		_landmark_rubble_tex[did] = sector._load_tex("res://assets/tiles/%s_rubble_albedo.png" % s)


func _init_default_state() -> void:
	districts_state = [
		{
			"id": 1,
			"name": "KOWLOON BIO-FOUNDRY SECTOR",
			"short": "D1 // KOWLOON",
			"organ_name": "BIO-FOUNDRY",
			"perk": "-65% CYBER-ORGAN R&D & SURGERY",
			"owner": 1,
			"revenue": 1350,
			"rubble": false,
			"pos": Vector2(185, 255),
			"adj": [2, 3, 5],
			"raid_from": 0,
		},
		{
			"id": 2,
			"name": "SHINJUKU BROADCAST SPIRE",
			"short": "D2 // SHINJUKU",
			"organ_name": "BROADCAST SPIRE",
			"perk": "+25% PERSUADERTRON MESH BANDWIDTH",
			"owner": 2,
			"revenue": 1650,
			"rubble": false,
			"pos": Vector2(470, 235),
			"adj": [1, 3, 4],
			"raid_from": 1,
		},
		{
			"id": 3,
			"name": "CHIBA MONORAIL & SUB-GRID",
			"short": "D3 // CHIBA HUB",
			"organ_name": "MONORAIL HUB",
			"perk": "INSTANT CROSS-SECTOR SQUAD TRANSIT",
			"owner": 2,
			"revenue": 1200,
			"rubble": false,
			"pos": Vector2(470, 395),
			"adj": [1, 2, 5, 6],
			"raid_from": 0,
		},
		{
			"id": 4,
			"name": "NEO-RUHR ORDINANCE FOUNDRY",
			"short": "D4 // NEO-RUHR",
			"organ_name": "ORDINANCE FOUNDRY",
			"perk": "-65% HEAVY ORDINANCE R&D & FAB",
			"owner": 2,
			"revenue": 1850,
			"rubble": false,
			"pos": Vector2(755, 255),
			"adj": [2, 6],
			"raid_from": 1,
		},
		{
			"id": 5,
			"name": "MID-LEVELS POWER SUB-GRID",
			"short": "D5 // MID-LEVELS",
			"organ_name": "POWER SUB-GRID",
			"perk": "SECTOR BLACKOUT IMMUNITY & EMP SHIELD",
			"owner": 3,
			"revenue": 1150,
			"rubble": false,
			"pos": Vector2(185, 445),
			"adj": [1, 3, 6],
			"raid_from": 2,
		},
		{
			"id": 6,
			"name": "ZAIBATSU CLEARINGHOUSE ARCOLOGY",
			"short": "D6 // CLEARINGHOUSE",
			"organ_name": "CLEARINGHOUSE",
			"perk": "+40% CORPORATE TARIFF & TAX YIELD",
			"owner": 4,
			"revenue": 1400,
			"rubble": false,
			"pos": Vector2(755, 445),
			"adj": [3, 4, 5],
			"raid_from": 3,
		},
	]

	syndicates_state = [
		{"id": 1, "name": "EUROCORP SYNDICATE", "treasury": 6000, "daily_net": 1350, "alive": 4, "thralls": 0},
		{"id": 2, "name": "ZAIBATSU KAO", "treasury": 6000, "daily_net": 4700, "alive": 4, "thralls": 0},
		{"id": 3, "name": "CHIBA TRIAD", "treasury": 5800, "daily_net": 1150, "alive": 4, "thralls": 0},
		{"id": 4, "name": "OMNI-DIRECTIVE", "treasury": 6400, "daily_net": 1400, "alive": 4, "thralls": 0},
	]

	blueprints_state = [
		{
			"id": 1,
			"name": "V3 MYOMER REFLEX LEGS",
			"category": "CYBERNETIC ORGAN",
			"organ_kind": 1, # Bio-Foundry discount
			"base_cost": 2000,
			"invested": 350,
			"daily_budget": 250,
			"unlocked": false,
			"slot": 0,
			"tier": 3,
		},
		{
			"id": 2,
			"name": "HEAVY GAUSS CANNON MK.III",
			"category": "HEAVY ORDINANCE",
			"organ_kind": 4, # Ordinance Foundry discount
			"base_cost": 2400,
			"invested": 420,
			"daily_budget": 300,
			"unlocked": false,
			"slot": 1,
			"tier": 3,
		},
		{
			"id": 3,
			"name": "V4 CORTICAL NEURAL-MESH ARRAY",
			"category": "CYBERNETIC ORGAN",
			"organ_kind": 1,
			"base_cost": 3200,
			"invested": 1120,
			"daily_budget": 350,
			"unlocked": false,
			"slot": 4,
			"tier": 4,
		},
		{
			"id": 4,
			"name": "ORBITAL SATELLITE RAIN LANCE",
			"category": "HEAVY ORDINANCE",
			"organ_kind": 4,
			"base_cost": 4000,
			"invested": 800,
			"daily_budget": 400,
			"unlocked": false,
			"slot": 1,
			"tier": 4,
		},
	]


func sync_from_snapshot(data: Dictionary) -> void:
	if data.has("syndicates") and typeof(data["syndicates"]) == TYPE_ARRAY:
		var syns: Array = data["syndicates"]
		for s_var in syns:
			var s: Dictionary = s_var
			var sid := int(s.get("id", 0))
			for local_s in syndicates_state:
				if int(local_s["id"]) == sid:
					local_s["treasury"] = int(s.get("treasury", local_s["treasury"]))
					local_s["daily_net"] = int(s.get("daily_net", local_s["daily_net"]))
					local_s["thralls"] = int(s.get("thralls_count", local_s["thralls"]))
					var alive_cnt := 0
					if s.has("squad") and typeof(s["squad"]) == TYPE_ARRAY:
						var sq: Array = s["squad"]
						for oi in range(sq.size()):
							var op: Dictionary = sq[oi]
							if bool(op.get("alive", true)):
								alive_cnt += 1
							if sid == 1 and oi < operative_organs_tiers.size() and op.has("organs"):
								var orgs: Array = op["organs"]
								for gi in range(mini(orgs.size(), 6)):
									operative_organs_tiers[oi][gi] = int(orgs[gi])
					local_s["alive"] = alive_cnt

	var bld_rubble_by_district := {}
	if data.has("buildings") and typeof(data["buildings"]) == TYPE_ARRAY:
		for b_var in data["buildings"] as Array:
			var b: Dictionary = b_var
			if bool(b.get("houses_city_organ", false)):
				bld_rubble_by_district[int(b.get("district_id", 0))] = (int(b.get("state", 0)) == 2)

	if data.has("districts") and typeof(data["districts"]) == TYPE_ARRAY:
		for d_var in data["districts"] as Array:
			var d: Dictionary = d_var
			var did := int(d.get("id", 0))
			for local_d in districts_state:
				if int(local_d["id"]) == did:
					local_d["owner"] = int(d.get("owner_syndicate", local_d["owner"]))
					local_d["revenue"] = int(d.get("daily_revenue", local_d["revenue"]))
					if bld_rubble_by_district.has(did):
						local_d["rubble"] = bool(bld_rubble_by_district[did])
	queue_redraw()


func set_mode(mode: int) -> void:
	active_mode = clampi(mode, 0, 3)
	queue_redraw()


func queue_redraw() -> void:
	if draw_node != null:
		draw_node.queue_redraw()


func has_organ_discount(organ_district_id: int) -> bool:
	for d in districts_state:
		if int(d["id"]) == organ_district_id:
			return int(d["owner"]) == 1 and not bool(d["rubble"])
	return false


func effective_cost(base_cost: int, organ_district_id: int) -> int:
	if has_organ_discount(organ_district_id):
		return int(round(float(base_cost) * 0.35))
	return base_cost


func upgrade_selected_organ() -> bool:
	var op_idx: int = sector.selected_operative
	var cur_tier: int = operative_organs_tiers[op_idx][selected_organ_slot]
	if cur_tier >= 4:
		status_toast = "IMPLANT SLOT ALREADY AT MAXIMUM TIER (V4)"
		queue_redraw()
		return false
	var base_c: int = (cur_tier) * 600
	var cost: int = effective_cost(base_c, 1)
	if sector.syndicate_treasury < cost:
		status_toast = "INSUFFICIENT CREDITS FOR V%d SURGERY (%d CR REQUIRED)" % [cur_tier + 1, cost]
		queue_redraw()
		return false
	sector.syndicate_treasury -= cost
	syndicates_state[0]["treasury"] = sector.syndicate_treasury
	operative_organs_tiers[op_idx][selected_organ_slot] = cur_tier + 1
	_sync_sector_organ_summary(op_idx)
	status_toast = "INSTALLED V%d %s ON %s (-%d CR%s)" % [
		cur_tier + 1,
		ORGAN_SLOT_NAMES[selected_organ_slot].get_slice(" ", 0),
		sector.OPERATIVE_CALLSIGNS[op_idx],
		cost,
		" // -65% BIO-FOUNDRY" if has_organ_discount(1) else "",
	]
	sector._refresh_hud()
	queue_redraw()
	return true


func thaw_cryo_replacement() -> bool:
	var cost := effective_cost(500, 1)
	if sector.syndicate_treasury < cost:
		status_toast = "INSUFFICIENT CREDITS FOR CRYO-VAT THAW (%d CR)" % cost
		queue_redraw()
		return false
	sector.syndicate_treasury -= cost
	syndicates_state[0]["treasury"] = sector.syndicate_treasury
	sector.cryo_generation += 1
	sector._rebuild_meat_puppet_roster()
	var op_node: Node2D = sector._get_selected_operative_node()
	if op_node != null:
		op_node.visible = true
	status_toast = "CRYO-STASIS VAT THAWED // NEW CORTICAL SUBJECT LINKED (-%d CR)" % cost
	sector._refresh_hud()
	queue_redraw()
	return true


func fund_selected_blueprint() -> bool:
	var bp: Dictionary = blueprints_state[selected_blueprint_idx]
	if bool(bp["unlocked"]):
		status_toast = "%s ALREADY UNLOCKED FOR MASS FABRICATION" % bp["name"]
		queue_redraw()
		return false
	var req := effective_cost(int(bp["base_cost"]), int(bp["organ_kind"]))
	var step_cost := mini(400, maxi(0, req - int(bp["invested"])))
	if sector.syndicate_treasury < step_cost or step_cost <= 0:
		status_toast = "INSUFFICIENT CREDITS FOR R&D FUNDING ALLOCATION"
		queue_redraw()
		return false
	sector.syndicate_treasury -= step_cost
	syndicates_state[0]["treasury"] = sector.syndicate_treasury
	bp["invested"] = int(bp["invested"]) + step_cost
	if int(bp["invested"]) >= req:
		bp["invested"] = req
		bp["unlocked"] = true
		status_toast = "R&D COMPLETE // %s UNLOCKED FOR SQUAD FABRICATION!" % bp["name"]
	else:
		status_toast = "ALLOCATED +%d CR TO %s (%d / %d CR)" % [step_cost, bp["name"], int(bp["invested"]), req]
	sector._refresh_hud()
	queue_redraw()
	return true


func equip_salvage_unit() -> bool:
	if sector.salvage_units <= 0:
		status_toast = "CRYO-VAULT SALVAGE EMPTY // HARVEST FALLEN RIVAL OPERATIVES IN FIELD"
		queue_redraw()
		return false
	sector.salvage_units -= 1
	var bp: Dictionary = blueprints_state[selected_blueprint_idx]
	var op_idx: int = sector.selected_operative
	var slot: int = int(bp["slot"])
	var tier: int = int(bp["tier"])
	operative_organs_tiers[op_idx][slot] = maxi(int(operative_organs_tiers[op_idx][slot]), tier)
	_sync_sector_organ_summary(op_idx)
	status_toast = "EQUIPPED FIELD-SALVAGED %s DIRECTLY ONTO %s (1 PHYSICAL UNIT CONSUMED)" % [
		bp["name"], sector.OPERATIVE_CALLSIGNS[op_idx]
	]
	sector._refresh_hud()
	queue_redraw()
	return true


func reverse_engineer_salvage_unit() -> bool:
	if sector.salvage_units <= 0:
		status_toast = "CRYO-VAULT SALVAGE EMPTY // HARVEST FALLEN RIVAL OPERATIVES IN FIELD"
		queue_redraw()
		return false
	var bp: Dictionary = blueprints_state[selected_blueprint_idx]
	if bool(bp["unlocked"]):
		status_toast = "%s ALREADY UNLOCKED" % bp["name"]
		queue_redraw()
		return false
	sector.salvage_units -= 1
	var req := effective_cost(int(bp["base_cost"]), int(bp["organ_kind"]))
	var boost := int(ceil(float(req) * 0.50))
	bp["invested"] = mini(req, int(bp["invested"]) + boost)
	if int(bp["invested"]) >= req:
		bp["unlocked"] = true
		status_toast = "REVERSE-ENGINEERING BREAKTHROUGH (+50%%) // %s UNLOCKED!" % bp["name"]
	else:
		status_toast = "SACRIFICED SALVAGE UNIT FOR +50%% R&D BREAKTHROUGH (+%d CR EQUIV ON %s)" % [boost, bp["name"]]
	sector._refresh_hud()
	queue_redraw()
	return true


func _sync_sector_organ_summary(op_idx: int) -> void:
	var t: Array = operative_organs_tiers[op_idx]
	sector.operative_organs_live[op_idx] = "V%d EYES | V%d BRAIN | V%d LEGS | V%d HEART" % [t[3], t[4], t[0], t[5]]


func handle_key_input(keycode: int) -> bool:
	if keycode == KEY_G or keycode == KEY_F7:
		set_mode(ScreenMode.NONE if active_mode == ScreenMode.MEGACITY_MAP else ScreenMode.MEGACITY_MAP)
		return true
	if keycode == KEY_U or keycode == KEY_F8:
		set_mode(ScreenMode.NONE if active_mode == ScreenMode.RIPPERDOC_BAY else ScreenMode.RIPPERDOC_BAY)
		return true
	if keycode == KEY_K or keycode == KEY_F9:
		set_mode(ScreenMode.NONE if active_mode == ScreenMode.RND_SALVAGE_LAB else ScreenMode.RND_SALVAGE_LAB)
		return true
	if keycode == KEY_ESCAPE and active_mode != ScreenMode.NONE:
		set_mode(ScreenMode.NONE)
		return true

	if active_mode == ScreenMode.NONE:
		return false

	if active_mode == ScreenMode.RIPPERDOC_BAY:
		if keycode == KEY_DOWN or keycode == KEY_S:
			selected_organ_slot = (selected_organ_slot + 1) % 6
			queue_redraw()
			return true
		if keycode == KEY_UP or keycode == KEY_W:
			selected_organ_slot = (selected_organ_slot + 5) % 6
			queue_redraw()
			return true
		if keycode == KEY_E or keycode == KEY_ENTER:
			upgrade_selected_organ()
			return true
		if keycode == KEY_N:
			thaw_cryo_replacement()
			return true

	elif active_mode == ScreenMode.RND_SALVAGE_LAB:
		if keycode == KEY_DOWN or keycode == KEY_S:
			selected_blueprint_idx = (selected_blueprint_idx + 1) % blueprints_state.size()
			queue_redraw()
			return true
		if keycode == KEY_UP or keycode == KEY_W:
			selected_blueprint_idx = (selected_blueprint_idx + blueprints_state.size() - 1) % blueprints_state.size()
			queue_redraw()
			return true
		if keycode == KEY_J or keycode == KEY_ENTER:
			fund_selected_blueprint()
			return true
		if keycode == KEY_X:
			equip_salvage_unit()
			return true
		if keycode == KEY_B:
			reverse_engineer_salvage_unit()
			return true

	return false


func _draw_hq_screen() -> void:
	if active_mode == ScreenMode.NONE or sector == null:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return

	# Full-screen translucent tactical command table backdrop
	draw_node.draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.05, 0.90), true)
	var frame := Rect2(24, 48, 1232, 652)
	draw_node.draw_rect(frame, Color(0.03, 0.06, 0.11, 0.96), true)
	draw_node.draw_rect(frame, Color(0.22, 0.88, 1.0, 0.92), false, 2.0)
	sector._draw_corner_brackets(draw_node, frame, Color(0.28, 0.96, 1.0, 1.0), 18.0, 2.6)

	# HQ Mode Tab Bar
	var tabs := [
		["[G] STRATEGIC MEGACITY 6-DISTRICT MAP", ScreenMode.MEGACITY_MAP],
		["[U] RIPPERDOC CYBER-SURGERY & CRYO BAY", ScreenMode.RIPPERDOC_BAY],
		["[K] 3-PATH R&D & SALVAGE LAB", ScreenMode.RND_SALVAGE_LAB],
		["[ESC] RETURN TO TACTICAL SECTOR", ScreenMode.NONE],
	]
	for i in range(tabs.size()):
		var tr := Rect2(40 + i * 302, 58, 292, 32)
		var is_cur := (active_mode == int(tabs[i][1]))
		var bg := Color(0.08, 0.34, 0.46, 0.96) if is_cur else Color(0.04, 0.09, 0.15, 0.92)
		var bd := Color(0.25, 0.98, 1.0, 1.0) if is_cur else Color(0.22, 0.50, 0.62, 0.75)
		draw_node.draw_rect(tr, bg, true)
		draw_node.draw_rect(tr, bd, false, 1.8 if is_cur else 1.0)
		draw_node.draw_string(font, Vector2(tr.position.x + 10, tr.position.y + 21), String(tabs[i][0]), HORIZONTAL_ALIGNMENT_LEFT, 276, 11, bd)

	if active_mode == ScreenMode.MEGACITY_MAP:
		_draw_megacity_map(font)
	elif active_mode == ScreenMode.RIPPERDOC_BAY:
		_draw_ripperdoc_bay(font)
	elif active_mode == ScreenMode.RND_SALVAGE_LAB:
		_draw_rnd_salvage_lab(font)

	# Bottom Status Toast & Control Strip
	var footer := Rect2(40, 654, 1200, 34)
	draw_node.draw_rect(footer, Color(0.02, 0.04, 0.08, 0.95), true)
	draw_node.draw_rect(footer, Color(0.22, 0.78, 0.92, 0.85), false, 1.2)
	draw_node.draw_string(font, Vector2(54, 676), status_toast, HORIZONTAL_ALIGNMENT_LEFT, 1170, 12, Color(0.98, 0.86, 0.28, 1.0))


func _draw_megacity_map(font: Font) -> void:
	# 1. 4-Syndicate Persistent Megacity War Ledger Strip
	for i in range(syndicates_state.size()):
		var syn: Dictionary = syndicates_state[i]
		var sid := int(syn["id"])
		var col: Color = SYN_COLORS.get(sid, Color.WHITE)
		var sbox := Rect2(40 + i * 302, 98, 292, 54)
		draw_node.draw_rect(sbox, Color(0.02, 0.05, 0.09, 0.95), true)
		draw_node.draw_rect(sbox, col, false, 1.6)
		var owned_cnt := 0
		for d in districts_state:
			if int(d["owner"]) == sid:
				owned_cnt += 1
		var treasury_val: int = sector.syndicate_treasury if sid == 1 else int(syn["treasury"])
		draw_node.draw_string(font, Vector2(sbox.position.x + 10, sbox.position.y + 19), "%s" % syn["name"], HORIZONTAL_ALIGNMENT_LEFT, 274, 12, col)
		draw_node.draw_string(font, Vector2(sbox.position.x + 10, sbox.position.y + 36), "TREASURY: %d CR (%+d/DAY)" % [treasury_val, int(syn["daily_net"])], HORIZONTAL_ALIGNMENT_LEFT, 274, 10, Color(0.90, 0.95, 1.0))
		draw_node.draw_string(font, Vector2(sbox.position.x + 10, sbox.position.y + 49), "DISTRICTS: %d/6 | SQUAD ALIVE: %d/4" % [owned_cnt, int(syn["alive"])], HORIZONTAL_ALIGNMENT_LEFT, 274, 10, Color(0.72, 0.84, 0.92))

	# 2. Holographic Megacity Transit & Power Grid Links
	var map_area := Rect2(40, 160, 860, 484)
	draw_node.draw_rect(map_area, Color(0.015, 0.03, 0.06, 0.95), true)
	draw_node.draw_rect(map_area, Color(0.16, 0.48, 0.62, 0.75), false, 1.2)
	for gx in range(1, 14):
		var x := map_area.position.x + gx * 62.0
		draw_node.draw_line(Vector2(x, map_area.position.y), Vector2(x, map_area.end.y), Color(0.10, 0.24, 0.34, 0.35), 1.0)
	for gy in range(1, 8):
		var y := map_area.position.y + gy * 62.0
		draw_node.draw_line(Vector2(map_area.position.x, y), Vector2(map_area.end.x, y), Color(0.10, 0.24, 0.34, 0.35), 1.0)

	var pos_by_id := {}
	for d in districts_state:
		pos_by_id[int(d["id"])] = d["pos"]

	for d in districts_state:
		var did := int(d["id"])
		var p1: Vector2 = d["pos"]
		for nb in d["adj"]:
			var nbid := int(nb)
			if nbid > did and pos_by_id.has(nbid):
				var p2: Vector2 = pos_by_id[nbid]
				draw_node.draw_line(p1, p2, Color(0.22, 0.68, 0.85, 0.55), 2.2)
		var raid_src := int(d["raid_from"])
		if raid_src > 0 and pos_by_id.has(raid_src):
			var rp: Vector2 = pos_by_id[raid_src]
			var mid := rp.lerp(p1, 0.52)
			draw_node.draw_line(rp, p1, Color(1.0, 0.36, 0.28, 0.85), 2.8)
			draw_node.draw_circle(mid, 5.0, Color(1.0, 0.82, 0.22, 0.95))

	# 3. 6 Interactive District Nodes with Live Landmark Previews
	for d in districts_state:
		var did := int(d["id"])
		var p: Vector2 = d["pos"]
		var owner := int(d["owner"])
		var ocol: Color = SYN_COLORS.get(owner, Color.WHITE)
		var is_focus: bool = (int(sector.focus_district_id) == did)
		var is_rubble: bool = bool(d["rubble"]) or (is_focus and bool(sector.tower_collapsed))
		var card := Rect2(p.x - 122, p.y - 58, 244, 116)
		draw_node.draw_rect(card, Color(0.03, 0.07, 0.13, 0.95) if is_focus else Color(0.02, 0.04, 0.08, 0.92), true)
		draw_node.draw_rect(card, Color(0.98, 0.92, 0.32, 1.0) if is_focus else ocol, false, 2.6 if is_focus else 1.6)

		var tex: Texture2D = _landmark_rubble_tex.get(did) if is_rubble else _landmark_intact_tex.get(did)
		if tex != null:
			draw_node.draw_texture_rect(tex, Rect2(card.position.x + 6, card.position.y + 18, 72, 82), false)

		var tx := card.position.x + 82
		draw_node.draw_string(font, Vector2(tx, card.position.y + 18), "[F%d] %s" % [did, d["short"]], HORIZONTAL_ALIGNMENT_LEFT, 156, 11, ocol)
		draw_node.draw_string(font, Vector2(tx, card.position.y + 34), "OWNER: %s" % SYN_SHORT.get(owner, "?"), HORIZONTAL_ALIGNMENT_LEFT, 156, 10, Color(0.92, 0.96, 1.0))
		var st_col := Color(1.0, 0.38, 0.24) if is_rubble else Color(0.25, 0.96, 0.65)
		draw_node.draw_string(font, Vector2(tx, card.position.y + 50), "%s: %s" % [d["organ_name"], "RUBBLE" if is_rubble else "INTACT"], HORIZONTAL_ALIGNMENT_LEFT, 156, 10, st_col)
		var rev := 0 if is_rubble else int(d["revenue"])
		draw_node.draw_string(font, Vector2(tx, card.position.y + 66), "YIELD: +%d CR/DAY" % rev, HORIZONTAL_ALIGNMENT_LEFT, 156, 10, Color(0.98, 0.84, 0.28))
		draw_node.draw_string(font, Vector2(tx, card.position.y + 82), String(d["perk"]).substr(0, 24), HORIZONTAL_ALIGNMENT_LEFT, 156, 9, Color(0.68, 0.86, 0.96))
		if is_focus:
			draw_node.draw_string(font, Vector2(tx, card.position.y + 100), ">> SQUAD DEPLOYED <<", HORIZONTAL_ALIGNMENT_LEFT, 156, 10, Color(0.25, 0.98, 1.0))

	# 4. Right-Side Selected District Strategic Dossier
	var d_sel: Dictionary = districts_state[clampi(int(sector.focus_district_id) - 1, 0, 5)]
	var rpanel := Rect2(912, 160, 328, 484)
	draw_node.draw_rect(rpanel, Color(0.02, 0.05, 0.09, 0.96), true)
	draw_node.draw_rect(rpanel, Color(0.22, 0.85, 1.0, 0.90), false, 1.6)
	var d_id := int(d_sel["id"])
	var d_rubble: bool = bool(d_sel["rubble"]) or bool(sector.tower_collapsed)
	var big_tex: Texture2D = _landmark_rubble_tex.get(d_id) if d_rubble else _landmark_intact_tex.get(d_id)
	if big_tex != null:
		draw_node.draw_texture_rect(big_tex, Rect2(996, 174, 160, 180), false)
	draw_node.draw_string(font, Vector2(928, 376), String(d_sel["name"]), HORIZONTAL_ALIGNMENT_LEFT, 296, 13, Color(0.25, 0.96, 1.0))
	draw_node.draw_string(font, Vector2(928, 398), "CITY ORGAN: %s (%s)" % [d_sel["organ_name"], "RUBBLE CRATER" if d_rubble else "OPERATIONAL"], HORIZONTAL_ALIGNMENT_LEFT, 296, 11, Color(0.95, 0.85, 0.30))
	draw_node.draw_multiline_string(font, Vector2(928, 420), "STRATEGIC PERK:\n  %s" % d_sel["perk"], HORIZONTAL_ALIGNMENT_LEFT, 296, 11, -1, Color(0.82, 0.94, 1.0))
	draw_node.draw_multiline_string(font, Vector2(928, 464), "CONTROLLING SYNDICATE:\n  %s" % SYN_NAMES.get(int(d_sel["owner"]), "CONTESTED"), HORIZONTAL_ALIGNMENT_LEFT, 296, 11, -1, SYN_COLORS.get(int(d_sel["owner"]), Color.WHITE))
	draw_node.draw_multiline_string(font, Vector2(928, 512), "SECTOR COMMANDS:\n  [F1-F6] Deploy Squad to District 1-6\n  [C] Toggle Landmark Structural Collapse\n  [U] Open Ripperdoc Cyber-Surgery Bay\n  [K] Open 3-Path R&D & Salvage Lab\n  [G / ESC] Return to Live Tactical View", HORIZONTAL_ALIGNMENT_LEFT, 296, 11, -1, Color(0.72, 0.88, 0.96))


func _draw_ripperdoc_bay(font: Font) -> void:
	var op_idx: int = sector.selected_operative
	var ident: Dictionary = sector._puppet_identities[op_idx]
	# Left Panel: 4-Operative Roster & Cryo-Stasis Replacement Vat
	var lpanel := Rect2(40, 102, 330, 540)
	draw_node.draw_rect(lpanel, Color(0.02, 0.05, 0.09, 0.95), true)
	draw_node.draw_rect(lpanel, Color(0.22, 0.82, 0.96, 0.88), false, 1.5)
	draw_node.draw_string(font, Vector2(54, 126), "SQUAD CORTICAL SUBJECT ROSTER [TAB]", HORIZONTAL_ALIGNMENT_LEFT, 300, 12, Color(0.25, 0.96, 1.0))

	for i in range(4):
		var rbox := Rect2(54, 138 + i * 82, 302, 74)
		var is_sel := (i == op_idx)
		draw_node.draw_rect(rbox, Color(0.07, 0.22, 0.30, 0.95) if is_sel else Color(0.03, 0.07, 0.12, 0.90), true)
		draw_node.draw_rect(rbox, Color(0.28, 0.98, 1.0, 1.0) if is_sel else Color(0.20, 0.45, 0.58, 0.75), false, 2.0 if is_sel else 1.0)
		if i < sector._portraits.size() and sector._portraits[i] != null:
			draw_node.draw_texture_rect(sector._portraits[i], Rect2(rbox.position.x + 6, rbox.position.y + 6, 62, 62), false)
		var id_i: Dictionary = sector._puppet_identities[i]
		draw_node.draw_string(font, Vector2(rbox.position.x + 76, rbox.position.y + 22), String(id_i["unit_code"]), HORIZONTAL_ALIGNMENT_LEFT, 218, 11, Color(0.25, 0.96, 1.0))
		draw_node.draw_string(font, Vector2(rbox.position.x + 76, rbox.position.y + 40), String(id_i["subj_line"]), HORIZONTAL_ALIGNMENT_LEFT, 218, 10, Color(0.88, 0.94, 1.0))
		draw_node.draw_string(font, Vector2(rbox.position.x + 76, rbox.position.y + 58), "CORTICAL LINK: %s // NO FREE WILL" % id_i["link_str"], HORIZONTAL_ALIGNMENT_LEFT, 218, 10, Color(0.28, 0.95, 0.62))

	var cryo_box := Rect2(54, 476, 302, 150)
	draw_node.draw_rect(cryo_box, Color(0.03, 0.10, 0.16, 0.95), true)
	draw_node.draw_rect(cryo_box, Color(0.25, 0.96, 0.72, 0.92), false, 1.6)
	draw_node.draw_string(font, Vector2(68, 500), "CRYO-STASIS REPLACEMENT VAT", HORIZONTAL_ALIGNMENT_LEFT, 276, 12, Color(0.25, 0.98, 0.72))
	draw_node.draw_multiline_string(font, Vector2(68, 522), "CRYO BATCH GEN: #%d\nTHAW COST: %d CR (-65%% BIO-FOUNDRY)\nTransfers salvaged V1-V4 chrome into\na mind-wiped replacement meat-puppet." % [
		sector.cryo_generation, effective_cost(500, 1)
	], HORIZONTAL_ALIGNMENT_LEFT, 276, 10, -1, Color(0.82, 0.94, 1.0))
	var thaw_btn := Rect2(68, 590, 274, 26)
	draw_node.draw_rect(thaw_btn, Color(0.08, 0.36, 0.28, 0.95), true)
	draw_node.draw_rect(thaw_btn, Color(0.28, 0.98, 0.72, 1.0), false, 1.4)
	draw_node.draw_string(font, Vector2(80, 608), "[N] THAW REPLACEMENT SUBJECT (-%d CR)" % effective_cost(500, 1), HORIZONTAL_ALIGNMENT_LEFT, 256, 10, Color(0.95, 1.0, 0.95))

	# Center Panel: 6-Slot Cybernetic Organ Surgical Matrix (V1-V4)
	var cpanel := Rect2(384, 102, 500, 540)
	draw_node.draw_rect(cpanel, Color(0.02, 0.05, 0.09, 0.95), true)
	draw_node.draw_rect(cpanel, Color(0.22, 0.82, 0.96, 0.88), false, 1.5)
	var disc_str := "BIO-FOUNDRY ONLINE (-65% COST)" if has_organ_discount(1) else "STANDARD SURGICAL RATE"
	draw_node.draw_string(font, Vector2(400, 126), "6-SLOT CYBER-ORGAN MATRIX // %s" % disc_str, HORIZONTAL_ALIGNMENT_LEFT, 470, 12, Color(0.25, 0.96, 1.0))

	var tiers: Array = operative_organs_tiers[op_idx]
	for s in range(6):
		var sbox := Rect2(400, 140 + s * 72, 468, 64)
		var is_sel_s := (s == selected_organ_slot)
		var tier_val := int(tiers[s])
		draw_node.draw_rect(sbox, Color(0.07, 0.20, 0.28, 0.95) if is_sel_s else Color(0.03, 0.07, 0.12, 0.90), true)
		draw_node.draw_rect(sbox, Color(0.98, 0.84, 0.28, 1.0) if is_sel_s else Color(0.22, 0.52, 0.66, 0.80), false, 2.0 if is_sel_s else 1.2)
		draw_node.draw_string(font, Vector2(414, sbox.position.y + 20), "%s" % ORGAN_SLOT_NAMES[s], HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color(0.25, 0.96, 1.0))
		draw_node.draw_string(font, Vector2(414, sbox.position.y + 38), ORGAN_SLOT_EFFECTS[s], HORIZONTAL_ALIGNMENT_LEFT, 290, 10, Color(0.76, 0.88, 0.96))
		var up_cost := effective_cost(tier_val * 600, 1)
		var cost_label := "MAX TIER V4" if tier_val >= 4 else ("[E] UPGRADE -> V%d (%d CR)" % [tier_val + 1, up_cost])
		draw_node.draw_string(font, Vector2(414, sbox.position.y + 55), cost_label, HORIZONTAL_ALIGNMENT_LEFT, 280, 10, Color(0.98, 0.84, 0.28))

		# V1..V4 tier pips
		for t_idx in range(1, 5):
			var pip := Rect2(708 + (t_idx - 1) * 38, sbox.position.y + 18, 32, 28)
			var active_t := (t_idx <= tier_val)
			var pcol := Color(0.22, 0.95, 0.65, 0.95) if active_t else Color(0.08, 0.14, 0.20, 0.90)
			draw_node.draw_rect(pip, pcol, true)
			draw_node.draw_rect(pip, Color(0.85, 0.98, 1.0, 0.95), false, 1.2)
			draw_node.draw_string(font, Vector2(pip.position.x + 7, pip.position.y + 19), "V%d" % t_idx, HORIZONTAL_ALIGNMENT_LEFT, 24, 11, Color(0.02, 0.04, 0.08) if active_t else Color(0.55, 0.70, 0.80))

	# Right Panel: Live I / P / A Biochem Telemetry & Cardiac Strain Thresholds
	var rpanel := Rect2(898, 102, 342, 540)
	draw_node.draw_rect(rpanel, Color(0.02, 0.05, 0.09, 0.95), true)
	draw_node.draw_rect(rpanel, Color(0.22, 0.82, 0.96, 0.88), false, 1.5)
	draw_node.draw_string(font, Vector2(914, 126), "BIOCHEM I/P/A & CARDIAC TELEMETRY", HORIZONTAL_ALIGNMENT_LEFT, 310, 12, Color(0.25, 0.96, 1.0))
	draw_node.draw_string(font, Vector2(914, 148), "%s // %s" % [ident["unit_code"], ident["subj_line"]], HORIZONTAL_ALIGNMENT_LEFT, 310, 11, Color(0.95, 0.85, 0.30))

	var ipa: Array = operative_ipa[op_idx]
	var ipa_specs := [
		["INTELLIGENCE (I) // NEURAL MESH", float(ipa[0]), Color(0.22, 0.92, 1.0), "Auto-aim stabilization & Persuadertron bandwidth"],
		["PERCEPTION (P) // THERMAL SIGHT", float(ipa[1]), Color(0.98, 0.78, 0.22), "Cross-stratum sightline & X-Ray wall penetration"],
		["ADRENALINE (A) // REFLEX SURGE", float(ipa[2]) if not sector.overclock_active else 0.98, Color(1.0, 0.28, 0.42), "0.25x tactical time dilation & fire-rate surge"],
	]
	for idx in range(3):
		var spec: Array = ipa_specs[idx]
		var by := 174 + idx * 84
		var val := float(spec[1])
		var bcol: Color = spec[2]
		draw_node.draw_string(font, Vector2(914, by), "%s: %d%%" % [spec[0], int(round(val * 100.0))], HORIZONTAL_ALIGNMENT_LEFT, 310, 11, bcol)
		var bar_bg := Rect2(914, by + 10, 310, 16)
		draw_node.draw_rect(bar_bg, Color(0.05, 0.09, 0.14, 0.95), true)
		draw_node.draw_rect(Rect2(914, by + 10, 310.0 * val, 16), bcol, true)
		draw_node.draw_rect(bar_bg, Color(0.45, 0.75, 0.88, 0.85), false, 1.2)
		draw_node.draw_string(font, Vector2(914, by + 42), String(spec[3]), HORIZONTAL_ALIGNMENT_LEFT, 310, 10, Color(0.75, 0.88, 0.96))

	var heart_tier: int = int(tiers[5])
	var strain_cap: int = 160 + heart_tier * 20
	var cur_bpm: int = 168 if sector.overclock_active else (88 + op_idx * 6)
	var cbox := Rect2(914, 434, 310, 190)
	draw_node.draw_rect(cbox, Color(0.04, 0.07, 0.12, 0.95), true)
	draw_node.draw_rect(cbox, Color(1.0, 0.35, 0.45, 0.90), false, 1.5)
	draw_node.draw_string(font, Vector2(928, 458), "CARDIAC STRAIN & OVERCLOCK MONITOR", HORIZONTAL_ALIGNMENT_LEFT, 284, 11, Color(1.0, 0.38, 0.48))
	draw_node.draw_multiline_string(font, Vector2(928, 482), "HEART IMPLANT: V%d ADRENAL-PUMP\nLIVE HEART RATE: %d BPM (CAP: %d BPM)\nOVERCLOCK STATE: %s\nTREASURY AVAILABLE: %d CR\n\nCONTROLS:\n  [W/S] Select Organ Slot | [E] Upgrade\n  [TAB] Cycle Operative   | [N] Cryo-Thaw" % [
		heart_tier,
		cur_bpm,
		strain_cap,
		"SURGE 0.25x" if sector.overclock_active else "NOMINAL 1.0x",
		sector.syndicate_treasury,
	], HORIZONTAL_ALIGNMENT_LEFT, 284, 10, -1, Color(0.86, 0.94, 1.0))


func _draw_rnd_salvage_lab(font: Font) -> void:
	# Path 1 (Left+Center): In-House HQ R&D Queue & Blueprints
	var lpanel := Rect2(40, 102, 760, 540)
	draw_node.draw_rect(lpanel, Color(0.02, 0.05, 0.09, 0.95), true)
	draw_node.draw_rect(lpanel, Color(0.22, 0.82, 0.96, 0.88), false, 1.5)
	draw_node.draw_string(font, Vector2(56, 126), "SYMMETRIC 3-PATH TECH PROGRESSION // PATH 1: HQ R&D QUEUE", HORIZONTAL_ALIGNMENT_LEFT, 720, 12, Color(0.25, 0.96, 1.0))

	for i in range(blueprints_state.size()):
		var bp: Dictionary = blueprints_state[i]
		var is_sel := (i == selected_blueprint_idx)
		var card := Rect2(56, 142 + i * 116, 728, 104)
		draw_node.draw_rect(card, Color(0.06, 0.18, 0.26, 0.95) if is_sel else Color(0.03, 0.07, 0.12, 0.92), true)
		draw_node.draw_rect(card, Color(0.98, 0.84, 0.28, 1.0) if is_sel else Color(0.22, 0.55, 0.70, 0.80), false, 2.2 if is_sel else 1.2)

		var organ_did := int(bp["organ_kind"])
		var has_disc := has_organ_discount(organ_did)
		var req := effective_cost(int(bp["base_cost"]), organ_did)
		var inv := mini(req, int(bp["invested"]))
		var pct := int(round(float(inv) / float(maxi(1, req)) * 100.0))
		var status_str := "UNLOCKED // MASS FABRICATION READY" if bool(bp["unlocked"]) else ("PROGRESS: %d / %d CR (%d%%)" % [inv, req, pct])

		draw_node.draw_string(font, Vector2(72, card.position.y + 22), "%s [%s]" % [bp["name"], bp["category"]], HORIZONTAL_ALIGNMENT_LEFT, 480, 13, Color(0.25, 0.96, 1.0))
		var disc_badge := "-65% CITY ORGAN DISCOUNT ACTIVE" if has_disc else "NO ORGAN DISCOUNT (CAPTURE DISTRICT %d)" % organ_did
		var dcol := Color(0.25, 0.98, 0.65) if has_disc else Color(1.0, 0.62, 0.28)
		draw_node.draw_string(font, Vector2(72, card.position.y + 42), disc_badge, HORIZONTAL_ALIGNMENT_LEFT, 460, 10, dcol)
		draw_node.draw_string(font, Vector2(72, card.position.y + 60), status_str, HORIZONTAL_ALIGNMENT_LEFT, 460, 11, Color(0.95, 0.96, 1.0))

		# Progress Bar
		var pbg := Rect2(72, card.position.y + 70, 692, 18)
		draw_node.draw_rect(pbg, Color(0.04, 0.08, 0.13, 0.95), true)
		var fill_w := 692.0 * clampf(float(inv) / float(maxi(1, req)), 0.0, 1.0)
		draw_node.draw_rect(Rect2(72, card.position.y + 70, fill_w, 18), Color(0.25, 0.96, 0.65) if bool(bp["unlocked"]) else Color(0.22, 0.88, 1.0), true)
		draw_node.draw_rect(pbg, Color(0.45, 0.78, 0.92, 0.85), false, 1.2)

	# Path 2 & Path 3 (Right Column): City Organ Accelerators + Cryo-Vault Field Salvage
	var rpanel := Rect2(814, 102, 426, 540)
	draw_node.draw_rect(rpanel, Color(0.02, 0.05, 0.09, 0.95), true)
	draw_node.draw_rect(rpanel, Color(0.22, 0.82, 0.96, 0.88), false, 1.5)

	draw_node.draw_string(font, Vector2(830, 126), "PATH 2 // CITY ORGAN R&D ACCELERATORS", HORIZONTAL_ALIGNMENT_LEFT, 394, 12, Color(0.25, 0.96, 1.0))
	var bf_ok := has_organ_discount(1)
	var of_ok := has_organ_discount(4)
	var p2_box := Rect2(830, 138, 394, 118)
	draw_node.draw_rect(p2_box, Color(0.03, 0.08, 0.14, 0.95), true)
	draw_node.draw_rect(p2_box, Color(0.25, 0.85, 0.96, 0.80), false, 1.2)
	draw_node.draw_multiline_string(font, Vector2(842, 160), "D1 KOWLOON BIO-FOUNDRY:\n  %s" % ("ONLINE -> -65% CYBER-ORGAN R&D & FAB" if bf_ok else "OFFLINE / RUBBLE (0% DISCOUNT)"), HORIZONTAL_ALIGNMENT_LEFT, 372, 10, -1, Color(0.28, 0.98, 0.65) if bf_ok else Color(1.0, 0.42, 0.32))
	draw_node.draw_multiline_string(font, Vector2(842, 204), "D4 NEO-RUHR ORDINANCE FOUNDRY:\n  %s" % ("ONLINE -> -65% HEAVY ORDINANCE R&D" if of_ok else "ZAIBATSU CONTROLLED (CAPTURE D4 FOR -65%)"), HORIZONTAL_ALIGNMENT_LEFT, 372, 10, -1, Color(0.28, 0.98, 0.65) if of_ok else Color(1.0, 0.72, 0.28))

	draw_node.draw_string(font, Vector2(830, 284), "PATH 3 // CRYO-VAULT FIELD SALVAGE", HORIZONTAL_ALIGNMENT_LEFT, 394, 12, Color(0.25, 0.98, 0.72))
	var p3_box := Rect2(830, 296, 394, 328)
	draw_node.draw_rect(p3_box, Color(0.03, 0.09, 0.14, 0.95), true)
	draw_node.draw_rect(p3_box, Color(0.25, 0.98, 0.72, 0.90), false, 1.6)
	draw_node.draw_string(font, Vector2(844, 322), "PHYSICAL SALVAGE UNITS IN VAULT: %d" % sector.salvage_units, HORIZONTAL_ALIGNMENT_LEFT, 368, 13, Color(0.98, 0.86, 0.28))
	draw_node.draw_multiline_string(font, Vector2(844, 348), "Harvested from fallen rival operatives in\ntactical sectors. Each physical unit can be:\n  1. Equipped immediately on 1 operative\n  2. Sacrificed in the centrifuge for a\n     +50% R&D reverse-engineering jump.", HORIZONTAL_ALIGNMENT_LEFT, 368, 10, -1, Color(0.82, 0.94, 1.0))

	var btn_j := Rect2(844, 448, 366, 36)
	draw_node.draw_rect(btn_j, Color(0.06, 0.26, 0.38, 0.95), true)
	draw_node.draw_rect(btn_j, Color(0.25, 0.96, 1.0, 1.0), false, 1.5)
	draw_node.draw_string(font, Vector2(856, 470), "[J] ALLOCATE +400 CR IN-HOUSE R&D FUNDING", HORIZONTAL_ALIGNMENT_LEFT, 346, 11, Color(0.95, 1.0, 1.0))

	var btn_x := Rect2(844, 496, 366, 36)
	draw_node.draw_rect(btn_x, Color(0.06, 0.30, 0.24, 0.95), true)
	draw_node.draw_rect(btn_x, Color(0.28, 0.98, 0.68, 1.0), false, 1.5)
	draw_node.draw_string(font, Vector2(856, 518), "[X] EQUIP SALVAGE UNIT ON %s" % sector.OPERATIVE_CALLSIGNS[sector.selected_operative], HORIZONTAL_ALIGNMENT_LEFT, 346, 11, Color(0.95, 1.0, 0.95))

	var btn_b := Rect2(844, 544, 366, 36)
	draw_node.draw_rect(btn_b, Color(0.28, 0.16, 0.06, 0.95), true)
	draw_node.draw_rect(btn_b, Color(0.98, 0.80, 0.24, 1.0), false, 1.5)
	draw_node.draw_string(font, Vector2(856, 566), "[B] SACRIFICE SALVAGE FOR +50% R&D BREAKTHROUGH", HORIZONTAL_ALIGNMENT_LEFT, 346, 11, Color(1.0, 0.95, 0.85))

	draw_node.draw_string(font, Vector2(844, 606), "TREASURY: %d CR | [W/S] Select Blueprint" % sector.syndicate_treasury, HORIZONTAL_ALIGNMENT_LEFT, 366, 11, Color(0.75, 0.90, 1.0))
