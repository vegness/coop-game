# HeavyChicken.gd
# 重鸡 - 移动慢、跳跃低，下重蛋
# 蛋效果：重量极大，可压住压力板，落地砸碎可破坏物
extends ChickenBase
class_name HeavyChicken

func _on_ready() -> void:
	super._on_ready()
	# 重鸡属性调整
	move_speed = 120.0
	jump_velocity = -320.0
	egg_recoil_force = -280.0
	max_fall_speed = 600.0
	_set_placeholder_color(Color.DIM_GRAY)

func _create_egg() -> Node2D:
	return preload("res://player/subclasses/heavy/HeavyEgg.tscn").instantiate()

func _set_placeholder_color(c: Color) -> void:
	var image := Image.create(28, 36, false, Image.FORMAT_RGBA8)
	image.fill(c)
	var tex := ImageTexture.create_from_image(image)
	if sprite:
		sprite.texture = tex
		sprite.offset = Vector2(0, -18)
