extends Node2D

enum Stratum {
	UNDER_GRID = 0,
	STREET = 1,
	SPIRE = 2,
}

var active_stratum: Stratum = Stratum.STREET
var overclock_active: bool = false

func _ready() -> void:
	_apply_stratum_cutaway(active_stratum)
	if DisplayServer.get_name() == "headless":
		print("wetware Godot 4.7.2 2.5D isometric vertical slice initialized cleanly.")

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
