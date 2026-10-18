# portal.gd
# 传送门机关（可复用、与关卡解耦）
# - 视觉：8 帧动画（用 res/Sheet/PORTAL*-Sheet.png 等横幅拆分），循环播放
# - 角色：@export sheet_texture 支持蓝/橙/红等不同颜色
# - 检测：两个 Area2D（SingleCheck 单人/小范围 + MultiCheck 多人/大范围），
#         维护 in_single / in_multi 数组（body_entered/exited 更新），
#         关卡根据单/多人选择对应数组判定通关
# 解耦：不引用任何关卡类/网络后端；只暴露 in_single/in_multi 给关卡查询
# 多人：各端鸡/蛋位置由同步器保证一致 → in_single/in_multi 各端一致 → 通关判定一致
extends Node2D
class_name Portal

## 传送门贴图（横条 8 帧 64×64）
@export var sheet_texture: Texture2D = preload("res://res/Sheet/PORTAL BLUE-Sheet.png")
## 帧数（默认 8）
@export var frame_count: int = 8
## 单帧尺寸（默认 64×64）
@export var frame_size: int = 64
## 动画播放速度（fps）
@export var frame_speed: float = 10.0
## 单人检测半径（小范围）
@export var single_radius: float = 28.0
## 多人检测半径（比单人广一些）
@export var multi_radius: float = 56.0

# 实时数据
var in_single: Array[int] = []  # 当前在单人范围内的 player_id 列表
var in_multi: Array[int] = []   # 当前在多人范围内的 player_id 列表

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _single: Area2D = $SingleCheck
@onready var _multi: Area2D = $MultiCheck


func _ready() -> void:
	_setup_animation()
	_setup_check_areas(_single, single_radius, "_on_single_entered", "_on_single_exited", in_single)
	_setup_check_areas(_multi, multi_radius, "_on_multi_entered", "_on_multi_exited", in_multi)


# 把横幅 sheet_texture 拆成 frame_count 帧，加到 AnimatedSprite2D 的 default 动画
# SpriteFrames.new() 默认含 "default" 动画（0 帧），脚本只补缺失帧（不重复 add_animation）
func _setup_animation() -> void:
	if sheet_texture == null or _sprite == null:
		return
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		frames = SpriteFrames.new()
		_sprite.sprite_frames = frames
	var existing: int = frames.get_frame_count("default")
	for i in frame_count:
		if i < existing:
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_texture
		atlas.region = Rect2i(i * frame_size, 0, frame_size, frame_size)
		frames.add_frame("default", atlas)
	frames.set_animation_speed("default", frame_speed)
	frames.set_animation_loop("default", true)
	_sprite.play("default")


# 设置单个检测 Area2D：圆形 collision、半径、回调
func _setup_check_areas(area: Area2D, radius: float, on_enter: String, on_exit: String, _arr: Array) -> void:
	var shape_node := area.get_node("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	area.collision_layer = 0
	area.collision_mask = 2  # Player（鸡）
	area.body_entered.connect(Callable(self, on_enter))
	area.body_exited.connect(Callable(self, on_exit))


# ============ SingleCheck（单人小范围）============
func _on_single_entered(body: Node) -> void:
	_collect_player(body, in_single)


func _on_single_exited(body: Node) -> void:
	_remove_player(body, in_single)


# ============ MultiCheck（多人大范围）============
func _on_multi_entered(body: Node) -> void:
	_collect_player(body, in_multi)


func _on_multi_exited(body: Node) -> void:
	_remove_player(body, in_multi)


func _collect_player(body: Node, arr: Array) -> void:
	if body is ChickenBase:
		var pid: int = (body as ChickenBase).player_id
		if pid != 0 and pid not in arr:
			arr.append(pid)


func _remove_player(body: Node, arr: Array) -> void:
	if body is ChickenBase:
		var pid: int = (body as ChickenBase).player_id
		arr.erase(pid)
