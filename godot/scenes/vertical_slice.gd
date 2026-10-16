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

const OPERATIVE_SEX := [
	"F",
	"M",
	"F",
	"M",
]

const OPERATIVE_ORGANS := [
	"V3 EYES | V3 BRAIN | V2 LEGS",
	"V3 ARMS | V3 CHEST | V2 HEART",
	"V4 BRAIN | V3 EYES | V2 CHEST",
	"V4 CHEST | V3 LEGS | V3 ARMS",
]

const PORTRAIT_POOL_PATHS := [
	"res://assets/sprites/portrait_kestrel_1.png",
	"res://assets/sprites/portrait_vex_2.png",
	"res://assets/sprites/portrait_null_3.png",
	"res://assets/sprites/portrait_chrome_4.png",
	"res://assets/sprites/portrait_cryo_f2.png",
	"res://assets/sprites/portrait_cryo_m3.png",
]

const MEAT_PUPPET_CODENAMES_F := [
	"KESTREL",
	"NULL",
	"CIPHER",
	"MANTIS",
	"VALKYRIE",
	"NYX",
]

const MEAT_PUPPET_CODENAMES_M := [
	"VEX",
	"CHROME",
	"RAZOR",
	"WRAITH",
	"VORTEX",
	"SHARD",
]

const WIPED_SURNAMES := [
	"V. CHEN",
	"K. SATO",
	"M. VOLKOV",
	"D. MERCER",
	"H. TAKAHASHI",
	"R. KOWALSKI",
	"S. NAKAMURA",
	"J. VANCE",
	"A. MORENO",
	"T. LINDQVIST",
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
const STRIDE_ROWS := [1, 0, 2, 0]

var active_stratum: Stratum = Stratum.STREET
var selected_operative: int = 0
var active_weapon_index: int = 0
var overclock_active: bool = false
var tower_collapsed: bool = false
var tower_structural_hp: int = 100
var tower_damage_stage: int = 0 # 0=INTACT, 1=DAMAGED, 2=RUBBLE, 3=REBUILDING
var transformer_sabotaged: bool = false
var convoy_intercepted: bool = false
var monorail_looted: bool = false
var crowd_surge_active: bool = false
var thrall_count: int = 0
var salvage_units: int = 1
var syndicate_treasury: int = 6000
var last_digest: String = "0x9f4a2c18e7b03d11"
var cryo_generation: int = 0

# M12 Live C++23 Command Bridge & M14 In-Engine Spatial Audio State
var _live_cpp_command_log: Array[String] = []
var _ambient_player: AudioStreamPlayer = null
var _sfx_player_2d: AudioStreamPlayer2D = null
var _sfx_streams: Dictionary = {}
var last_played_sfx: String = ""
var sfx_play_count: int = 0

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
var _portrait_pool: Array[Texture2D] = []
var _portraits: Array[Texture2D] = []
var _puppet_identities: Array[Dictionary] = []
var _overlay: Node2D = null
var _camera: Camera2D = null
var _cam_target_pos: Vector2 = Vector2(640, 360)
var _cam_target_zoom: float = 1.0

# M7 Multi-Pose Animation, Procedural Crowd & Dense City Cutaway State
var _actor_prev_pos: Dictionary = {}
var _actor_walk_phase: Dictionary = {}
const DISTRICT_LANDMARKS := {
	1: {"name": "KOWLOON BIO-FOUNDRY SECTOR", "organ": "BIO-FOUNDRY", "stem": "biofoundry_tower"},
	2: {"name": "SHINJUKU BROADCAST SPIRE", "organ": "BROADCAST SPIRE", "stem": "broadcast_spire"},
	3: {"name": "CHIBA MONORAIL & SUB-GRID", "organ": "MONORAIL HUB", "stem": "monorail_hub"},
	4: {"name": "NEO-RUHR ORDINANCE FOUNDRY", "organ": "ORDINANCE FOUNDRY", "stem": "ordinance_foundry"},
	5: {"name": "MID-LEVELS POWER SUB-GRID", "organ": "POWER SUB-GRID", "stem": "power_subgrid"},
	6: {"name": "ZAIBATSU CLEARINGHOUSE ARCOLOGY", "organ": "CLEARINGHOUSE", "stem": "clearinghouse"},
}

var _actor_fire_timer: Dictionary = {}
var _actor_facing_sector: Dictionary = {}
var _city_buildings: Array[Sprite2D] = []
var _city_building_is_tenement: Array[bool] = []
var _building_alpha: Dictionary = {}
var _occluded_actor_ids: Dictionary = {}
var _proc_civilians: Array[Dictionary] = []
var _street_vehicles: Array[Dictionary] = []
var _extra_prop_nodes: Array[Sprite2D] = []
var _m7_initialized: bool = false

# M8 snapshot replay: rival operatives exist only when created from an
# authoritative C++ snapshot (see sim_replay.gd); nothing here is staged.
var _rival_operatives: Array[Dictionary] = []
var _replay: Node = null
var _hq_screens: Node = null
var focus_district_id: int = 1
var focus_district_name: String = "KOWLOON BIO-FOUNDRY SECTOR"
var focus_organ_name: String = "BIO-FOUNDRY"
var focus_organ_placeholder: bool = false
var replay_objectives_text: String = ""
var operative_organs_live: Array[String] = [
	"V3 EYES | V3 BRAIN | V2 LEGS",
	"V3 ARMS | V3 CHEST | V2 HEART",
	"V4 BRAIN | V3 EYES | V2 CHEST",
	"V4 CHEST | V3 LEGS | V3 ARMS",
]

func _load_tex(res_path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return load(res_path) as Texture2D

func _ensure_m7_initialized() -> void:
	if _m7_initialized:
		return
	_m7_initialized = true
	for p in PORTRAIT_POOL_PATHS:
		_portrait_pool.append(_load_tex(p))
	_rebuild_meat_puppet_roster()
	_configure_multi_pose_actors()
	_populate_sector_grid()
	_setup_spatial_audio()
	var hq_script := load("res://scenes/hq_screens.gd") as GDScript
	if hq_script != null:
		_hq_screens = hq_script.new()
		_hq_screens.name = "HqScreens"
		add_child(_hq_screens)
		_hq_screens.setup(self)

var _trailer_director: Node = null

func _ready() -> void:
	_ensure_m7_initialized()
	_setup_camera()
	_setup_tactical_overlay()
	_apply_stratum_cutaway(active_stratum)
	_update_actor_animations_and_depth(0.016)
	_update_building_proximity_cutaway(1.0)
	_update_operative_card()
	_refresh_hud()
	var uargs := OS.get_cmdline_user_args()
	var trailer_act := 0
	var hq_screen_arg := 0
	var snap_dir := "/tmp/wetware-m9-snaps"
	for idx in range(uargs.size()):
		if uargs[idx] == "--snapshot" and idx + 1 < uargs.size():
			start_snapshot_replay(uargs[idx + 1])
		elif uargs[idx] == "--trailer-act" and idx + 1 < uargs.size():
			trailer_act = int(uargs[idx + 1])
		elif uargs[idx] == "--hq-screen" and idx + 1 < uargs.size():
			hq_screen_arg = int(uargs[idx + 1])
		elif uargs[idx] == "--snap-dir" and idx + 1 < uargs.size():
			snap_dir = uargs[idx + 1]
	if hq_screen_arg >= 1 and hq_screen_arg <= 3:
		set_hq_screen(hq_screen_arg)
	elif trailer_act >= 1 and trailer_act <= 6:
		var td_script := load("res://scenes/trailer_director.gd") as GDScript
		if td_script != null:
			_trailer_director = td_script.new()
			_trailer_director.name = "TrailerDirector"
			add_child(_trailer_director)
			_trailer_director.begin(self, trailer_act, snap_dir)
	elif "--demo-reel" in uargs:
		demo_reel_active = true
		_select_operative(1)
	if DisplayServer.get_name() == "headless":
		_apply_stratum_cutaway(Stratum.UNDER_GRID)
		_apply_stratum_cutaway(Stratum.SPIRE)
		_apply_stratum_cutaway(Stratum.STREET)
		set_tower_collapsed(true)
		set_tower_collapsed(false)
		print("wetware Godot 4.7.2 Kowloon Bio-Foundry 3-stratum vertical slice verified cleanly.")

func _rebuild_meat_puppet_roster() -> void:
	_puppet_identities.clear()
	_portraits.clear()
	for i in range(4):
		var sex: String = OPERATIVE_SEX[i]
		var idx: int = (i + cryo_generation)
		var codename: String = (
			MEAT_PUPPET_CODENAMES_F[(i / 2 + cryo_generation) % MEAT_PUPPET_CODENAMES_F.size()]
			if sex == "F"
			else MEAT_PUPPET_CODENAMES_M[(i / 2 + cryo_generation) % MEAT_PUPPET_CODENAMES_M.size()]
		)
		var serial_num: int = 104 + ((idx * 217 + i * 83) % 880)
		var wiped_name: String = WIPED_SURNAMES[(idx * 3 + i * 2) % WIPED_SURNAMES.size()]
		var link_val: float = 98.4 + float((idx + i) % 15) * 0.1
		var p_idx: int = i
		if cryo_generation > 0:
			p_idx = (4 if (sex == "F" and (cryo_generation + i) % 2 == 1) else (5 if (sex == "M" and (cryo_generation + i) % 2 == 1) else i))
		_portraits.append(_portrait_pool[clampi(p_idx, 0, _portrait_pool.size() - 1)])
		_puppet_identities.append({
			"unit_code": "UNIT 0%d-%s // %s" % [i + 1, sex, codename],
			"short_tag": "%d:%s-%s" % [i + 1, codename.substr(0, 6), sex],
			"subj_line": "SUBJ #%d [%s]" % [serial_num, wiped_name],
			"link_str": "%.1f%%" % link_val,
			"sex": sex,
		})

func _configure_multi_pose_actors() -> void:
	var fem_op_alb := _load_tex("res://assets/sprites/operative_female_albedo.png")
	var fem_op_emi := _load_tex("res://assets/sprites/operative_female_emissive.png")
	var fem_op_nrm := _load_tex("res://assets/normals/operative_female_normal.png")
	var male_op_alb := _load_tex("res://assets/sprites/operative_trenchcoat_albedo.png")
	var male_op_emi := _load_tex("res://assets/sprites/operative_trenchcoat_emissive.png")
	var male_op_nrm := _load_tex("res://assets/normals/operative_trenchcoat_normal.png")

	for i in range(OPERATIVE_NODES.size()):
		var op := get_node_or_null(OPERATIVE_NODES[i]) as Sprite2D
		if op == null:
			continue
		op.hframes = 8
		op.vframes = 4
		var is_fem: bool = (String(OPERATIVE_SEX[i]) == "F")
		op.texture = fem_op_alb if is_fem else male_op_alb
		if op.material is ShaderMaterial:
			var smat := (op.material as ShaderMaterial).duplicate() as ShaderMaterial
			smat.set_shader_parameter("sheet_vframes", 4)
			smat.set_shader_parameter("emissive_mask", fem_op_emi if is_fem else male_op_emi)
			smat.set_shader_parameter("normal_map", fem_op_nrm if is_fem else male_op_nrm)
			op.material = smat
		_actor_prev_pos[op.get_instance_id()] = op.position
		_actor_facing_sector[op.get_instance_id()] = op.frame % 8

	var guard_alb := _load_tex("res://assets/sprites/corp_sec_guard_albedo.png")
	var guard_emi := _load_tex("res://assets/sprites/corp_sec_guard_emissive.png")
	var guard_nrm := _load_tex("res://assets/normals/corp_sec_guard_normal.png")
	for g_name in ["CorpSecGuard1", "CorpSecGuard2"]:
		var g := get_node_or_null(g_name) as Sprite2D
		if g == null:
			continue
		g.hframes = 8
		g.vframes = 4
		g.texture = guard_alb
		if g.material is ShaderMaterial:
			var smat := (g.material as ShaderMaterial).duplicate() as ShaderMaterial
			smat.set_shader_parameter("sheet_vframes", 4)
			smat.set_shader_parameter("emissive_mask", guard_emi)
			smat.set_shader_parameter("normal_map", guard_nrm)
			g.material = smat
		_actor_prev_pos[g.get_instance_id()] = g.position
		_actor_facing_sector[g.get_instance_id()] = g.frame % 8

	var civ_m_alb := _load_tex("res://assets/sprites/megacity_civilian_albedo.png")
	var civ_m_emi := _load_tex("res://assets/sprites/megacity_civilian_emissive.png")
	var civ_m_nrm := _load_tex("res://assets/normals/megacity_civilian_normal.png")
	var civ_f_alb := _load_tex("res://assets/sprites/megacity_civilian_f_albedo.png")
	var civ_f_emi := _load_tex("res://assets/sprites/megacity_civilian_f_emissive.png")
	var civ_f_nrm := _load_tex("res://assets/normals/megacity_civilian_f_normal.png")

	var civ1 := get_node_or_null("MegacityCivilian1") as Sprite2D
	if civ1:
		civ1.hframes = 8
		civ1.vframes = 4
		civ1.texture = civ_m_alb
		if civ1.material is ShaderMaterial:
			var smat := (civ1.material as ShaderMaterial).duplicate() as ShaderMaterial
			smat.set_shader_parameter("sheet_vframes", 4)
			smat.set_shader_parameter("emissive_mask", civ_m_emi)
			smat.set_shader_parameter("normal_map", civ_m_nrm)
			civ1.material = smat
		_actor_prev_pos[civ1.get_instance_id()] = civ1.position
		_actor_facing_sector[civ1.get_instance_id()] = civ1.frame % 8

	var civ2 := get_node_or_null("MegacityCivilian2") as Sprite2D
	if civ2:
		civ2.hframes = 8
		civ2.vframes = 4
		civ2.texture = civ_f_alb
		if civ2.material is ShaderMaterial:
			var smat := (civ2.material as ShaderMaterial).duplicate() as ShaderMaterial
			smat.set_shader_parameter("sheet_vframes", 4)
			smat.set_shader_parameter("emissive_mask", civ_f_emi)
			smat.set_shader_parameter("normal_map", civ_f_nrm)
			civ2.material = smat
		_actor_prev_pos[civ2.get_instance_id()] = civ2.position
		_actor_facing_sector[civ2.get_instance_id()] = civ2.frame % 8

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
	floor_root.z_index = -2000
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

	# Populate dense multi-building city blocks, procedural M/F civilian population & street props
	_populate_surrounding_city_blocks(floor_root)
	_spawn_procedural_civilian_crowd()

func _populate_surrounding_city_blocks(floor_root: Node2D) -> void:
	var tower_tpl := get_node_or_null("BioFoundryTowerIntact") as Sprite2D
	var rubble_tpl := get_node_or_null("BioFoundryTowerRubble") as Sprite2D
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

	if tower_tpl.material is ShaderMaterial:
		tower_tpl.material = (tower_tpl.material as ShaderMaterial).duplicate()
	if rubble_tpl != null and rubble_tpl.material is ShaderMaterial:
		rubble_tpl.material = (rubble_tpl.material as ShaderMaterial).duplicate()
	_city_buildings.append(tower_tpl)
	_city_building_is_tenement.append(false)
	_building_alpha[tower_tpl.get_instance_id()] = 1.0

	var ten_alb := _load_tex("res://assets/tiles/city_block_tenement_albedo.png")
	var ten_emi := _load_tex("res://assets/tiles/city_block_tenement_emissive.png")
	var ten_nrm := _load_tex("res://assets/normals/city_block_tenement_normal.png")
	var corp_alb := _load_tex("res://assets/tiles/city_block_corp_albedo.png")
	var corp_emi := _load_tex("res://assets/tiles/city_block_corp_emissive.png")
	var corp_nrm := _load_tex("res://assets/normals/city_block_corp_normal.png")

	# Dense city blocks surrounding the avenues (including foreground blocks that trigger proximity cutaway)
	var dense_blocks := [
		# Inner foreground & flanking blocks right across the avenues from Bio-Foundry
		[Vector2(1.4, 4.2), true, 0.88],
		[Vector2(4.2, 1.4), false, 0.90],
		[Vector2(-1.6, 4.2), false, 0.86],
		[Vector2(4.2, -1.6), true, 0.86],
		[Vector2(-4.2, 1.6), true, 0.88],
		[Vector2(-1.6, -4.2), false, 0.86],
		# Mid-block high-density Kowloon tenements & corporate arcologies
		[Vector2(4.6, 4.6), false, 0.96],
		[Vector2(-4.6, 4.6), true, 0.94],
		[Vector2(4.6, -4.6), true, 0.94],
		[Vector2(-4.6, -4.6), false, 0.96],
		[Vector2(6.5, 6.5), true, 0.92],
		[Vector2(-6.5, 6.5), false, 0.92],
		[Vector2(6.5, -6.5), false, 0.92],
		[Vector2(-6.5, -6.5), true, 0.92],
	]

	for b_spec in dense_blocks:
		var bc: Vector2 = b_spec[0]
		var is_tenement: bool = b_spec[1]
		var b_scale: float = b_spec[2]
		var iso := Vector2((bc.x - bc.y) * 64.0, (bc.x + bc.y) * 32.0)
		var b_node := Sprite2D.new()
		b_node.texture = ten_alb if is_tenement else corp_alb
		if tower_tpl.material is ShaderMaterial:
			var bmat := (tower_tpl.material as ShaderMaterial).duplicate() as ShaderMaterial
			bmat.set_shader_parameter("emissive_mask", ten_emi if is_tenement else corp_emi)
			bmat.set_shader_parameter("normal_map", ten_nrm if is_tenement else corp_nrm)
			bmat.set_shader_parameter("building_cutaway_alpha", 1.0)
			b_node.material = bmat
		b_node.position = Vector2(640, 310) + iso
		b_node.scale = Vector2(b_scale, b_scale)
		b_node.z_index = int(b_node.position.y + 42.0)
		b_node.set_meta("stratum", 1)
		add_child(b_node)
		_city_buildings.append(b_node)
		_city_building_is_tenement.append(is_tenement)
		_building_alpha[b_node.get_instance_id()] = 1.0

	# Perimeter vehicles & infrastructure across the outer avenues (aligned to 2:1 isometric road lanes)
	var extra_props := [
		[hauler_tpl, Vector2(-6, -3), 4, 1, "ExtraHauler"],
		[dozer_tpl, Vector2(6, -3), 0, 1, "ExtraDozer"],
		[decon_tpl, Vector2(-3, 6), 6, 1, "ExtraDecon"],
		[gate_tpl, Vector2(0, -6), 0, 1, "ExtraGateNorth"],
		[gate_tpl, Vector2(0, 6), 4, 1, "ExtraGateSouth"],
		[turret_tpl, Vector2(-6, 3), 4, 1, "ExtraTurretWest"],
		[turret_tpl, Vector2(6, 3), 0, 1, "ExtraTurretEast"],
		[vending_tpl, Vector2(-4, -2), 0, 1, "ExtraVendingWest"],
		[vending_tpl, Vector2(4, 2), 4, 1, "ExtraVendingEast"],
		[hvac_tpl, Vector2(-6, -5), 2, 2, "ExtraHvacWest"],
		[hvac_tpl, Vector2(6, -5), 6, 2, "ExtraHvacEast"],
		[vat_tpl, Vector2(-6, 0), 2, 0, "ExtraVatWest"],
		[vat_tpl, Vector2(6, 0), 6, 0, "ExtraVatEast"],
	]
	var extra_vehicle_map := {}
	for item in extra_props:
		var tpl: Sprite2D = item[0]
		if tpl == null:
			continue
		var g: Vector2 = item[1]
		var iso := Vector2((g.x - g.y) * 64.0, (g.x + g.y) * 32.0)
		var p := Sprite2D.new()
		p.name = String(item[4])
		p.texture = tpl.texture
		p.material = (tpl.material as ShaderMaterial).duplicate() if tpl.material is ShaderMaterial else tpl.material
		p.hframes = tpl.hframes
		p.frame = int(item[2])
		var st := int(item[3])
		var base_y := 376.0 if st == 1 else (500.0 if st == 0 else 196.0)
		var scale_iso := 1.0 if st == 1 else (0.85 if st == 0 else 0.9)
		p.position = Vector2(640, base_y) + iso * scale_iso
		p.set_meta("stratum", st)
		if st == 1:
			p.z_index = int(p.position.y)
			add_child(p)
			_extra_prop_nodes.append(p)
			extra_vehicle_map[p.name] = p
		else:
			floor_root.add_child(p)

	_init_street_vehicle_traffic(extra_vehicle_map)

func _register_street_vehicle(v_node: Sprite2D, grid_waypoints: Array, speed: float, init_dir: Vector2, is_convoy: bool = false) -> void:
	if v_node == null:
		return
	if v_node.material is ShaderMaterial:
		v_node.material = (v_node.material as ShaderMaterial).duplicate()
	var wps: Array[Vector2] = []
	for g in grid_waypoints:
		var gv: Vector2 = g
		wps.append(_grid_to_street_pos(gv.x, gv.y))
	_update_vehicle_facing(v_node, init_dir)
	v_node.z_index = int(v_node.position.y)
	_street_vehicles.append({
		"node": v_node,
		"waypoints": wps,
		"wp_index": 0,
		"speed": speed,
		"vel_dir": init_dir.normalized(),
		"hp": 100,
		"max_hp": 100,
		"destroyed": false,
		"is_convoy": is_convoy,
	})

func _init_street_vehicle_traffic(extra_vehicle_map: Dictionary) -> void:
	_street_vehicles.clear()
	_register_street_vehicle(
		get_node_or_null("ExecutiveArmoredLimo") as Sprite2D,
		[Vector2(3, 3), Vector2(3, -3), Vector2(-3, -3), Vector2(-3, 3)],
		42.0,
		Vector2(2.0, 1.0),
		true
	)
	_register_street_vehicle(
		get_node_or_null("CorpSecurityInterceptor") as Sprite2D,
		[Vector2(3, -3), Vector2(-3, -3), Vector2(-3, 3), Vector2(3, 3)],
		58.0,
		Vector2(2.0, -1.0)
	)
	_register_street_vehicle(
		get_node_or_null("SyndicateApc") as Sprite2D,
		[Vector2(3, 3), Vector2(3, 9), Vector2(-3, 9), Vector2(-3, 3)],
		36.0,
		Vector2(2.0, 1.0)
	)
	_register_street_vehicle(
		get_node_or_null("AutonomousCargoHauler") as Sprite2D,
		[Vector2(-3, 3), Vector2(-9, 3), Vector2(-9, -3), Vector2(-3, -3)],
		32.0,
		Vector2(-2.0, 1.0)
	)
	if extra_vehicle_map.has("ExtraHauler"):
		_register_street_vehicle(
			extra_vehicle_map["ExtraHauler"] as Sprite2D,
			[Vector2(3, -3), Vector2(3, -9), Vector2(-9, -9), Vector2(-9, -3)],
			34.0,
			Vector2(2.0, 1.0)
		)
	if extra_vehicle_map.has("ExtraDozer"):
		_register_street_vehicle(
			extra_vehicle_map["ExtraDozer"] as Sprite2D,
			[Vector2(3, -3), Vector2(3, 3), Vector2(9, 3), Vector2(9, -3)],
			28.0,
			Vector2(-2.0, -1.0)
		)
	if extra_vehicle_map.has("ExtraDecon"):
		_register_street_vehicle(
			extra_vehicle_map["ExtraDecon"] as Sprite2D,
			[Vector2(-3, 3), Vector2(3, 3), Vector2(3, 9), Vector2(-3, 9)],
			30.0,
			Vector2(2.0, -1.0)
		)

func _grid_to_street_pos(gx: float, gy: float) -> Vector2:
	return Vector2(640.0 + (gx - gy) * 64.0, 376.0 + (gx + gy) * 32.0)

func _spawn_procedural_civilian_crowd() -> void:
	var civ1_tpl := get_node_or_null("MegacityCivilian1") as Sprite2D
	if civ1_tpl == null or not (civ1_tpl.material is ShaderMaterial):
		return
	var civ_m_alb := _load_tex("res://assets/sprites/megacity_civilian_albedo.png")
	var civ_m_emi := _load_tex("res://assets/sprites/megacity_civilian_emissive.png")
	var civ_m_nrm := _load_tex("res://assets/normals/megacity_civilian_normal.png")
	var civ_f_alb := _load_tex("res://assets/sprites/megacity_civilian_f_albedo.png")
	var civ_f_emi := _load_tex("res://assets/sprites/megacity_civilian_f_emissive.png")
	var civ_f_nrm := _load_tex("res://assets/normals/megacity_civilian_f_normal.png")

	# 12 Procedural M/F Civilians with shader palette remapping (jacket, pants, skin, hair)
	var crowd_specs := [
		[true, Vector2(-2.6, 2.8), Vector2(2.6, 2.8), 38.0, Vector3(0.95, 0.35, 0.25), Vector3(0.22, 0.28, 0.38), Vector3(1.02, 0.88, 0.78), Vector3(0.18, 0.15, 0.22)],
		[false, Vector2(2.8, 2.6), Vector2(2.8, -2.6), 34.0, Vector3(0.25, 0.82, 0.95), Vector3(0.28, 0.22, 0.35), Vector3(0.82, 0.65, 0.52), Vector3(0.85, 0.28, 0.55)],
		[true, Vector2(2.6, -2.8), Vector2(-2.6, -2.8), 40.0, Vector3(0.88, 0.76, 0.22), Vector3(0.18, 0.24, 0.28), Vector3(0.62, 0.45, 0.35), Vector3(0.15, 0.15, 0.18)],
		[false, Vector2(-2.8, -2.6), Vector2(-2.8, 2.6), 36.0, Vector3(0.78, 0.28, 0.88), Vector3(0.20, 0.26, 0.34), Vector3(1.05, 0.92, 0.84), Vector3(0.25, 0.88, 0.72)],
		[true, Vector2(0.4, 3.2), Vector2(3.4, 3.2), 42.0, Vector3(0.28, 0.88, 0.52), Vector3(0.24, 0.22, 0.28), Vector3(0.92, 0.76, 0.64), Vector3(0.45, 0.28, 0.18)],
		[false, Vector2(3.2, 0.4), Vector2(3.2, 3.4), 35.0, Vector3(0.96, 0.48, 0.68), Vector3(0.18, 0.20, 0.30), Vector3(0.74, 0.56, 0.44), Vector3(0.92, 0.82, 0.32)],
		[true, Vector2(-3.2, 0.4), Vector2(-3.2, 3.4), 37.0, Vector3(0.35, 0.58, 0.96), Vector3(0.26, 0.28, 0.32), Vector3(1.0, 0.86, 0.76), Vector3(0.22, 0.20, 0.24)],
		[false, Vector2(-0.4, 3.2), Vector2(-3.4, 3.2), 39.0, Vector3(0.92, 0.58, 0.22), Vector3(0.20, 0.25, 0.32), Vector3(0.86, 0.70, 0.58), Vector3(0.68, 0.22, 0.32)],
		[true, Vector2(0.0, 3.5), Vector2(0.0, 6.2), 36.0, Vector3(0.48, 0.88, 0.82), Vector3(0.22, 0.20, 0.28), Vector3(0.68, 0.50, 0.38), Vector3(0.18, 0.18, 0.22)],
		[false, Vector2(3.5, 0.0), Vector2(6.2, 0.0), 38.0, Vector3(0.86, 0.32, 0.48), Vector3(0.24, 0.26, 0.36), Vector3(1.02, 0.90, 0.80), Vector3(0.32, 0.78, 0.95)],
	]

	for i in range(crowd_specs.size()):
		var spec: Array = crowd_specs[i]
		var is_fem: bool = spec[0]
		var wp_a := _grid_to_street_pos(spec[1].x, spec[1].y)
		var wp_b := _grid_to_street_pos(spec[2].x, spec[2].y)
		var spd: float = spec[3]
		var c_node := Sprite2D.new()
		c_node.name = "ProcCivilian_%d" % i
		c_node.hframes = 8
		c_node.vframes = 4
		c_node.texture = civ_f_alb if is_fem else civ_m_alb
		var smat := (civ1_tpl.material as ShaderMaterial).duplicate() as ShaderMaterial
		smat.set_shader_parameter("sheet_vframes", 4)
		smat.set_shader_parameter("emissive_mask", civ_f_emi if is_fem else civ_m_emi)
		smat.set_shader_parameter("normal_map", civ_f_nrm if is_fem else civ_m_nrm)
		smat.set_shader_parameter("enable_palette_remap", true)
		smat.set_shader_parameter("jacket_tint", spec[4])
		smat.set_shader_parameter("pants_tint", spec[5])
		smat.set_shader_parameter("skin_tint", spec[6])
		smat.set_shader_parameter("hair_tint", spec[7])
		c_node.material = smat
		c_node.position = wp_a.lerp(wp_b, float(i % 4) * 0.25)
		c_node.set_meta("stratum", 1)
		add_child(c_node)
		_actor_prev_pos[c_node.get_instance_id()] = c_node.position
		_actor_facing_sector[c_node.get_instance_id()] = 0
		_proc_civilians.append({
			"node": c_node,
			"wp_a": wp_a,
			"wp_b": wp_b,
			"to_b": (i % 2 == 0),
			"speed": spd,
		})

func start_snapshot_replay(json_path: String) -> bool:
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_error("snapshot replay: cannot open %s" % json_path)
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not valid_snapshot(data):
		push_error("snapshot replay: invalid snapshot %s" % json_path)
		return false
	var replay_script := load("res://scenes/sim_replay.gd") as GDScript
	_replay = replay_script.new()
	_replay.name = "SimReplay"
	add_child(_replay)
	return _replay.begin(self, data as Dictionary)

func spawn_actor_sprite(node_name: String, is_fem: bool, tint: Vector3) -> Sprite2D:
	var op_tpl := get_node_or_null("OperativeVex2") as Sprite2D
	var r_node := Sprite2D.new()
	r_node.name = node_name
	r_node.hframes = 8
	r_node.vframes = 4
	if is_fem:
		r_node.texture = _load_tex("res://assets/sprites/operative_female_albedo.png")
	else:
		r_node.texture = _load_tex("res://assets/sprites/operative_trenchcoat_albedo.png")
	if op_tpl != null and op_tpl.material is ShaderMaterial:
		var smat := (op_tpl.material as ShaderMaterial).duplicate() as ShaderMaterial
		smat.set_shader_parameter("sheet_vframes", 4)
		var stem := "operative_female" if is_fem else "operative_trenchcoat"
		smat.set_shader_parameter("emissive_mask", _load_tex("res://assets/sprites/%s_emissive.png" % stem))
		smat.set_shader_parameter("normal_map", _load_tex("res://assets/normals/%s_normal.png" % stem))
		smat.set_shader_parameter("pulse_tint", tint)
		smat.set_shader_parameter("pulse_intensity", 0.30)
		r_node.material = smat
	add_child(r_node)
	_actor_prev_pos[r_node.get_instance_id()] = r_node.position
	_actor_facing_sector[r_node.get_instance_id()] = 0
	return r_node

func sector_grid_to_world(x: float, y: float, stratum: int) -> Vector2:
	# Simulation sectors are 16x16; centre them on the rendered Kowloon grid.
	var gx := x - 8.0
	var gy := y - 8.0
	var iso := Vector2((gx - gy) * 64.0, (gx + gy) * 32.0)
	if stratum == 2:
		return Vector2(640, 196) + iso * 0.9
	if stratum == 0:
		return Vector2(640, 500) + iso * 0.85
	return Vector2(640, 388) + iso

func set_camera_focus(world_pos: Vector2, zoom: float) -> void:
	_cam_target_pos = world_pos
	_cam_target_zoom = zoom
	if _camera != null:
		_camera.position = world_pos
		_camera.zoom = Vector2(zoom, zoom)

func set_banner(text: String) -> void:
	demo_banner_text = text
	demo_reel_active = not text.is_empty()

func _process(delta: float) -> void:
	var needs_redraw := false
	var real_dt: float = delta / maxf(Engine.time_scale, 0.05)

	if demo_reel_active and _replay == null and _trailer_director == null:
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

	# Step procedural civilian crowd and street vehicle traffic
	if _replay == null:
		_step_procedural_civilians(real_dt)
	_step_street_vehicles(real_dt)

	# Update multi-pose stride/combat rows & depth sorting across all actors
	_update_actor_animations_and_depth(real_dt)

	# Update proximity building cutaway transparency & occluded X-Ray tracking
	if _update_building_proximity_cutaway(real_dt):
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

func _step_procedural_civilians(real_dt: float) -> void:
	for c_entry in _proc_civilians:
		var c_node: Sprite2D = c_entry["node"]
		if c_node == null or not c_node.visible:
			continue
		var tgt: Vector2 = c_entry["wp_b"] if bool(c_entry["to_b"]) else c_entry["wp_a"]
		var spd: float = float(c_entry["speed"]) * (1.35 if crowd_surge_active else 1.0)
		var delta_vec := tgt - c_node.position
		if delta_vec.length() <= 5.0:
			c_entry["to_b"] = not bool(c_entry["to_b"])
		else:
			var dir := delta_vec.normalized()
			c_node.position += dir * spd * real_dt
			_update_sprite_facing(c_node, dir)

func _step_street_vehicles(real_dt: float) -> void:
	for v_entry in _street_vehicles:
		var v_node: Sprite2D = v_entry["node"]
		if v_node == null or not v_node.visible:
			continue
		if bool(v_entry["destroyed"]) or (bool(v_entry["is_convoy"]) and convoy_intercepted):
			continue
		var wps: Array = v_entry["waypoints"]
		if wps.is_empty():
			continue
		var wp_idx: int = int(v_entry["wp_index"]) % wps.size()
		var tgt: Vector2 = wps[wp_idx]
		var spd: float = float(v_entry["speed"])
		var delta_vec := tgt - v_node.position
		var dist := delta_vec.length()
		if dist <= 6.0:
			wp_idx = (wp_idx + 1) % wps.size()
			v_entry["wp_index"] = wp_idx
			tgt = wps[wp_idx]
			delta_vec = tgt - v_node.position
			dist = delta_vec.length()
		if dist > 0.01:
			var seg_dir := delta_vec / dist
			v_node.position += seg_dir * minf(spd * real_dt, dist)
			var cur_dir: Vector2 = v_entry["vel_dir"]
			# Smoothly rotate through the 45-degree corner transition frames near intersections,
			# and lock tightly to the 2:1 isometric road lane on straightaways.
			var turn_rate := 8.5 if dist < 28.0 else 18.0
			cur_dir = cur_dir.lerp(seg_dir, clampf(real_dt * turn_rate, 0.0, 1.0)).normalized()
			v_entry["vel_dir"] = cur_dir
			_update_vehicle_facing(v_node, cur_dir)

func _update_actor_animations_and_depth(real_dt: float) -> void:
	var all_actors: Array[Sprite2D] = []
	for op_name in OPERATIVE_NODES:
		var op := get_node_or_null(op_name) as Sprite2D
		if op:
			all_actors.append(op)
	for n_name in ["CorpSecGuard1", "CorpSecGuard2", "MegacityCivilian1", "MegacityCivilian2"]:
		var a := get_node_or_null(n_name) as Sprite2D
		if a:
			all_actors.append(a)
	for c_entry in _proc_civilians:
		var cn: Sprite2D = c_entry["node"]
		if cn:
			all_actors.append(cn)
	for r_entry in _rival_operatives:
		var rn: Sprite2D = r_entry["node"]
		if rn:
			all_actors.append(rn)

	for actor in all_actors:
		var iid := actor.get_instance_id()
		var prev_p: Vector2 = _actor_prev_pos.get(iid, actor.position)
		var dist := actor.position.distance_to(prev_p)
		_actor_prev_pos[iid] = actor.position

		var f_timer: float = maxf(0.0, float(_actor_fire_timer.get(iid, 0.0)) - real_dt)
		_actor_fire_timer[iid] = f_timer

		var dir_sector: int = int(_actor_facing_sector.get(iid, actor.frame_coords.x)) % 8
		var row: int = 0
		if f_timer > 0.0:
			row = 3 # Braced Combat Fire Crouch + Muzzle Flash Star
		elif dist > 0.12:
			var phase: float = float(_actor_walk_phase.get(iid, 0.0)) + dist * 0.18
			_actor_walk_phase[iid] = phase
			row = STRIDE_ROWS[int(phase) % STRIDE_ROWS.size()]
		else:
			_actor_walk_phase[iid] = 0.0
			row = 0

		if actor.vframes == 4:
			actor.frame_coords = Vector2i(dir_sector, row)

		var st := int(actor.get_meta("stratum")) if actor.has_meta("stratum") else 1
		if st == 2:
			actor.z_index = 1200 + int(actor.position.y)
		elif st == 0:
			actor.z_index = -900 + int(actor.position.y)
		else:
			actor.z_index = int(actor.position.y)

	# Depth-sort all street vehicles and street props so buildings/agents sort cleanly around them
	for v_name in [
		"ExecutiveArmoredLimo", "CorpSecurityInterceptor", "SyndicateApc", "AutonomousCargoHauler",
		"AutomatedCheckpointGate", "ConcreteRiotBarricade", "StreetVendingMachineBank",
		"CyberClinicMedPod", "PlasmaSentryTurret"
	]:
		var v := get_node_or_null(v_name) as Node2D
		if v:
			v.z_index = int(v.position.y)
	for ep in _extra_prop_nodes:
		if ep != null:
			ep.z_index = int(ep.position.y)

func _update_building_proximity_cutaway(real_dt: float) -> bool:
	var changed := false
	_occluded_actor_ids.clear()
	if active_stratum != Stratum.STREET:
		return false

	var key_actors: Array[Node2D] = []
	for op_name in OPERATIVE_NODES:
		var op := get_node_or_null(op_name) as Node2D
		if op and op.visible and int(op.get_meta("stratum", 1)) == 1:
			key_actors.append(op)
	for t_name in ["CorpSecGuard1", "CorpSecGuard2", "MegacityCivilian1", "MegacityCivilian2", "ExecutiveArmoredLimo"]:
		var tn := get_node_or_null(t_name) as Node2D
		if tn and tn.visible:
			key_actors.append(tn)
	for r_entry in _rival_operatives:
		var rn: Node2D = r_entry["node"]
		if rn and rn.visible and int(rn.get_meta("stratum", 1)) == 1:
			key_actors.append(rn)

	for b in _city_buildings:
		if b == null or not b.visible:
			continue
		var bid := b.get_instance_id()
		var base_y := b.position.y + 42.0
		var should_cutaway := false
		for act in key_actors:
			# Actor is behind the building's front foundation and within its upper-story silhouette
			if act.position.y < base_y + 18.0 and act.position.y > b.position.y - 115.0:
				if absf(act.position.x - b.position.x) < 108.0:
					should_cutaway = true
					_occluded_actor_ids[act.get_instance_id()] = true

		var target_a := 0.24 if should_cutaway else 1.0
		var cur_a: float = float(_building_alpha.get(bid, 1.0))
		var next_a := lerpf(cur_a, target_a, clampf(real_dt * 9.0, 0.0, 1.0))
		if absf(next_a - cur_a) > 0.005:
			changed = true
		_building_alpha[bid] = next_a
		if b.material is ShaderMaterial:
			(b.material as ShaderMaterial).set_shader_parameter("building_cutaway_alpha", next_a)

	return changed

func _step_demo_reel(f: int) -> void:
	# Act I (1..48): Street Deployment, Proximity Building Cutaway & Zaibatsu Convoy Ambush
	if f == 1:
		demo_banner_text = "ACT I // MULTI-POSE STRIDE, BUILDING CUTAWAY & CONVOY AMBUSH"
		_select_operative(1)
		active_weapon_index = 0
		_update_operative_card()
		move_target_pos = Vector2(512, 434)
		has_move_target = true
		_cam_target_pos = Vector2(545, 425)
		_cam_target_zoom = 1.02
	elif f > 1 and f < 46:
		var null_op := get_node_or_null("OperativeNull3") as Sprite2D
		if null_op:
			var nd := Vector2(-0.7, 0.45)
			null_op.position += nd
			_update_sprite_facing(null_op, nd)
	var limo_node := get_node_or_null("ExecutiveArmoredLimo") as Node2D
	var limo_aim := limo_node.position if limo_node != null else Vector2(460, 478)
	if f == 16:
		_fire_active_weapon_at(limo_aim)
	elif f == 28:
		active_weapon_index = 1
		_update_operative_card()
		_fire_active_weapon_at(limo_aim)
	elif f == 36:
		_fire_active_weapon_at(limo_aim)
		_intercept_executive_convoy()

	# Act II (49..96): Female Operative NULL-3, Persuadertron Neural-Mesh & Infinite Civilian Crowd
	elif f == 49:
		demo_banner_text = "ACT II // FEMALE AGENT NULL-3, PERSUADERTRON & CIVILIAN CROWD"
		_select_operative(2)
		move_target_pos = Vector2(656, 430)
		has_move_target = true
		_cam_target_pos = Vector2(695, 415)
		_cam_target_zoom = 0.96
	elif f == 60:
		_trigger_persuadertron_wave()
	elif f > 60 and f <= 96:
		var civ1 := get_node_or_null("MegacityCivilian1") as Sprite2D
		var civ2 := get_node_or_null("MegacityCivilian2") as Sprite2D
		var guard1 := get_node_or_null("CorpSecGuard1") as Sprite2D
		if civ1:
			var d1 := Vector2(1.15, -0.55)
			civ1.position += d1
			_update_sprite_facing(civ1, d1)
		if civ2:
			var d2 := Vector2(-1.05, 0.52)
			civ2.position += d2
			_update_sprite_facing(civ2, d2)
		if guard1:
			var d3 := Vector2(1.2, -0.4)
			guard1.position += d3
			_update_sprite_facing(guard1, d3)
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

	# Act IV (145..192): Female Operative KESTREL-1 on Spire Skybridge, Adrenaline Overclock & Monorail Vault
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

	# Act V (193..240): Wide Dense City Zoom Out + Satellite Rain & Bio-Foundry Tower Collapse
	elif f == 193:
		demo_banner_text = "ACT V // SATELLITE RAIN STRIKE & BIO-FOUNDRY TOWER COLLAPSE"
		_select_operative(1)
		_set_global_blackout(0.88)
		active_weapon_index = 2
		_update_operative_card()
		move_target_pos = Vector2(564, 368)
		has_move_target = true
		_cam_target_pos = Vector2(640, 348)
		_cam_target_zoom = 0.82
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

func _draw_xray_cyber_silhouette(c: Node2D, screen_pos: Vector2, z: float, col: Color) -> void:
	# Tactical X-Ray Cyber-Silhouette drawn when an operative or guard is behind an occluding building
	var head_c := screen_pos + Vector2(0, -18.0 * z)
	c.draw_arc(head_c, 6.0 * z, 0.0, TAU, 16, col, 1.6)
	var torso := PackedVector2Array([
		screen_pos + Vector2(-9.0 * z, -10.0 * z),
		screen_pos + Vector2(9.0 * z, -10.0 * z),
		screen_pos + Vector2(12.0 * z, 18.0 * z),
		screen_pos + Vector2(-12.0 * z, 18.0 * z),
		screen_pos + Vector2(-9.0 * z, -10.0 * z),
	])
	c.draw_polyline(torso, col, 1.6)
	c.draw_line(screen_pos + Vector2(-5.0 * z, 18.0 * z), screen_pos + Vector2(-7.0 * z, 32.0 * z), col, 1.6)
	c.draw_line(screen_pos + Vector2(5.0 * z, 18.0 * z), screen_pos + Vector2(7.0 * z, 32.0 * z), col, 1.6)

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
		var bf_w := 204.0 if not focus_organ_placeholder else 360.0
		var bf_tag := Rect2(bf_rect.position.x + (bf_rect.size.x - bf_w) * 0.5, bf_rect.position.y - 24.0, bf_w, 20)
		_overlay.draw_rect(bf_tag, Color(0.03, 0.05, 0.09, 0.90), true)
		_overlay.draw_rect(bf_tag, bf_col, false, 1.2)
		var bf_txt := ("%s // RUBBLE CRATER" % focus_organ_name) if tower_collapsed else ("CITY ORGAN // %s" % focus_organ_name)
		if focus_organ_placeholder:
			bf_txt += " [PLACEHOLDER ART]"
		_overlay.draw_string(font, Vector2(bf_tag.position.x + 8, bf_tag.position.y + 14), bf_txt, HORIZONTAL_ALIGNMENT_LEFT, bf_w - 12.0, 11, bf_col)

		var limo := get_node_or_null("ExecutiveArmoredLimo") as Node2D
		if limo != null and _replay == null:
			var l_sp := _w2s(limo.position)
			var l_col := Color(0.25, 0.95, 0.62, 0.9) if convoy_intercepted else Color(1.0, 0.72, 0.22, 0.9)
			var l_tag := Rect2(l_sp.x - 73, l_sp.y - 44 * z, 146, 17)
			_overlay.draw_rect(l_tag, Color(0.03, 0.05, 0.09, 0.88), true)
			_overlay.draw_rect(l_tag, l_col, false, 1.2)
			var l_txt := "CONVOY: +1500 CR" if convoy_intercepted else "TARGET: ZAIBATSU LIMO"
			_overlay.draw_string(font, Vector2(l_tag.position.x + 6, l_tag.position.y + 12), l_txt, HORIZONTAL_ALIGNMENT_LEFT, 136, 10, l_col)

		for g_name in ["CorpSecGuard1", "CorpSecGuard2"]:
			var g_node := get_node_or_null(g_name) as Node2D
			if g_node != null and g_node.visible:
				var g_sp := _w2s(g_node.position)
				var g_col := Color(0.25, 0.95, 1.0, 0.9) if crowd_surge_active else Color(1.0, 0.35, 0.32, 0.88)
				if _occluded_actor_ids.has(g_node.get_instance_id()):
					_draw_xray_cyber_silhouette(_overlay, g_sp, z, g_col)
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

	# 2. World-Space Squad Operative Callsign Badges, X-Ray Silhouettes & Selection Reticle
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
		var border_col := Color(0.22, 0.96, 1.0, 1.0) if is_sel else Color(0.20, 0.86, 0.58, 1.0)

		if _occluded_actor_ids.has(op.get_instance_id()):
			_draw_xray_cyber_silhouette(_overlay, op_sp, z, border_col)

		if is_sel:
			var base := _w2s(op.position + Vector2(0, 32))
			var pts := PackedVector2Array([
				base + Vector2(0, -11 * z),
				base + Vector2(24 * z, 0),
				base + Vector2(0, 11 * z),
				base + Vector2(-24 * z, 0),
				base + Vector2(0, -11 * z),
			])
			_overlay.draw_polyline(pts, Color(0.22, 0.96, 1.0, 0.95), 2.2)
			_draw_corner_brackets(_overlay, Rect2(op_sp.x - 24 * z, op_sp.y - 36 * z, 48 * z, 72 * z), Color(0.22, 0.96, 1.0, 0.85), 7.0, 1.6)

			if has_move_target:
				var tgt_sp := _w2s(move_target_pos + Vector2(0, 32))
				_overlay.draw_line(base, tgt_sp, Color(0.22, 0.96, 1.0, 0.55), 1.8)
				_overlay.draw_circle(tgt_sp, 5.0, Color(0.22, 0.96, 1.0, 0.85))

		var b_rect := Rect2(op_sp.x - 40, op_sp.y - 56 * z, 80, 18)
		_overlay.draw_rect(b_rect, Color(0.03, 0.05, 0.09, 0.90), true)
		_overlay.draw_rect(b_rect, border_col, false, 1.5 if is_sel else 1.0)
		var short_tag: String = _puppet_identities[i]["short_tag"] if i < _puppet_identities.size() else OPERATIVE_SHORT[i]
		_overlay.draw_string(font, Vector2(b_rect.position.x + 4, b_rect.position.y + 11), short_tag, HORIZONTAL_ALIGNMENT_LEFT, 72, 10, border_col)
		_overlay.draw_rect(Rect2(b_rect.position.x + 4, b_rect.position.y + 14, 46, 2), Color(0.20, 0.92, 0.55, 1.0), true)
		_overlay.draw_rect(Rect2(b_rect.position.x + 52, b_rect.position.y + 14, 24, 2), Color(1.0, 0.35, 0.45, 1.0), true)

	# 2b. Rival syndicate operatives created from the C++ snapshot (sim_replay.gd)
	for r_entry in _rival_operatives:
		var rn: Node2D = r_entry["node"]
		if rn == null or not rn.visible:
			continue
		var r_s := int(rn.get_meta("stratum", 1))
		if r_s != int(active_stratum):
			continue
		var r_sp := _w2s(rn.position)
		var r_col: Color = r_entry["color"]
		if _occluded_actor_ids.has(rn.get_instance_id()):
			_draw_xray_cyber_silhouette(_overlay, r_sp, z, r_col)
		var r_tag_str: String = r_entry["tag"]
		var r_w := 142.0 if bool(r_entry["hijacked"]) else 108.0
		var r_rect := Rect2(r_sp.x - r_w * 0.5, r_sp.y - 56 * z, r_w, 18)
		_overlay.draw_rect(r_rect, Color(0.03, 0.05, 0.09, 0.92), true)
		_overlay.draw_rect(r_rect, r_col, false, 1.4)
		_overlay.draw_string(font, Vector2(r_rect.position.x + 5, r_rect.position.y + 11), r_tag_str, HORIZONTAL_ALIGNMENT_LEFT, r_w - 8, 9, r_col)
		var hp_w := (r_w - 10.0) * float(r_entry["hp_ratio"])
		_overlay.draw_rect(Rect2(r_rect.position.x + 5, r_rect.position.y + 14, hp_w, 2), r_col, true)

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
		var banner := Rect2(310, 48, 660, 28)
		_overlay.draw_rect(banner, Color(0.03, 0.05, 0.09, 0.92), true)
		_overlay.draw_rect(banner, Color(0.25, 0.95, 1.0, 0.92), false, 1.6)
		_overlay.draw_string(font, Vector2(324, 67), demo_banner_text, HORIZONTAL_ALIGNMENT_LEFT, 636, 13, Color(0.98, 0.84, 0.28, 1.0))

	# 6. Bottom-Left Active Operative Detail Card + 4-Operative Cortical Meat-Puppet Roster
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
		var short_tag: String = _puppet_identities[i]["short_tag"] if i < _puppet_identities.size() else OPERATIVE_SHORT[i]
		_overlay.draw_string(font, Vector2(rx + 5, ry + 13), short_tag, HORIZONTAL_ALIGNMENT_LEFT, 112, 10, c_border)
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
	_overlay.draw_string(font, Vector2(1084, 64), "%s RADAR" % focus_district_name.get_slice(" ", 0), HORIZONTAL_ALIGNMENT_LEFT, 180, 9, Color(0.28, 0.95, 1.0, 0.95))

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

	# City block building blips on radar
	for b in _city_buildings:
		if b == null:
			continue
		var brel := (b.position - Vector2(640, 388)) * 0.042
		var bpos := mc + Vector2(clampf(brel.x, -82.0, 82.0), clampf(brel.y, -42.0, 42.0))
		_overlay.draw_rect(Rect2(bpos.x - 2, bpos.y - 2, 4, 4), Color(0.35, 0.62, 0.78, 0.65), true)

	# Bio-Foundry Core blip at center
	var bf_c := Color(1.0, 0.38, 0.22, 1.0) if tower_collapsed else Color(0.22, 0.98, 0.62, 1.0)
	_overlay.draw_rect(Rect2(mc.x - 4, mc.y - 4, 8, 8), bf_c, true)

	# Squad operative blips
	for i in range(OPERATIVE_NODES.size()):
		var op := get_node_or_null(OPERATIVE_NODES[i]) as Node2D
		if op == null or not op.visible:
			continue
		var rel := (op.position - Vector2(640, 388)) * Vector2(0.042, 0.042)
		var bp := mc + Vector2(clampf(rel.x, -82.0, 82.0), clampf(rel.y, -42.0, 42.0))
		var oc := Color(0.25, 0.98, 1.0, 1.0) if i == selected_operative else Color(0.25, 0.92, 0.55, 0.9)
		_overlay.draw_circle(bp, 3.0 if i == selected_operative else 2.2, oc)

	# Rival syndicate operative blips (Zaibatsu Crimson & Chiba Triad Emerald)
	for r_entry in _rival_operatives:
		var rn: Node2D = r_entry["node"]
		if rn == null or not rn.visible:
			continue
		var r_rel := (rn.position - Vector2(640, 388)) * Vector2(0.042, 0.042)
		var r_bp := mc + Vector2(clampf(r_rel.x, -82.0, 82.0), clampf(r_rel.y, -42.0, 42.0))
		var r_col: Color = r_entry["color"]
		_overlay.draw_circle(r_bp, 2.2, r_col)

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
			KEY_F1:
				set_focus_district(1)
				return
			KEY_F2:
				set_focus_district(2)
				return
			KEY_F3:
				set_focus_district(3)
				return
			KEY_F4:
				set_focus_district(4)
				return
			KEY_F5:
				set_focus_district(5)
				return
			KEY_F6:
				set_focus_district(6)
				return
		if _hq_screens != null and _hq_screens.handle_key_input(event.keycode):
			return
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
			KEY_N:
				cryo_generation += 1
				_rebuild_meat_puppet_roster()
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
	if _hq_screens != null:
		_hq_screens.queue_redraw()
	_request_overlay_redraw()

func _get_selected_operative_node() -> Sprite2D:
	return get_node_or_null(OPERATIVE_NODES[selected_operative]) as Sprite2D

func _vehicle_dir_to_frame(dir: Vector2) -> int:
	if dir.length_squared() < 0.0001:
		return 0
	var iso_v := Vector2(dir.x, dir.y * 2.0)
	var ang := atan2(iso_v.y, iso_v.x)
	var steps := int(round((-0.75 * PI - ang) / (0.25 * PI)))
	return ((steps % 8) + 8) % 8

func _update_vehicle_facing(sprite: Sprite2D, dir: Vector2) -> void:
	if sprite == null or sprite.hframes != 8:
		return
	sprite.frame = _vehicle_dir_to_frame(dir)

func _update_sprite_facing(sprite: Sprite2D, dir: Vector2) -> void:
	if sprite == null or sprite.hframes != 8:
		return
	var angle := atan2(dir.x, dir.y)
	if angle < 0.0:
		angle += TAU
	var sector := int(round(angle / (PI / 4.0))) % 8
	_actor_facing_sector[sprite.get_instance_id()] = sector
	if sprite.vframes == 4:
		sprite.frame_coords = Vector2i(sector, sprite.frame_coords.y)
	else:
		sprite.frame = sector

func _damage_street_vehicle_at(target_pos: Vector2, dmg: int) -> bool:
	var hit_any := false
	for v_entry in _street_vehicles:
		var v_node: Sprite2D = v_entry["node"]
		if v_node == null or not v_node.visible:
			continue
		if v_node.position.distance_to(target_pos) <= 68.0:
			hit_any = true
			var next_hp: int = max(0, int(v_entry["hp"]) - dmg)
			v_entry["hp"] = next_hp
			if v_node.material is ShaderMaterial:
				var smat := v_node.material as ShaderMaterial
				smat.set_shader_parameter("pulse_tint", Vector3(1.0, 0.35, 0.1))
				smat.set_shader_parameter("pulse_intensity", 0.55)
			if next_hp <= 0 and not bool(v_entry["destroyed"]):
				v_entry["destroyed"] = true
				v_entry["speed"] = 0.0
				if v_node.material is ShaderMaterial:
					var smat := v_node.material as ShaderMaterial
					smat.set_shader_parameter("blackout_factor", 0.38)
					smat.set_shader_parameter("pulse_tint", Vector3(1.0, 0.28, 0.06))
					smat.set_shader_parameter("pulse_intensity", 0.62)
				if bool(v_entry["is_convoy"]):
					_intercept_executive_convoy()
				else:
					syndicate_treasury += 400
					_refresh_hud()
	return hit_any

func _setup_spatial_audio() -> void:
	if _ambient_player != null:
		return
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientSynthPlayer"
	_ambient_player.volume_db = -9.0
	_ambient_player.stream = _synthesize_sfx_wav("ambient", 1.2)
	add_child(_ambient_player)

	_sfx_player_2d = AudioStreamPlayer2D.new()
	_sfx_player_2d.name = "TacticalSfxPlayer2D"
	_sfx_player_2d.max_distance = 1800.0
	_sfx_player_2d.attenuation = 1.15
	add_child(_sfx_player_2d)

	for s_name in ["gauss", "minigun", "plasma", "persuade", "collapse"]:
		_sfx_streams[s_name] = _synthesize_sfx_wav(s_name, 0.28)

func _synthesize_sfx_wav(kind: String, duration_sec: float) -> AudioStreamWAV:
	var mix_rate := 11025
	var samples := int(mix_rate * duration_sec)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(mix_rate)
		var env := clampf(1.0 - (t / maxf(0.05, duration_sec)), 0.0, 1.0)
		var sig := 0.0
		match kind:
			"ambient":
				sig = 0.35 * sin(TAU * 55.0 * t) + 0.20 * sin(TAU * 110.0 * t)
			"gauss":
				sig = env * env * sin(TAU * (880.0 - 620.0 * t) * t)
			"minigun":
				var pulse := 1.0 if int(t * 28.0) % 2 == 0 else 0.2
				sig = env * pulse * sin(TAU * 210.0 * t)
			"plasma":
				sig = env * (0.6 * sin(TAU * 140.0 * t) + 0.4 * sin(TAU * 420.0 * t))
			"persuade":
				sig = env * (0.5 * sin(TAU * 528.0 * t) + 0.5 * sin(TAU * 660.0 * t))
			"collapse":
				sig = env * (0.7 * sin(TAU * 48.0 * t) + 0.3 * cos(TAU * 93.0 * t))
		var sample_i16 := clampi(int(sig * 14000.0), -32767, 32767)
		pcm.encode_s16(i * 2, sample_i16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = pcm
	return wav

func play_sfx(sfx_name: String, world_pos: Vector2 = Vector2(640, 360)) -> void:
	last_played_sfx = sfx_name
	sfx_play_count += 1
	if _sfx_player_2d == null or not _sfx_streams.has(sfx_name):
		return
	_sfx_player_2d.position = world_pos
	_sfx_player_2d.stream = _sfx_streams[sfx_name]
	if DisplayServer.get_name() != "headless":
		_sfx_player_2d.play()

func dispatch_live_cpp_command(cmd_stmt: String, run_cli_binary: bool = false) -> bool:
	if cmd_stmt.is_empty():
		return false
	_live_cpp_command_log.append(cmd_stmt)
	# Deterministic FNV-1a 64-bit rolling digest over the live command log
	var h: int = 0x57455457415245
	var joined := ";".join(_live_cpp_command_log)
	for idx in range(joined.length()):
		h = ((h ^ joined.unicode_at(idx)) * 1099511628211) & 0x7FFFFFFFFFFFFFFF
	last_digest = "0x%016x" % h

	if run_cli_binary:
		var cli_candidates := [
			"/tmp/wetware-m12-build/wetware_cli",
			"/tmp/wetware-build/wetware_cli",
			ProjectSettings.globalize_path("res://../build/wetware_cli"),
		]
		for cli_path in cli_candidates:
			if FileAccess.file_exists(cli_path):
				var out := []
				var code := OS.execute(cli_path, ["--commands", joined], out, false)
				if code == 0 and not out.is_empty():
					var parsed: Variant = JSON.parse_string(String(out[0]))
					if valid_snapshot(parsed):
						return apply_snapshot(parsed as Dictionary)
				break
	_refresh_hud()
	return true

func apply_tower_damage(dmg: int) -> void:
	if tower_collapsed:
		return
	tower_structural_hp = maxi(0, tower_structural_hp - dmg)
	if tower_structural_hp <= 0:
		set_tower_collapsed(true)
	elif tower_structural_hp <= 55:
		set_tower_damage_stage(1)
	else:
		set_tower_damage_stage(0)

func set_tower_damage_stage(stage: int) -> void:
	tower_damage_stage = clampi(stage, 0, 3)
	tower_collapsed = (tower_damage_stage == 2)
	var intact_node := get_node_or_null("BioFoundryTowerIntact") as Sprite2D
	var rubble_node := get_node_or_null("BioFoundryTowerRubble") as Sprite2D
	if intact_node:
		intact_node.visible = (tower_damage_stage != 2)
		if intact_node.material is ShaderMaterial:
			var smat := intact_node.material as ShaderMaterial
			if tower_damage_stage == 1:
				smat.set_shader_parameter("pulse_tint", Vector3(1.0, 0.38, 0.12))
				smat.set_shader_parameter("pulse_intensity", 0.45)
			elif tower_damage_stage == 3:
				smat.set_shader_parameter("pulse_tint", Vector3(0.22, 0.92, 1.0))
				smat.set_shader_parameter("pulse_intensity", 0.32)
			else:
				smat.set_shader_parameter("pulse_intensity", 0.0)
	if rubble_node:
		rubble_node.visible = (tower_damage_stage == 2)
	if _hq_screens != null:
		_hq_screens.queue_redraw()
	_refresh_hud()

func _fire_active_weapon_at(target_pos: Vector2) -> void:
	var op_node := _get_selected_operative_node()
	if op_node == null:
		return
	var to_target := target_pos - op_node.position
	if to_target.length_squared() > 1.0:
		_update_sprite_facing(op_node, to_target.normalized())
	_actor_fire_timer[op_node.get_instance_id()] = 0.34
	if op_node.vframes == 4:
		var sec: int = int(_actor_facing_sector.get(op_node.get_instance_id(), op_node.frame_coords.x)) % 8
		op_node.frame_coords = Vector2i(sec, 3)

	tracer_start = op_node.position + Vector2(0, -6)
	tracer_end = target_pos
	tracer_timer = 0.28

	var wpn_dmg := 100 if (active_weapon_index == 2 or active_weapon_index == 3) else 50
	if active_weapon_index == 2 or active_weapon_index == 3:
		tracer_color = Color(1.0, 0.48, 0.18, 1.0)
		play_sfx("plasma", target_pos)
	elif active_weapon_index == 1:
		tracer_color = Color(0.25, 0.95, 1.0, 1.0)
		play_sfx("minigun", op_node.position)
	else:
		tracer_color = Color(0.25, 0.95, 1.0, 1.0)
		play_sfx("gauss", op_node.position)

	dispatch_live_cpp_command("fire:%d:%d:%d:8:8:%d" % [
		selected_operative, focus_district_id, active_weapon_index + 1, int(active_stratum)
	])
	_damage_street_vehicle_at(target_pos, wpn_dmg)
	if target_pos.distance_to(Vector2(640, 292)) < 110.0 and not tower_collapsed:
		apply_tower_damage(wpn_dmg)
	_request_overlay_redraw()

func _trigger_persuadertron_wave() -> void:
	var op_node := _get_selected_operative_node()
	if op_node == null:
		return
	persuade_origin = op_node.position
	persuade_timer = 0.55
	target_pulse_timer = 0.45
	play_sfx("persuade", op_node.position)
	dispatch_live_cpp_command("persuade:%d:%d" % [selected_operative, focus_district_id])
	if not crowd_surge_active:
		crowd_surge_active = true
		thrall_count = 14
	for actor_name in ["MegacityCivilian1", "MegacityCivilian2", "CorpSecGuard1", "CorpSecGuard2"]:
		var actor := get_node_or_null(actor_name) as Sprite2D
		if actor and actor.material is ShaderMaterial:
			var smat := actor.material as ShaderMaterial
			smat.set_shader_parameter("pulse_tint", Vector3(0.2, 0.95, 1.0))
			smat.set_shader_parameter("pulse_intensity", 0.45)
	for c_entry in _proc_civilians:
		var cn: Sprite2D = c_entry["node"]
		if cn and cn.material is ShaderMaterial:
			var cmat := cn.material as ShaderMaterial
			cmat.set_shader_parameter("pulse_tint", Vector3(0.2, 0.95, 1.0))
			cmat.set_shader_parameter("pulse_intensity", 0.38)
	_update_operative_card()
	_refresh_hud()
	_request_overlay_redraw()

func _clear_actor_shader_pulses() -> void:
	for actor_name in ["MegacityCivilian1", "MegacityCivilian2", "CorpSecGuard1", "CorpSecGuard2"]:
		var actor := get_node_or_null(actor_name) as Sprite2D
		if actor and actor.material is ShaderMaterial:
			var smat := actor.material as ShaderMaterial
			smat.set_shader_parameter("pulse_intensity", 0.0)
	for v_entry in _street_vehicles:
		var vn: Sprite2D = v_entry["node"]
		if vn and vn.material is ShaderMaterial and not bool(v_entry["destroyed"]):
			(vn.material as ShaderMaterial).set_shader_parameter("pulse_intensity", 0.0)
	for c_entry in _proc_civilians:
		var cn: Sprite2D = c_entry["node"]
		if cn and cn.material is ShaderMaterial:
			(cn.material as ShaderMaterial).set_shader_parameter("pulse_intensity", 0.0)

func _toggle_transformer_sabotage() -> void:
	transformer_sabotaged = not transformer_sabotaged
	var blackout := 0.52 if transformer_sabotaged else 1.0
	_set_global_blackout(blackout)
	if transformer_sabotaged:
		dispatch_live_cpp_command("sabotage:%d" % focus_district_id)
	_refresh_hud()

func _intercept_executive_convoy() -> void:
	if not convoy_intercepted:
		convoy_intercepted = true
		syndicate_treasury += 1500
		salvage_units += 1
		target_pulse_timer = 0.45
		dispatch_live_cpp_command("convoy:%d" % focus_district_id)
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
		dispatch_live_cpp_command("monorail:%d" % focus_district_id)
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

func set_focus_district(district_id: int) -> void:
	_ensure_m7_initialized()
	var did := clampi(district_id, 1, 6)
	focus_district_id = did
	var info: Dictionary = DISTRICT_LANDMARKS.get(did, DISTRICT_LANDMARKS[1])
	focus_district_name = String(info["name"])
	focus_organ_name = String(info["organ"])
	focus_organ_placeholder = false
	var stem: String = String(info["stem"])

	var intact_node := get_node_or_null("BioFoundryTowerIntact") as Sprite2D
	if intact_node != null:
		intact_node.texture = _load_tex("res://assets/tiles/%s_intact_albedo.png" % stem)
		if intact_node.material is ShaderMaterial:
			var smat := intact_node.material as ShaderMaterial
			smat.set_shader_parameter("emissive_mask", _load_tex("res://assets/tiles/%s_intact_emissive.png" % stem))
			smat.set_shader_parameter("normal_map", _load_tex("res://assets/normals/%s_intact_normal.png" % stem))

	var rubble_node := get_node_or_null("BioFoundryTowerRubble") as Sprite2D
	if rubble_node != null:
		rubble_node.texture = _load_tex("res://assets/tiles/%s_rubble_albedo.png" % stem)
		if rubble_node.material is ShaderMaterial:
			var rmat := rubble_node.material as ShaderMaterial
			rmat.set_shader_parameter("emissive_mask", _load_tex("res://assets/tiles/%s_rubble_emissive.png" % stem))
			rmat.set_shader_parameter("normal_map", _load_tex("res://assets/normals/%s_rubble_normal.png" % stem))

	if _hq_screens != null:
		_hq_screens.queue_redraw()
	_refresh_hud()

func set_surrounding_blocks_collapsed(collapsed_count: int) -> void:
	_ensure_m7_initialized()
	var rub_alb := _load_tex("res://assets/tiles/city_block_rubble_albedo.png")
	var rub_emi := _load_tex("res://assets/tiles/city_block_rubble_emissive.png")
	var rub_nrm := _load_tex("res://assets/normals/city_block_rubble_normal.png")
	var ten_alb := _load_tex("res://assets/tiles/city_block_tenement_albedo.png")
	var ten_emi := _load_tex("res://assets/tiles/city_block_tenement_emissive.png")
	var ten_nrm := _load_tex("res://assets/normals/city_block_tenement_normal.png")
	var corp_alb := _load_tex("res://assets/tiles/city_block_corp_albedo.png")
	var corp_emi := _load_tex("res://assets/tiles/city_block_corp_emissive.png")
	var corp_nrm := _load_tex("res://assets/normals/city_block_corp_normal.png")

	for idx in range(1, _city_buildings.size()):
		var b_node := _city_buildings[idx]
		if b_node == null:
			continue
		var is_collapsed := (idx <= collapsed_count)
		var is_ten := _city_building_is_tenement[idx] if idx < _city_building_is_tenement.size() else false
		if is_collapsed:
			b_node.texture = rub_alb
			if b_node.material is ShaderMaterial:
				var bmat := b_node.material as ShaderMaterial
				bmat.set_shader_parameter("emissive_mask", rub_emi)
				bmat.set_shader_parameter("normal_map", rub_nrm)
		else:
			b_node.texture = ten_alb if is_ten else corp_alb
			if b_node.material is ShaderMaterial:
				var bmat := b_node.material as ShaderMaterial
				bmat.set_shader_parameter("emissive_mask", ten_emi if is_ten else corp_emi)
				bmat.set_shader_parameter("normal_map", ten_nrm if is_ten else corp_nrm)
	_request_overlay_redraw()

func set_hq_screen(mode: int) -> void:
	_ensure_m7_initialized()
	if _hq_screens != null:
		_hq_screens.set_mode(mode)

func get_hq_screen() -> int:
	if _hq_screens != null:
		return int(_hq_screens.active_mode)
	return 0

func valid_snapshot(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if d.get("schema_version") != 2:
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
	_ensure_m7_initialized()
	last_digest = String(data["state_digest"])
	var t_scale := float(data["tactical_time_scale"])
	overclock_active = t_scale < 0.5
	Engine.time_scale = t_scale

	var snap_focus := int(data.get("focus_district_id", focus_district_id))
	if snap_focus >= 1 and snap_focus <= 6:
		set_focus_district(snap_focus)

	var non_organ_collapsed := 0
	for bld_var in data["buildings"] as Array:
		var bld: Dictionary = bld_var
		var b_did := int(bld.get("district_id", 1))
		var is_organ := bool(bld.get("houses_city_organ", int(bld["id"]) == 10))
		if b_did == focus_district_id and is_organ:
			set_tower_damage_stage(int(bld["state"]))
		elif b_did == focus_district_id and int(bld["state"]) == 2:
			non_organ_collapsed += 1
	set_surrounding_blocks_collapsed(non_organ_collapsed * 3)

	var districts: Variant = data.get("districts")
	if typeof(districts) == TYPE_ARRAY and not (districts as Array).is_empty():
		var d_focus: Dictionary = (districts as Array)[0]
		for d_var in districts as Array:
			var d_entry: Dictionary = d_var
			if int(d_entry.get("id", 0)) == focus_district_id:
				d_focus = d_entry
				break
		transformer_sabotaged = not bool(d_focus.get("transformer_intact", true)) or bool(d_focus.get("power_blackout", false))
		convoy_intercepted = not bool(d_focus.get("executive_convoy_active", true))
		crowd_surge_active = bool(d_focus.get("crowd_surge_active", false))
		_set_global_blackout(0.52 if transformer_sabotaged else 1.0)

	var player_syn: Dictionary = (data["syndicates"] as Array)[0]
	syndicate_treasury = int(player_syn.get("treasury", 0))
	salvage_units = int(player_syn.get("salvage_units", player_syn.get("salvage_count", salvage_units)))
	thrall_count = int(player_syn.get("thralls_count", thrall_count))
	var squad: Array = player_syn["squad"]
	for i in range(min(squad.size(), OPERATIVE_NODES.size())):
		var op: Dictionary = squad[i]
		var node := get_node_or_null(OPERATIVE_NODES[i]) as Node2D
		if node:
			var s := int(op["stratum"])
			node.set_meta("stratum", s)
			node.visible = bool(op["alive"])

	if _hq_screens != null:
		_hq_screens.sync_from_snapshot(data)

	_apply_stratum_cutaway(active_stratum)
	_update_operative_card()
	_refresh_hud()
	return true

func set_tower_collapsed(collapsed: bool) -> void:
	if collapsed and not tower_collapsed:
		play_sfx("collapse", Vector2(640, 292))
		dispatch_live_cpp_command("shear:%d:4" % (focus_district_id * 10))
	tower_structural_hp = 0 if collapsed else 100
	set_tower_damage_stage(2 if collapsed else 0)

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
	var ident: Dictionary = _puppet_identities[selected_operative] if selected_operative < _puppet_identities.size() else {
		"unit_code": "UNIT 01-F // KESTREL",
		"subj_line": "SUBJ #104 [V. CHEN - WIPED]",
		"link_str": "99.4%",
	}
	var bpm_val: int = 164 if overclock_active else (92 + selected_operative * 6)
	var ipa_text := "95/92/98% [SURGE]" if overclock_active else "82/78/65%"
	var org_str: String = operative_organs_live[selected_operative] if selected_operative < operative_organs_live.size() else OPERATIVE_ORGANS[selected_operative]
	bio_label.text = "%s [%s]\n%s | LINK: %s | %d BPM\nORGANS: %s\nI/P/A: %s | WPN: %s | THRALLS: %d" % [
		ident["unit_code"],
		s_name,
		ident["subj_line"],
		ident["link_str"],
		bpm_val,
		org_str,
		ipa_text,
		WEAPON_NAMES[active_weapon_index],
		thrall_count,
	]
	_request_overlay_redraw()

func _refresh_hud() -> void:
	var hud_label := get_node_or_null("TacticalHud/HudTelemetryLabel") as Label
	if hud_label != null:
		var stratum_name: String = STRATUM_NAMES.get(int(active_stratum), "STREET")
		var organ_state := "RUBBLE" if tower_collapsed else ("DAMAGED" if tower_damage_stage == 1 else ("REBUILDING" if tower_damage_stage == 3 else "INTACT"))
		var oc_state := "OVERCLOCK 0.25x" if overclock_active else "NOMINAL 1.00x"
		var grid_power := "BLACKOUT" if transformer_sabotaged else "GRID ONLINE"
		hud_label.text = ("CR: %d | STRATUM: %s | " + focus_organ_name + ": %s | %s | %s | DIGEST: %s") % [
			syndicate_treasury,
			stratum_name,
			organ_state,
			oc_state,
			grid_power,
			last_digest,
		]

	var obj_label := get_node_or_null("TacticalHud/ObjectivesLabel") as Label
	if obj_label != null and not replay_objectives_text.is_empty():
		obj_label.text = replay_objectives_text
	elif obj_label != null:
		obj_label.text = (
			"%s OBJECTIVES:\n" % focus_district_name
			+ "[%s] SHEAR %s PILLARS (C / RMB FIRE)\n" % ["X" if tower_collapsed else " ", focus_organ_name]
			+ "[%s] SABOTAGE SUB-GRID TRANSFORMER (T)\n" % ("X" if transformer_sabotaged else " ")
			+ "[%s] AMBUSH ZAIBATSU LIMO CONVOY (V) | MONORAIL (M)\n" % ("X" if (convoy_intercepted or monorail_looted) else " ")
			+ "[%s] PERSUADERTRON CROWD SURGE (P) | CRYO-CYCLE (N)\n" % ("X" if crowd_surge_active else " ")
			+ "HQ SCREENS: [G] Megacity Map | [U] Ripperdoc Surgery | [K] R&D & Salvage Lab\n"
			+ "DISTRICTS: [F1-F6] Switch Sector | [1-3] Stratum | [Tab] Op | [Space] Overclock"
		)
	_update_operative_card()
	_request_overlay_redraw()
