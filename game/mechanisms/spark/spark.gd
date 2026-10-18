# spark.gd
# 尖刺机关（可复用、与关卡解耦）
# 功能：
#   1. 往复移动：伸出 ↔ 缩回（先向左缩回 retract_distance，再向右伸出），Tween 循环
#   2. 墙内遮挡：缩回墙内的部分通过 shader 按世界 x 裁剪线变透明（视觉上像缩进墙里）
#   3. 致命：HazardArea（Area2D）检测到鸡 → 像掉坑一样传回 last_landed_position
# 解耦：不引用任何关卡类/网络后端；只依赖 ChickenBase 通用接口 + EventBus 信号；
#       多人下仅在鸡的 authority 端处理死亡（防止各端重复复活）
extends Node2D
class_name Spark

## 每段移动距离（px）：缩回/伸出各移动这么多
@export var retract_distance: float = 50.0
## 移动速度（px/s）
@export var move_speed: float = 80.0
## 墙的世界 x 坐标（裁剪线）：0 = 不启用墙内遮挡
@export var wall_x: float = 0.0
## 遮挡方向：true = x<wall_x（墙在左）透明；false = x>wall_x（墙在右）透明
@export var hide_left_of_wall: bool = true
## 关卡加载后延迟启动（秒）：避免就绪瞬间误伤/动画瞬跳
@export var start_delay: float = 0.5

const CLIP_SHADER: Shader = preload("res://mechanisms/spark/spark_clip.gdshader")

var _start_x: float = 0.0
var _tween: Tween

@onready var _hazard_area: Area2D = $HazardArea


func _ready() -> void:
	_start_x = position.x
	_hazard_area.body_entered.connect(_on_hazard_body_entered)
	# 挂 Mechanism(8) 层：供 ChickenBase 检测"危险区"（复活点安全判定用）
	_hazard_area.collision_layer = 8
	# 死亡判定区 = 用户画的刺碰撞体积（从 StaticBody2D/CollisionPolygon2D 动态同步，
	# 保证"整个刺都不能碰"；以后调整刺碰撞体也无需改 HazardArea）
	_sync_hazard_shape()
	_apply_clip()
	_start_later()


# 死亡判定多边形跟随用户画的刺碰撞体积：
# StaticBody2D 的 CollisionPolygon2D 是"参照源"（用户画的体积），运行时复制到
# HazardArea。这样判定区永远精确等于用户画的刺形状，而不是手工复制的一份旧数据。
func _sync_hazard_shape() -> void:
	var src := get_node_or_null("StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
	var dst := get_node_or_null("HazardArea/CollisionPolygon2D") as CollisionPolygon2D
	if src != null and dst != null:
		dst.polygon = src.polygon


func _start_later() -> void:
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if not is_inside_tree():
		return
	_start_tween()


# 往复：先向左缩回，再向右伸出（每段 retract_distance），无限循环
func _start_tween() -> void:
	var duration: float = retract_distance / move_speed
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "position:x", _start_x - retract_distance, duration)
	_tween.tween_property(self, "position:x", _start_x, duration)


# 墙内遮挡：给 Sprite2D 挂裁剪 shader（以世界 x 为裁剪线，墙内像素 alpha=0）
func _apply_clip() -> void:
	if wall_x == 0.0:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = CLIP_SHADER
		sprite.material = mat
	mat.set_shader_parameter("clip_x", wall_x)
	mat.set_shader_parameter("from_left", hide_left_of_wall)


# 碰到鸡 → 像掉坑一样传回最后落脚点（与关卡 _on_level_process 的坠落处理一致）
func _on_hazard_body_entered(body: Node) -> void:
	if not (body is ChickenBase):
		return
	var chicken := body as ChickenBase
	if chicken.is_dead:
		return
	# 多人：仅鸡的 authority 端处理（远端副本位置由权威端同步覆盖，防止重复复活）
	if not chicken.is_multiplayer_authority():
		return
	var respawn_pos: Vector2 = chicken.last_landed_position
	if respawn_pos == Vector2.ZERO:
		# 兜底：读当前场景的 spawn_position（鸭子类型，不依赖具体关卡类）
		var scene := get_tree().current_scene
		if scene != null and "spawn_position" in scene:
			respawn_pos = scene.spawn_position
		else:
			respawn_pos = Vector2(200, 632)
	chicken.revive(respawn_pos)
	EventBus.player_fell_off.emit(chicken.player_id)
