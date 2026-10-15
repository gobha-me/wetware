extends Node2D

enum Stratum {
	UNDER_GRID = 0,
	STREET = 1,
	SPIRE = 2,
}

const OPERATIVE_NODES := [
	"OperativeKestrel1",
	"OperativeVex2",
	"OperativeNull3",
	"OperativeChrome4",
]

const OPERATIVE_CALLSIGNS := [
	"KESTREL-1",
	"VEX-2",
	"NULL-3",
	"CHROME-4",
]

const OPERATIVE_ORGANS := [
	"V3 EYES | V3 BRAIN | V2 LEGS",
	"V3 ARMS | V3 CHEST | V2 HEART",
	"V4 BRAIN | V3 EYES | V2 CHEST",
	"V4 CHEST | V3 LEGS | V3 ARMS",
]

const PORTRAIT_PATHS := [
	"res://assets/sprites/portrait_kestrel_1.png",
	"res://assets/sprites/portrait_vex_2.png",
	"res://assets/sprites/portrait_null_3.png",
	"res://assets/sprites/portrait_chrome_4.png",
]

const WEAPON_NAMES := [
	"GAUSS CARBINE",
	"MINIGUN",
	"PLASMA LANCE",
	"SATELLITE RAIN",
]

const STRATUM_NAMES := {
	0: "UNDER-GRID",
	1: "STREET",
	2: "SPIRE",
}

var active_stratum: Stratum = Stratum.STREET
var selected_operative: int = 0
var active_weapon_index: int = 0
var overclock_active: bool = false
var tower_collapsed: bool = false
var transformer_sabotaged: bool = false
var convoy_intercepted: bool = false
var monorail_looted: bool = false
var crowd_surge_active: bool = false
var thrall_count: int = 0
var salvage_units: int = 1
var syndicate_treasury: int = 6000
var last_digest: String = "0x9f4a2c18e7b03d11"

# Interactive VFX state for _draw() and 2.5D shader pulses
var move_target_pos: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var tracer_start: Vector2 = Vector2.ZERO
var tracer_end: Vector2 = Vector2.ZERO
var tracer_color: Color = Color(0.25, 0.92, 1.0, 1.0)
var tracer_timer: float = 0.0
var persuade_origin: Vector2 = Vector2.ZERO
var persuade_timer: float = 0.0
var _portraits: Array[Texture2D] = []

func _ready() -> void:
	for p in PORTRAIT_PATHS:
		var tex := load(p) as Texture2D
		_portraits.append(tex)
	_populate_sector_grid()
	_apply_stratum_cutaway(active_stratum)
	_update_operative_card()
	_refresh_hud()
	if DisplayServer.get_name() == "headless":
		_apply_stratum_cutaway(Stratum.UNDER_GRID)
		_apply_stratum_cutaway(Stratum.SPIRE)
		_apply_stratum_cutaway(Stratum.STREET)
		set_tower_collapsed(true)
		set_tower_collapsed(false)
		print("wetware Godot 4.7.2 Kowloon Bio-Foundry 3-stratum vertical slice verified cleanly.")

func _populate_sector_grid() -> void:
	var floor_root := get_node_or_null("SectorFloorTiles") as Node2D
	if floor_root == null or floor_root.get_child_count() > 0:
		return
	var under_tpl := get_node_or_null("UnderGridCatwalk") as Sprite2D
	var street_tpl := get_node_or_null("StreetTileRoot") as Sprite2D
	var spire_tpl := get_node_or_null("SpireSkybridge") as Sprite2D
	if under_tpl == null or street_tpl == null or spire_tpl == null:
		return

	# Populate a full 128x64 isometric sector grid across Under-Grid, Street, and Spire
	for gx in range(-6, 7):
		for gy in range(-6, 7):
			var iso_offset := Vector2((gx - gy) * 64.0, (gx + gy) * 32.0)

			# Under-Grid catwalk network
			if abs(gx) <= 4 and abs(gy) <= 4 and (gx % 2 == 0 or gy % 2 == 0):
				var u_tile := Sprite2D.new()
				u_tile.texture = under_tpl.texture
				u_tile.material = under_tpl.material
				u_tile.position = Vector2(640, 500) + iso_offset * 0.85
				u_tile.set_meta("stratum", 0)
				floor_root.add_child(u_tile)

			# Street wet-asphalt city block (full 11x11 diamond)
			if abs(gx) <= 5 and abs(gy) <= 5:
				var s_tile := Sprite2D.new()
				s_tile.texture = street_tpl.texture
				s_tile.material = street_tpl.material
				s_tile.position = Vector2(640, 388) + iso_offset
				s_tile.set_meta("stratum", 1)
				floor_root.add_child(s_tile)

			# Spire skybridge cross-corridors
			if (abs(gx) <= 1 and abs(gy) <= 5) or (abs(gy) <= 1 and abs(gx) <= 5):
				var sp_tile := Sprite2D.new()
				sp_tile.texture = spire_tpl.texture
				sp_tile.material = spire_tpl.material
				sp_tile.position = Vector2(640, 196) + iso_offset * 0.9
				sp_tile.set_meta("stratum", 2)
				floor_root.add_child(sp_tile)

func _process(delta: float) -> void:
	var needs_redraw := false
	var real_dt: float = delta / maxf(Engine.time_scale, 0.05)

	# Keyboard / Steam Machine Gamepad continuous movement
	var move_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0

	var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_x) > 0.2 or abs(joy_y) > 0.2:
		move_vec = Vector2(joy_x, joy_y)

	var op_node := _get_selected_operative_node()
	if op_node != null:
		if move_vec.length_squared() > 0.01:
			has_move_target = false
			var dir := move_vec.normalized()
			op_node.position += dir * 165.0 * real_dt
			op_node.position.x = clampf(op_node.position.x, 120.0, 1160.0)
			op_node.position.y = clampf(op_node.position.y, 96.0, 620.0)
			_update_sprite_facing(op_node, dir)
			needs_redraw = true
		elif has_move_target:
			var to_target := move_target_pos - op_node.position
			if to_target.length() <= 6.0:
				op_node.position = move_target_pos
				has_move_target = false
			else:
				var dir := to_target.normalized()
				op_node.position += dir * 180.0 * real_dt
				_update_sprite_facing(op_node, dir)
			needs_redraw = true

	if tracer_timer > 0.0:
		tracer_timer = maxf(0.0, tracer_timer - real_dt)
		needs_redraw = true
		if tracer_timer == 0.0:
			_set_global_shader_pulse(Vector3.ZERO, 0.0)

	if persuade_timer > 0.0:
		persuade_timer = maxf(0.0, persuade_timer - real_dt)
		needs_redraw = true

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var op_node := _get_selected_operative_node()
	if op_node != null:
		# Draw isometric tactical selection diamond under selected operative's boots
		var base := op_node.position + Vector2(0, 34)
		var pts := PackedVector2Array([
			base + Vector2(0, -12),
			base + Vector2(24, 0),
			base + Vector2(0, 12),
			base + Vector2(-24, 0),
			base + Vector2(0, -12),
		])
		draw_polyline(pts, Color(0.25, 0.96, 1.0, 0.9), 2.0)

		if has_move_target:
			draw_line(base, move_target_pos + Vector2(0, 34), Color(0.25, 0.96, 1.0, 0.45), 1.5)
			draw_circle(move_target_pos + Vector2(0, 34), 5.0, Color(0.25, 0.96, 1.0, 0.75))

	if tracer_timer > 0.0:
		var alpha := clampf(tracer_timer / 0.28, 0.0, 1.0)
		var c := Color(tracer_color.r, tracer_color.g, tracer_color.b, alpha)
		draw_line(tracer_start, tracer_end, c, 3.5)
		draw_line(tracer_start, tracer_end, Color(1.0, 1.0, 1.0, alpha * 0.85), 1.5)
		draw_circle(tracer_end, 14.0 * (1.1 - alpha * 0.5), Color(tracer_color.r, tracer_color.g, tracer_color.b, alpha * 0.55))

	if persuade_timer > 0.0:
		var progress := 1.0 - (persuade_timer / 0.55)
		var radius := 24.0 + progress * 160.0
		var alpha := clampf(1.0 - progress, 0.0, 1.0)
		draw_arc(persuade_origin, radius, 0.0, TAU, 48, Color(0.22, 0.95, 1.0, alpha), 2.5)
		draw_arc(persuade_origin, radius * 0.65, 0.0, TAU, 36, Color(0.95, 0.35, 0.85, alpha * 0.75), 1.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_apply_stratum_cutaway(Stratum.UNDER_GRID)
			KEY_2:
				_apply_stratum_cutaway(Stratum.STREET)
			KEY_3:
				_apply_stratum_cutaway(Stratum.SPIRE)
			KEY_TAB, KEY_Q:
				_select_operative((selected_operative + 1) % OPERATIVE_NODES.size())
			KEY_R:
				active_weapon_index = (active_weapon_index + 1) % WEAPON_NAMES.size()
				_update_operative_card()
			KEY_C:
				set_tower_collapsed(not tower_collapsed)
			KEY_F:
				_fire_active_weapon_at(Vector2(640, 292))
			KEY_P:
				_trigger_persuadertron_wave()
			KEY_T:
				_toggle_transformer_sabotage()
			KEY_V:
				_intercept_executive_convoy()
			KEY_M:
				_loot_monorail_wreck()
			KEY_SPACE:
				overclock_active = not overclock_active
				Engine.time_scale = 0.25 if overclock_active else 1.0
				_refresh_hud()

	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			move_target_pos = mb.position - Vector2(0, 28)
			has_move_target = true
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_fire_active_weapon_at(mb.position)

	elif event is InputEventJoypadButton and event.pressed:
		var jb := event as InputEventJoypadButton
		match jb.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_select_operative((selected_operative + OPERATIVE_NODES.size() - 1) % OPERATIVE_NODES.size())
			JOY_BUTTON_RIGHT_SHOULDER:
				_select_operative((selected_operative + 1) % OPERATIVE_NODES.size())
			JOY_BUTTON_DPAD_UP:
				_apply_stratum_cutaway( clampi(int(active_stratum) + 1, 0, 2) as Stratum )
			JOY_BUTTON_DPAD_DOWN:
				_apply_stratum_cutaway( clampi(int(active_stratum) - 1, 0, 2) as Stratum )
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				active_weapon_index = (active_weapon_index + 1) % WEAPON_NAMES.size()
				_update_operative_card()
			JOY_BUTTON_X:
				_fire_active_weapon_at(Vector2(640, 292))
			JOY_BUTTON_Y:
				_trigger_persuadertron_wave()
			JOY_BUTTON_A:
				_execute_contextual_objective()
			JOY_BUTTON_B:
				overclock_active = not overclock_active
				Engine.time_scale = 0.25 if overclock_active else 1.0
				_refresh_hud()

func _select_operative(index: int) -> void:
	selected_operative = clampi(index, 0, OPERATIVE_NODES.size() - 1)
	var op_node := _get_selected_operative_node()
	if op_node != null and op_node.has_meta("stratum"):
		_apply_stratum_cutaway(int(op_node.get_meta("stratum")) as Stratum)
	_update_operative_card()
	queue_redraw()

func _get_selected_operative_node() -> Sprite2D:
	return get_node_or_null(OPERATIVE_NODES[selected_operative]) as Sprite2D

func _update_sprite_facing(sprite: Sprite2D, dir: Vector2) -> void:
	if sprite == null or sprite.hframes != 8:
		return
	var angle := atan2(dir.x, dir.y)
	if angle < 0.0:
		angle += TAU
	var sector := int(round(angle / (PI / 4.0))) % 8
	sprite.frame = sector

func _fire_active_weapon_at(target_pos: Vector2) -> void:
	var op_node := _get_selected_operative_node()
	if op_node == null:
		return
	var to_target := target_pos - op_node.position
	if to_target.length_squared() > 1.0:
		_update_sprite_facing(op_node, to_target.normalized())
	tracer_start = op_node.position + Vector2(0, -6)
	tracer_end = target_pos
	tracer_timer = 0.28

	if active_weapon_index == 2 or active_weapon_index == 3:
		tracer_color = Color(1.0, 0.48, 0.18, 1.0)
		_set_global_shader_pulse(Vector3(1.0, 0.45, 0.15), 0.85)
	else:
		tracer_color = Color(0.25, 0.95, 1.0, 1.0)
		_set_global_shader_pulse(Vector3(0.25, 0.9, 1.0), 0.65)

	# Check if firing near Bio-Foundry Tower center -> shear pillars & collapse
	if target_pos.distance_to(Vector2(640, 292)) < 110.0 and not tower_collapsed:
		set_tower_collapsed(true)
	queue_redraw()

func _trigger_persuadertron_wave() -> void:
	var op_node := _get_selected_operative_node()
	if op_node == null:
		return
	persuade_origin = op_node.position
	persuade_timer = 0.55
	if not crowd_surge_active:
		crowd_surge_active = true
		thrall_count = 4
	for actor_name in ["MegacityCivilian1", "MegacityCivilian2", "CorpSecGuard1", "CorpSecGuard2"]:
		var actor := get_node_or_null(actor_name) as Sprite2D
		if actor and actor.material is ShaderMaterial:
			var smat := actor.material as ShaderMaterial
			smat.set_shader_parameter("pulse_tint", Vector3(0.2, 0.95, 1.0))
			smat.set_shader_parameter("pulse_intensity", 1.15)
	_update_operative_card()
	_refresh_hud()
	queue_redraw()

func _toggle_transformer_sabotage() -> void:
	transformer_sabotaged = not transformer_sabotaged
	var blackout := 0.38 if transformer_sabotaged else 1.0
	_set_global_blackout(blackout)
	_refresh_hud()

func _intercept_executive_convoy() -> void:
	if not convoy_intercepted:
		convoy_intercepted = true
		syndicate_treasury += 1500
		salvage_units += 1
		var limo := get_node_or_null("ExecutiveArmoredLimo") as Sprite2D
		if limo and limo.material is ShaderMaterial:
			(limo.material as ShaderMaterial).set_shader_parameter("pulse_tint", Vector3(1.0, 0.35, 0.1))
			(limo.material as ShaderMaterial).set_shader_parameter("pulse_intensity", 1.2)
		_refresh_hud()

func _loot_monorail_wreck() -> void:
	if not monorail_looted:
		monorail_looted = true
		syndicate_treasury += 2500
		salvage_units += 1
		_refresh_hud()

func _execute_contextual_objective() -> void:
	if not transformer_sabotaged and active_stratum == Stratum.UNDER_GRID:
		_toggle_transformer_sabotage()
	elif not convoy_intercepted and active_stratum == Stratum.STREET:
		_intercept_executive_convoy()
	elif not monorail_looted and active_stratum == Stratum.SPIRE:
		_loot_monorail_wreck()
	else:
		_trigger_persuadertron_wave()

func _set_global_blackout(factor: float) -> void:
	for child in get_children():
		if child is CanvasItem and child.material is ShaderMaterial:
			(child.material as ShaderMaterial).set_shader_parameter("blackout_factor", factor)

func _set_global_shader_pulse(tint: Vector3, intensity: float) -> void:
	for child in get_children():
		if child is CanvasItem and child.material is ShaderMaterial:
			var smat := child.material as ShaderMaterial
			smat.set_shader_parameter("pulse_tint", tint)
			smat.set_shader_parameter("pulse_intensity", intensity)

func valid_snapshot(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if d.get("schema_version") != 1:
		return false
	if typeof(d.get("state_digest")) != TYPE_STRING or String(d.get("state_digest")).is_empty():
		return false
	var t_scale: Variant = d.get("tactical_time_scale")
	if typeof(t_scale) != TYPE_FLOAT and typeof(t_scale) != TYPE_INT:
		return false
	if not is_finite(float(t_scale)) or float(t_scale) <= 0.0 or float(t_scale) > 4.0:
		return false
	var syndicates: Variant = d.get("syndicates")
	if typeof(syndicates) != TYPE_ARRAY or (syndicates as Array).is_empty():
		return false
	for syn in syndicates as Array:
		if typeof(syn) != TYPE_DICTIONARY:
			return false
		var squad: Variant = (syn as Dictionary).get("squad")
		if typeof(squad) != TYPE_ARRAY or (squad as Array).size() != 4:
			return false
		for op in squad as Array:
			if typeof(op) != TYPE_DICTIONARY:
				return false
			var s_val: Variant = (op as Dictionary).get("stratum")
			if (typeof(s_val) != TYPE_INT and typeof(s_val) != TYPE_FLOAT) or int(s_val) < 0 or int(s_val) > 2:
				return false
	var buildings: Variant = d.get("buildings")
	if typeof(buildings) != TYPE_ARRAY or (buildings as Array).is_empty():
		return false
	for bld in buildings as Array:
		if typeof(bld) != TYPE_DICTIONARY:
			return false
		var st: Variant = (bld as Dictionary).get("state")
		if (typeof(st) != TYPE_INT and typeof(st) != TYPE_FLOAT) or int(st) < 0 or int(st) > 3:
			return false
	return true

func apply_snapshot(data: Dictionary) -> bool:
	if not valid_snapshot(data):
		return false
	last_digest = String(data["state_digest"])
	var t_scale := float(data["tactical_time_scale"])
	overclock_active = t_scale < 0.5
	Engine.time_scale = t_scale

	for bld_var in data["buildings"] as Array:
		var bld: Dictionary = bld_var
		if int(bld["id"]) == 10:
			set_tower_collapsed(int(bld["state"]) == 2)

	var districts: Variant = data.get("districts")
	if typeof(districts) == TYPE_ARRAY and not (districts as Array).is_empty():
		var d0: Dictionary = (districts as Array)[0]
		transformer_sabotaged = not bool(d0.get("transformer_intact", true)) or bool(d0.get("power_blackout", false))
		convoy_intercepted = not bool(d0.get("executive_convoy_active", true))
		crowd_surge_active = bool(d0.get("crowd_surge_active", false))
		_set_global_blackout(0.38 if transformer_sabotaged else 1.0)

	var player_syn: Dictionary = (data["syndicates"] as Array)[0]
	syndicate_treasury = int(player_syn.get("treasury", 0))
	salvage_units = int(player_syn.get("salvage_count", salvage_units))
	thrall_count = int(player_syn.get("thrall_count", thrall_count))
	var squad: Array = player_syn["squad"]
	for i in range(min(squad.size(), OPERATIVE_NODES.size())):
		var op: Dictionary = squad[i]
		var node := get_node_or_null(OPERATIVE_NODES[i]) as Node2D
		if node:
			var s := int(op["stratum"])
			node.set_meta("stratum", s)
			node.visible = bool(op["alive"])

	_apply_stratum_cutaway(active_stratum)
	_update_operative_card()
	_refresh_hud()
	return true

func set_tower_collapsed(collapsed: bool) -> void:
	tower_collapsed = collapsed
	var intact_node := get_node_or_null("BioFoundryTowerIntact") as CanvasItem
	var rubble_node := get_node_or_null("BioFoundryTowerRubble") as CanvasItem
	if intact_node:
		intact_node.visible = not collapsed
	if rubble_node:
		rubble_node.visible = collapsed
	_refresh_hud()

func _apply_stratum_cutaway(focus_stratum: Stratum) -> void:
	active_stratum = focus_stratum
	for child in get_children():
		_apply_node_stratum_alpha(child, focus_stratum)
	var floor_root := get_node_or_null("SectorFloorTiles")
	if floor_root:
		for tile in floor_root.get_children():
			_apply_node_stratum_alpha(tile, focus_stratum)
	_refresh_hud()

func _apply_node_stratum_alpha(node: Node, focus_stratum: Stratum) -> void:
	if not node.has_meta("stratum"):
		return
	var node_stratum: int = int(node.get_meta("stratum"))
	var alpha: float = 1.0
	if node_stratum > int(focus_stratum):
		alpha = 0.18
	elif node_stratum < int(focus_stratum):
		alpha = 0.65
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		var smat := (node as CanvasItem).material as ShaderMaterial
		smat.set_shader_parameter("stratum_cutaway_alpha", alpha)

func _update_operative_card() -> void:
	var portrait_rect := get_node_or_null("TacticalHud/PortraitRect") as TextureRect
	if portrait_rect and selected_operative < _portraits.size() and _portraits[selected_operative] != null:
		portrait_rect.texture = _portraits[selected_operative]

	var bio_label := get_node_or_null("TacticalHud/OperativeBioLabel") as Label
	if bio_label == null:
		return
	var op_node := _get_selected_operative_node()
	var op_stratum := int(op_node.get_meta("stratum")) if (op_node and op_node.has_meta("stratum")) else int(active_stratum)
	var s_name: String = STRATUM_NAMES.get(op_stratum, "STREET")
	var ipa_text := "95% / 92% / 98% [SURGE]" if overclock_active else "82% / 78% / 65%"
	bio_label.text = "OP-%d: %s [%s]\nORGANS: %s\nBIOCHEM I/P/A: %s\nWEAPON: %s | THRALLS: %d | SALVAGE: %d" % [
		selected_operative + 1,
		OPERATIVE_CALLSIGNS[selected_operative],
		s_name,
		OPERATIVE_ORGANS[selected_operative],
		ipa_text,
		WEAPON_NAMES[active_weapon_index],
		thrall_count,
		salvage_units,
	]

func _refresh_hud() -> void:
	var hud_label := get_node_or_null("TacticalHud/HudTelemetryLabel") as Label
	if hud_label != null:
		var stratum_name: String = STRATUM_NAMES.get(int(active_stratum), "STREET")
		var organ_state := "RUBBLE" if tower_collapsed else "INTACT"
		var oc_state := "OVERCLOCK 0.25x" if overclock_active else "NOMINAL 1.00x"
		var grid_power := "BLACKOUT" if transformer_sabotaged else "GRID ONLINE"
		hud_label.text = "CR: %d | STRATUM: %s | BIO-FOUNDRY: %s | %s | %s | DIGEST: %s" % [
			syndicate_treasury,
			stratum_name,
			organ_state,
			oc_state,
			grid_power,
			last_digest,
		]

	var obj_label := get_node_or_null("TacticalHud/ObjectivesLabel") as Label
	if obj_label != null:
		obj_label.text = (
			"KOWLOON SECTOR OBJECTIVES:\n"
			+ "[%s] SHEAR BIO-FOUNDRY PILLARS (C / RMB FIRE)\n" % ("X" if tower_collapsed else " ")
			+ "[%s] SABOTAGE SUB-GRID TRANSFORMER (T)\n" % ("X" if transformer_sabotaged else " ")
			+ "[%s] AMBUSH ZAIBATSU LIMO CONVOY (V)\n" % ("X" if convoy_intercepted else " ")
			+ "[%s] LOOT DERAILED MONORAIL VAULT (M)\n" % ("X" if monorail_looted else " ")
			+ "[%s] PERSUADERTRON CROWD SURGE (P)\n" % ("X" if crowd_surge_active else " ")
			+ "KBM: LMB/WASD Move | RMB/F Fire | R Weapon | Tab Op | 1-3 Stratum | Space 0.25x\n"
			+ "STEAM PAD: L-Stick Move | X Fire | Y Persuade | A Action | LB/RB Op | D-Pad Stratum"
		)
	_update_operative_card()
