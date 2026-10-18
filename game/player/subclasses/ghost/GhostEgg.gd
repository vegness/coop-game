# GhostEgg.gd
# 幽灵蛋 - 可穿透墙体，触碰蛋的玩家获得短暂穿墙能力
extends EggBase
class_name GhostEgg

@export var ghost_power_duration: float = 3.0

func _on_ready() -> void:
	super._on_ready()
	# 幽灵蛋不与 World 层碰撞（穿透墙体），只与 Player 层碰撞
	collision_mask = 2  # Player layer only
	collision_layer = 4  # Egg layer
	body_entered.connect(_on_ghost_body_entered)

func _on_ghost_body_entered(body: Node) -> void:
	if body is ChickenBase:
		_grant_ghost_power(body as ChickenBase)

func _grant_ghost_power(chicken: ChickenBase) -> void:
	# 临时让鸡穿透墙体
	var original_mask := chicken.collision_mask
	chicken.collision_mask = chicken.collision_mask & ~1  # 移除 World 碰撞

	# 视觉反馈：鸡变半透明
	if chicken.sprite:
		chicken.sprite.modulate.a = 0.5

	# 定时恢复
	var chicken_ref := chicken
	var timer := get_tree().create_timer(ghost_power_duration)
	timer.timeout.connect(func():
		if is_instance_valid(chicken_ref):
			chicken_ref.collision_mask = original_mask
			if chicken_ref.sprite:
				chicken_ref.sprite.modulate.a = 1.0
	)

func _trigger_effect() -> void:
	pass

func _get_placeholder_color() -> Color:
	return Color.MEDIUM_PURPLE
