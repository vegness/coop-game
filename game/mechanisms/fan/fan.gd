# fan.gd
# 风扇机关（可复用、与关卡解耦）
# 功能：
#   1. 转动动画：Fan_8.png（横向 8 帧 32x16 序列帧合集），仅 activate() 后转动，deactivate() 停止（停在第一帧）
#   2. 致死：HazardArea（风扇本体）检测到鸡 → 像掉坑一样传回 last_landed_position（复用 spark.gd 的死亡模式）
#   3. 气流：WindArea（风扇上方气流区）内的鸡持续受到向上推力；
#      最高被吹到 max_blow_y（默认 y=200）：到达后清零向上速度并钳制位置（硬天花板）
# 解耦：不引用关卡类/网络后端；只暴露 activate()/deactivate()（MechanismBase 兼容），
#       由关卡把按钮信号接进来（多个按钮 OR/AND 语义由关卡脚本决定，本机不关心）。
# 多人：死亡仅鸡的 authority 端处理（与 spark 一致，防止各端重复复活）。
extends Node2D
class_name Fan

## 气流强度（向上加速度 px/s²，需大于重力 980 才能吹起）
@export var wind_strength: float = 1600.0
## 被吹飞的最高 y（硬天花板；小于它则钳制，吹不上更上面）
@export var max_blow_y: float = 200.0
## 转动动画速度（fps）
@export var spin_fps: float = 12.0
## 风扇贴图（横向 8 帧序列帧合集）
@export var sheet_texture: Texture2D = preload("res://mechanisms/fan/Fan_8.png")
## 帧数
@export var frame_count: int = 8
## 单帧尺寸（默认 32x16）
@export var frame_size: Vector2i = Vector2i(32, 16)

## 是否激活（默认不转）
var is_active: bool = false

@onready var _sprite: AnimatedSprite2D = $FanSprite
@onready var _hazard: Area2D = $HazardArea
@onready var _wind: Area2D = $WindArea


func _ready() -> void:
	_setup_animation()
	_hazard.body_entered.connect(_on_hazard_body_entered)
	# 挂 Mechanism(8) 层：供 ChickenBase 检测"危险区"（复活点安全判定用）
	_hazard.collision_layer = 8
	if is_active:
		_sprite.play("spin")
	else:
		# 未触发也显示第一帧（静止扇叶）：必须先指定当前动画名，
		# 否则 AnimatedSprite2D 的 animation 仍是默认 "default"（本机只有 "spin" 动画）→ 什么都不显示
		_sprite.animation = "spin"
		_sprite.frame = 0
		_sprite.stop()


# ============================================================
# 控制接口（MechanismBase 兼容，由关卡按钮信号调用）
# ============================================================
func activate() -> void:
	is_active = true
	if _sprite != null:
		_sprite.play("spin")


func deactivate() -> void:
	is_active = false
	if _sprite != null:
		# 停转后仍显示第一帧（静止扇叶），不隐藏
		_sprite.animation = "spin"
		_sprite.frame = 0
		_sprite.stop()


# ============================================================
# 每帧：气流推力 + 高度封顶
# ============================================================
func _physics_process(delta: float) -> void:
	if not is_active:
		return
	for body in _wind.get_overlapping_bodies():
		if not (body is ChickenBase):
			continue
		var chicken := body as ChickenBase
		if chicken.is_dead:
			continue
		# 向上加速（重力在 ChickenBase._apply_gravity 中同时作用，wind>gravity 才能吹起）
		chicken.velocity.y -= wind_strength * delta
		# 硬天花板：到达 max_blow_y 后不再继续上升（吹飞的最高位置）
		if chicken.global_position.y <= max_blow_y:
			chicken.global_position.y = max_blow_y
			if chicken.velocity.y < 0.0:
				chicken.velocity.y = 0.0


# ============================================================
# 致死：碰到风扇本体 → 传回最后落脚点（与 spark.gd / 掉坑一致）
# ============================================================
func _on_hazard_body_entered(body: Node) -> void:
	if not (body is ChickenBase):
		return
	var chicken := body as ChickenBase
	if chicken.is_dead:
		return
	# 多人：仅鸡的 authority 端处理（防止各端重复复活）
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


# ============================================================
# 动画：把横向序列帧合集拆成 frame_count 帧
# ============================================================
func _setup_animation() -> void:
	if sheet_texture == null or _sprite == null:
		return
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null:
		frames = SpriteFrames.new()
		_sprite.sprite_frames = frames
	if not frames.has_animation("spin"):
		frames.add_animation("spin")
	frames.clear("spin")
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_texture
		atlas.region = Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame("spin", atlas)
	frames.set_animation_speed("spin", spin_fps)
	frames.set_animation_loop("spin", true)
