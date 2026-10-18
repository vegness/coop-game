# door.gd
# 抬升门（机关）：被 trigger 联动后门向上抬升，门下底面最高到 clip_y（缩进墙/天花板内）
# 视觉：y<clip_y 的部分裁剪透明（"缩进墙里被遮挡"的效果）；门体用鲜明色
# 解耦：extends MechanismBase（提供 activate/deactivate 接口，trigger 通过
#       linked_mechanisms + has_method 联动）；不引用任何关卡类/网络后端
# 注意：不声明 class_name（旧 mechanisms/Door.gd 已占用 Door，本实现是抬升版）
extends MechanismBase

## 门最高抬升时下底面 y（= 裁剪线；门缩进墙后下底面贴住墙下沿，墙内部分不可见）
@export var clip_y: float = 500.0
## 升降速度（px/s）
@export var move_speed: float = 150.0
## 初始是否已抬起
@export var start_open: bool = false
## 被门压后复活免疫时长（秒）：防"复活点仍在门下 → 立即再压死"的死循环
@export var crush_immunity_time: float = 0.8

const CLIP_SHADER: Shader = preload("res://mechanisms/trigger/door_clip.gdshader")

var _base_y: float = 0.0
var _half_h: float = 0.0

# 压击免疫表：chicken -> 免疫到期时间（秒，基于 Time.get_ticks_msec）
var _crush_immunity: Dictionary = {}
var _crush_area: Area2D = null

# 是否处于"可压击"状态：门关闭/正在落下时才允许判压死。
# 门抬起（activate）后设 false → 小鸡在门下跳跃（含二段跳）不会被 CrushArea 误判死亡。
var _can_crush: bool = false


func _ready() -> void:
	_base_y = position.y
	_half_h = _compute_half_height()
	_apply_clip()
	_crush_area = get_node_or_null("CrushArea") as Area2D
	if _crush_area != null:
		_crush_area.body_entered.connect(_on_crush_body_entered)
	if start_open:
		position.y = _target_y()
		current_state = MechanismState.ACTIVATED
		is_triggered = true
	# 初始状态：门未抬起（关闭）则能压击；已抬起（打开）则不能
	_can_crush = not start_open


func _physics_process(_delta: float) -> void:
	# 每物理帧兜底轮询（body_entered 可能因门体实心挤压时序而漏判/迟到）：
	# 直接查 CrushArea 当前重叠的 body，只要有小鸡在门下且门在落下就判压死。
	# 免疫表防止"复活→仍在门下→再判死"死循环。
	if _crush_area == null:
		return
	for body in _crush_area.get_overlapping_bodies():
		if body is ChickenBase:
			_try_crush(body as ChickenBase)


# 从碰撞体算门的全局半高（door.tscn 内 2x8 + 关卡实例 scale 会一起缩放）
func _compute_half_height() -> float:
	var shape_node := get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size.y * 0.5 * shape_node.scale.y * self.scale.y
	return 0.0


# 抬起时门中心目标 y（使下底面 = clip_y）
func _target_y() -> float:
	return clip_y - _half_h


func _on_activate() -> void:
	_can_crush = false  # 门开始抬起 → 门下空间可通行，不再判压击
	_tween_to(_target_y())


func _on_deactivate() -> void:
	_can_crush = true  # 门开始落下 → 门下小鸡会被压死
	_tween_to(_base_y)


func _tween_to(target_y: float) -> void:
	var dist := absf(target_y - position.y)
	if dist < 0.5:
		position.y = target_y
		return
	create_tween().tween_property(self, "position:y", target_y, dist / move_speed)


# 门体裁剪：y<clip_y（缩进墙内的部分）透明
func _apply_clip() -> void:
	var visual := get_node_or_null("DoorVisual") as CanvasItem
	if visual == null:
		return
	var mat := visual.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = CLIP_SHADER
		visual.material = mat
	mat.set_shader_parameter("clip_y", clip_y)


# ============================================================
# 压击判定：门落下压到鸡（鸡在门体区域内）→ 死亡传送回落脚点
# 与掉坑/尖刺类似但触发不同：这里是"被门体挤压"（防止鸡被压穿地面卡死）
# ============================================================
func _on_crush_body_entered(body: Node) -> void:
	if body is ChickenBase:
		_try_crush(body as ChickenBase)


func _try_crush(chicken: ChickenBase) -> void:
	# 门抬起（打开）时不判压击：否则小鸡在门下跳跃会误触 CrushArea 被误判死亡
	if not _can_crush:
		return
	if chicken.is_dead:
		return
	# 只有小鸡真正与门体实心碰撞（被门压住）才判死：
	# CrushArea 是门下的大范围检测区，若只凭"在区内"就判死，
	# 门下若叠了平台（如移动地板），小鸡正常站在平台上经过就会被误杀。
	if not _chicken_touching_door(chicken):
		return
	# 多人：仅鸡的 authority 端处理（防止各端重复复活）
	if not chicken.is_multiplayer_authority():
		return
	# 免疫期：刚被压复活后短时间内不再判死（否则复活点若仍在门下会无限循环）
	if _is_immune(chicken):
		return
	_mark_immune(chicken)
	var respawn_pos: Vector2 = _get_respawn_pos(chicken)
	chicken.revive(respawn_pos)
	EventBus.player_fell_off.emit(chicken.player_id)


# 小鸡碰撞体是否与门体实心碰撞（世界 AABB 相交判定）
func _chicken_touching_door(chicken: ChickenBase) -> bool:
	var door_shape_node := get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if door_shape_node == null:
		return true  # 无法判定时保守：保持原行为（区内即判）
	var door_rect := _collision_global_rect(door_shape_node)
	var chick_shape_node := chicken.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if chick_shape_node == null:
		return door_rect.grow(12.0).has_point(chicken.global_position)
	return door_rect.intersects(_collision_global_rect(chick_shape_node))


# 把 CollisionShape2D 转成世界坐标 AABB（含父链 scale；非矩形按节点位置 8x8 退化）
func _collision_global_rect(shape_node: CollisionShape2D) -> Rect2:
	var s: Shape2D = shape_node.shape
	if s is RectangleShape2D:
		var size: Vector2 = (s as RectangleShape2D).size * shape_node.global_scale
		var center: Vector2 = shape_node.global_position
		return Rect2(center - size * 0.5, size)
	var p: Vector2 = shape_node.global_position
	return Rect2(p - Vector2(4, 4), Vector2(8, 8))


func _is_immune(chicken: ChickenBase) -> bool:
	return _crush_immunity.get(chicken, 0.0) > Time.get_ticks_msec() / 1000.0


func _mark_immune(chicken: ChickenBase) -> void:
	_crush_immunity[chicken] = Time.get_ticks_msec() / 1000.0 + crush_immunity_time


# 复活位置：优先最后落脚点（与掉坑一致）；若该位置在门正下方（会被再次压死），
# 则水平偏移到门旁边（免疫期有限，偏移保证一次复活后不会立刻再压）
func _get_respawn_pos(chicken: ChickenBase) -> Vector2:
	var pos: Vector2 = chicken.last_landed_position
	if pos == Vector2.ZERO:
		var scene := get_tree().current_scene
		if scene != null and "spawn_position" in scene:
			pos = scene.spawn_position
		else:
			pos = Vector2(200, 632)
	var half_w: float = _compute_half_width()
	if absf(pos.x - global_position.x) < half_w + 14.0:
		var dir: float = 1.0 if global_position.x >= pos.x else -1.0
		pos.x = global_position.x + dir * (half_w + 24.0)
	return pos


# 门的全局半宽（door.tscn 内 2x8 + 关卡实例 scale 一起缩放）
func _compute_half_width() -> float:
	var shape_node := get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size.x * 0.5 * shape_node.scale.x * self.scale.x
	return 0.0