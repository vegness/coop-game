# ChickenBase.gd
# 鸡角色抽象基类
# 包含：状态机、移动、跳跃/下蛋/滑翔、碰撞检测
# 子类必须重写 _create_egg() 返回对应蛋类型
extends CharacterBody2D
class_name ChickenBase

# ============================================================
# 状态枚举
# ============================================================
enum ChickenState {
	GROUND,    # 地面
	JUMPING,   # 上升中（一段跳）
	FALLING,   # 下落中
	EGG_LAID,  # 已下蛋（可滑翔）
	GLIDING,   # 滑翔中
	PECKING,   # 啄击中
	STOMPING,  # 踩踏中（空中按 S 俯冲，踩到蛋才碎蛋）
	DEAD       # 死亡/掉出地图
}

# ============================================================
# 移动参数
# ============================================================
@export var move_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0
@export var air_control: float = 0.6  # 空中操控系数

# 跳跃参数
@export var jump_velocity: float = -360.0  # 跳跃高度 ≈ 66px（重力 980）
@export var jump_horizontal_boost: float = 50.0  # 一段跳水平助力

# 下蛋（K 键）参数
@export var egg_recoil_force: float = -320.0       # 下蛋反冲垂直力（高度 ≈ 52px，地面/空中统一）
@export var egg_recoil_horizontal: float = 120.0    # 下蛋反冲水平力
@export var egg_lay_cooldown: float = 3.0           # 下蛋冷却（秒），防止连按刷蛋
@export var egg_ignore_duration: float = 0.3        # 下蛋后鸡与蛋免碰撞时长（秒），期间鸡 mask 排除 Egg 层

# 滑翔参数
@export var glide_gravity: float = 150.0   # 滑翔重力（远小于默认重力）
@export var glide_max_fall: float = 80.0   # 滑翔最大下落速度
@export var glide_horizontal_speed: float = 180.0

# 踩踏（空中按 S / move_down 俯冲）参数
@export var stomp_fall_speed: float = 700.0       # 踩踏俯冲速度（恒定下压）
@export var stomp_bounce_velocity: float = -220.0 # 踩碎蛋后的反弹速度

# 挤蛋参数
@export var egg_push_force: float = 900.0  # 侧向挤压蛋的力（鸡移动时把蛋挤开/推着走）

# 其他
@export var max_fall_speed: float = 500.0
@export var ground_detection_margin: float = 5.0
@export var weight: float = 1.0  # 按钮重量（鸡站上按钮 = 1.0；蛋 = 0.5）

# 起跳蓄力帧展示时长（jump_start 动画 = 1.png，仅地面起跳展示一次）
const JUMP_START_SHOW_TIME: float = 0.12

# 致死机关层（project.godot layer_4="Mechanism"=8）：刺/风扇本体等 HazardArea 挂此层，
# 用于"_is_point_in_hazard 判断安全落脚点"（复活点不能是危险区）
const HAZARD_LAYER: int = 8

# 一次腾空（离开地面 → 落地）的跳跃预算：地面起跳 1 次 + 空中 1 次
const MAX_AIR_JUMPS: int = 2

# ============================================================
# 状态管理
# ============================================================
# @export：current_state 需进入 MultiplayerSynchronizer 的复制列表，远端小鸡据此播放正确动画
@export var current_state: ChickenState = ChickenState.GROUND
var has_laid_egg_this_cycle: bool = false  # 本次腾空是否已下蛋（一次腾空只下一次蛋；落地/起跳重置）
var can_air_jump_after_stomp: bool = false # 踩踏碎蛋反弹后刷新一次空中跳跃
var jump_count_used: int = 0               # 本次腾空已用跳跃次数（上限 MAX_AIR_JUMPS；落地/起跳重置）
var egg_lay_cooldown_timer: float = 0.0    # 下蛋冷却计时
var _egg_ignore_timer: float = 0.0         # 下蛋后鸡与蛋免碰撞计时（期间 mask 排除 Egg 层）
var _base_collision_mask: int = 0          # 初始碰撞掩码（恢复用）
var _jump_start_timer: float = 0.0         # 起跳蓄力帧（1.png）展示计时
var was_on_floor: bool = false
var is_dead: bool = false
var last_landed_position: Vector2 = Vector2.ZERO  # 最后一次落地位置（掉坑后传送回这里）
var _blink_tween: Tween = null  # 复活闪烁 tween

# 输入缓冲
var jump_buffer_timer: float = 0.0
const JUMP_BUFFER_TIME: float = 0.1  # 跳跃缓冲时间

# 滑翔输入
var is_glide_pressed: bool = false

# 联机就绪标记：等待主机"关卡就绪"广播后才处理输入/物理（单机恒 true）。
# 就绪前小鸡无任何状态变化 → 同步器不发数据 → 不会污染对端同步路径缓存
var play_ready: bool = false

# 网络 ID
var player_id: int = 0
# 上一帧物理速度（move_and_slide 前的原始速度；供蛋压碎检测等读取碰撞前速度）
var prev_velocity: Vector2 = Vector2.ZERO
# 蛋生成序号（用于给蛋节点唯一命名，避免 MultiplayerSpawner 报保留名错误）
var _egg_spawn_counter: int = 0

# 引用
# 视觉节点兼容两种结构：
#   - AnimatedSprite2D（chick.tscn，jump/run/stop 序列帧动画）
#   - Sprite2D（ChickenBase.tscn，纯色占位）
@onready var sprite = get_node_or_null("AnimatedSprite2D") if has_node("AnimatedSprite2D") else get_node_or_null("Sprite2D")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = get_node_or_null("Camera2D")  # 调试用（可选）
@onready var state_label: Label = get_node_or_null("StateLabel")  # 调试用（可选）


# ============================================================
# 啄击参数
# ============================================================
const PECK_RANGE: float = 40.0       # 啄击射线长度
const PECK_KICK_FORCE: float = 180.0 # 踢蛋冲量
const PECK_DURATION: float = 0.2     # 啄击状态持续时间


# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	_setup_collision()
	_setup_camera()
	_base_collision_mask = collision_mask  # 记录初始掩码（下蛋免碰撞后恢复用）
	add_to_group("player")  # 通用组：按钮/传送带等按组检测
	_on_ready()
	# 单机直接就绪；联机由关卡就绪握手解锁（LevelBase 收到广播后调用 set_play_ready）
	# ⚠️ 不能依赖 has_multiplayer_peer()（Godot 4.6 单机也有 OfflineMultiplayerPeer，恒 true）
	if not MultiplayerManager.is_network_connected():
		play_ready = true


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 联机就绪握手：未收到主机"关卡就绪"广播前不处理输入/物理。
	# 此时无状态变化 → 同步器不发数据 → 避免同步数据早于对端节点创建到达
	if MultiplayerManager.is_network_connected() and not play_ready:
		return

	# 多人模式：非 authority（远端小鸡）只根据同步数据更新动画，
	# 位置/状态（position/velocity/current_state/朝向）由 MultiplayerSynchronizer 同步，不处理输入/物理
	if _is_network_client():
		_update_animation()
		return

	_handle_input_buffer(delta)
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump_input()
	_handle_glide_input()
	_handle_peck_input()
	_handle_stomp_input()
	_handle_egg_lay_input()
	_update_state_transitions()

	# 下蛋免碰撞计时：期间 collision_mask 排除 Egg 层（鸡不撞刚下的蛋），到期恢复
	if _egg_ignore_timer > 0.0:
		_egg_ignore_timer -= delta
		if _egg_ignore_timer <= 0.0:
			collision_mask = _base_collision_mask

	# 起跳蓄力帧计时（递减到 0 后 _update_animation 恢复空中循环）
	if _jump_start_timer > 0.0:
		_jump_start_timer -= delta
	# 下蛋冷却计时
	if egg_lay_cooldown_timer > 0.0:
		egg_lay_cooldown_timer -= delta

	var previous_velocity := velocity
	prev_velocity = velocity
	move_and_slide()

	# 踩踏检测：俯冲撞到蛋 → 碎蛋 + 反弹（只有踩踏状态能碎蛋）
	if current_state == ChickenState.STOMPING:
		_check_stomp_hit()

	# 挤蛋：侧向挤压落地蛋时推动它（跑动/走位时自然把蛋挤开）
	_push_eggs()

	# 落地检测（velocity.y >= 0 防止踩蛋反弹瞬间被 is_on_floor 误判为落地，
	# 导致 GROUND 状态覆盖 FALLING 而失去重力 → 恒定速度上升）
	var on_floor := check_on_floor()
	if on_floor and not was_on_floor and velocity.y >= 0.0:
		_on_landed()
	was_on_floor = on_floor

	# 按状态切换动画（待机/走路/跳跃）
	_update_animation()


# 多人客户端判定：已联网且本节点非 authority
func _is_network_client() -> bool:
	# 联机判定走 MultiplayerManager（后端无关）：未连接/单机时一律视为本地控制。
	# 不能直接读 multiplayer.multiplayer_peer / get_connection_status()——那属于网络
	# 实现细节（Godot 原生 API），游戏逻辑层只通过 MultiplayerManager 查询网络状态；
	# 且断开状态下调用 is_multiplayer_authority() 会报 "multiplayer instance isn't currently active"
	if not MultiplayerManager.is_network_connected():
		return false
	return not is_multiplayer_authority()


## 解锁小鸡输入/物理（关卡就绪握手用；由 LevelBase 在收到主机广播后调用）。
## 就绪时同时把 NetSync 的 authority 从占位 0 恢复为 player_id：
## 同步器 `_start()` 重新注册开始发送，此时接收端关卡节点已存在，路径缓存正常。
func set_play_ready(ready: bool) -> void:
	play_ready = ready
	if ready and MultiplayerManager.is_network_connected():
		var net_sync := get_node_or_null("NetSync") as MultiplayerSynchronizer
		if net_sync != null and net_sync.get_multiplayer_authority() != player_id:
			net_sync.set_multiplayer_authority(player_id)


# ============================================================
# 输入处理
# ============================================================
func _handle_input_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta


func _handle_movement(delta: float) -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")

	if current_state == ChickenState.GLIDING:
		# 滑翔时水平控制
		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * glide_horizontal_speed, acceleration * air_control * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * air_control * delta)
	elif current_state == ChickenState.GROUND:
		# 地面移动
		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		# 空中移动（含一段跳、下落、已下蛋状态）
		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * air_control * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * air_control * delta)

	# 翻转朝向
	if input_dir != 0.0 and current_state != ChickenState.DEAD:
		sprite.scale.x = sign(input_dir) * abs(sprite.scale.x)


func _handle_jump_input() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if not Input.is_action_just_pressed("jump"):
		# 仅即时按下触发，缓冲用于提前按
		return

	if current_state == ChickenState.GROUND:
		_perform_jump()
		jump_buffer_timer = 0.0

	elif current_state == ChickenState.JUMPING or current_state == ChickenState.FALLING \
		or current_state == ChickenState.EGG_LAID:
		# 空中按跳 = 二段跳：一次腾空总共 2 次跳跃（地面起跳 + 空中 1 次）。
		# 下蛋后（EGG_LAID）仍可跳——只要跳跃预算没用完（修复：跳→下蛋→再跳 无效的 bug）；
		# 踩踏碎蛋反弹后 can_air_jump_after_stomp 可再刷新一次
		if jump_count_used < MAX_AIR_JUMPS or can_air_jump_after_stomp:
			_perform_air_jump()
			jump_buffer_timer = 0.0


func _handle_egg_lay_input() -> void:
	if not Input.is_action_just_pressed("egg_lay"):
		return
	if egg_lay_cooldown_timer > 0.0:
		return
	if has_laid_egg_this_cycle:
		return  # 一次腾空只能下一次蛋（落地/起跳后重置）；InfiniteChicken 覆盖 _perform_egg_lay 绕过
	# 死亡/啄击/踩踏俯冲中不允许下蛋（俯冲下蛋会被自己踩碎）
	match current_state:
		ChickenState.DEAD, ChickenState.PECKING, ChickenState.STOMPING:
			return
	_perform_egg_lay()
	egg_lay_cooldown_timer = egg_lay_cooldown


func _handle_glide_input() -> void:
	is_glide_pressed = Input.is_action_pressed("jump")

	# 滑翔启动条件：已下蛋（EGG_LAID）或空中跳跃预算已用完（jump_count_used >= MAX_AIR_JUMPS），长按跳且不再上升。
	# 一段跳后仍可空中跳（预算没用完）→ 不滑翔；
	# 二段跳/踩踏刷新跳/下蛋反冲后跳跃预算用尽 → 长按跳即可滑翔。
	# 排除：地面（check_on_floor）与踩踏俯冲（STOMPING）中不滑翔。
	var can_glide: bool = current_state != ChickenState.STOMPING \
		and not check_on_floor() \
		and (current_state == ChickenState.EGG_LAID or jump_count_used >= MAX_AIR_JUMPS)
	if can_glide and is_glide_pressed and velocity.y >= 0.0:
		if current_state != ChickenState.GLIDING:
			current_state = ChickenState.GLIDING
			_on_glide_start()

	if current_state == ChickenState.GLIDING and not is_glide_pressed:
		current_state = ChickenState.FALLING
		_on_glide_end()


func _handle_peck_input() -> void:
	if Input.is_action_just_pressed("peck"):
		_perform_peck()


func _handle_stomp_input() -> void:
	if not Input.is_action_just_pressed("move_down"):
		return
	# 空中才能踩踏（一段跳/下落/已下蛋/滑翔中均可按 S 俯冲）
	match current_state:
		ChickenState.JUMPING, ChickenState.FALLING, ChickenState.EGG_LAID, ChickenState.GLIDING:
			_perform_stomp()


# ============================================================
# 动作执行
# ============================================================
func _perform_jump() -> void:
	velocity.y = jump_velocity
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x += input_dir * jump_horizontal_boost
	current_state = ChickenState.JUMPING
	has_laid_egg_this_cycle = false
	jump_count_used = 1  # 地面起跳 = 本次腾空第 1 次跳跃（还剩 1 次空中跳）
	# 地面起跳：短暂展示蓄力帧（1.png），随后切空中循环（2/3/4）
	_jump_start_timer = JUMP_START_SHOW_TIME
	_on_jump()


# 空中跳跃（纯跳跃，不产生蛋；踩踏碎蛋反弹后可刷新一次）
func _perform_air_jump() -> void:
	velocity.y = jump_velocity
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x += input_dir * jump_horizontal_boost
	current_state = ChickenState.JUMPING
	jump_count_used += 1
	can_air_jump_after_stomp = false  # 踩踏奖励的跳跃已用掉
	_on_jump()


func _perform_egg_lay() -> void:
	# 下蛋反冲（地面/空中统一）：蛋的弹力把小鸡顶起（跳跃效果），转 EGG_LAID（长按跳可滑翔）
	velocity.y = egg_recoil_force
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x += input_dir * egg_recoil_horizontal
	current_state = ChickenState.EGG_LAID
	has_laid_egg_this_cycle = true
	# 下蛋瞬移免碰撞统一放在 _spawn_egg()（所有子类包括 InfiniteChicken 直接调 _spawn_egg 也生效）
	_spawn_egg()
	_on_egg_laid()


func _perform_peck() -> void:
	current_state = ChickenState.PECKING
	_on_peck()

	# 啄击射线检测：激活前方机关 / 踢飞蛋
	var hit := _peck_raycast()
	if hit != null:
		if hit is MechanismBase:
			(hit as MechanismBase).activate()
		elif hit is EggBase:
			var dir := Vector2(1.0, 0.0) if sprite.scale.x >= 0.0 else Vector2(-1.0, 0.0)
			(hit as EggBase).kick(dir * PECK_KICK_FORCE)

	await get_tree().create_timer(PECK_DURATION).timeout
	if current_state == ChickenState.PECKING:
		current_state = ChickenState.GROUND if check_on_floor() else ChickenState.FALLING


# 踩踏：空中俯冲（只有踩踏状态碰到蛋才会碎蛋）
func _perform_stomp() -> void:
	current_state = ChickenState.STOMPING
	velocity.y = stomp_fall_speed
	_on_stomp_start()


# 踩踏碰撞检测：move_and_slide 后检查滑行碰撞，撞到蛋 → 碎蛋 + 反弹
func _check_stomp_hit() -> void:
	for i in range(get_slide_collision_count()):
		var body: Node = get_slide_collision(i).get_collider()
		if body is EggBase:
			var egg := body as EggBase
			if not egg.is_broken:
				egg.broadcast_break()
				velocity.y = stomp_bounce_velocity
				current_state = ChickenState.FALLING
				# 踩碎蛋后刷新一次跳跃：反弹到空中可再跳一次（不能下蛋）
				can_air_jump_after_stomp = true
				_on_stomp_hit_egg()
			return


# 挤蛋：鸡侧向挤压落地蛋时施加水平力推动（法线水平才算挤，站蛋上/踩蛋不推）
func _push_eggs() -> void:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var body: Node = col.get_collider()
		if body is EggBase:
			var egg := body as EggBase
			if egg.is_broken:
				continue
			var normal: Vector2 = col.get_normal()
			# 水平侧向挤压才推动（abs(normal.x) > 0.5），垂直接触（站/踩）不推
			if absf(normal.x) > 0.5:
				egg.apply_force(-normal * egg_push_force)


# 啄击射线：从前方向前方发射，检测 Egg(4) 和 Mechanism(16) 层
func _peck_raycast() -> Node:
	var dir_x: float = sprite.scale.x
	var dir := Vector2(1.0, 0.0) if dir_x >= 0.0 else Vector2(-1.0, 0.0)
	var origin := global_position + Vector2(0.0, -8.0)  # 鸡身体中心高度
	var target := origin + dir * PECK_RANGE
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, target)
	query.exclude = [self]
	query.collision_mask = 4 | 16  # Egg layer + Mechanism layer
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	return result.collider as Node


# ============================================================
# 重力 & 物理
# ============================================================
func _apply_gravity(delta: float) -> void:
	if current_state == ChickenState.GROUND or current_state == ChickenState.PECKING:
		return

	# 踩踏：恒定俯冲速度（忽略普通重力与最大下落速度限制）
	if current_state == ChickenState.STOMPING:
		velocity.y = stomp_fall_speed
		return

	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

	if current_state == ChickenState.GLIDING:
		velocity.y += glide_gravity * delta
		velocity.y = min(velocity.y, glide_max_fall)
	else:
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)


# ============================================================
# 动画切换
# 仅当视觉节点是 AnimatedSprite2D 时生效（chick.tscn）
# 约定动画名：stop=待机, run=走路, jump=跳跃（含下落/滑翔）
# ============================================================
func _update_animation() -> void:
	if sprite == null or not (sprite is AnimatedSprite2D):
		return

	var animated_sprite := sprite as AnimatedSprite2D

	# 起跳蓄力帧：仅地面起跳展示一次（1.png），期间不切换其他动画
	if _jump_start_timer > 0.0:
		if animated_sprite.animation != "jump_start":
			animated_sprite.play("jump_start")
		return

	var target_animation: String = ""
	match current_state:
		ChickenState.GROUND:
			target_animation = "run" if abs(velocity.x) > 10.0 else "stop"
		ChickenState.JUMPING, ChickenState.FALLING, ChickenState.EGG_LAID, ChickenState.GLIDING:
			target_animation = "jump"
		ChickenState.STOMPING:
			target_animation = "down"
		ChickenState.PECKING:
			target_animation = "stop"
		_:
			return

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)


# ============================================================
# 状态转换
# ============================================================
func _update_state_transitions() -> void:
	match current_state:
		ChickenState.GROUND:
			# 走出平台边缘 → 转下落（否则 GROUND 无重力会浮空）
			if not is_on_floor():
				current_state = ChickenState.FALLING
				_on_fall_start()
		ChickenState.JUMPING:
			if velocity.y >= 0.0:
				current_state = ChickenState.FALLING
				_on_fall_start()
		ChickenState.FALLING:
			pass  # 下落中只能通过落地或下蛋转换
		ChickenState.EGG_LAID:
			pass  # 等滑翔或落地
		ChickenState.GLIDING:
			pass  # 松开 Space 时已在 _handle_glide_input 处理


func _on_landed() -> void:
	has_laid_egg_this_cycle = false
	can_air_jump_after_stomp = false  # 落地重置踩踏刷新跳
	jump_count_used = 0               # 落地重置腾空跳跃预算
	current_state = ChickenState.GROUND
	# 记录最后一次落脚点（掉坑传送用）——但只记录"安全的普通地面"：
	#   · 站在蛋上（蛋梯/踩蛋过河）不算：蛋可能滚走/碎掉，且蛋常位于危险区（如刺上方）
	#   · 脚底在致死 Hazard 内（刺/风扇本体等）不算：复活到那里会立刻再死
	if _is_standing_on_world() and not _is_point_in_hazard():
		last_landed_position = global_position


# 脚下 40px 内是否有 World(1) 实体地面（普通地面/平台）。蛋(4)不满足 → 站蛋不算落脚点
func _is_standing_on_world() -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 40.0)
	)
	query.collision_mask = 1  # World layer
	query.exclude = [self]
	return not space_state.intersect_ray(query).is_empty()


# 脚底是否位于致死 Hazard（刺/风扇本体等的 HazardArea，挂 Mechanism=8 层）内
func _is_point_in_hazard() -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(0, 24.0)  # 脚底（碰撞体底缘）
	query.collision_mask = HAZARD_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not space_state.intersect_point(query).is_empty()


func check_on_floor() -> bool:
	# 使用 move_and_slide 内置检测 + 射线检测
	if is_on_floor():
		return true

	# 额外射线检测（防止边缘漏检）
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, ground_detection_margin + 10)
	)
	query.collision_mask = 1  # World layer
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	return not result.is_empty()


# ============================================================
# 蛋生成（子类重写）
# ============================================================
func _spawn_egg() -> void:
	# 下蛋瞬移免碰撞：短时间排除 Egg 层（鸡不撞刚下的蛋），避免蛋生成瞬间把鸡挤开。
	# 放在下蛋公共入口（InfiniteChicken 等子类直接调 _spawn_egg 也会经过这里，行为与基类一致）。
	_egg_ignore_timer = egg_ignore_duration
	collision_mask = _base_collision_mask & ~4  # 4 = Egg 层
	var egg: Node2D = _create_egg()
	if egg == null:
		return

	# 蛋生成位置：鸡身正下方偏后（配合 set_ignore_player 免碰撞，蛋不会卡鸡体/被挤开）
	var spawn_offset := Vector2(0, 16)
	if sprite.scale.x < 0:
		spawn_offset.x -= 8  # 面向左时偏后
	else:
		spawn_offset.x += 8  # 面向右时偏后
	var egg_pos: Vector2 = global_position + spawn_offset

	# 设置蛋的所有者
	if egg.has_method("set_owner_id"):
		egg.set_owner_id(player_id)

	# 优先通过关卡的 EggSpawner 生成（MultiplayerSpawner 自动广播到所有端 + 合法节点名）
	var eggs_container: Node = _get_eggs_container()
	if eggs_container != null:
		var spawner: MultiplayerSpawner = eggs_container.get_node_or_null("EggSpawner")
		# 多人模式：蛋必须由 EggSpawner 的 authority（主机）通过 spawner.spawn() 生成才会同步到所有端。
		# 客机直接调 spawn() 会因非 authority 返回 null（引擎 ERR_FAIL_COND_V 静默返回），
		# 且客机在 spawn_path 下 add_child 也不会被非 authority 的 spawner 广播 → 蛋只存在于客机本机。
		if spawner != null and spawner.spawn_function.is_valid():
			# 单机（无后端/未连接，Godot 4.6 的 OfflineMultiplayerPeer）或联机主机：本地经 spawner 生成
			if not MultiplayerManager.is_network_connected() or MultiplayerManager.is_server():
				_spawn_egg_via_spawner(spawner, egg_pos)
			else:
				# 客机：RPC 广播请求主机代为生成（走 MultiplayerManager autoload，目标恒存在；
				# 主机 guard 在 request_egg_spawn 内 → 广播而非 rpc_id(1)——Steam 下主机 id 非 1，
				# 硬编码 rpc_id(1) 会失效，广播 + 主机 guard 才是后端无关的写法）
				MultiplayerManager.request_egg_spawn.rpc(egg_pos, player_id, get_path())
			return

		# 单机 / fallback：直接添加（给蛋唯一命名避免保留名报错）
		egg.name = "Egg_%d" % _egg_spawn_counter
		_egg_spawn_counter += 1
		egg.global_position = egg_pos
		# 下蛋瞬移免碰撞：蛋与下蛋鸡暂时互不碰撞（蛋蛋/蛋世界碰撞保留），分离后自动恢复
		if egg.has_method("set_ignore_player"):
			egg.set_ignore_player(self)
		eggs_container.add_child(egg)
	else:
		egg.global_position = egg_pos
		get_parent().add_child(egg)

	EventBus.egg_laid.emit(egg, player_id)


# 查找关卡中的 Eggs 容器：优先 current_scene，兜底从自身向上找父链
# （避免关卡切换瞬间 current_scene 尚未更新时找不到容器）
func _get_eggs_container() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		var eggs := scene.get_node_or_null("Eggs")
		if eggs != null:
			return eggs
	var node: Node = self
	while node != null:
		if node.has_node("Eggs"):
			return node.get_node("Eggs")
		node = node.get_parent()
	return null


# 通过 EggSpawner 生成蛋（仅主机/spawner authority 调用；spawner.spawn 会把蛋广播到所有端）
func _spawn_egg_via_spawner(spawner: MultiplayerSpawner, egg_pos: Vector2) -> void:
	var spawned: Node = spawner.spawn({
		"pos": egg_pos,
		"owner": player_id,
		"ignore_chicken": str(get_path()),
	})
	if spawned != null:
		# 主机本地的蛋直接免碰撞；其他端的蛋由 _spawn_egg_net 按 ignore_chicken 节点路径解析处理
		if spawned.has_method("set_ignore_player"):
			spawned.set_ignore_player(self)
		EventBus.egg_laid.emit(spawned, player_id)


# 抽象方法：子类必须重写，返回对应蛋实例
func _create_egg() -> Node2D:
	push_warning("ChickenBase._create_egg() 未被子类重写！")
	return null


# ============================================================
# 碰撞设置
# ============================================================
func _setup_collision() -> void:
	collision_layer = 2  # Player layer
	collision_mask = 1 | 4 | 16  # World + Mechanism + OneWayPlatform


# ============================================================
# 摄像机设置
# ============================================================
func _setup_camera() -> void:
	if camera == null:
		return
	# 多人模式只让本地 authority 控制本机摄像机（其他玩家客户端 disable 自己摄像机看自己的）
	# ⚠️ 联机判定用 MultiplayerManager.is_network_connected()：单机 OfflineMultiplayerPeer 下
	#    has_multiplayer_peer() 恒 true，虽功能等价但语义混乱且违背"游戏逻辑层不碰 multiplayer 原生"
	if MultiplayerManager.is_network_connected():
		camera.enabled = is_multiplayer_authority()
	else:
		camera.enabled = true

	# 从关卡读取相机边界
	var bounds: Rect2 = _get_camera_bounds()
	if bounds != Rect2(0, 0, 0, 0):
		camera.limit_left = int(bounds.position.x)
		camera.limit_right = int(bounds.end.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_bottom = int(bounds.end.y)


func _get_camera_bounds() -> Rect2:
	var scene: Node = get_tree().current_scene
	if scene != null and "camera_bounds" in scene:
		return scene.camera_bounds
	return Rect2(0, 0, 0, 0)


# ============================================================
# 死亡/复活
# ============================================================
func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = ChickenState.DEAD
	collision_shape.disabled = true
	velocity = Vector2.ZERO
	_kill_blink()
	EventBus.player_died.emit(player_id)
	_on_die()


func revive(spawn_position: Vector2) -> void:
	is_dead = false
	current_state = ChickenState.GROUND
	# ⚠️ 不能在 body_entered 等物理回调（flushing queries）期间直接改碰撞形状状态，
	#    否则报 "Can't change this state while flushing queries"。仅当确实被禁用时才用
	#    set_deferred 延迟到安全时机恢复（本游戏流程中 die() 很少被调用，通常跳过）。
	if collision_shape.disabled:
		collision_shape.set_deferred("disabled", false)
	global_position = spawn_position
	velocity = Vector2.ZERO
	has_laid_egg_this_cycle = false
	jump_count_used = 0
	can_air_jump_after_stomp = false
	_start_respawn_blink()
	EventBus.player_revived.emit(player_id)
	_on_revive()


# ============================================================
# 复活闪烁：复活后短暂无敌，透明度 1.0 ↔ 0.4 循环（3 秒）
# 所有死亡复活（掉坑/尖刺/门压）统一走 revive() → 都会触发闪烁
# ============================================================
const RESPAWN_BLINK_DURATION: float = 3.0   # 闪烁总时长（秒）
const RESPAWN_BLINK_MIN_ALPHA: float = 0.4  # 闪烁最低透明度（40%）
const RESPAWN_BLINK_PERIOD: float = 0.2     # 单个周期（秒）→ 每秒 5 次


func _start_respawn_blink() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	_kill_blink()
	var cycles := int(RESPAWN_BLINK_DURATION / RESPAWN_BLINK_PERIOD)
	if cycles <= 0:
		return
	var tween := create_tween()
	for _i in range(cycles):
		tween.tween_property(sprite, "modulate:a", RESPAWN_BLINK_MIN_ALPHA, RESPAWN_BLINK_PERIOD * 0.5)
		tween.tween_property(sprite, "modulate:a", 1.0, RESPAWN_BLINK_PERIOD * 0.5)
	tween.tween_callback(_on_blink_finished)
	_blink_tween = tween


func _on_blink_finished() -> void:
	_blink_tween = null
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate.a = 1.0


func _kill_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate.a = 1.0


# ============================================================
# 虚方法（子类可选重写）
# ============================================================
func _on_ready() -> void:
	pass

func _on_jump() -> void:
	pass

func _on_egg_laid() -> void:
	pass

func _on_glide_start() -> void:
	pass

func _on_glide_end() -> void:
	pass

func _on_peck() -> void:
	pass

func _on_stomp_start() -> void:
	pass

func _on_stomp_hit_egg() -> void:
	pass

func _on_landed_extended() -> void:
	pass

func _on_fall_start() -> void:
	pass

func _on_die() -> void:
	pass

func _on_revive() -> void:
	pass
