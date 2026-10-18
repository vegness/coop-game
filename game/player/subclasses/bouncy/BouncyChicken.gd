# BouncyChicken.gd
# 弹弹鸡 - 高弹跳，下弹弹蛋
# 蛋效果：高弹性，踩上去弹飞，蛋之间可连锁反弹
extends ChickenBase
class_name BouncyChicken

func _on_ready() -> void:
	super._on_ready()
	jump_velocity = -480.0
	egg_recoil_force = -420.0
	_set_placeholder_color(Color.HOT_PINK)

func _create_egg() -> Node2D:
	return preload("res://player/subclasses/bouncy/BouncyEgg.tscn").instantiate()

func _set_placeholder_color(c: Color) -> void:
	var image := Image.create(22, 30, false, Image.FORMAT_RGBA8)
	image.fill(c)
	var tex := ImageTexture.create_from_image(image)
	if sprite:
		sprite.texture = tex
		sprite.offset = Vector2(0, -15)
