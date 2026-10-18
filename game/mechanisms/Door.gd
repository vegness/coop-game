# Door.gd
# 门 - 可被压力板/开关控制开关
extends StaticBody2D
class_name Door

# ============================================================
# 属性
# ============================================================
@export var door_id: String = ""
@export var start_open: bool = false
@export var open_speed: float = 3.0  # 开关动画速度

var is_open: bool = false
var target_open_amount: float = 1.0  # 0=关闭, 1=完全打开

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0
	if start_open:
		_open_instant()


func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	target_open_amount = move_toward(target_open_amount, target, open_speed * delta)

	# 视觉缩放
	color_rect.scale.y = 1.0 - target_open_amount * 0.9

	# 碰撞体
	if target_open_amount > 0.9:
		collision_shape.disabled = true
	else:
		collision_shape.disabled = false


# ============================================================
# 控制接口
# ============================================================
func activate() -> void:
	if not is_open:
		_open()


func deactivate() -> void:
	if is_open:
		_close()


func _open() -> void:
	is_open = true
	EventBus.door_opened.emit(door_id)


func _close() -> void:
	is_open = false
	EventBus.door_closed.emit(door_id)


func _open_instant() -> void:
	is_open = true
	target_open_amount = 1.0
	color_rect.scale.y = 0.1
	collision_shape.disabled = true


# ============================================================
# 占位视觉
# ============================================================
func _setup_visual() -> void:
	if not color_rect:
		return
	color_rect.size = Vector2(48, 64)
	color_rect.color = Color.SADDLE_BROWN
	color_rect.position = Vector2(-24, -64)
