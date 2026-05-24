extends CharacterBody3D

@export var speed := 12.0
@export var box_size := 1.2
@export var box_count := 8
@export var box_visible_duration := 2.0
@export var box_hidden_duration := 2.0
@export var spawn_area_position := Vector3(-8.0, 0.6, -6.0)
@export var spawn_area_size := Vector3(16.0, 0.0, 12.0)
@export var background_tile_size := Vector2(18.0, 18.0)
@export var idle_color := Color(0.239216, 0.521569, 0.776471, 1.0)
@export var walk_color := Color(0.945098, 0.411765, 0.223529, 1.0)

var _spawned_boxes: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _player_visual: MeshInstance3D
var _background_root: Node3D
var _speed_label: Label
var _speed_input: LineEdit
var _position_label: Label
var _position_x_input: LineEdit
var _position_y_input: LineEdit
var _move_button: Button

func _ready():
	_rng.randomize()
	_player_visual = $PlayerVisual
	_background_root = $Background
	_speed_label = $UI/SpeedPanel/MarginContainer/VBoxContainer/SpeedLabel
	_speed_input = $UI/SpeedPanel/MarginContainer/VBoxContainer/SpeedInput
	_position_label = $UI/SpeedPanel/MarginContainer/VBoxContainer/PositionLabel
	_position_x_input = $UI/SpeedPanel/MarginContainer/VBoxContainer/PositionXInput
	_position_y_input = $UI/SpeedPanel/MarginContainer/VBoxContainer/PositionYInput
	_move_button = $UI/SpeedPanel/MarginContainer/VBoxContainer/MoveButton
	_speed_input.text = str(int(speed))
	_speed_input.text_submitted.connect(_on_speed_input_submitted)
	_speed_input.focus_exited.connect(_on_speed_input_focus_exited)
	_position_x_input.text_submitted.connect(_on_position_input_submitted)
	_position_y_input.text_submitted.connect(_on_position_input_submitted)
	_position_x_input.focus_exited.connect(_on_position_input_focus_exited)
	_position_y_input.focus_exited.connect(_on_position_input_focus_exited)
	_move_button.pressed.connect(_move_to_input_position)
	_update_speed_label()
	_update_position_ui()
	_update_infinite_background()
	_spawn_box()
	_box_cycle()
	_update_player_animation()

func _physics_process(_delta: float):
	var direction := Vector3.ZERO

	if Input.is_action_pressed("ui_right"):
		direction.x += 1.0

	if Input.is_action_pressed("ui_left"):
		direction.x -= 1.0

	if Input.is_action_pressed("ui_down"):
		direction.z += 1.0

	if Input.is_action_pressed("ui_up"):
		direction.z -= 1.0

	var move_direction := direction.normalized()
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed
	velocity.y = 0.0
	move_and_slide()
	_update_infinite_background()
	_update_player_animation()
	_update_position_ui()

func _box_cycle():
	while is_inside_tree():
		await get_tree().create_timer(box_visible_duration).timeout
		_remove_box()
		await get_tree().create_timer(box_hidden_duration).timeout
		_spawn_box()

func _spawn_box():
	_remove_box()

	var world_parent := get_parent()
	if world_parent == null:
		return

	for i in range(box_count):
		var spawned_box := MeshInstance3D.new()
		spawned_box.name = "SpawnedBox%d" % i
		spawned_box.mesh = BoxMesh.new()
		spawned_box.scale = Vector3.ZERO
		spawned_box.position = _random_spawn_position()

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.980392, 0.737255, 0.235294, 1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spawned_box.material_override = material

		var mesh := spawned_box.mesh as BoxMesh
		if mesh != null:
			mesh.size = Vector3(box_size, box_size, box_size)

		world_parent.add_child(spawned_box)
		_spawned_boxes.append(spawned_box)
		_animate_box_spawn(spawned_box)

func _remove_box():
	for spawned_box in _spawned_boxes:
		if is_instance_valid(spawned_box):
			_animate_box_despawn(spawned_box)

	_spawned_boxes.clear()

func _random_spawn_position() -> Vector3:
	return Vector3(
		_rng.randf_range(spawn_area_position.x, spawn_area_position.x + spawn_area_size.x),
		spawn_area_position.y,
		_rng.randf_range(spawn_area_position.z, spawn_area_position.z + spawn_area_size.z)
	)

func _update_infinite_background():
	if _background_root == null:
		return

	var center := Vector3(
		floor(global_position.x / background_tile_size.x) * background_tile_size.x,
		0.0,
		floor(global_position.z / background_tile_size.y) * background_tile_size.y
	)
	_background_root.global_position = center

func _update_player_animation():
	if _player_visual == null:
		return

	var material := _player_visual.get_active_material(0) as StandardMaterial3D
	if velocity.length() > 0.01:
		if material != null:
			material.albedo_color = walk_color
		_player_visual.rotation.y = atan2(velocity.x, velocity.z)
	else:
		if material != null:
			material.albedo_color = idle_color

func _animate_box_spawn(spawned_box: MeshInstance3D):
	var tween := create_tween()
	tween.tween_property(
		spawned_box,
		"scale",
		Vector3.ONE,
		0.25
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		spawned_box,
		"rotation",
		Vector3(
			_rng.randf_range(-0.35, 0.35),
			_rng.randf_range(-0.35, 0.35),
			_rng.randf_range(-0.35, 0.35)
		),
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _animate_box_despawn(spawned_box: MeshInstance3D):
	var tween := create_tween()
	tween.tween_property(
		spawned_box,
		"scale",
		Vector3.ZERO,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(spawned_box.queue_free)

func _update_speed_label():
	if _speed_label != null:
		_speed_label.text = "Speed: %d" % int(speed)

func _on_speed_input_submitted(new_text: String):
	_apply_speed_input(new_text)

func _on_speed_input_focus_exited():
	if _speed_input != null:
		_apply_speed_input(_speed_input.text)

func _apply_speed_input(new_text: String):
	var parsed_speed := new_text.to_float()
	speed = max(parsed_speed, 0.0)
	if _speed_input != null:
		_speed_input.text = str(int(speed))
	_update_speed_label()

func _update_position_ui():
	if _position_label != null:
		_position_label.text = "Position: (%d, %d)" % [int(global_position.x), int(global_position.z)]

	if _position_x_input != null and not _position_x_input.has_focus():
		_position_x_input.text = str(int(global_position.x))

	if _position_y_input != null and not _position_y_input.has_focus():
		_position_y_input.text = str(int(global_position.z))

func _on_position_input_submitted(_new_text: String):
	_move_to_input_position()

func _on_position_input_focus_exited():
	_move_to_input_position()

func _move_to_input_position():
	var target_x := global_position.x
	var target_z := global_position.z

	if _position_x_input != null and _position_x_input.text != "":
		target_x = _position_x_input.text.to_float()

	if _position_y_input != null and _position_y_input.text != "":
		target_z = _position_y_input.text.to_float()

	global_position = Vector3(target_x, global_position.y, target_z)
	velocity = Vector3.ZERO
	_update_infinite_background()
	_update_position_ui()
