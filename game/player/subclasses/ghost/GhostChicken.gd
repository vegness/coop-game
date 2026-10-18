# GhostChicken.gd
# 幽灵鸡 - 下幽灵蛋
# 蛋效果：蛋可穿透墙体，鸡触碰蛋后获得短暂穿墙能力
extends ChickenBase
class_name GhostChicken

func _on_ready() -> void:
	super._on_ready()
	_set_placeholder_color(Color.MEDIUM_PURPLE)

func _create_egg() -> Node2D:
	return preload("res://player/subclasses/ghost/GhostEgg.tscn").instantiate()

func _set_placeholder_color(c: Color) -> void:
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(c)
	var tex := ImageTexture.create_from_image(image)
	if sprite:
		sprite.texture = tex
		sprite.offset = Vector2(0, -16)
