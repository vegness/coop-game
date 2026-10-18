# IceChicken.gd
# 冰鸡 - 下冰蛋
# 蛋效果：落地碎裂成临时冰面平台，摩擦力极低
extends ChickenBase
class_name IceChicken

func _on_ready() -> void:
	super._on_ready()
	_set_placeholder_color(Color.LIGHT_BLUE)

func _create_egg() -> Node2D:
	return preload("res://player/subclasses/ice/IceEgg.tscn").instantiate()

func _set_placeholder_color(c: Color) -> void:
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(c)
	var tex := ImageTexture.create_from_image(image)
	if sprite:
		sprite.texture = tex
		sprite.offset = Vector2(0, -16)
