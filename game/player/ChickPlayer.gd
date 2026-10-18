# ChickPlayer.gd
# 基础玩家鸡（scenes/chick.tscn 使用）
# 使用 AnimatedSprite2D 播放序列帧动画：stop=待机, run=走路, jump=跳跃, down=踩踏
# 继承 ChickenBase 完整状态机（移动/跳跃/二段跳/滑翔/踩踏/下蛋）
# 下蛋：按 K 键（egg_lay）生成 EggBase 实体（可被站立/踢走/踩碎，10s 后自动裂开）
#
# 颜色系统：支持 6 种颜色小鸡（blue/green/pink/red/white/yellow），
# 动画帧动态从 res://res/chick/{color}/{stop,run,jump,down}/ 加载
extends ChickenBase
class_name ChickPlayer

const EGG_SCENE: PackedScene = preload("res://player/EggBase.tscn")

# 可用颜色列表（与 res/chick/ 目录一致）
const COLORS: Array[String] = ["blue", "green", "pink", "red", "white", "yellow"]
const CHICK_DIR := "res://res/chick/"

# 当前颜色（关卡生成时通过 set_chicken_color 设置，默认 yellow）
var chicken_color: String = "yellow"


func _create_egg() -> Node2D:
	return EGG_SCENE.instantiate()


func _on_ready() -> void:
	# 加载对应颜色的动画帧（替换场景默认 SpriteFrames）
	_load_color_animation()


# 设置小鸡颜色（关卡生成时调用；可在进树前或进树后调用）
func set_chicken_color(color: String) -> void:
	if color in COLORS:
		chicken_color = color
		if is_inside_tree():
			_load_color_animation()


# 根据当前颜色重建 SpriteFrames（stop/run/jump/down 四状态）
func _load_color_animation() -> void:
	var anim := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim == null:
		return
	var frames := SpriteFrames.new()
	# stop: [1,1,2,3,3] 待机（呼吸感）
	_add_anim_frames(frames, "stop", [1, 1, 2, 3, 3], true, 5.0)
	# run: [1,2,3,2] 走路
	_add_anim_frames(frames, "run", [1, 2, 3, 2], true, 6.0)
	# jump_start: [1] 地面起跳蓄力帧（帧取自 jump/1.png，仅展示一次不参与空中循环）
	_add_anim_frames(frames, "jump_start", [1], false, 12.0, "jump")
	# jump: [2,3,4] 空中跳跃循环
	_add_anim_frames(frames, "jump", [2, 3, 4], true, 6.0)
	# down: [1] 踩踏（单帧）
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
