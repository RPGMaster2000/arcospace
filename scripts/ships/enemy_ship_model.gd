extends "res://scripts/ships/ship_3d.gd"

# RESPONSIBILITY: Build the interceptor wedge and retain accent colors with shared ship effect passes.
# Preserve authored accent colors while sharing the existing damage/repair shader chain.
@export var pointed_hull: bool = false


func _ready() -> void:
	if pointed_hull:
		$Body/Hull.mesh = _interceptor_hull()
		$Body/Hull.rotation = Vector3.ZERO
	super._ready()
	for part in $Body/Details.get_children():
		if part is MeshInstance3D:
			part.material_override = part.material_override.duplicate()
			part.material_override.next_pass = damage_material


# A closed triangular wedge, +X forward, made with Godot geometry only.
func _interceptor_hull() -> ArrayMesh:
	var vertices: Array[Vector3] = [
		Vector3(1.9, 0.12, 0),
		Vector3(1.9, -0.12, 0),
		Vector3(-1.35, 0.25, -1.15),
		Vector3(-1.35, 0.25, 1.15),
		Vector3(-1.35, -0.25, -1.15),
		Vector3(-1.35, -0.25, 1.15)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [
		[0, 2, 3], [1, 4, 5], [0, 1, 4], [0, 4, 2], [0, 3, 5], [0, 5, 1], [2, 4, 5], [2, 5, 3]
	]:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		if normal.dot((a + b + c) / 3.0) < 0:
			var swap: Vector3 = b
			b = c
			c = swap
			normal = -normal
		for vertex in [a, b, c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	return surface.commit()
