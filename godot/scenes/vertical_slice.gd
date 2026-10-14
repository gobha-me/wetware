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

var active_stratum: Stratum = Stratum.STREET
var overclock_active: bool = false
var tower_collapsed: bool = false
var last_digest: String = ""

func _ready() -> void:
	_apply_stratum_cutaway(active_stratum)
	if DisplayServer.get_name() == "headless":
		_apply_stratum_cutaway(Stratum.UNDER_GRID)
		_apply_stratum_cutaway(Stratum.SPIRE)
		_apply_stratum_cutaway(Stratum.STREET)
		set_tower_collapsed(true)
		set_tower_collapsed(false)
		print("wetware Godot 4.7.2 Kowloon Bio-Foundry 3-stratum vertical slice verified cleanly.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_apply_stratum_cutaway(Stratum.UNDER_GRID)
			KEY_2:
				_apply_stratum_cutaway(Stratum.STREET)
			KEY_3:
				_apply_stratum_cutaway(Stratum.SPIRE)
			KEY_C:
				set_tower_collapsed(not tower_collapsed)
			KEY_SPACE:
				overclock_active = not overclock_active
				Engine.time_scale = 0.25 if overclock_active else 1.0

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
			# BuildingState::Rubble == 2
			set_tower_collapsed(int(bld["state"]) == 2)

	var player_syn: Dictionary = (data["syndicates"] as Array)[0]
	var squad: Array = player_syn["squad"]
	for i in range(min(squad.size(), OPERATIVE_NODES.size())):
		var op: Dictionary = squad[i]
		var node := get_node_or_null(OPERATIVE_NODES[i]) as Node2D
		if node:
			var s := int(op["stratum"])
			node.set_meta("stratum", s)
			node.visible = bool(op["alive"])

	_apply_stratum_cutaway(active_stratum)
	return true

func set_tower_collapsed(collapsed: bool) -> void:
	tower_collapsed = collapsed
	var intact_node := get_node_or_null("BioFoundryTowerIntact") as CanvasItem
	var rubble_node := get_node_or_null("BioFoundryTowerRubble") as CanvasItem
	if intact_node:
		intact_node.visible = not collapsed
	if rubble_node:
		rubble_node.visible = collapsed

func _apply_stratum_cutaway(focus_stratum: Stratum) -> void:
	active_stratum = focus_stratum
	for child in get_children():
		if not child.has_meta("stratum"):
			continue
		var node_stratum: int = int(child.get_meta("stratum"))
		var alpha: float = 1.0
		if node_stratum > int(focus_stratum):
			alpha = 0.18
		elif node_stratum < int(focus_stratum):
			alpha = 0.65
		if child is CanvasItem and child.material is ShaderMaterial:
			var smat := child.material as ShaderMaterial
			smat.set_shader_parameter("stratum_cutaway_alpha", alpha)
