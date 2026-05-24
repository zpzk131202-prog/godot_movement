extends CharacterBody2D

@export var speed = 300.0
@export var box_size = 24.0
@export var box_count = 8
@export var box_visible_duration = 2.0
@export var box_hidden_duration = 2.0
@export var spawn_area_position = Vector2(100, 100)
@export var spawn_area_size = Vector2(900, 500)

var _spawned_boxes: Array[Polygon2D] = []
var _rng := RandomNumberGenerator.new()
var _player_visual: AnimatedSprite2D
var _background_root: Node2D
var _background_template: Sprite2D
var _background_tiles: Array[Sprite2D] = []
var _background_tile_size := Vector2.ZERO
var _speed_label: Label
var _speed_input: LineEdit
var _position_label: Label
var _position_x_input: LineEdit
var _position_y_input: LineEdit
var _move_button: Button

func _ready():
	_rng.randomize()
	_player_visual = $AnimatedSprite2D
	_background_root = $Background
	_background_template = $Background/Tile
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
	_setup_infinite_background()
	_spawn_box()
	_box_cycle()

func _physics_process(_delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		direction.x += 1

	if Input.is_action_pressed("ui_left"):
		direction.x -= 1

	if Input.is_action_pressed("ui_down"):
		direction.y += 1

	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	velocity = direction.normalized() * speed
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
		var spawned_box := Polygon2D.new()
		spawned_box.name = "SpawnedBox%d" % i
		spawned_box.color = Color(0.980392, 0.737255, 0.235294, 1)
		spawned_box.scale = Vector2.ZERO
		spawned_box.polygon = PackedVector2Array(
			[
				Vector2(-box_size * 0.5, -box_size * 0.5),
				Vector2(box_size * 0.5, -box_size * 0.5),
				Vector2(box_size * 0.5, box_size * 0.5),
				Vector2(-box_size * 0.5, box_size * 0.5),
			]
		)
		spawned_box.global_position = _random_spawn_position()
		world_parent.add_child(spawned_box)
		_spawned_boxes.append(spawned_box)
		_animate_box_spawn(spawned_box)

func _remove_box():
	for spawned_box in _spawned_boxes:
		if is_instance_valid(spawned_box):
			_animate_box_despawn(spawned_box)

	_spawned_boxes.clear()

func _random_spawn_position() -> Vector2:
	return Vector2(
		_rng.randf_range(spawn_area_position.x, spawn_area_position.x + spawn_area_size.x),
		_rng.randf_range(spawn_area_position.y, spawn_area_position.y + spawn_area_size.y)
	)

func _setup_infinite_background():
	if _background_root == null or _background_template == null or _background_template.texture == null:
		return

	_background_tile_size = _background_template.texture.get_size()
	_background_tiles.append(_background_template)

	for y in range(-1, 2):
		for x in range(-1, 2):
			var tile: Sprite2D
			if x == 0 and y == 0:
				tile = _background_template
			else:
				tile = _background_template.duplicate()
				_background_root.add_child(tile)

			tile.position = Vector2(x, y) * _background_tile_size
			if tile not in _background_tiles:
				_background_tiles.append(tile)

	_update_infinite_background()

func _update_infinite_background():
	if _background_root == null or _background_tile_size == Vector2.ZERO:
		return

	var center = Vector2(
		floor(global_position.x / _background_tile_size.x) * _background_tile_size.x,
		floor(global_position.y / _background_tile_size.y) * _background_tile_size.y
	)
	_background_root.global_position = center

func _update_player_animation():
	if _player_visual == null:
		return

	if velocity.length() > 0.0:
		if _player_visual.animation != &"walk":
			_player_visual.play(&"walk")
		_player_visual.flip_h = velocity.x < 0.0
	else:
		_player_visual.play(&"idle")

func _animate_box_spawn(spawned_box: Polygon2D):
	var tween = create_tween()
	tween.tween_property(spawned_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(spawned_box, "rotation", _rng.randf_range(-0.35, 0.35), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _animate_box_despawn(spawned_box: Polygon2D):
	var tween = create_tween()
	tween.tween_property(spawned_box, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(spawned_box, "modulate:a", 0.0, 0.2)
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
	var parsed_speed = new_text.to_float()
	speed = max(parsed_speed, 0.0)
	if _speed_input != null:
		_speed_input.text = str(int(speed))
	_update_speed_label()

func _update_position_ui():
	if _position_label != null:
		_position_label.text = "Position: (%d, %d)" % [int(global_position.x), int(global_position.y)]

	if _position_x_input != null and not _position_x_input.has_focus():
		_position_x_input.text = str(int(global_position.x))

	if _position_y_input != null and not _position_y_input.has_focus():
		_position_y_input.text = str(int(global_position.y))

func _on_position_input_submitted(_new_text: String):
	_move_to_input_position()

func _on_position_input_focus_exited():
	_move_to_input_position()

func _move_to_input_position():
	var target_x = global_position.x
	var target_y = global_position.y

	if _position_x_input != null and _position_x_input.text != "":
		target_x = _position_x_input.text.to_float()

	if _position_y_input != null and _position_y_input.text != "":
		target_y = _position_y_input.text.to_float()

	global_position = Vector2(target_x, target_y)
	velocity = Vector2.ZERO
	_update_infinite_background()
	_update_position_ui()
