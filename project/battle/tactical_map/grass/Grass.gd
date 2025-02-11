extends Spatial

export var game_count: int
export var editor_count: int
export var area = Vector2(10, 10)
export var blade_height = Vector2(0.06, 0.08)
export var blade_width = Vector2(0.01, 0.02)
export var blade_rotation = Vector2(-180, 180)
export var blade_sway_yaw = Vector2(-0.175, 0.175)
export var blade_sway_pitch = Vector2(0, 0.175)

export var thread_count: int = 4
var threads = []

var multimesh_rid: RID
var mesh_rid: RID

var material = preload("res://assets/battle/grass/Grass.material").get_rid()


func _ready():
	pass


func generate(
	_cells: Array,
	_cell_size: Vector2,
	_amount_blade_in_cell: int
):
	if multimesh_rid != null and mesh_rid != null:
		clear()
	
	rebuild(_cells, _cell_size, _amount_blade_in_cell)


func rid_blade_mesh() -> RID:
	var mesh = VisualServer.mesh_create()
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	
	var verts = PoolVector3Array()
	var uvs = PoolVector2Array()
	
	verts.push_back(Vector3(-0.5, 0.0, 0.0))
	verts.push_back(Vector3(0.5, 0.0, 0.0))
	verts.push_back(Vector3(0.0, 1.0, 0.0))
	
	uvs.push_back(Vector2(0.0, 0.0))
	uvs.push_back(Vector2(1.0, 0.0))
	uvs.push_back(Vector2(0.5, 1.0))
	
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	
	VisualServer.mesh_add_surface_from_arrays(mesh, Mesh.PRIMITIVE_TRIANGLES, arr)
	
	return mesh


func rebuild(_cells: Array, _cell_size: Vector2, _amount_blade_in_cell: int):
	var multimesh = VisualServer.multimesh_create()
	multimesh_rid = multimesh
	
	var instances_count = _cells.size() * _amount_blade_in_cell
	VisualServer.multimesh_allocate(
		multimesh, instances_count,
		VisualServer.MULTIMESH_TRANSFORM_3D,
		VisualServer.MULTIMESH_COLOR_NONE,
		VisualServer.MULTIMESH_CUSTOM_DATA_FLOAT
	)
	
	mesh_rid = rid_blade_mesh()
	VisualServer.multimesh_set_mesh(multimesh, mesh_rid)
	
	threads = []
	
	var bpt_cell = int(ceil(_cells.size() / thread_count))
	var bpt_cell_remainder = int(ceil(_cells.size() % thread_count))
	
	var arg: Dictionary
	var rng = RandomNumberGenerator.new()
	
	var index: int = 0
	
	for t in thread_count:
		arg.clear()
		
		arg["multimesh"] = multimesh
		
		arg["start_cell"] = bpt_cell * t
		arg["stop_cell"] = bpt_cell * t + bpt_cell
		
		arg["start_index"] = index
		arg["stop_index"] = index + (bpt_cell * _amount_blade_in_cell)
		
		arg["cells"] = _cells
		arg["cell_size"] = _cell_size
		arg["amount_blade_in_cell"] = _amount_blade_in_cell
		
		arg["rng"] = rng
		
		if t == (thread_count - 1):
			arg["stop_index"] += (bpt_cell_remainder * _amount_blade_in_cell)
			arg["stop_cell"] += bpt_cell_remainder
		
		index += (bpt_cell * _amount_blade_in_cell)
		
		threads.append(Thread.new())
		threads[t].start(self, "thread_worker", arg.duplicate())
	
	for t in thread_count:
		threads[t].wait_to_finish()
	
	var instance = VisualServer.instance_create()
	var scenario = get_world().scenario
	
	VisualServer.instance_set_scenario(instance, scenario)
	VisualServer.instance_set_base(instance, multimesh)
	
	VisualServer.instance_geometry_set_material_override(instance, material)


func clear():
	VisualServer.free_rid(mesh_rid)
	VisualServer.free_rid(multimesh_rid)


func thread_worker(data: Dictionary):
	var rid: RID = data["multimesh"]
	
	var start: int = data["start_index"]
	var stop: int = data["stop_index"]
	
	var start_cell: int = data["start_cell"]
	var stop_cell: int = data["stop_cell"]
	
	var cells: Array = data["cells"]
	var cell_size: Vector2 = data["cell_size"]
	var amount_blade_in_cell: int = data["amount_blade_in_cell"]
	
	var rng: RandomNumberGenerator = data["rng"]
	
	var cell_index: int = start_cell
	var cell_current_number_blades: int = 0
	
	for i in range(start, stop):
		setup_blade(
			rid,
			i,
			cells[cell_index],
			cell_size,
			rng
		)
		cell_current_number_blades += 1
		
		if cell_current_number_blades == amount_blade_in_cell:
			cell_current_number_blades = 0
			cell_index += 1
		
		if cell_index == stop_cell:
			break


func setup_blade(
	rid: RID,
	i: int,
	cell_coord: Vector3,
	cell_size: Vector2,
	rng: RandomNumberGenerator
) -> void:
	var width = rand_range(blade_width.x, blade_width.y)
	var height = rand_range(blade_height.x, blade_height.y)
	
	var x = cell_size.x
	var y = cell_size.y
	
	var rand_shift = Vector2(
		rng.randf_range(-x/2, x/2),
		rng.randf_range(-y/2, y/2)
	)
	
	var position: Vector3
	position = cell_coord
	position += Vector3(rand_shift.x, 0, rand_shift.y)
	
	var rotation = rand_range(blade_rotation.x, blade_rotation.y)
	
	var sway_yaw = rand_range(blade_sway_yaw.x, blade_sway_yaw.y)
	var sway_pitch = rand_range(blade_sway_pitch.x, blade_sway_pitch.y)
	
	var transform = Transform.IDENTITY
	transform.origin = Vector3(position.x, 0, position.z)
	transform.basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(rotation))
	
	VisualServer.multimesh_instance_set_transform(rid, i, transform)
	VisualServer.multimesh_instance_set_custom_data(
		rid,
		i,
		Color(
			width,
			height,
			deg2rad(sway_pitch),
			deg2rad(sway_yaw)
		)
	)
