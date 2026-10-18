# spike_2.gd
# 尖刺机关（序列帧动画版，可复用、与关卡解耦）
# 功能：
#   1. 序列帧动画：Spike_10.png（横向 10 帧 32x32 合集）循环播放（尖刺"伸缩呼吸"）
#   2. 全帧碰撞：碰撞体 = 所有帧非透明区域的**并集**（帧内 x=[0..31], y=[7..21]），
#      覆盖帧变化过程中的任意中间状态 —— 玩家看到的刺有多高，判定就有多高
#   3. 实心：StaticBody2D 供蛋垫脚（刺高 14px < 蛋直径 28px → 蛋能"跨"在刺上，踩蛋过河）
#   4. 致命：HazardArea 检测到鸡 → 传回 last_landed_position（复用 spark.gd 的死亡模式）
# 解耦：不引用关卡类/网络后端；只依赖 ChickenBase 通用接口 + EventBus 信号；
#       多人下仅在鸡的 authority 端处理死亡（防止各端重复复活）
extends Node2D
class_name SpikeHazard

## 动画播放速度（fps）
@export var anim_fps: float = 10.0
## 尖刺贴图（横向 10 帧序列帧合集）
@export var sheet_texture: Texture2D = preload("res://mechanisms/spike_2/Spike_10.png")
## 帧数
@export var frame_count: int = 10
## 单帧尺寸（默认 32x32）
@export var frame_size: Vector2i = Vector2i(32, 32)

@onready var _hazard_area: Area2D = $HazardArea


func _ready() -> void:
	_setup_animation()
	_hazard_area.body_entered.connect(_on_hazard_body_entered)
	# 挂 Mechanism(8) 层：供 ChickenBase 检测"危险区"（复活点安全判定用）
	_hazard_area.collision_layer = 8


# ============================================================
# 动画：把横向序列帧合集拆成 frame_count 帧
# ============================================================
func _setup_animation() -> void:
	var sprite := get_node_or_null("SpikeSprite") as AnimatedSprite2D
	if sprite == null or sheet_texture == null:
		return
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		frames = SpriteFrames.new()
		sprite.sprite_frames = frames
	if not frames.has_animation("default"):
		frames.add_animation("default")
	frames.clear("default")
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_texture
		atlas.region = Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame("default", atlas)
	frames.set_animation_speed("default", anim_fps)
	frames.set_animation_loop("default", true)
	sprite.play("default")


# ============================================================
# 致死：碰到刺 → 传回最后落脚点（与 spark.gd / 掉坑一致）
# ============================================================
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
		var scene := get_tree().current_scene
		if scene != null and "spawn_position" in scene:
			respawn_pos = scene.spawn_position
		else:
			respawn_pos = Vector2(200, 632)
	chicken.revive(respawn_pos)
	EventBus.player_fell_off.emit(chicken.player_id)
