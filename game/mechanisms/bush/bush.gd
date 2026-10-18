## 普通草丛藏身点 bush：密实不透明，7 束圆润草团组成
## 尺寸 144x124 / scale=0.5 → 世界 72x62（> 小鸡 51x51，完全藏住）
## 4 帧摆动动画 sway：身体进入 Sensor 时停摆，退出恢复
class_name BushHiding
extends Node2D

@export var sprite_path: NodePath = ^"Sprite"
@export var sensor_path: NodePath = ^"Sensor"
@export var speed: float = 6.0
@export var target_group: StringName = &"player"

signal entered_cover(body)
signal exited_cover(body)

var _sprite: AnimatedSprite2D
var _sensor: Area2D
var _covered: bool = false

func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_sensor = get_node_or_null(sensor_path) as Area2D
	if _sprite == null:
		push_error("bush.gd: 缺少子节点 Sprite (AnimatedSprite2D)")
		return
	if _sensor == null:
		push_error("bush.gd: 缺少子节点 Sensor (Area2D)")
		return
	# 4 帧摆动循环
	if _sprite.sprite_frames == null:
		push_error("bush.gd: Sprite.sprite_frames 未配置 (frames=" + bush_resource_name() + ")")
		return
	if _sprite.sprite_frames.has_animation(&"sway"):
		_sprite.play(&"sway")
		_sprite.speed_scale = speed
	_sensor.body_entered.connect(_on_body_entered)
	_sensor.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(target_group):
		return
	if _covered:
		return
	_covered = true
	if _sprite != null:
		_sprite.pause()
	entered_cover.emit(body)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group(target_group):
		return
	if not _covered:
		return
	_covered = false
	if _sprite != null:
		_sprite.play()
	exited_cover.emit(body)

func bush_resource_name() -> String:
	return "bush_sway"