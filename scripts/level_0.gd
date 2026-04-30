extends Node3D

# Procedural Level 0 builder.
# Generates a Backrooms-like grid of yellow-wallpaper rooms, corridors,
# damp carpet, ceiling tiles, and flickering fluorescent lights.

const TILE_SIZE: float = 4.0
const ROOM_HEIGHT: float = 3.2
const GRID_W: int = 24
const GRID_H: int = 24
const RNG_SEED: int = 13_071_996  # The Backrooms wiki Level 0 seed reference.

const FlickerLight := preload("res://scripts/flicker_light.gd")
const NoclipExit := preload("res://scripts/noclip_exit.gd")
const WALL_TEX := preload("res://assets/textures/wall.png")
const CARPET_TEX := preload("res://assets/textures/carpet.png")

var _rng := RandomNumberGenerator.new()
var _grid: Array[Array] = []  # _grid[x][z] -> 0 wall / 1 open
var _wall_material: StandardMaterial3D
var _carpet_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D


func _ready() -> void:
	_rng.seed = RNG_SEED
	_generate_grid()
	_build_materials()
	_spawn_floor_and_ceiling()
	_spawn_walls()
	_spawn_lights()
	_spawn_noclip_exit()
	_spawn_player_at_open_tile()


# --- Grid generation -------------------------------------------------------

func _generate_grid() -> void:
	_grid.resize(GRID_W)
	for x in GRID_W:
		var col: Array[int] = []
		col.resize(GRID_H)
		for z in GRID_H:
			col[z] = 0
		_grid[x] = col

	# Carve a few large open rooms.
	var room_count: int = _rng.randi_range(5, 8)
	for _i in room_count:
		var rw: int = _rng.randi_range(4, 8)
		var rh: int = _rng.randi_range(4, 8)
		var rx: int = _rng.randi_range(1, GRID_W - rw - 1)
		var rz: int = _rng.randi_range(1, GRID_H - rh - 1)
		for x in range(rx, rx + rw):
			for z in range(rz, rz + rh):
				_grid[x][z] = 1

	# Connect rooms with random corridors (drunkard's walk between centers).
	var anchors: Array[Vector2i] = []
	for _i in 12:
		anchors.append(Vector2i(_rng.randi_range(2, GRID_W - 3), _rng.randi_range(2, GRID_H - 3)))
	for i in anchors.size() - 1:
		_carve_corridor(anchors[i], anchors[i + 1])

	# Ensure the spawn tile (center) is open.
	for x in range(GRID_W / 2 - 2, GRID_W / 2 + 2):
		for z in range(GRID_H / 2 - 2, GRID_H / 2 + 2):
			_grid[x][z] = 1


func _carve_corridor(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var cur := from_pos
	var max_steps: int = (GRID_W + GRID_H) * 2
	var steps: int = 0
	while cur != to_pos and steps < max_steps:
		_grid[cur.x][cur.y] = 1
		# Carve a 2-wide corridor for that "wide hallway" feel.
		if cur.x + 1 < GRID_W:
			_grid[cur.x + 1][cur.y] = 1
		if cur.x > to_pos.x:
			cur.x -= 1
		elif cur.x < to_pos.x:
			cur.x += 1
		elif cur.y > to_pos.y:
			cur.y -= 1
		elif cur.y < to_pos.y:
			cur.y += 1
		steps += 1


# --- Materials -------------------------------------------------------------

func _build_materials() -> void:
	_wall_material = StandardMaterial3D.new()
	_wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_wall_material.albedo_color = Color(1.0, 1.0, 1.0)
	_wall_material.albedo_texture = WALL_TEX
	_wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Wall pattern repeats roughly once per ~2m horizontally; tile twice across
	# a 4m block and once vertically across the 3.2m room height.
	_wall_material.uv1_scale = Vector3(2.0, 1.0, 2.0)
	_wall_material.roughness = 0.85
	_wall_material.metallic = 0.0

	_carpet_material = StandardMaterial3D.new()
	_carpet_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_carpet_material.albedo_color = Color(1.0, 1.0, 1.0)
	_carpet_material.albedo_texture = CARPET_TEX
	_carpet_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# One carpet tile per ~3m of floor.
	_carpet_material.uv1_scale = Vector3(GRID_W * TILE_SIZE / 3.0, GRID_H * TILE_SIZE / 3.0, 1.0)
	_carpet_material.roughness = 0.95

	_ceiling_material = StandardMaterial3D.new()
	_ceiling_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_ceiling_material.albedo_color = Color("e6dfc8")
	_ceiling_material.albedo_texture = _make_ceiling_texture()
	_ceiling_material.uv1_scale = Vector3(GRID_W * 0.5, GRID_H * 0.5, 1.0)
	_ceiling_material.roughness = 0.9


func _make_wallpaper_texture() -> ImageTexture:
	var size: int = 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1
	noise.frequency = 0.04
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	for y in size:
		for x in size:
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			# Embossed striped pattern reminiscent of mid-century wallpaper.
			var stripe: float = sin(float(y) * 0.18) * 0.08
			var dot: float = (sin(float(x) * 0.4) * cos(float(y) * 0.4)) * 0.06
			var base := Color("d8b94a")
			var c := Color(
				clamp(base.r + n * 0.18 - 0.09 + stripe + dot, 0.0, 1.0),
				clamp(base.g + n * 0.14 - 0.07 + stripe + dot, 0.0, 1.0),
				clamp(base.b + n * 0.06 - 0.03 + stripe + dot, 0.0, 1.0),
			)
			# Random damp stains.
			var stain: float = noise.get_noise_2d(x * 0.5 + 100, y * 0.5 + 100)
			if stain > 0.55:
				var t: float = (stain - 0.55) / 0.45
				c = c.lerp(Color("6e561a"), t * 0.4)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_carpet_texture() -> ImageTexture:
	var size: int = 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.12
	for y in size:
		for x in size:
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var dirt: float = (noise.get_noise_2d(x * 0.3, y * 0.3) + 1.0) * 0.5
			var base := Color("8c5a26")
			var c := base.lerp(Color("4d3110"), 0.4 + n * 0.4)
			# Damp patches.
			if dirt > 0.65:
				c = c.lerp(Color("2a1a08"), (dirt - 0.65) / 0.35 * 0.7)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_ceiling_texture() -> ImageTexture:
	var size: int = 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 19
	noise.frequency = 0.04
	for y in size:
		for x in size:
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var base := Color("e6dfc8")
			var c := base.lerp(Color("c8bfa3"), n * 0.35)
			# Tile grid lines.
			var tile_x: int = x % 64
			var tile_y: int = y % 64
			if tile_x < 2 or tile_y < 2:
				c = c.darkened(0.35)
			# Stains.
			var stain: float = noise.get_noise_2d(x * 0.6 + 200, y * 0.6 + 200)
			if stain > 0.6:
				c = c.lerp(Color("8a7a55"), (stain - 0.6) / 0.4 * 0.6)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- World construction ----------------------------------------------------

func _spawn_floor_and_ceiling() -> void:
	var w: float = GRID_W * TILE_SIZE
	var h: float = GRID_H * TILE_SIZE

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(w, h)
	floor_mesh.mesh = floor_plane
	floor_mesh.material_override = _carpet_material
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(w, 0.2, h)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_mesh)
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(w * 0.5, 0, h * 0.5)
	add_child(floor_body)

	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"
	var ceiling_plane := PlaneMesh.new()
	ceiling_plane.size = Vector2(w, h)
	ceiling.mesh = ceiling_plane
	ceiling.material_override = _ceiling_material
	ceiling.position = Vector3(w * 0.5, ROOM_HEIGHT, h * 0.5)
	ceiling.rotation_degrees = Vector3(180, 0, 0)
	add_child(ceiling)


func _spawn_walls() -> void:
	# A wall fills any tile that is closed (_grid == 0).
	for x in GRID_W:
		for z in GRID_H:
			if _grid[x][z] == 0:
				_spawn_wall_block(x, z)


func _spawn_wall_block(gx: int, gz: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Wall_%d_%d" % [gx, gz]
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE_SIZE, ROOM_HEIGHT, TILE_SIZE)
	mesh.mesh = box
	mesh.material_override = _wall_material
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = Vector3(TILE_SIZE, ROOM_HEIGHT, TILE_SIZE)
	shape.shape = col
	body.add_child(mesh)
	body.add_child(shape)
	body.position = Vector3(
		gx * TILE_SIZE + TILE_SIZE * 0.5,
		ROOM_HEIGHT * 0.5,
		gz * TILE_SIZE + TILE_SIZE * 0.5
	)
	add_child(body)


func _spawn_lights() -> void:
	# Place a flickering fluorescent light over open tiles, every other tile.
	for x in range(0, GRID_W, 2):
		for z in range(0, GRID_H, 2):
			if _grid[x][z] != 1:
				continue
			var light_root := Node3D.new()
			light_root.set_script(FlickerLight)
			light_root.position = Vector3(
				x * TILE_SIZE + TILE_SIZE * 0.5,
				ROOM_HEIGHT - 0.05,
				z * TILE_SIZE + TILE_SIZE * 0.5
			)
			# Visible fixture (a thin glowing box).
			var fixture := MeshInstance3D.new()
			var fixture_mesh := BoxMesh.new()
			fixture_mesh.size = Vector3(1.4, 0.1, 0.4)
			fixture.mesh = fixture_mesh
			var fixture_mat := StandardMaterial3D.new()
			fixture_mat.albedo_color = Color("fff4c2")
			fixture_mat.emission_enabled = true
			fixture_mat.emission = Color("fff4c2")
			fixture_mat.emission_energy_multiplier = 1.6
			fixture.material_override = fixture_mat
			light_root.add_child(fixture)
			# Actual light source.
			var omni := OmniLight3D.new()
			omni.light_color = Color("fff4c2")
			omni.light_energy = 1.4
			omni.omni_range = TILE_SIZE * 2.0
			omni.shadow_enabled = true
			omni.position = Vector3(0, -0.2, 0)
			light_root.add_child(omni)
			add_child(light_root)


func _spawn_noclip_exit() -> void:
	# Pick a random open tile near the edge to mark as the noclip exit wall.
	var attempts: int = 0
	while attempts < 200:
		attempts += 1
		var ex: int = _rng.randi_range(2, GRID_W - 3)
		var ez: int = _rng.randi_range(2, GRID_H - 3)
		if _grid[ex][ez] != 1:
			continue
		# Find an adjacent wall tile.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var wx: int = ex + d.x
			var wz: int = ez + d.y
			if wx < 0 or wx >= GRID_W or wz < 0 or wz >= GRID_H:
				continue
			if _grid[wx][wz] == 0:
				_create_noclip_marker(ex, ez, wx, wz)
				return


func _create_noclip_marker(open_x: int, open_z: int, wall_x: int, wall_z: int) -> void:
	var area := Area3D.new()
	area.name = "NoclipExit"
	area.set_script(NoclipExit)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE_SIZE * 0.9, ROOM_HEIGHT * 0.9, TILE_SIZE * 0.9)
	col.shape = box
	area.add_child(col)
	area.position = Vector3(
		open_x * TILE_SIZE + TILE_SIZE * 0.5,
		ROOM_HEIGHT * 0.5,
		open_z * TILE_SIZE + TILE_SIZE * 0.5
	)

	# Visual hint: a slightly different colored wall right next to it.
	var hint := MeshInstance3D.new()
	hint.name = "NoclipHint"
	var hint_mesh := QuadMesh.new()
	hint_mesh.size = Vector2(TILE_SIZE * 0.9, ROOM_HEIGHT * 0.9)
	hint.mesh = hint_mesh
	var hint_mat := StandardMaterial3D.new()
	hint_mat.albedo_color = Color("a8842a")
	hint_mat.emission_enabled = true
	hint_mat.emission = Color("4a3a10")
	hint_mat.emission_energy_multiplier = 0.4
	hint.material_override = hint_mat
	# Place the quad on the face of the wall facing into the open tile.
	var wall_center := Vector3(
		wall_x * TILE_SIZE + TILE_SIZE * 0.5,
		ROOM_HEIGHT * 0.5,
		wall_z * TILE_SIZE + TILE_SIZE * 0.5
	)
	var open_center := Vector3(
		open_x * TILE_SIZE + TILE_SIZE * 0.5,
		ROOM_HEIGHT * 0.5,
		open_z * TILE_SIZE + TILE_SIZE * 0.5
	)
	var dir := (open_center - wall_center).normalized()
	hint.position = wall_center + dir * (TILE_SIZE * 0.5 + 0.01)
	add_child(hint)
	hint.look_at(hint.global_position + dir, Vector3.UP)
	add_child(area)


func _spawn_player_at_open_tile() -> void:
	# The Player is added by main.tscn; just emit the spawn point.
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(
		(GRID_W / 2) * TILE_SIZE + TILE_SIZE * 0.5,
		1.0,
		(GRID_H / 2) * TILE_SIZE + TILE_SIZE * 0.5
	)
	add_child(spawn)
