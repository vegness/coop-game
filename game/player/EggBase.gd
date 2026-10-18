# EggBase.gd
# 蛋抽象基类（RigidBody2D）
#
# 物理设计（更精确的蛋物理引擎）：
#   - 空中（未落地）：无碰撞体积 —— collision_layer=0（不对玩家/蛋/机关产生碰撞），
#     仅 collision_mask=World 以便蛋能落到地面停住
#   - 落地后：激活完整碰撞 —— layer=Egg(4)，mask=World|Player|Egg
#     · 玩家可以站在蛋上（作为临时平台）
#     · 鸡跑过/碰到会把蛋推着滚动（CharacterBody2D 物理推动）
#     · 蛋与蛋互相碰撞、可以挤开
#   - 圆形碰撞 + 不锁旋转 → 被啄击踢飞后自然翻滚
#   - 碎蛋规则：只有小鸡处于"踩踏(STOMPING)"状态踩到蛋才会碎，
#     其他动作（普通跳跃/下落/滑翔）踩到蛋都不会碎
# 子类重写 _trigger_effect() 实现不同蛋效果
extends RigidBody2D
class_name EggBase

# ============================================================
# 属性
# ============================================================
@export var lifetime: float = 10.0            # 存活时间（秒，到点自动消失；-1 = 永久，特殊蛋用）
@export var destroy_on_impact: bool = false  # 落地即触发（炸弹蛋等特殊蛋用）
@export var break_show_time: float = 0.6     # 压碎后保留显示时间
@export var ignore_restore_delay: float = 0.3  # 下蛋免碰撞持续时长（鸡与蛋连续分离多久后恢复碰撞）
@export var weight: float = 0.5              # 按钮重量（压力板按 weight 累加判定，1 个蛋不足以压住 require 1.0 的按钮）

# 物理层常量
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_EGG: int = 4

var owner_id: int = -1    # 下蛋玩家 peer_id
var age: float = 0.0
var is_broken: bool = false
var is_landed: bool = false      # 是否已落地（落地后激活完整碰撞，持久）
var _ground_contact: bool = false  # 是否已与地面接触（body_entered 信号）

var egg_sprite: Sprite2D
var egg_collision: CollisionShape2D

# 下蛋瞬间与鸡互不碰撞：记录"下蛋的鸡"，碰撞掩码排除 Player 层
# （蛋与蛋、蛋与世界碰撞全部保留）；鸡与蛋连续分离 ignore_restore_delay 秒后恢复完整碰撞
var _ignored_chicken: ChickenBase = null
var _separated_time: float = 0.0  # 免碰撞已持续时长（到 ignore_restore_delay 无条件恢复 Player 碰撞）


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	# 空中：无碰撞层，只与地面碰撞（用于落地停下）
	collision_layer = 0
	collision_mask = LAYER_WORLD

	mass = 0.5
	gravity_scale = 1.0
	lock_rotation = false  # 允许滚动（被踢着翻滚）

	# 物理材质：中等摩擦（滚动自然）、轻微弹性
	var mat := PhysicsMaterial.new()
	mat.friction = 0.5
	mat.bounce = 0.15
	physics_material_override = mat

	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	# 蛋分组：碎蛋时唤醒可能失去支撑的上方蛋（修复堆叠蛋浮空）
	add_to_group("eggs")
	# 通用组（按钮按组检测重量）；与 "eggs" 并存兼容旧代码
	add_to_group("egg")
	_setup_visual()
	_on_ready()


func _physics_process(delta: float) -> void:
	if is_broken:
		return
	age += delta

	# 落地检测：一次性激活完整碰撞（此后蛋有完整物理：可站/可踢/可互挤）
	if not is_landed and _check_on_ground():
		_activate_full_collision()

	# 下蛋瞬移免碰撞：固定时长窗口（ignore_restore_delay），到点无条件恢复 Player 层碰撞。
	# 不能用"鸡与蛋分离才恢复"——鸡站在新下的蛋上时，蛋中心在鸡碰撞体内，
	# 重叠判定恒 true → 免碰撞永续 → 穿模。固定窗口下：下蛋反冲跳起（0.3s 内必已分离），
	# 恢复时鸡在空中不会挤开蛋；鸡落回新蛋上时碰撞已恢复，正常站立。
	if _ignored_chicken != null:
		_separated_time += delta
		if _separated_time >= ignore_restore_delay:
			_ignored_chicken = null
			_update_collision_mask()

	if lifetime > 0:
		if age >= lifetime:
			# 停留到期：自动裂开（复用踩踏碎裂视觉流程：broken 图 + 短暂保留 + 销毁）
			broadcast_break()
			return
	# 出界销毁（x 上限要覆盖最宽关卡：level2 宽 4800 + 余量；level1 兼容）
	if global_position.y > 900 or global_position.x < -200 or global_position.x > 5000:
		_destroy()


# 检测是否已接触支撑（World 地面/平台 + 其他蛋）：
# 1) body_entered 信号（主动下落场景可靠）；2) 每帧向下射线兜底
# ⚠️ 必须包含 Egg 层：蛋可以垫在蛋上（蛋梯），落在蛋上也要激活完整碰撞；
#    否则新蛋落在旧蛋上会一直保持 layer=0（无碰撞体积）→ 永久穿模
func _check_on_ground() -> bool:
	if _ground_contact:
		return true
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 20.0)
	)
	q.collision_mask = LAYER_WORLD | LAYER_EGG
	q.exclude = [self]
	var result := space.intersect_ray(q)
	if result.is_empty():
		return false
	# 蛋半径 14：中心距支撑面约 14px（含接触间隙），放宽到 20px 才不会被误判为悬空
	var hit: Vector2 = result.position
	return global_position.distance_to(hit) < 20.0


# 激活完整碰撞：蛋从此拥有平台/互挤/被踢属性（若仍在下蛋瞬移免碰撞期，Player 层暂不启用）
func _activate_full_collision() -> void:
	is_landed = true
	collision_layer = LAYER_EGG
	_update_collision_mask()
	_on_landed_activated()


# ============================================================
# 视觉（用 res/egg/egg.png；碎裂时切 broken_egg.png）
# ============================================================
func _setup_visual() -> void:
	egg_sprite = Sprite2D.new()
	var tex := load("res://res/egg/egg.png") as Texture2D
	if tex:
		egg_sprite.texture = tex
	egg_sprite.centered = true
	add_child(egg_sprite)

	# 圆形碰撞：匹配蛋宽（36px），滚动最自然
	egg_collision = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	egg_collision.shape = shape
	add_child(egg_collision)


# ============================================================
# 碰撞回调
# ============================================================
func _on_body_entered(body: Node) -> void:
	if is_broken:
		return

	# 支撑接触（用于落地激活）：World 地面/平台 + 其他蛋（蛋可垫在蛋上）
	if body is StaticBody2D or body is TileMap or body is TileMapLayer or body is EggBase:
		_ground_contact = true

	# 踩踏碎蛋（蛋端保险）：只有 STOMPING 状态的小鸡踩到蛋才碎
	if body is ChickenBase:
		var chicken := body as ChickenBase
		if chicken.current_state == ChickenBase.ChickenState.STOMPING:
			broadcast_break()
			return

	if destroy_on_impact and body is not ChickenBase:
		_trigger_effect()
		_destroy()


# ============================================================
# 效果（子类重写）
# ============================================================
func _trigger_effect() -> void:
	push_warning("EggBase._trigger_effect() 未被子类重写！")


# ============================================================
# 压碎：换 broken_egg.png 视觉 → 短暂保留 → 销毁
# 只有踩踏（stomp_break）能触发；碎蛋无碰撞体积
# 注意：本函数保持同步（无 await），销毁由 SceneTreeTimer 回调完成，
#       避免在 ChickenBase 碰撞回调里被非 await 调用导致协程挂起
# @rpc：多人下由任一玩家触发时广播到所有端（幂等：is_broken 已碎则直接返回）
# ============================================================
@rpc("any_peer", "call_local", "reliable")
func stomp_break() -> void:
	if is_broken:
		return
	is_broken = true
	if egg_collision:
		egg_collision.set_deferred("disabled", true)
	if egg_sprite:
		var broken_tex := load("res://res/egg/broken_egg.png") as Texture2D
		if broken_tex:
			egg_sprite.texture = broken_tex
			egg_sprite.scale = Vector2(0.05, 0.05)
	# 暂停物理（变碎片不滚动）
	set_deferred("freeze", true)
	EventBus.egg_destroyed.emit(self)
	# 修复堆叠蛋浮空：下方蛋碰撞禁用后，上方蛋若处于 RigidBody2D sleeping 状态不会自动唤醒
	# → 失去支撑仍浮空。延迟（等 collision disabled 生效）后统一唤醒所有蛋。
	var wake_timer := get_tree().create_timer(0.05)
	wake_timer.timeout.connect(_wake_nearby_eggs)
	var timer := get_tree().create_timer(break_show_time)
	timer.timeout.connect(_free_after_break)


# 广播碎蛋：多人下通过 RPC 同步到所有端（蛋节点名各端一致 → 路径可路由）；单机直接本地执行
# ⚠️ 联机判定必须用 MultiplayerManager.is_network_connected()：Godot 4.6 单机也有
#    OfflineMultiplayerPeer，multiplayer.has_multiplayer_peer() 恒 true（虽功能等价，但语义混乱）
func broadcast_break() -> void:
	if MultiplayerManager.is_network_connected():
		stomp_break.rpc()
	else:
		stomp_break()


func _free_after_break() -> void:
	# 仅 authority 端自行 queue_free：由 spawner 的 despawn 广播同步移除其他端副本，
	# 避免双端同时释放导致 on_despawn_receive 的 ERR_UNAUTHORIZED 竞态
	if not is_multiplayer_authority():
		return
	if is_instance_valid(self):
		queue_free()


# 碎蛋后唤醒其他蛋（修复：下方蛋碎掉后上方蛋浮空）
# 原因：堆叠静止的 RigidBody2D 会进入 sleeping；下方蛋 collision disabled 后，
#       上方蛋失去支撑但物理引擎不主动唤醒它 → 保持静止浮空。
# 方案：等碰撞禁用生效（约 3 物理帧）后，对所有蛋 wakeup()（唤醒后恢复重力下落）
func _wake_nearby_eggs() -> void:
	for egg in get_tree().get_nodes_in_group("eggs"):
		if egg == self or not is_instance_valid(egg):
			continue
		var rb := egg as RigidBody2D
		if rb != null:
			# Godot 4 无 wakeup()：手动退出 sleeping 即可恢复重力/物理
			rb.sleeping = false


# ============================================================
# 销毁（普通销毁，未碎裂）
# ============================================================
func _destroy() -> void:
	if is_broken:
		return
	_on_destroy()
	EventBus.egg_destroyed.emit(self)
	queue_free()


# ============================================================
# 公开接口
# ============================================================
func set_owner_id(id: int) -> void:
	owner_id = id


# 下蛋瞬移免碰撞：传入下蛋的鸡，蛋暂时不与其碰撞（其他碰撞全部保留），
# 固定窗口（ignore_restore_delay）到期后由 _physics_process 无条件恢复
func set_ignore_player(chicken: ChickenBase) -> void:
	_ignored_chicken = chicken
	_update_collision_mask()


# 按当前免碰撞状态设置碰撞掩码：
#   免碰撞期 → World|Egg（排除 Player，下蛋鸡不会挤到蛋/蛋不会挤到鸡）
#   正常期   → World|Player|Egg（鸡可站蛋上、踢蛋、互挤）
func _update_collision_mask() -> void:
	var mask: int = LAYER_WORLD | LAYER_EGG
	if _ignored_chicken == null:
		mask |= LAYER_PLAYER
	collision_mask = mask


# 被鸡啄击调用：施加冲量踢飞（落地后的蛋会翻滚滚动）
func kick(impulse: Vector2) -> void:
	apply_impulse(impulse)


# ============================================================
# 虚方法（子类可选重写）
# ============================================================
func _on_ready() -> void:
	pass

func _on_landed_activated() -> void:
	pass

func _on_destroy() -> void:
	pass
