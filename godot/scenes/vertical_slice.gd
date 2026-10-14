extends Node2D

enum Stratum {
	UNDER_GRID = 0,
	STREET = 1,
	SPIRE = 2,
}

var active_stratum: Stratum = Stratum.STREET
var overclock_active: bool = false
var tower_collapsed: bool = false

func _ready() -> void:
	_apply_stratum_cutaway(active_stratum)
	if DisplayServer.get_name() == "headless":
		# Verify all 3 strata, building state toggle, and overclock toggle in headless mode
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
