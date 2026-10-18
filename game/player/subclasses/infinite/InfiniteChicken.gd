# InfiniteChicken.gd
# 无限鸡 - 无冷却无限下蛋，蛋为普通蛋
# 特点：每轮跳跃周期内可多次下蛋（覆盖 has_laid_egg_this_cycle 限制）
# 外观：与 ChickPlayer 一致 —— AnimatedSprite2D 播放 6 色小鸡序列帧动画（stop/run/jump/down）
extends ChickenBase
class_name InfiniteChicken

# 可用颜色列表（与 res/chick/ 目录一致）
const COLORS: Array[String] = ["blue", "green", "pink", "red", "white", "yellow"]
const CHICK_DIR := "res://res/chick/"

# 当前颜色（关卡生成时通过 set_chicken_color 设置，默认 yellow）
var chicken_color: String = "yellow"


func _on_ready() -> void:
	super._on_ready()
	_load_color_animation()


# 设置小鸡颜色（关卡生成时调用；可在进树前或进树后调用）——与 ChickPlayer 一致
func set_chicken_color(color: String) -> void:
	if color in COLORS:
		chicken_color = color
		if is_inside_tree():
			_load_color_animation()


# 根据当前颜色重建 SpriteFrames（stop/run/jump/down 四状态，与 ChickPlayer 一致）
func _load_color_animation() -> void:
	var anim := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null:
		return
	var frames := SpriteFrames.new()
	_add_anim_frames(frames, "stop", [1, 1, 2, 3, 3], true, 5.0)
	_add_anim_frames(frames, "run", [1, 2, 3, 2], true, 6.0)
	_add_anim_frames(frames, "jump_start", [1], false, 12.0, "jump")
	_add_anim_frames(frames, "jump", [2, 3, 4], true, 6.0)
	_add_anim_frames(frames, "down", [1], false, 8.0)
	anim.sprite_frames = frames
	anim.play("stop")


func _add_anim_frames(frames: SpriteFrames, anim_name: String, indices: Array, loop: bool, speed: float, dir_name: String = "") -> void:
	var dir := dir_name if dir_name != "" else anim_name
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, speed)
	for idx in indices:
		var tex := load("%s%s/%s/%d.png" % [CHICK_DIR, chicken_color, dir, idx]) as Texture2D
		if tex:
			frames.add_frame(anim_name, tex)


func _perform_egg_lay() -> void:
	# 无限鸡不消耗 has_laid_egg_this_cycle；免碰撞逻辑统一在 _spawn_egg()（与基类一致）
	velocity.y = egg_recoil_force
	var input_dir: float = Input.get_axis("move_left", "move_right")
	velocity.x += input_dir * egg_recoil_horizontal
	# 不设置 has_laid_egg_this_cycle = true，允许再次下蛋
	current_state = ChickenState.EGG_LAID
	_spawn_egg()
	_on_egg_laid()


func _on_landed() -> void:
	# 复用基类完整落地逻辑：重置跳跃预算 + 记录最后一次落脚点（死亡复活/掉坑传送用）。
	# ⚠️ 之前覆盖时丢了 last_landed_position，导致死亡恒回起点（last_landed_position 恒为 ZERO）
	super._on_landed()


func _create_egg() -> Node2D:
	# 无限鸡使用基础蛋
	var egg := EggBase.new()
	egg._setup_visual()
	return egg
