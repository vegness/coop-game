# StickyChicken.gd
# 粘鸡 - 下粘蛋
# 蛋效果：蛋粘在墙面/天花板上作为攀爬固定点
extends ChickenBase
class_name StickyChicken

func _on_ready() -> void:
	super._on_ready()
	_set_placeholder_color(Color.GREEN_YELLOW)

func _create_egg() -> Node2D:
	return preload("res://player/subclasses/sticky/StickyEgg.tscn").instantiate()

func _set_placeholder_color(c: Color) -> void:
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(c)
	var tex := ImageTexture.create_from_image(image)
	if sprite:
		sprite.texture = tex
		sprite.offset = Vector2(0, -16)
