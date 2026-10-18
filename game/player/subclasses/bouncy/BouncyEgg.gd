# BouncyEgg.gd
# 弹弹蛋 - 高弹性，玩家踩上弹飞，蛋之间可连锁
extends EggBase
class_name BouncyEgg

@export var bounce_force: float = 500.0
@export var bounciness: float = 0.95

func _on_ready() -> void:
	super._on_ready()
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = bounciness
	body_entered.connect(_on_bouncy_body_entered)

func _on_bouncy_body_entered(body: Node) -> void:
	if body is ChickenBase:
		var chicken := body as ChickenBase
		# 计算弹飞方向
		var dir := chicken.global_position - global_position
		if dir.length() < 0.1:
			dir = Vector2.UP
		dir = dir.normalized()
		chicken.velocity = dir * bounce_force + Vector2.UP * bounce_force
		chicken.current_state = ChickenBase.ChickenState.FALLING

func _trigger_effect() -> void:
	pass

func _get_placeholder_color() -> Color:
	return Color.HOT_PINK
