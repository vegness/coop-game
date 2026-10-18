# WindZone.gd
# 风区 - 进入区域的玩家/蛋受风力影响
# 可用于解谜：吹飞玩家、推动蛋
extends Area2D
class_name WindZone

# ============================================================
# 属性
# ============================================================
@export var wind_direction: Vector2 = Vector2.UP     # 风向
@export var wind_strength: float = 300.0              # 风力
@export var is_active: bool = true                    # 是否激活
@export var wind_color: Color = Color.SKY_BLUE

var affected_bodies: Array[Node2D] = []


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4  # Player + Egg
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_visual()


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	for body in affected_bodies:
		if not is_instance_valid(body):
			affected_bodies.erase(body)
			continue

		if body is ChickenBase:
			var chicken := body as ChickenBase
			chicken.velocity += wind_direction * wind_strength * delta
		elif body is RigidBody2D:
			body.apply_central_force(wind_direction * wind_strength)


# ============================================================
# 碰撞回调
# ============================================================
func _on_body_entered(body: Node2D) -> void:
	if body not in affected_bodies:
		affected_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	affected_bodies.erase(body)


# ============================================================
# 控制接口
# ============================================================
func activate() -> void:
	is_active = true
	modulate.a = 1.0


func deactivate() -> void:
	is_active = false
	modulate.a = 0.3


# ============================================================
# 占位视觉
# ============================================================
func _setup_visual() -> void:
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(64, 64)
	color_rect.color = Color(wind_color, 0.2)
	color_rect.position = Vector2(-32, -32)
	add_child(color_rect)

	# 方向箭头指示
	var arrow := ColorRect.new()
	arrow.size = Vector2(4, 20)
	arrow.color = wind_color
	arrow.position = Vector2(-2, -10)
	arrow.pivot_offset = Vector2(2, 10)
	arrow.rotation = wind_direction.angle() + PI / 2
	add_child(arrow)
