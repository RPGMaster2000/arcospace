extends RefCounted
## Small reusable scenery meshes. Constructed once; no physics or frame updates.


static func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.48 if metallic > 0 else 0.92
	return result


static func part(
	parent: Node3D, label: String, mesh: Mesh, at: Vector3, material: Material
) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.position = at
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result


static func instances(
	parent: Node3D,
	label: String,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D],
	visible_fraction: float = 1.0
) -> MultiMeshInstance3D:
	var result := MultiMeshInstance3D.new()
	result.name = label
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.material_override = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(
			i, Color(float(i) * 0.137, float(i) * 0.271, float(i) * 0.193, 1)
		)
	multimesh.visible_instance_count = maxi(1, roundi(transforms.size() * visible_fraction))
	result.multimesh = multimesh
	# The headless dummy renderer does not retain MultiMesh transform buffers.
	# Keep the immutable construction data for clearance audits and editor tooling.
	transforms.make_read_only()
	result.set_meta("scenery_transforms", transforms)
	parent.add_child(result)
	return result


static func rock() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 7
	mesh.rings = 3
	return mesh


static func tube(points: PackedVector3Array, radius: float, sides: int = 6) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var tangent := (points[i + 1] - points[i]).normalized()
		var right := tangent.cross(Vector3.UP).normalized()
		if right.is_zero_approx():
			right = tangent.cross(Vector3.RIGHT).normalized()
		var up := tangent.cross(right).normalized()
		for side in sides:
			var a := TAU * side / sides
			var b := TAU * (side + 1) / sides
			var normal_a := right * cos(a) + up * sin(a)
			var normal_b := right * cos(b) + up * sin(b)
			var vertices := [
				points[i] + normal_a * radius,
				points[i + 1] + normal_a * radius,
				points[i + 1] + normal_b * radius,
				points[i] + normal_a * radius,
				points[i + 1] + normal_b * radius,
				points[i] + normal_b * radius
			]
			for vertex in vertices:
				surface.set_normal((vertex - points[i]).slide(tangent).normalized())
				surface.add_vertex(vertex)
	return surface.commit()


static func arc(radius: float, start: float, end: float, depth: float = 0.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in range(25):
		var angle := lerpf(start, end, float(i) / 24)
		result.append(Vector3(cos(angle) * radius, sin(angle) * radius, sin(angle * 2) * depth))
	return result


static func wreckage(frame: bool = false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bar := BoxMesh.new()
	if frame:
		bar.size = Vector3(4.8, 0.18, 0.22)
		for y in [-1.5, 1.5]:
			surface.append_from(bar, 0, Transform3D(Basis.IDENTITY, Vector3(0, y, 0)))
		bar.size = Vector3(0.18, 3, 0.22)
		for x in [-2.3, 2.3]:
			surface.append_from(bar, 0, Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
	else:
		bar.size = Vector3(3.4, 0.22, 0.28)
		for i in range(3):
			var basis := Basis.from_euler(Vector3(0.0, i * 0.28, i * 0.15))
			surface.append_from(bar, 0, Transform3D(basis, Vector3((i - 1) * 2.9, i * 0.18, 0)))
	return surface.commit()
