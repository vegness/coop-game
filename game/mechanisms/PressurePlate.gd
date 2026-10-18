# PressurePlate.gd
# 压力板 - 玩家/蛋站在上面时触发
# 可连接门、平台等机关
extends Area2D
class_name PressurePlate

# ============================================================
# 属性
# ============================================================
@export var required_weight: int = 1      # 需要多少个物体压住
@export var linked_mechanisms: Array[NodePath] = []  # 关联的机关节点路径
@export var plate_color: Color = Color.ORANGE

var bodies_on_plate: int = 0
var is_pressed: bool = false

@onready var color_rect: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4  # Player + Egg
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# ============================================================
# 碰撞回调
# ============================================================
func _on_body_entered(body: Node2D) -> void:
	if body is ChickenBase or body is EggBase:
		bodies_on_plate += 1
		if bodies_on_plate >= required_weight and not is_pressed:
			_press()


func _on_body_exited(body: Node2D) -> void:
	if body is ChickenBase or body is EggBase:
		bodies_on_plate = max(0, bodies_on_plate - 1)
		if bodies_on_plate < required_weight and is_pressed:
			_release()


# ============================================================
# 按下/释放
# ============================================================
func _press() -> void:
	is_pressed = true
	color_rect.color = plate_color.darkened(0.3)
	EventBus.pressure_plate_activated.emit(self)
	_activate_linked_mechanisms()


func _release() -> void:
	is_pressed = false
	color_rect.color = plate_color
	EventBus.pressure_plate_deactivated.emit(self)
	_deactivate_linked_mechanisms()


func _activate_linked_mechanisms() -> void:
	for path in linked_mechanisms:
		var node := get_node(path)
		if node and node.has_method("activate"):
			node.activate()


func _deactivate_linked_mechanisms() -> void:
	for path in linked_mechanisms:
		var node := get_node(path)
		if node and node.has_method("deactivate"):
			node.deactivate()
