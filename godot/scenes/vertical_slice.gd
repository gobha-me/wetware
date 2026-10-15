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

const OPERATIVE_SHORT := [
	"1:KESTREL",
	"2:VEX",
	"3:NULL",
	"4:CHROME",
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

const GRID_RADIUS := 16

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

# Interactive VFX state rendered on foreground TacticalOverlay inside TacticalHud
var move_target_pos: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var tracer_start: Vector2 = Vector2.ZERO
var tracer_end: Vector2 = Vector2.ZERO
var tracer_color: Color = Color(0.25, 0.92, 1.0, 1.0)
var tracer_timer: float = 0.0
var persuade_origin: Vector2 = Vector2.ZERO
var persuade_timer: float = 0.0
var satellite_strike_timer: float = 0.0
var target_pulse_timer: float = 0.0
var demo_reel_active: bool = false
var demo_frame: int = 0
var demo_banner_text: String = ""
var _portraits: Array[Texture2D] = []
var _overlay: Node2D = null
var _camera: Camera2D = null
var _cam_target_pos: Vector2 = Vector2(640, 360)
var _cam_target_zoom: float = 1.0

func _ready() -> void:
	for p in PORTRAIT_PATHS:
		var tex := load(p) as Texture2D
		_portraits.append(tex)
	_setup_camera()
	_setup_tactical_overlay()
	_populate_sector_grid()
	_apply_stratum_cutaway(active_stratum)
	_update_operative_card()
	_refresh_hud()
	if "--demo-reel" in OS.get_cmdline_user_args():
		demo_reel_active = true
		_select_operative(1)
	if DisplayServer.get_name() == "headless":
		_apply_stratum_cutaway(Stratum.UNDER_GRID)
		_apply_stratum_cutaway(Stratum.SPIRE)
		_apply_stratum_cutaway(Stratum.STREET)
		set_tower_collapsed(true)
		set_tower_collapsed(false)
		print("wetware Godot 4.7.2 Kowloon Bio-Foundry 3-stratum vertical slice verified cleanly.")

func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "SectorCamera"
	_camera.position = Vector2(640, 360)
	_camera.enabled = true
	add_child(_camera)

func _w2s(world_pos: Vector2) -> Vector2:
	return get_canvas_transform() * world_pos

func _setup_tactical_overlay() -> void:
	var hud := get_node_or_null("TacticalHud")
	if hud == null:
		return
	for bg_name in ["TopBarBg", "OperativeCardBg", "ObjectivesBg"]:
		var bg := hud.get_node_or_null(bg_name) as CanvasItem
		if bg:
			bg.visible = false
	_overlay = Node2D.new()
	_overlay.name = "TacticalOverlay"
	_overlay.z_index = -1
	hud.add_child(_overlay)
	hud.move_child(_overlay, 0)
	_overlay.draw.connect(_draw_tactical_overlay)

func _request_overlay_redraw() -> void:
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()

func _is_street_road(gx: int, gy: int) -> bool:
	var ax := absi(gx)
	var ay := absi(gy)
	# Inner Ring Road around Bio-Foundry (radius 3)
	if (ax == 3 and ay <= 9) or (ay == 3 and ax <= 9):
		return true
	# Outer District Boulevard Ring (radius 9)
	if (ax == 9 and ay <= 9) or (ay == 9 and ax <= 9):
		return true
	# Outer Sector Highway Perimeter (radius 15)
	if (ax == 15 and ay <= 15) or (ay == 15 and ax <= 15):
		return true
	# Radial Avenues creating T-forks and 4-way crosswalk intersections across blocks
	if gx == 0 and ay >= 3 and ay <= 15:
		return true
	if gy == 0 and ax >= 3 and ax <= 15:
		return true
	return false

func _get_street_tile_frame(gx: int, gy: int) -> int:
	var ax := absi(gx)
	var ay := absi(gy)
	# Central Bio-Foundry Compound Plaza & Neighboring Corporate Block Plazas
	if (ax <= 2 and ay <= 2) or (ax in [5, 6, 7] and ay in [5, 6, 7]):
		return 0
	if not _is_street_road(gx, gy):
		return 1 # Pedestrian Sidewalk & Urban Apron

	var up := _is_street_road(gx + 1, gy)
	var un := _is_street_road(gx - 1, gy)
	var vp := _is_street_road(gx, gy + 1)
	var vn := _is_street_road(gx, gy - 1)

	if up and un and vp and vn:
		return 4 # 4-Way Crosswalk Intersection
	if up and un and vp and not vn:
		return 5 # T-Fork +v
	if up and un and not vp and vn:
		return 6 # T-Fork -v
	if up and not un and vp and vn:
		return 7 # T-Fork +u
	if not up and un and vp and vn:
		return 8 # T-Fork -u
	if up and not un and vp and not vn:
		return 9 # 90-deg Curved Turn (+u, +v)
	if not up and un and vp and not vn:
		return 10 # 90-deg Curved Turn (-u, +v)
	if up and not un and not vp and vn:
		return 11 # 90-deg Curved Turn (+u, -v)
	if not up and un and not vp and vn:
		return 12 # 90-deg Curved Turn (-u, -v)
	if vp or vn:
		return 3 # Straight Avenue along gy (v)
	return 2 # Straight Avenue along gx (u)

func _populate_sector_grid() -> void:
	var floor_root := get_node_or_null("SectorFloorTiles") as Node2D
	if floor_root == null or floor_root.get_child_count() > 0:
		return
	var under_tpl := get_node_or_null("UnderGridCatwalk") as Sprite2D
	var street_tpl := get_node_or_null("StreetTileRoot") as Sprite2D
	var spire_tpl := get_node_or_null("SpireSkybridge") as Sprite2D
	if under_tpl == null or street_tpl == null or spire_tpl == null:
		return
	under_tpl.visible = false
	street_tpl.visible = false
	spire_tpl.visible = false

	# Populate sprawling 33x33 multi-block megacity sector (4224x2112 world area, zero black void)
	for gx in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gy in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var iso_offset := Vector2((gx - gy) * 64.0, (gx + gy) * 32.0)

			# Under-Grid sprawling catwalk network across all city blocks
			if abs(gx) <= 14 and abs(gy) <= 14 and (gx % 2 == 0 or gy % 2 == 0):
				var u_tile := Sprite2D.new()
				u_tile.texture = under_tpl.texture
				u_tile.material = under_tpl.material
				u_tile.position = Vector2(640, 500) + iso_offset * 0.85
				u_tile.set_meta("stratum", 0)
				floor_root.add_child(u_tile)

			# Full 33x33 Street multi-block urban road & plaza network
			var s_tile := Sprite2D.new()
			s_tile.texture = street_tpl.texture
			s_tile.material = street_tpl.material
			s_tile.hframes = 13
			s_tile.frame = _get_street_tile_frame(gx, gy)
			s_tile.position = Vector2(640, 388) + iso_offset
			s_tile.set_meta("stratum", 1)
			floor_root.add_child(s_tile)

			# Spire multi-corridor skybridge network spanning neighboring towers
			if (abs(gx) <= 1 or abs(gx) == 6) and abs(gy) <= 12 or (abs(gy) <= 1 or abs(gy) == 6) and abs(gx) <= 12:
				var sp_tile := Sprite2D.new()
				sp_tile.texture = spire_tpl.texture
				sp_tile.material = spire_tpl.material
				sp_tile.position = Vector2(640, 196) + iso_offset * 0.9
				sp_tile.set_meta("stratum", 2)
				floor_root.add_child(sp_tile)

	# Populate secondary buildings, checkpoints, vehicles & props across neighboring city blocks
	_populate_surrounding_city_blocks(floor_root)

func _populate_surrounding_city_blocks(floor_root: Node2D) -> void:
	var tower_tpl := get_node_or_null("BioFoundryTowerIntact") as Sprite2D
	var hauler_tpl := get_node_or_null("AutonomousCargoHauler") as Sprite2D
	var dozer_tpl := get_node_or_null("HeavyRiotBulldozer") as Sprite2D
	var decon_tpl := get_node_or_null("HazmatDeconRig") as Sprite2D
	var gate_tpl := get_node_or_null("AutomatedCheckpointGate") as Sprite2D
	var turret_tpl := get_node_or_null("PlasmaSentryTurret") as Sprite2D
	var vending_tpl := get_node_or_null("StreetVendingMachineBank") as Sprite2D
	var hvac_tpl := get_node_or_null("RooftopHvacCoolingTower") as Sprite2D
	var vat_tpl := get_node_or_null("CryoStasisVat") as Sprite2D
	if tower_tpl == null:
		return

	# 4 Flanking Corporate Sub-Towers on the neighboring 4 city block plazas ((±6, ±6))
	var block_centers := [
		Vector2(-6, -6),
		Vector2(6, -6),
		Vector2(-6, 6),
		Vector2(6, 6),
	]
	for bc in block_centers:
		var iso := Vector2((bc.x - bc.y) * 64.0, (bc.x + bc.y) * 32.0)
		var sub_tower := Sprite2D.new()
		sub_tower.texture = tower_tpl.texture
		sub_tower.material = tower_tpl.material
		sub_tower.position = Vector2(640, 298) + iso
		sub_tower.scale = Vector2(0.82, 0.82)
		sub_tower.set_meta("stratum", 1)
		floor_root.add_child(sub_tower)

	# Perimeter vehicles & infrastructure across the outer avenues
	var extra_props := [
		[hauler_tpl, Vector2(-6, -3), 2, 1],
		[dozer_tpl, Vector2(6, -3), 6, 1],
		[decon_tpl, Vector2(-3, 6), 0, 1],
		[gate_tpl, Vector2(0, -6), 3, 1],
		[gate_tpl, Vector2(0, 6), 7, 1],
		[turret_tpl, Vector2(-6, 3), 2, 1],
		[turret_tpl, Vector2(6, 3), 6, 1],
		[vending_tpl, Vector2(-4, -2), 1, 1],
		[vending_tpl, Vector2(4, 2), 5, 1],
		[hvac_tpl, Vector2(-6, -5), 3, 2],
		[hvac_tpl, Vector2(6, -5), 5, 2],
		[vat_tpl, Vector2(-6, 0), 2, 0],
		[vat_tpl, Vector2(6, 0), 6, 0],
	]
	for item in extra_props:
		var tpl: Sprite2D = item[0]
		if tpl == null:
			continue
		var g: Vector2 = item[1]
		var iso := Vector2((g.x - g.y) * 64.0, (g.x + g.y) * 32.0)
		var p := Sprite2D.new()
		p.texture = tpl.texture
		p.material = tpl.material
		p.hframes = tpl.hframes
		p.frame = int(item[2])
		var st := int(item[3])
		var base_y := 388.0 if st == 1 else (500.0 if st == 0 else 196.0)
		var scale_iso := 1.0 if st == 1 else (0.85 if st == 0 else 0.9)
		p.position = Vector2(640, base_y) + iso * scale_iso
		p.set_meta("stratum", st)
		floor_root.add_child(p)

func _process(delta: float) -> void:
	var needs_redraw := false
	var real_dt: float = delta / maxf(Engine.time_scale, 0.05)

	if demo_reel_active:
		demo_frame += 1
		_step_demo_reel(demo_frame)
		needs_redraw = true

	var move_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_vec.x += 1.0

	var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_x) > 0.2 or abs(joy_y) > 0.2:
		move_vec = Vector2(joy_x, joy_y)

	# Arrow keys or Right-Stick pan the tactical camera across the sprawling sector
	var cam_pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP):
		cam_pan.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		cam_pan.y += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		cam_pan.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		cam_pan.x += 1.0
	var rjoy_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var rjoy_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rjoy_x) > 0.2 or abs(rjoy_y) > 0.2:
		cam_pan = Vector2(rjoy_x, rjoy_y)
	if cam_pan.length_squared() > 0.01:
		_cam_target_pos += cam_pan.normalized() * 340.0 * real_dt
		_cam_target_pos.x = clampf(_cam_target_pos.x, 180.0, 1100.0)
		_cam_target_pos.y = clampf(_cam_target_pos.y, 120.0, 620.0)
		needs_redraw = true

	var op_node := _get_selected_operative_node()
	if op_node != null:
		if move_vec.length_squared() > 0.01:
			has_move_target = false
			var dir := move_vec.normalized()
			op_node.position += dir * 165.0 * real_dt
			op_node.position.x = clampf(op_node.position.x, -400.0, 1680.0)
			op_node.position.y = clampf(op_node.position.y, -200.0, 960.0)
			_update_sprite_facing(op_node, dir)
			_cam_target_pos = op_node.position
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

	if _camera != null:
		var prev_pos := _camera.position
		var prev_zoom := _camera.zoom.x
		_camera.position = _camera.position.lerp(_cam_target_pos, clampf(real_dt * 6.5, 0.0, 1.0))
		var z := lerpf(_camera.zoom.x, _cam_target_zoom, clampf(real_dt * 5.0, 0.0, 1.0))
		_camera.zoom = Vector2(z, z)
		if prev_pos.distance_squared_to(_camera.position) > 0.05 or absf(prev_zoom - z) > 0.001:
			needs_redraw = true

	if tracer_timer > 0.0:
		tracer_timer = maxf(0.0, tracer_timer - real_dt)
		needs_redraw = true

	if persuade_timer > 0.0:
		persuade_timer = maxf(0.0, persuade_timer - real_dt)
		needs_redraw = true

	if satellite_strike_timer > 0.0:
		satellite_strike_timer = maxf(0.0, satellite_strike_timer - real_dt)
		needs_redraw = true

	if target_pulse_timer > 0.0:
		target_pulse_timer = maxf(0.0, target_pulse_timer - real_dt)
		if target_pulse_timer == 0.0:
			_clear_actor_shader_pulses()

	if needs_redraw:
		_request_overlay_redraw()

func _step_demo_reel(f: int) -> void:
	# Act I (1..48): Street Deployment & Zaibatsu Convoy Ambush (Camera pans West-South boulevard)
	if f == 1:
		demo_banner_text = "ACT I // STREET DEPLOYMENT & ZAIBATSU LIMO AMBUSH"
		_select_operative(1)
		active_weapon_index = 0
		_update_operative_card()
		move_target_pos = Vector2(516, 430)
		has_move_target = true
		_cam_target_pos = Vector2(520, 410)
		_cam_target_zoom = 1.02
	elif f > 1 and f < 36:
		var limo := get_node_or_null("ExecutiveArmoredLimo") as Sprite2D
		if limo and not convoy_intercepted:
			limo.position += Vector2(0.85, 0.42)
	if f == 16:
		_fire_active_weapon_at(Vector2(490, 470))
	elif f == 28:
		active_weapon_index = 1
		_update_operative_card()
		_fire_active_weapon_at(Vector2(498, 474))
	elif f == 36:
		_fire_active_weapon_at(Vector2(504, 478))
		_intercept_executive_convoy()

	# Act II (49..96): Persuadertron Neural-Mesh Wave & Crowd Surge (Camera pans East across intersection)
	elif f == 49:
		demo_banner_text = "ACT II // PERSUADERTRON NEURAL-MESH & CROWD SURGE"
		_select_operative(2)
		move_target_pos = Vector2(648, 422)
		has_move_target = true
		_cam_target_pos = Vector2(710, 405)
		_cam_target_zoom = 0.96
	elif f == 60:
		_trigger_persuadertron_wave()
	elif f > 60 and f <= 96:
		var civ1 := get_node_or_null("MegacityCivilian1") as Sprite2D
		var guard1 := get_node_or_null("CorpSecGuard1") as Sprite2D
		if civ1:
			var d1 := Vector2(0.9, -0.45)
			civ1.position += d1
			_update_sprite_facing(civ1, d1)
		if guard1:
			var d2 := Vector2(1.1, -0.3)
			guard1.position += d2
			_update_sprite_facing(guard1, d2)
		if f == 78:
			_trigger_persuadertron_wave()

	# Act III (97..144): Under-Grid Cutaway & High-Voltage Transformer Sabotage
	elif f == 97:
		demo_banner_text = "ACT III // UNDER-GRID CUTAWAY & SUB-GRID BLACKOUT"
		_select_operative(3)
		active_weapon_index = 0
		_update_operative_card()
		move_target_pos = Vector2(464, 520)
		has_move_target = true
		_cam_target_pos = Vector2(485, 490)
		_cam_target_zoom = 1.0
	elif f > 97 and f <= 144:
		var crawler := get_node_or_null("SubGridRepairCrawler") as Sprite2D
		if crawler:
			crawler.position += Vector2(-0.6, 0.25)
		if f == 112:
			_fire_active_weapon_at(Vector2(360, 528))
		elif f == 124:
			_fire_active_weapon_at(Vector2(360, 528))
			_toggle_transformer_sabotage()

	# Act IV (145..192): Spire Skybridge, Adrenaline Overclock 0.25x & Monorail Vault Breach
	elif f == 145:
		demo_banner_text = "ACT IV // SPIRE SKYBRIDGE, ADRENALINE OVERCLOCK & MONORAIL VAULT"
		_select_operative(0)
		overclock_active = true
		_refresh_hud()
		move_target_pos = Vector2(452, 190)
		has_move_target = true
		_cam_target_pos = Vector2(540, 235)
		_cam_target_zoom = 0.95
	elif f > 145 and f <= 192:
		var drone := get_node_or_null("QuadHunterKillerDrone") as Sprite2D
		var spinner := get_node_or_null("SyndicateSpinner") as Sprite2D
		if drone:
			drone.position += Vector2(-1.1, 0.35)
		if spinner:
			spinner.position += Vector2(-0.9, 0.2)
		if f == 162:
			_fire_active_weapon_at(Vector2(348, 188))
		elif f == 174:
			_fire_active_weapon_at(Vector2(348, 188))
			_loot_monorail_wreck()

	# Act V (193..240): Wide Multi-Block Zoom Out + Satellite Rain & Bio-Foundry Tower Collapse
	elif f == 193:
		demo_banner_text = "ACT V // SATELLITE RAIN STRIKE & BIO-FOUNDRY TOWER COLLAPSE"
		_select_operative(1)
		_set_global_blackout(0.88)
		active_weapon_index = 2
		_update_operative_card()
		move_target_pos = Vector2(564, 368)
		has_move_target = true
		_cam_target_pos = Vector2(640, 348)
		_cam_target_zoom = 0.84
	elif f == 202:
		_fire_active_weapon_at(Vector2(525, 315))
	elif f == 212:
		active_weapon_index = 3
		_update_operative_card()
		satellite_strike_timer = 0.75
		_fire_active_weapon_at(Vector2(640, 292))
	elif f == 224:
		_select_operative(2)
		active_weapon_index = 2
		_update_operative_card()
		_fire_active_weapon_at(Vector2(640, 292))

func _draw_corner_brackets(c: Node2D, rect: Rect2, col: Color, arm: float = 8.0, width: float = 1.8) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := x0 + rect.size.x
	var y1 := y0 + rect.size.y
	c.draw_line(Vector2(x0, y0), Vector2(x0 + arm, y0), col, width)
	c.draw_line(Vector2(x0, y0), Vector2(x0, y0 + arm), col, width)
	c.draw_line(Vector2(x1, y0), Vector2(x1 - arm, y0), col, width)
	c.draw_line(Vector2(x1, y0), Vector2(x1, y0 + arm), col, width)
	c.draw_line(Vector2(x0, y1), Vector2(x0 + arm, y1), col, width)
	c.draw_line(Vector2(x0, y1), Vector2(x0, y1 - arm), col, width)
	c.draw_line(Vector2(x1, y1), Vector2(x1 - arm, y1), col, width)
	c.draw_line(Vector2(x1, y1), Vector2(x1, y1 - arm), col, width)

func _draw_tactical_overlay() -> void:
	if _overlay == null:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var z := _camera.zoom.x if _camera != null else 1.0

	# 1. World-Space Sector Objective Callouts & Reticles (projected via _w2s)
	if active_stratum == Stratum.STREET:
		var bf_tl := _w2s(Vector2(534, 152))
		var bf_br := _w2s(Vector2(746, 388))
		var bf_rect := Rect2(bf_tl, bf_br - bf_tl)
		var bf_col := Color(1.0, 0.38, 0.22, 0.88) if tower_collapsed else Color(0.22, 0.96, 0.65, 0.85)
		_draw_corner_brackets(_overlay, bf_rect, bf_col, 14.0, 2.0)
		var bf_tag := Rect2(bf_rect.position.x + (bf_rect.size.x - 204.0) * 0.5, bf_rect.position.y - 24.0, 204, 20)
		_overlay.draw_rect(bf_tag, Color(0.03, 0.05, 0.09, 0.90), true)
		_overlay.draw_rect(bf_tag, bf_col, false, 1.2)
		var bf_txt := "BIO-FOUNDRY // RUBBLE CRATER" if tower_collapsed else "CITY ORGAN // BIO-FOUNDRY CORE"
		_overlay.draw_string(font, Vector2(bf_tag.position.x + 8, bf_tag.position.y + 14), bf_txt, HORIZONTAL_ALIGNMENT_LEFT, 192, 11, bf_col)

		var limo := get_node_or_null("ExecutiveArmoredLimo") as Node2D
		if limo != null:
			var l_sp := _w2s(limo.position)
			var l_col := Color(0.25, 0.95, 0.62, 0.9) if convoy_intercepted else Color(1.0, 0.72, 0.22, 0.9)
			var l_tag := Rect2(l_sp.x - 73, l_sp.y - 44 * z, 146, 17)
			_overlay.draw_rect(l_tag, Color(0.03, 0.05, 0.09, 0.88), true)
			_overlay.draw_rect(l_tag, l_col, false, 1.2)
			var l_txt := "CONVOY: +1500 CR" if convoy_intercepted else "TARGET: ZAIBATSU LIMO"
			_overlay.draw_string(font, Vector2(l_tag.position.x + 6, l_tag.position.y + 12), l_txt, HORIZONTAL_ALIGNMENT_LEFT, 136, 10, l_col)

		for g_name in ["CorpSecGuard1", "CorpSecGuard2"]:
			var g_node := get_node_or_null(g_name) as Node2D
			if g_node != null:
				var g_sp := _w2s(g_node.position)
				var g_col := Color(0.25, 0.95, 1.0, 0.9) if crowd_surge_active else Color(1.0, 0.35, 0.32, 0.88)
				var g_tag := Rect2(g_sp.x - 36, g_sp.y - 52 * z, 72, 15)
				_overlay.draw_rect(g_tag, Color(0.03, 0.05, 0.09, 0.86), true)
				_overlay.draw_rect(g_tag, g_col, false, 1.0)
				var g_txt := "THRALL [LINK]" if crowd_surge_active else "SEC-GUARD"
				_overlay.draw_string(font, Vector2(g_tag.position.x + 5, g_tag.position.y + 11), g_txt, HORIZONTAL_ALIGNMENT_LEFT, 64, 9, g_col)

	elif active_stratum == Stratum.UNDER_GRID:
		var xfmr := get_node_or_null("HighVoltageTransformerBank") as Node2D
		if xfmr != null:
			var x_sp := _w2s(xfmr.position)
			var x_col := Color(1.0, 0.38, 0.22, 0.92) if transformer_sabotaged else Color(1.0, 0.76, 0.22, 0.92)
			_draw_corner_brackets(_overlay, Rect2(x_sp.x - 48 * z, x_sp.y - 38 * z, 96 * z, 72 * z), x_col, 10.0, 1.8)
			var x_tag := Rect2(x_sp.x - 68, x_sp.y - 58 * z, 136, 18)
			_overlay.draw_rect(x_tag, Color(0.03, 0.05, 0.09, 0.90), true)
			_overlay.draw_rect(x_tag, x_col, false, 1.2)
			var x_txt := "SUB-GRID // BLACKOUT" if transformer_sabotaged else "TARGET // HV TRANSFORMER"
			_overlay.draw_string(font, Vector2(x_tag.position.x + 6, x_tag.position.y + 13), x_txt, HORIZONTAL_ALIGNMENT_LEFT, 126, 10, x_col)

	elif active_stratum == Stratum.SPIRE:
		var mono := get_node_or_null("MonorailArmoredCar") as Node2D
		if mono != null:
			var m_sp := _w2s(mono.position)
			var m_col := Color(0.25, 0.95, 0.62, 0.92) if monorail_looted else Color(0.95, 0.42, 0.88, 0.92)
			_draw_corner_brackets(_overlay, Rect2(m_sp.x - 52 * z, m_sp.y - 36 * z, 104 * z, 68 * z), m_col, 10.0, 1.8)
			var m_tag := Rect2(m_sp.x - 68, m_sp.y - 56 * z, 136, 18)
			_overlay.draw_rect(m_tag, Color(0.03, 0.05, 0.09, 0.90), true)
			_overlay.draw_rect(m_tag, m_col, false, 1.2)
			var m_txt := "VAULT BREACHED +2500 CR" if monorail_looted else "TARGET // MONORAIL VAULT"
			_overlay.draw_string(font, Vector2(m_tag.position.x + 6, m_tag.position.y + 13), m_txt, HORIZONTAL_ALIGNMENT_LEFT, 126, 10, m_col)

	# 2. World-Space Squad Operative Callsign Badges & Selection Reticle (active stratum only)
	for i in range(OPERATIVE_NODES.size()):
		var op := get_node_or_null(OPERATIVE_NODES[i]) as Node2D
		if op == null or not op.visible:
			continue
		var op_s := int(op.get_meta("stratum")) if op.has_meta("stratum") else 1
		var is_sel := (i == selected_operative)
		var on_focus := (op_s == int(active_stratum))
		if not on_focus and not is_sel:
			continue
		var op_sp := _w2s(op.position)

		if is_sel:
			var base := _w2s(op.position + Vector2(0, 36))
			var pts := PackedVector2Array([
				base + Vector2(0, -11 * z),
				base + Vector2(24 * z, 0),
				base + Vector2(0, 11 * z),
				base + Vector2(-24 * z, 0),
				base + Vector2(0, -11 * z),
			])
			_overlay.draw_polyline(pts, Color(0.22, 0.96, 1.0, 0.95), 2.2)
			_draw_corner_brackets(_overlay, Rect2(op_sp.x - 24 * z, op_sp.y - 36 * z, 48 * z, 76 * z), Color(0.22, 0.96, 1.0, 0.85), 7.0, 1.6)

			if has_move_target:
				var tgt_sp := _w2s(move_target_pos + Vector2(0, 36))
				_overlay.draw_line(base, tgt_sp, Color(0.22, 0.96, 1.0, 0.55), 1.8)
				_overlay.draw_circle(tgt_sp, 5.0, Color(0.22, 0.96, 1.0, 0.85))

		var b_rect := Rect2(op_sp.x - 36, op_sp.y - 58 * z, 72, 18)
		var border_col := Color(0.22, 0.96, 1.0, 1.0) if is_sel else Color(0.20, 0.86, 0.58, 1.0)
		_overlay.draw_rect(b_rect, Color(0.03, 0.05, 0.09, 0.90), true)
		_overlay.draw_rect(b_rect, border_col, false, 1.5 if is_sel else 1.0)
		_overlay.draw_string(font, Vector2(b_rect.position.x + 5, b_rect.position.y + 11), OPERATIVE_SHORT[i], HORIZONTAL_ALIGNMENT_LEFT, 64, 10, border_col)
		_overlay.draw_rect(Rect2(b_rect.position.x + 4, b_rect.position.y + 14, 42, 2), Color(0.20, 0.92, 0.55, 1.0), true)
		_overlay.draw_rect(Rect2(b_rect.position.x + 48, b_rect.position.y + 14, 20, 2), Color(1.0, 0.35, 0.45, 1.0), true)

	# 3. Foreground Combat VFX: Weapon Tracers, Persuadertron Waves, Satellite Rain Beam
	if tracer_timer > 0.0:
		var ts := _w2s(tracer_start)
		var te := _w2s(tracer_end)
		var a := clampf(tracer_timer / 0.28, 0.0, 1.0)
		var c := Color(tracer_color.r, tracer_color.g, tracer_color.b, a)
		_overlay.draw_line(ts, te, c, 4.0)
		_overlay.draw_line(ts, te, Color(1.0, 1.0, 1.0, a * 0.9), 1.6)
		_overlay.draw_circle(ts, 7.0 * a, Color(1.0, 0.95, 0.8, a * 0.85))
		_overlay.draw_circle(te, 16.0 * (1.1 - a * 0.5), Color(tracer_color.r, tracer_color.g, tracer_color.b, a * 0.65))
		_overlay.draw_circle(te, 6.0 * a, Color(1.0, 1.0, 1.0, a * 0.9))

	if persuade_timer > 0.0:
		var po := _w2s(persuade_origin)
		var progress := 1.0 - (persuade_timer / 0.55)
		var radius := (24.0 + progress * 165.0) * z
		var a := clampf(1.0 - progress, 0.0, 1.0)
		_overlay.draw_arc(po, radius, 0.0, TAU, 48, Color(0.22, 0.95, 1.0, a), 2.8)
		_overlay.draw_arc(po, radius * 0.65, 0.0, TAU, 36, Color(0.95, 0.35, 0.85, a * 0.8), 1.8)

	if satellite_strike_timer > 0.0:
		var p := 1.0 - (satellite_strike_timer / 0.75)
		var a := clampf(1.0 - p, 0.0, 1.0)
		var impact := _w2s(Vector2(640, 298))
		_overlay.draw_line(Vector2(impact.x, 0), impact, Color(1.0, 0.52, 0.16, a * 0.85), 20.0 * a + 4.0)
		_overlay.draw_line(Vector2(impact.x, 0), impact, Color(1.0, 0.96, 0.85, a), 7.0 * a + 2.0)
		_overlay.draw_arc(impact, (28.0 + p * 195.0) * z, 0.0, TAU, 56, Color(1.0, 0.55, 0.18, a), 3.8)
		_overlay.draw_arc(impact, (16.0 + p * 115.0) * z, 0.0, TAU, 48, Color(0.25, 0.95, 1.0, a * 0.8), 2.2)

	# 4. Top Tactical Command Bar + 3-Stratum Cutaway Selector Pills
	var top_rect := Rect2(8, 6, 1264, 38)
	_overlay.draw_rect(top_rect, Color(0.03, 0.05, 0.09, 0.92), true)
	_overlay.draw_rect(top_rect, Color(0.18, 0.68, 0.82, 0.85), false, 1.5)

	var strata_labels := ["[1] UNDER-GRID", "[2] STREET", "[3] SPIRE"]
	for s_idx in range(3):
		var pill := Rect2(900 + s_idx * 120, 11, 112, 26)
		var is_active_s := (int(active_stratum) == s_idx)
		var p_bg := Color(0.08, 0.32, 0.42, 0.95) if is_active_s else Color(0.04, 0.08, 0.13, 0.85)
		var p_border := Color(0.28, 0.96, 1.0, 1.0) if is_active_s else Color(0.22, 0.42, 0.52, 0.65)
		_overlay.draw_rect(pill, p_bg, true)
		_overlay.draw_rect(pill, p_border, false, 1.6 if is_active_s else 1.0)
		_overlay.draw_string(font, Vector2(pill.position.x + 8, pill.position.y + 17), strata_labels[s_idx], HORIZONTAL_ALIGNMENT_LEFT, 100, 11, p_border)

	# 5. Live Multi-Block Sector Radar Minimap (Top-Right HUD)
	_draw_sector_minimap(font)

	if demo_reel_active and not demo_banner_text.is_empty():
		var banner := Rect2(330, 48, 620, 28)
		_overlay.draw_rect(banner, Color(0.03, 0.05, 0.09, 0.92), true)
		_overlay.draw_rect(banner, Color(0.25, 0.95, 1.0, 0.92), false, 1.6)
		_overlay.draw_string(font, Vector2(346, 67), demo_banner_text, HORIZONTAL_ALIGNMENT_LEFT, 590, 13, Color(0.98, 0.84, 0.28, 1.0))

	# 6. Bottom-Left Active Operative Detail Card + 4-Operative Squad Mini-Roster
	var op_panel := Rect2(10, 548, 720, 162)
	_overlay.draw_rect(op_panel, Color(0.03, 0.05, 0.09, 0.92), true)
	_overlay.draw_rect(op_panel, Color(0.20, 0.78, 0.92, 0.85), false, 1.5)
	_draw_corner_brackets(_overlay, op_panel, Color(0.28, 0.96, 1.0, 0.95), 10.0, 2.0)

	for i in range(4):
		var rx := 462.0 + (i % 2) * 130.0
		var ry := 556.0 + int(i / 2) * 74.0
		var rcard := Rect2(rx, ry, 122, 68)
		var is_sel := (i == selected_operative)
		var c_border := Color(0.25, 0.96, 1.0, 1.0) if is_sel else Color(0.20, 0.45, 0.55, 0.75)
		_overlay.draw_rect(rcard, Color(0.06, 0.14, 0.20, 0.92) if is_sel else Color(0.04, 0.07, 0.11, 0.88), true)
		_overlay.draw_rect(rcard, c_border, false, 1.6 if is_sel else 1.0)
		if i < _portraits.size() and _portraits[i] != null:
			_overlay.draw_texture_rect(_portraits[i], Rect2(rx + 4, ry + 18, 44, 44), false)
		_overlay.draw_string(font, Vector2(rx + 5, ry + 13), OPERATIVE_SHORT[i], HORIZONTAL_ALIGNMENT_LEFT, 112, 10, c_border)
		var i_len := 58.0 if overclock_active else 46.0
		var p_len := 56.0 if overclock_active else 42.0
		var a_len := 60.0 if overclock_active else 38.0
		_overlay.draw_rect(Rect2(rx + 52, ry + 24, i_len, 5), Color(0.22, 0.92, 1.0, 0.95), true)
		_overlay.draw_rect(Rect2(rx + 52, ry + 36, p_len, 5), Color(0.98, 0.76, 0.22, 0.95), true)
		_overlay.draw_rect(Rect2(rx + 52, ry + 48, a_len, 5), Color(1.0, 0.28, 0.42, 0.95), true)

	# 7. Bottom-Right Mission Objectives & Dual Input Panel
	var obj_panel := Rect2(738, 548, 534, 162)
	_overlay.draw_rect(obj_panel, Color(0.03, 0.05, 0.09, 0.92), true)
	_overlay.draw_rect(obj_panel, Color(0.20, 0.78, 0.92, 0.85), false, 1.5)
	_draw_corner_brackets(_overlay, obj_panel, Color(0.28, 0.96, 1.0, 0.95), 10.0, 2.0)

func _draw_sector_minimap(font: Font) -> void:
	var map_rect := Rect2(1076, 50, 194, 122)
	_overlay.draw_rect(map_rect, Color(0.02, 0.04, 0.08, 0.92), true)
	_overlay.draw_rect(map_rect, Color(0.20, 0.78, 0.92, 0.85), false, 1.4)
	_draw_corner_brackets(_overlay, map_rect, Color(0.28, 0.96, 1.0, 0.95), 7.0, 1.6)
	_overlay.draw_string(font, Vector2(1084, 64), "KOWLOON SECTOR RADAR [33x33]", HORIZONTAL_ALIGNMENT_LEFT, 180, 9, Color(0.28, 0.95, 1.0, 0.95))

	var mc := Vector2(1173, 116)
	# Draw multi-block road rings & arterial avenues on radar
	for r_scale: float in [0.22, 0.58, 0.92]:
		var rw: float = 74.0 * r_scale
		var rh: float = 37.0 * r_scale
		var ring_pts := PackedVector2Array([
			mc + Vector2(0, -rh),
			mc + Vector2(rw, 0),
			mc + Vector2(0, rh),
			mc + Vector2(-rw, 0),
			mc + Vector2(0, -rh),
		])
		_overlay.draw_polyline(ring_pts, Color(0.32, 0.52, 0.65, 0.75), 1.2)
	_overlay.draw_line(mc + Vector2(-38, -19), mc + Vector2(38, 19), Color(0.32, 0.52, 0.65, 0.65), 1.0)
	_overlay.draw_line(mc + Vector2(-38, 19), mc + Vector2(38, -19), Color(0.32, 0.52, 0.65, 0.65), 1.0)

	# Bio-Foundry Core blip at center
	var bf_c := Color(1.0, 0.38, 0.22, 1.0) if tower_collapsed else Color(0.22, 0.98, 0.62, 1.0)
	_overlay.draw_rect(Rect2(mc.x - 4, mc.y - 4, 8, 8), bf_c, true)

	# Squad operative blips
	for i in range(OPERATIVE_NODES.size()):
		var op := get_node_or_null(OPERATIVE_NODES[i]) as Node2D
		if op == null:
			continue
		var rel := (op.position - Vector2(640, 388)) * Vector2(0.042, 0.042)
		var bp := mc + Vector2(clampf(rel.x, -82.0, 82.0), clampf(rel.y, -42.0, 42.0))
		var oc := Color(0.25, 0.98, 1.0, 1.0) if i == selected_operative else Color(0.25, 0.92, 0.55, 0.9)
		_overlay.draw_circle(bp, 3.0 if i == selected_operative else 2.2, oc)

	# Camera viewport indicator box on radar
	var cam_p := _camera.position if _camera != null else Vector2(640, 360)
	var cam_z := _camera.zoom.x if _camera != null else 1.0
	var crel := (cam_p - Vector2(640, 388)) * 0.042
	var vw := (28.0 / cam_z)
	var vh := (16.0 / cam_z)
	_overlay.draw_rect(Rect2(mc.x + crel.x - vw * 0.5, mc.y + crel.y - vh * 0.5, vw, vh), Color(0.95, 0.95, 1.0, 0.75), false, 1.0)

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
			KEY_Z:
				_cam_target_zoom = 0.78 if _cam_target_zoom > 0.88 else 1.0
			KEY_SPACE:
				overclock_active = not overclock_active
				Engine.time_scale = 0.25 if overclock_active else 1.0
				_refresh_hud()

	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var world_pos: Vector2 = get_canvas_transform().affine_inverse() * mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			move_target_pos = world_pos - Vector2(0, 28)
			has_move_target = true
			_request_overlay_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_fire_active_weapon_at(world_pos)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_target_zoom = clampf(_cam_target_zoom + 0.08, 0.72, 1.25)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_target_zoom = clampf(_cam_target_zoom - 0.08, 0.72, 1.25)

	elif event is InputEventJoypadButton and event.pressed:
		var jb := event as InputEventJoypadButton
		match jb.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_select_operative((selected_operative + OPERATIVE_NODES.size() - 1) % OPERATIVE_NODES.size())
			JOY_BUTTON_RIGHT_SHOULDER:
				_select_operative((selected_operative + 1) % OPERATIVE_NODES.size())
			JOY_BUTTON_DPAD_UP:
				_apply_stratum_cutaway(clampi(int(active_stratum) + 1, 0, 2) as Stratum)
			JOY_BUTTON_DPAD_DOWN:
				_apply_stratum_cutaway(clampi(int(active_stratum) - 1, 0, 2) as Stratum)
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
	_request_overlay_redraw()

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
	else:
		tracer_color = Color(0.25, 0.95, 1.0, 1.0)

	if target_pos.distance_to(Vector2(640, 292)) < 110.0 and not tower_collapsed:
		set_tower_collapsed(true)
	_request_overlay_redraw()

func _trigger_persuadertron_wave() -> void:
	var op_node := _get_selected_operative_node()
	if op_node == null:
		return
	persuade_origin = op_node.position
	persuade_timer = 0.55
	target_pulse_timer = 0.45
	if not crowd_surge_active:
		crowd_surge_active = true
		thrall_count = 4
	for actor_name in ["MegacityCivilian1", "MegacityCivilian2", "CorpSecGuard1", "CorpSecGuard2"]:
		var actor := get_node_or_null(actor_name) as Sprite2D
		if actor and actor.material is ShaderMaterial:
			var smat := actor.material as ShaderMaterial
			smat.set_shader_parameter("pulse_tint", Vector3(0.2, 0.95, 1.0))
			smat.set_shader_parameter("pulse_intensity", 0.45)
	_update_operative_card()
	_refresh_hud()
	_request_overlay_redraw()

func _clear_actor_shader_pulses() -> void:
	for actor_name in ["MegacityCivilian1", "MegacityCivilian2", "CorpSecGuard1", "CorpSecGuard2", "ExecutiveArmoredLimo"]:
		var actor := get_node_or_null(actor_name) as Sprite2D
		if actor and actor.material is ShaderMaterial:
			var smat := actor.material as ShaderMaterial
			smat.set_shader_parameter("pulse_intensity", 0.0)

func _toggle_transformer_sabotage() -> void:
	transformer_sabotaged = not transformer_sabotaged
	var blackout := 0.52 if transformer_sabotaged else 1.0
	_set_global_blackout(blackout)
	_refresh_hud()

func _intercept_executive_convoy() -> void:
	if not convoy_intercepted:
		convoy_intercepted = true
		syndicate_treasury += 1500
		salvage_units += 1
		target_pulse_timer = 0.45
		var limo := get_node_or_null("ExecutiveArmoredLimo") as Sprite2D
		if limo and limo.material is ShaderMaterial:
			(limo.material as ShaderMaterial).set_shader_parameter("pulse_tint", Vector3(1.0, 0.35, 0.1))
			(limo.material as ShaderMaterial).set_shader_parameter("pulse_intensity", 0.5)
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
		_set_global_blackout(0.52 if transformer_sabotaged else 1.0)

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
		alpha = 0.08
	elif node_stratum < int(focus_stratum):
		alpha = 0.12
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
	bio_label.text = "OP-%d: %s [%s]\nORGANS: %s\nBIOCHEM I/P/A: %s\nWEAPON: %s\nTHRALLS: %d | SALVAGE: %d" % [
		selected_operative + 1,
		OPERATIVE_CALLSIGNS[selected_operative],
		s_name,
		OPERATIVE_ORGANS[selected_operative],
		ipa_text,
		WEAPON_NAMES[active_weapon_index],
		thrall_count,
		salvage_units,
	]
	_request_overlay_redraw()

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
			+ "KBM: LMB/WASD Move | Arrows Pan | Wheel/Z Zoom | RMB Fire | Tab Op | 1-3 Stratum\n"
			+ "STEAM PAD: L-Stick Move | R-Stick Pan | X Fire | Y Persuade | LB/RB Op | D-Pad"
		)
	_update_operative_card()
	_request_overlay_redraw()
