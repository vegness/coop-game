# BombEgg.gd
# 炸弹蛋 - 落地/被啄后爆炸
# 效果：破坏 ExplodableWall，击退范围内玩家（无伤害），炸飞其他蛋
extends EggBase
class_name BombEgg

@export var explosion_radius: float = 80.0
@export var knockback_force: float = 600.0

var is_triggered: bool = false

func _on_ready() -> void:
	super._on_ready()
	# 落地后自动触发
	body_entered.connect(_on_bomb_body_entered)
	# 被啄击时也触发（由 Chicken 的 peck 逻辑检测）

func _on_bomb_body_entered(body: Node) -> void:
	if is_triggered:
		return
	if body is ChickenBase and (body as ChickenBase).player_id == owner_id:
		return  # 不触发自己的鸡
	if body is EggBase:
		return  # 等主碰撞
	_explode()

func _trigger_effect() -> void:
	_explode()

func _explode() -> void:
	if is_triggered:
		return
	is_triggered = true

	# 爆炸范围检测
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2 | 4 | 8  # Player + Egg + Mechanism

	var results := space.intersect_shape(query)

	for result in results:
		var obj := result.get("collider")
		if obj == null:
			continue

		# 击退 Chicken
		if obj is ChickenBase:
			var chicken := obj as ChickenBase
			var dir := chicken.global_position - global_position
			var dist := dir.length()
			if dist > 0:
				dir = dir.normalized()
			else:
				dir = Vector2.UP
			var force := knockback_force * (1.0 - dist / explosion_radius)
			chicken.velocity += dir * force

		# 炸飞其他蛋
		if obj is EggBase:
			var egg := obj as EggBase
			if egg == self:
				continue
			var dir := egg.global_position - global_position
			egg.apply_central_impulse(dir.normalized() * knockback_force * 0.5)

		# 破坏可破坏墙体
		if obj.has_method("destroy"):
			obj.destroy()

	# 视觉爆炸效果（占位）
	_show_explosion_effect()
	await get_tree().create_timer(0.1).timeout
	_destroy()

func _show_explosion_effect() -> void:
	# 占位爆炸效果：橙色圆形缩放消失
	for child in get_children():
		if child is ColorRect:
			child.color = Color.ORANGE
			var tween := create_tween()
			tween.tween_property(child, "scale", Vector2(3, 3), 0.1)

func _get_placeholder_color() -> Color:
	return Color.ORANGE
