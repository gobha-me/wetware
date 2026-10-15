extends Node
## Snapshot replay for the C++23 simulation (schema 2).
##
## Everything rendered here comes from a `wetware_cli --scenario <name>`
## snapshot: operative positions, strata, health, deaths, thralls, corpse
## drops, building states and the authoritative `events` log. The replay
## rewinds the final state through the event log to recover the opening
## state, then plays the events forward with VFX. Nothing is staged; if the
## simulation did not record it, it is not drawn.

const SYN_COLORS := {
	1: Color(0.22, 0.96, 1.0, 1.0),  # EuroCorp cyan
	2: Color(1.0, 0.28, 0.35, 1.0),  # Zaibatsu crimson
	3: Color(0.28, 0.98, 0.52, 1.0),  # Chiba Triad emerald
	4: Color(1.0, 0.78, 0.22, 1.0),  # Omni-Directive amber
}
const SYN_TINTS := {
	1: Vector3(0.22, 0.96, 1.0),
	2: Vector3(1.0, 0.22, 0.28),
	3: Vector3(0.25, 0.96, 0.45),
	4: Vector3(1.0, 0.75, 0.18),
}
const SYN_SHORT := {1: "EUROCORP", 2: "ZAIBATSU", 3: "TRIAD", 4: "OMNI"}
const WEAPON_COLORS := {
	1: Color(0.35, 0.85, 1.0, 1.0),  # Gauss
	2: Color(1.0, 0.85, 0.30, 1.0),  # Minigun
	4: Color(1.0, 0.45, 0.95, 1.0),  # Plasma
	5: Color(1.0, 0.55, 0.16, 1.0),  # Satellite Rain
}
const KIND_DURATION := {
	"operative_deployed": 0.30,
	"persuaded": 0.12,
	"shot_fired": 0.45,
	"operative_hit": 0.55,
	"shield_intercept": 0.70,
	"operative_killed": 0.80,
	"orbital_strike": 1.10,
	"slab_breach": 0.70,
	"fall_damage": 0.90,
	"cardiac_flatline": 1.10,
	"rival_hijacked": 0.90,
	"salvage_extracted": 0.90,
	"cryo_thaw": 0.90,
	"building_collapsed": 1.20,
	"district_captured": 1.20,
}

var sector = null  # vertical_slice.gd instance (dynamic access)
var snap: Dictionary = {}
var focus := 0
var focus_name := ""
var focus_organ := 0
var focus_organ_building := 0

var actors := {}  # "syn:id" -> Dictionary
var building_state := {}  # id -> int
var all_events: Array = []
var cursor := 0
var timer := 0.6
var finished := false

var thrall_ring := 0
var ring_center_key := "1:103"
var breach_cells: Array = []  # Vector3(x, y, stratum)
var corpses := {}  # "syn:id" -> {pos: Vector3, extracted: bool}

var vfx: Array = []
var popups: Array = []
var layer: CanvasLayer = null
var draw_node: Node2D = null


func begin(sec: Node2D, data: Dictionary) -> bool:
	sector = sec
	snap = data
	focus = int(data.get("focus_district_id", 0))
	for d in data["districts"]:
		if int(d["id"]) == focus:
			focus_name = String(d["name"])
			focus_organ = int(d["organ"])
	for b in data["buildings"]:
		building_state[int(b["id"])] = int(b["state"])
		if int(b["district_id"]) == focus and bool(b["houses_city_organ"]):
			focus_organ_building = int(b["id"])

	sector.apply_snapshot(data)
	_build_final_actor_state(data)
	all_events = data["events"]
	_rewind_to_opening()
	_create_nodes()
	_sync_all_nodes()
	_sync_focus_building()
	_hide_kowloon_props()
	_set_sector_labels()
	_frame_camera()

	layer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	draw_node = Node2D.new()
	layer.add_child(draw_node)
	draw_node.draw.connect(_draw_replay)
	_update_banner("OPENING STATE")
	return true


func _key(syn: int, op_id: int) -> String:
	return "%d:%d" % [syn, op_id]


func _build_final_actor_state(data: Dictionary) -> void:
	for syn in data["syndicates"]:
		var syn_id := int(syn["id"])
		var squad: Array = syn["squad"]
		for i in range(squad.size()):
			var op: Dictionary = squad[i]
			actors[_key(syn_id, int(op["id"]))] = {
				"syn": syn_id,
				"id": int(op["id"]),
				"idx": i,
				"callsign": String(op["callsign"]),
				"pos": Vector3(int(op["grid_x"]), int(op["grid_y"]), int(op["stratum"])),
				"district": int(op["district_id"]),
				"alive": bool(op["alive"]),
				"health": int(op["health"]),
				"hijacked": false,
				"node": null,
			}
	var player_thralls := 0
	for syn in data["syndicates"]:
		if int(syn["id"]) == 1:
			for t in syn["thralls"]:
				if int(t["district_id"]) == focus and int(t["directive"]) == 0:
					player_thralls += 1
	thrall_ring = player_thralls


func _coord(c: Dictionary) -> Vector3:
	return Vector3(int(c["x"]), int(c["y"]), int(c["stratum"]))


func _rewind_to_opening() -> void:
	for i in range(all_events.size() - 1, -1, -1):
		var ev: Dictionary = all_events[i]
		var kind := String(ev["kind"])
		var a: Variant = actors.get(_key(int(ev["syndicate_id"]), int(ev["actor_id"])))
		match kind:
			"operative_deployed":
				if a != null:
					a["pos"] = _coord(ev["from"])
					a["district"] = int(ev["value"])
			"fall_damage":
				if a != null:
					a["pos"] = _coord(ev["from"])
					a["health"] = int(a["health"]) + int(ev["value"])
			"operative_hit":
				if a != null:
					a["health"] = int(a["health"]) + int(ev["value"])
			"operative_killed", "cardiac_flatline":
				if a != null:
					a["alive"] = true
			"rival_hijacked":
				var v: Variant = actors.get(_key(int(ev["value"]), int(ev["target_id"])))
				if v != null:
					v["alive"] = true
			"cryo_thaw":
				if a != null:
					a["alive"] = false
					a["health"] = 0
			"building_collapsed":
				building_state[int(ev["actor_id"])] = 0
			"persuaded":
				if int(ev["syndicate_id"]) == 1 and int(ev["district_id"]) == focus:
					thrall_ring -= 1
			"shield_intercept":
				if int(ev["district_id"]) == focus:
					thrall_ring += 1
	thrall_ring = maxi(thrall_ring, 0)


func _ever_in_focus(a: Dictionary) -> bool:
	if int(a["district"]) == focus:
		return true
	for ev in all_events:
		if String(ev["kind"]) == "operative_deployed" and int(ev["district_id"]) == focus \
				and _key(int(ev["syndicate_id"]), int(ev["actor_id"])) == _key(int(a["syn"]), int(a["id"])):
			return true
	return false


func _create_nodes() -> void:
	var player_nodes := ["OperativeKestrel1", "OperativeVex2", "OperativeNull3", "OperativeChrome4"]
	for key in actors:
		var a: Dictionary = actors[key]
		var syn := int(a["syn"])
		if syn == 1:
			a["node"] = sector.get_node_or_null(player_nodes[int(a["idx"])])
			continue
		if not _ever_in_focus(a):
			continue
		var is_fem := int(a["idx"]) % 2 == 1
		var node: Sprite2D = sector.spawn_actor_sprite(
			"Rival_%s_%s" % [SYN_SHORT[syn], a["callsign"]], is_fem, SYN_TINTS[syn])
		a["node"] = node
		sector._rival_operatives.append({
			"node": node,
			"tag": "%s // %s" % [SYN_SHORT[syn], a["callsign"]],
			"syndicate": syn,
			"color": SYN_COLORS[syn],
			"hp_ratio": 1.0,
			"hijacked": false,
			"key": key,
		})


func _sync_node(a: Dictionary) -> void:
	var node: Sprite2D = a["node"]
	if node == null:
		return
	var p: Vector3 = a["pos"]
	var in_focus := int(a["district"]) == focus
	node.visible = in_focus and (bool(a["alive"]) or bool(a["hijacked"]))
	node.position = sector.sector_grid_to_world(p.x, p.y, int(p.z))
	node.set_meta("stratum", int(p.z))
	for r in sector._rival_operatives:
		if r.get("key", "") == _key(int(a["syn"]), int(a["id"])):
			r["hp_ratio"] = clampf(float(a["health"]) / 100.0, 0.0, 1.0)
			r["hijacked"] = bool(a["hijacked"])
			if bool(a["hijacked"]):
				r["color"] = SYN_COLORS[1]
				r["tag"] = "THRALL // %s [HIJACKED]" % a["callsign"]


func _sync_all_nodes() -> void:
	for key in actors:
		_sync_node(actors[key])
	sector._apply_stratum_cutaway(sector.active_stratum)
	sector._update_actor_animations_and_depth(0.016)


func _sync_focus_building() -> void:
	if focus_organ_building != 0:
		sector.set_tower_collapsed(int(building_state.get(focus_organ_building, 0)) == 2)


func _hide_kowloon_props() -> void:
	# Hand-placed Kowloon demo actors are not part of the simulation; hide
	# them so only snapshot-driven actors appear in the replay.
	for n in ["CorpSecGuard1", "CorpSecGuard2", "MegacityCivilian1", "MegacityCivilian2", "ExecutiveArmoredLimo"]:
		var node := sector.get_node_or_null(n) as CanvasItem
		if node != null:
			node.visible = false


func _objectives_text() -> String:
	var owner := 0
	var revenue := 0
	for d in snap["districts"]:
		if int(d["id"]) == focus:
			owner = int(d["owner_syndicate"])
			revenue = int(d["daily_revenue"])
	var lines := "%s // SIM REPLAY\n" % focus_name
	lines += "OWNER: %s | REVENUE: %d CR/DAY\n" % [SYN_SHORT.get(owner, "-"), revenue]
	lines += "%s: %s\n" % [_organ_name(focus_organ), "RUBBLE" if int(building_state.get(focus_organ_building, 0)) == 2 else "INTACT"]
	var alive := {1: 0, 2: 0, 3: 0, 4: 0}
	for key in actors:
		var a: Dictionary = actors[key]
		if int(a["district"]) == focus and bool(a["alive"]):
			alive[int(a["syn"])] += 1
	lines += "IN SECTOR: EURO %d | ZAIBATSU %d | TRIAD %d | OMNI %d\n" % [alive[1], alive[2], alive[3], alive[4]]
	var unharvested := 0
	for ck in corpses:
		if not bool(corpses[ck]["extracted"]):
			unharvested += 1
	lines += "ESCORT THRALLS: %d | UNHARVESTED CORPSE DROPS: %d\n" % [thrall_ring, unharvested]
	lines += "Source: wetware_cli snapshot + event log (tick %d)" % int(snap.get("tick", 0))
	return lines


func _set_sector_labels() -> void:
	sector.focus_district_name = focus_name
	sector.focus_organ_name = _organ_name(focus_organ)
	# Only the Kowloon Bio-Foundry has finished landmark art so far; other
	# districts render it as a clearly-labelled placeholder until Step 2.
	sector.focus_organ_placeholder = focus_organ != 3
	sector.replay_objectives_text = _objectives_text()
	sector._refresh_hud()


func _organ_name(organ: int) -> String:
	match organ:
		1: return "POWER SUB-GRID"
		2: return "BROADCAST SPIRE"
		3: return "BIO-FOUNDRY"
		4: return "MONORAIL HUB"
		5: return "ORDINANCE FOUNDRY"
		6: return "CLEARINGHOUSE"
	return "CITY ORGAN"


func _frame_camera() -> void:
	# Frame every street-projected position an actor occupies in the focus
	# district, at the opening (rewound) and at the end (snapshot).
	var pts: Array[Vector2] = []
	for key in actors:
		var a: Dictionary = actors[key]
		if int(a["district"]) == focus:
			var p: Vector3 = a["pos"]
			pts.append(sector.sector_grid_to_world(p.x, p.y, 1))
	for syn in snap["syndicates"]:
		for op in syn["squad"]:
			if int(op["district_id"]) == focus:
				pts.append(sector.sector_grid_to_world(int(op["grid_x"]), int(op["grid_y"]), 1))
	if pts.is_empty():
		sector.set_camera_focus(Vector2(640, 360), 0.9)
		return
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var span := hi - lo
	# Visible play area is roughly 1180x470 of the 1280x720 canvas above the HUD.
	var zoom := clampf(minf(1180.0 / maxf(span.x + 260.0, 1.0), 470.0 / maxf(span.y + 220.0, 1.0)), 0.55, 1.05)
	var centre := (lo + hi) * 0.5
	# Shift the camera down so the action sits above the bottom HUD panels.
	sector.set_camera_focus(centre + Vector2(0, 70.0 / zoom), zoom)


func _world(c: Vector3) -> Vector2:
	return sector.sector_grid_to_world(c.x, c.y, int(c.z))


func _popup(text: String, world_pos: Vector2, color: Color, dur: float = 1.6) -> void:
	popups.append({"text": text, "pos": world_pos, "color": color, "t": 0.0, "dur": dur})


func _update_banner(detail: String) -> void:
	sector.set_banner("SIM REPLAY // %s // TICK %d // EVENT %d/%d: %s" % [
		focus_name, int(snap.get("tick", 0)), cursor, all_events.size(), detail])


func _process(delta: float) -> void:
	if sector == null:
		return
	var dt: float = delta / maxf(Engine.time_scale, 0.05)
	sector._step_procedural_civilians(dt)
	_place_thrall_ring(dt)
	for v in vfx:
		v["t"] = float(v["t"]) + dt
	vfx = vfx.filter(func(v: Dictionary) -> bool: return float(v["t"]) < float(v["dur"]))
	for p in popups:
		p["t"] = float(p["t"]) + dt
	popups = popups.filter(func(p: Dictionary) -> bool: return float(p["t"]) < float(p["dur"]))

	if not finished:
		timer -= dt
		while timer <= 0.0 and cursor < all_events.size():
			var ev: Dictionary = all_events[cursor]
			cursor += 1
			_apply_event(ev)
			timer += float(KIND_DURATION.get(String(ev["kind"]), 0.4)) if int(ev["district_id"]) == focus else 0.0
		if cursor >= all_events.size() and timer <= 0.0:
			finished = true
			sector.set_banner("SIM REPLAY COMPLETE // %s // TICK %d // DIGEST %s" % [
				focus_name, int(snap.get("tick", 0)), String(snap.get("state_digest", ""))])
	draw_node.queue_redraw()


func _place_thrall_ring(dt: float) -> void:
	var centre_actor: Variant = actors.get(ring_center_key)
	var civs: Array = sector._proc_civilians
	var shown := mini(thrall_ring, civs.size())
	if centre_actor == null or centre_actor["node"] == null:
		return
	var c: Vector2 = (centre_actor["node"] as Node2D).position
	for i in range(civs.size()):
		var cn: Sprite2D = civs[i]["node"]
		if i < shown:
			var ang := float(i) * TAU / float(maxi(shown, 1)) + float(Time.get_ticks_msec()) * 0.0009
			var tgt := c + Vector2(cos(ang) * 46.0, sin(ang) * 25.0)
			var to := tgt - cn.position
			if to.length() > 2.0:
				var d := to.normalized()
				cn.position += d * minf(to.length(), 140.0 * dt)
				sector._update_sprite_facing(cn, d)


func _apply_event(ev: Dictionary) -> void:
	var kind := String(ev["kind"])
	var syn := int(ev["syndicate_id"])
	var a: Variant = actors.get(_key(syn, int(ev["actor_id"])))
	var in_focus := int(ev["district_id"]) == focus
	var to_w := _world(_coord(ev["to"]))
	var from_w := _world(_coord(ev["from"]))
	match kind:
		"operative_deployed":
			if a != null:
				a["pos"] = _coord(ev["to"])
				a["district"] = int(ev["district_id"])
				_sync_node(a)
		"persuaded":
			if in_focus and syn == 1:
				ring_center_key = _key(1, int(ev["actor_id"]))
				thrall_ring += 1
				vfx.append({"kind": "wave", "to": from_w, "color": SYN_COLORS[1], "t": 0.0, "dur": 0.5})
		"shot_fired":
			if in_focus:
				var col: Color = WEAPON_COLORS.get(int(ev["weapon"]), SYN_COLORS.get(syn, Color.WHITE))
				vfx.append({"kind": "tracer", "from": from_w, "to": to_w, "color": col,
					"edge": SYN_COLORS.get(syn, Color.WHITE), "t": 0.0, "dur": 0.45})
				if a != null and a["node"] != null:
					var n: Sprite2D = a["node"]
					sector._update_sprite_facing(n, (to_w - n.position).normalized())
					sector._actor_fire_timer[n.get_instance_id()] = 0.45
		"shield_intercept":
			thrall_ring = maxi(thrall_ring - 1, 0)
			_popup("THRALL INTERCEPT // -%d ABSORBED" % int(ev["value"]), to_w + Vector2(0, -70), SYN_COLORS[1])
			vfx.append({"kind": "burst", "to": to_w + Vector2(30, -10), "color": SYN_COLORS[1], "t": 0.0, "dur": 0.6})
		"operative_hit":
			if a != null:
				a["health"] = maxi(int(a["health"]) - int(ev["value"]), 0)
				_sync_node(a)
			_popup("-%d HP" % int(ev["value"]), to_w + Vector2(0, -60), Color(1.0, 0.4, 0.35))
			vfx.append({"kind": "burst", "to": to_w, "color": Color(1.0, 0.4, 0.3), "t": 0.0, "dur": 0.5})
		"operative_killed":
			if a != null:
				a["alive"] = false
				a["health"] = 0
				corpses[_key(syn, int(ev["actor_id"]))] = {"pos": a["pos"], "extracted": false, "label": "KIA // %s" % a["callsign"]}
				_sync_node(a)
			_popup("KIA", to_w + Vector2(0, -50), Color(1.0, 0.3, 0.3))
		"orbital_strike":
			vfx.append({"kind": "orbital", "to": to_w, "color": WEAPON_COLORS[5], "t": 0.0, "dur": 1.1})
		"slab_breach":
			breach_cells.append(_coord(ev["to"]))
			vfx.append({"kind": "burst", "to": to_w, "color": Color(1.0, 0.62, 0.18), "t": 0.0, "dur": 0.7})
			_popup("SKYBRIDGE SLAB BREACHED", to_w + Vector2(0, -40), Color(1.0, 0.7, 0.25))
		"fall_damage":
			if a != null:
				a["pos"] = _coord(ev["to"])
				a["health"] = maxi(int(a["health"]) - int(ev["value"]), 0)
				_sync_node(a)
				vfx.append({"kind": "fall", "from": from_w, "to": to_w, "color": SYN_COLORS.get(syn, Color.WHITE), "t": 0.0, "dur": 0.8})
				_popup("%s FALLS // -%d HP" % [a["callsign"], int(ev["value"])], to_w + Vector2(0, -64), Color(1.0, 0.76, 0.25))
		"cardiac_flatline":
			if a != null:
				a["alive"] = false
				corpses[_key(syn, int(ev["actor_id"]))] = {"pos": a["pos"], "extracted": false, "label": "FLATLINE // %s" % a["callsign"]}
				_sync_node(a)
				_popup("CARDIAC FLATLINE // %s" % a["callsign"], to_w + Vector2(0, -64), Color(1.0, 0.25, 0.4), 2.2)
		"rival_hijacked":
			var v: Variant = actors.get(_key(int(ev["value"]), int(ev["target_id"])))
			if v != null:
				v["alive"] = false
				v["hijacked"] = true
				_sync_node(v)
				_popup("RIVAL HIJACKED // %s" % v["callsign"], to_w + Vector2(0, -64), SYN_COLORS[1], 2.0)
			vfx.append({"kind": "wave", "to": from_w, "color": Color(0.95, 0.35, 0.85), "t": 0.0, "dur": 0.8})
		"salvage_extracted":
			for ck in corpses:
				var cdat: Dictionary = corpses[ck]
				if cdat["pos"] == _coord(ev["to"]):
					cdat["extracted"] = true
			_popup("+%d CHROME -> CRYO-VAULT" % int(ev["value"]), to_w + Vector2(0, -64), Color(0.25, 0.98, 0.72), 2.0)
		"cryo_thaw":
			if a != null:
				a["alive"] = true
				a["health"] = 100
				_sync_node(a)
				_popup("CRYO-THAW // %s (-500 CR)" % a["callsign"], to_w + Vector2(0, -64), Color(0.55, 0.85, 1.0), 2.0)
		"building_collapsed":
			building_state[int(ev["actor_id"])] = 2
			_sync_focus_building()
			if in_focus:
				vfx.append({"kind": "orbital", "to": sector.sector_grid_to_world(8, 8, 1) + Vector2(0, -90), "color": Color(1.0, 0.5, 0.2), "t": 0.0, "dur": 1.2})
				_popup("%s COLLAPSES // REVENUE 0 CR/DAY" % _organ_name(focus_organ), sector.sector_grid_to_world(8, 8, 1) + Vector2(0, -200), Color(1.0, 0.45, 0.25), 2.6)
		"district_captured":
			_popup("%s CAPTURED BY %s" % [focus_name, SYN_SHORT.get(syn, "?")], sector.sector_grid_to_world(8, 8, 1) + Vector2(0, -200), SYN_COLORS.get(syn, Color.WHITE), 2.6)
	if syn == 1 and a != null and in_focus and kind in ["persuaded", "shot_fired", "salvage_extracted", "cryo_thaw"]:
		if sector.selected_operative != int(a["idx"]):
			sector.selected_operative = int(a["idx"])
	sector.thrall_count = thrall_ring
	sector.replay_objectives_text = _objectives_text()
	sector._refresh_hud()
	sector._apply_stratum_cutaway(sector.active_stratum)
	_update_banner(kind.to_upper())


func _draw_replay() -> void:
	var font := ThemeDB.fallback_font
	var z: float = sector._camera.zoom.x if sector._camera != null else 1.0

	for cell in breach_cells:
		var bp: Vector2 = sector._w2s(_world(cell))
		draw_node.draw_arc(bp, 34.0 * z, 0.0, TAU, 32, Color(1.0, 0.62, 0.18, 0.85), 2.2)

	# Corpse / organ-drop crates from the simulation.
	var stacked := {}
	for ck in corpses:
		var cdat: Dictionary = corpses[ck]
		if bool(cdat["extracted"]):
			continue
		var slot: int = stacked.get(cdat["pos"], 0)
		stacked[cdat["pos"]] = slot + 1
		var cp: Vector2 = sector._w2s(_world(cdat["pos"])) + Vector2(0, 16.0 * slot)
		var r := Rect2(cp.x - 10 * z, cp.y - 6 * z, 20 * z, 14 * z)
		draw_node.draw_rect(r, Color(0.08, 0.28, 0.34, 0.95), true)
		draw_node.draw_rect(r, Color(0.25, 0.98, 0.72, 1.0), false, 2.0)
		draw_node.draw_string(font, Vector2(cp.x - 60, cp.y + 26 * z), String(cdat["label"]), HORIZONTAL_ALIGNMENT_LEFT, 160, 10, Color(0.25, 0.98, 0.72))

	# Escort mesh tethers (count from the simulation; positions are presentation).
	var ca: Variant = actors.get(ring_center_key)
	if thrall_ring > 0 and ca != null and ca["node"] != null and (ca["node"] as Node2D).visible:
		var cp2: Vector2 = sector._w2s((ca["node"] as Node2D).position)
		var civs: Array = sector._proc_civilians
		for i in range(mini(thrall_ring, civs.size())):
			var tp: Vector2 = sector._w2s((civs[i]["node"] as Node2D).position)
			draw_node.draw_line(cp2, tp, Color(0.22, 0.96, 1.0, 0.6), 1.4)
		var tag := Rect2(cp2.x - 96, cp2.y + 36 * z, 192, 17)
		draw_node.draw_rect(tag, Color(0.03, 0.05, 0.09, 0.9), true)
		draw_node.draw_rect(tag, SYN_COLORS[1], false, 1.2)
		draw_node.draw_string(font, Vector2(tag.position.x + 6, tag.position.y + 12), "ESCORT MESH // %d THRALLS" % thrall_ring, HORIZONTAL_ALIGNMENT_LEFT, 184, 10, SYN_COLORS[1])

	for v in vfx:
		var t := float(v["t"]) / float(v["dur"])
		var a := clampf(1.0 - t, 0.0, 1.0)
		var col: Color = v["color"]
		var to_s: Vector2 = sector._w2s(v["to"])
		match String(v["kind"]):
			"tracer":
				var fs: Vector2 = sector._w2s(v["from"]) + Vector2(0, -8)
				draw_node.draw_line(fs, to_s, Color(col.r, col.g, col.b, a), 4.0)
				draw_node.draw_line(fs, to_s, Color(1, 1, 1, a * 0.9), 1.5)
				draw_node.draw_circle(fs, 6.0 * a, Color(1.0, 0.95, 0.8, a))
				draw_node.draw_circle(to_s, 12.0 * (1.2 - a * 0.5), Color(col.r, col.g, col.b, a * 0.6))
			"burst":
				draw_node.draw_arc(to_s, (8.0 + t * 40.0) * z, 0.0, TAU, 28, Color(col.r, col.g, col.b, a), 3.0)
				draw_node.draw_circle(to_s, 6.0 * a, Color(1, 1, 1, a))
			"wave":
				draw_node.draw_arc(to_s, (20.0 + t * 150.0) * z, 0.0, TAU, 48, Color(col.r, col.g, col.b, a), 2.6)
			"fall":
				var fs2: Vector2 = sector._w2s(v["from"])
				var pos := fs2.lerp(to_s, minf(1.0, t * 1.6))
				draw_node.draw_line(fs2, pos, Color(col.r, col.g, col.b, a * 0.7), 2.0)
				draw_node.draw_circle(pos, 7.0, Color(col.r, col.g, col.b, a))
			"orbital":
				draw_node.draw_line(Vector2(to_s.x, 0), to_s, Color(col.r, col.g, col.b, a * 0.85), 18.0 * a + 4.0)
				draw_node.draw_line(Vector2(to_s.x, 0), to_s, Color(1.0, 0.96, 0.85, a), 6.0 * a + 2.0)
				draw_node.draw_arc(to_s, (24.0 + t * 180.0) * z, 0.0, TAU, 56, Color(col.r, col.g, col.b, a), 3.6)

	for p in popups:
		var pt := float(p["t"]) / float(p["dur"])
		var pa := clampf(1.4 - pt * 1.4, 0.0, 1.0)
		var ps: Vector2 = sector._w2s(p["pos"]) + Vector2(0, -28.0 * pt)
		var text := String(p["text"])
		var w := float(text.length()) * 7.2 + 14.0
		var box := Rect2(ps.x - w * 0.5, ps.y - 14, w, 19)
		var pc: Color = p["color"]
		draw_node.draw_rect(box, Color(0.03, 0.05, 0.09, 0.9 * pa), true)
		draw_node.draw_rect(box, Color(pc.r, pc.g, pc.b, pa), false, 1.4)
		draw_node.draw_string(font, Vector2(box.position.x + 7, box.position.y + 14), text, HORIZONTAL_ALIGNMENT_LEFT, w, 11, Color(pc.r, pc.g, pc.b, pa))
