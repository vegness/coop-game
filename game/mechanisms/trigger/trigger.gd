# trigger.gd
# 触发机关（压力按钮）：按"重量"触发，鸡=1.0 / 蛋=0.5（weight 属性）
# 需要 total_weight >= require_weight 才按下（如 require=1.0 → 1 只鸡 或 2 个蛋）
# 视觉：up（未触发，凸起）/ down（触发，压下）两帧切换 + 板面轻微下沉
# 输出：pressed/released/weight_changed 信号 + EventBus.pressure_plate_activated/deactivated
#       + linked_mechanisms 联动（门/平台，调用 activate/deactivate）
# 重量每帧重算（遍历 overlapping bodies），不依赖 body_entered/exited 事件——
#   蛋 10 秒消失/被销毁时按钮重量自动正确更新（验收：蛋消失按钮正确松开）
# 复用：丢进关卡即可，@export 配贴图/缩放/require_weight/关联机关；不引用关卡类/网络后端（解耦）
# 多人：检测输入源（鸡/蛋位置）由上层同步器保证各端一致 → 各端本地检测结果天然一致，无需 RPC
class_name Trigger
extends Area2D

## 触发信号：从 false→true 触发一次
signal pressed
## 松开信号：从 true→false 触发一次
signal released
## 重量变化（持续触发，参数为当前总重量）
signal weight_changed(current_weight: float)

## 未触发贴图（凸起）
@export var up_texture: Texture2D = preload("res://mechanisms/trigger/trigger_up.png")
## 触发贴图（压下）
@export var down_texture: Texture2D = preload("res://mechanisms/trigger/trigger_down.png")
## 触发所需总重量（1.0=1只鸡或2个蛋；0.5=1个蛋即可）
@export var require_weight: float = 1.0
## 按下时板面下沉像素（视觉反馈）
@export var pressed_offset_y: float = 4.0
## 初始是否按下
@export var start_pressed: bool = false
## 关联机关（按下时 activate，松开时 deactivate）
@export var linked_mechanisms: Array[NodePath] = []

# 碰撞层（项目约定：鸡=2，蛋=4）
const LAYER_PLAYER: int = 2
const LAYER_EGG: int = 4

# 运行时
var current_weight: float = 0.0
var is_pressed: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0  # 机关不挡人
	collision_mask = LAYER_PLAYER | LAYER_EGG
	# ⚠️ 视觉大小与碰撞体完全由用户在编辑器里调好（Sprite2D/实例 scale + CollisionShape2D），
	#    脚本不覆盖任何尺寸（编辑器所见即运行时所得）
	_set_visual(start_pressed)


func _physics_process(_delta: float) -> void:
	_recalculate_weight()


# 每帧重算重量：遍历当前重叠 body，累加 player/egg 组的 weight 属性
# （鸡 1.0 / 蛋 0.5）。蛋被销毁/传送带推走时 overlap 消失 → 重量自动扣减
func _recalculate_weight() -> void:
	var total := 0.0
	for body in get_overlapping_bodies():
		if (body.is_in_group("player") or body.is_in_group("egg")) and "weight" in body:
			total += body.weight
	if absf(total - current_weight) > 0.0001:
		current_weight = total
		weight_changed.emit(current_weight)
	var should_press := current_weight >= require_weight
	if should_press and not is_pressed:
		_press()
	elif not should_press and is_pressed:
		_release()


# ============================================================
# 按下/释放
# ============================================================
func _press() -> void:
	is_pressed = true
	_set_visual(true)
	pressed.emit()
	EventBus.pressure_plate_activated.emit(self)
	_activate_linked_mechanisms()


func _release() -> void:
	is_pressed = false
	_set_visual(false)
	released.emit()
	EventBus.pressure_plate_deactivated.emit(self)
	_deactivate_linked_mechanisms()


func _set_visual(pressed: bool) -> void:
	_sprite.texture = down_texture if pressed else up_texture
	_sprite.position = Vector2(0, pressed_offset_y if pressed else 0.0)


# ============================================================
# 关联机关
# ============================================================
func _activate_linked_mechanisms() -> void:
	for path in linked_mechanisms:
		var node := get_node_or_null(path)
		if node != null and node.has_method("activate"):
			node.activate()


func _deactivate_linked_mechanisms() -> void:
	for path in linked_mechanisms:
		var node := get_node_or_null(path)
		if node != null and node.has_method("deactivate"):
			node.deactivate()
