# BombChicken.gd
# 炸弹鸡 - 下蛋反冲 + 爆炸破坏
# 蛋效果：落地/被啄后爆炸，破坏可破坏墙体，击退玩家（无伤害）
extends ChickenBase
class_name BombChicken

func _create_egg() -> Node2D:
	return preload("res://player/subclasses/bomb/BombEgg.tscn").instantiate()

func _on_ready() -> void:
	super._on_ready()
	# 炸弹鸡标识色：红色
	_set_placeholder_color(Color.RED)

func _setup_visual() -> void:
	_ensure_sprite_with_color(Color.RED)

func _set_placeholder_color(c: Color) -> void:
	_ensure_sprite_with_color(c)

func _ensure_sprite_with_color(c: Color) -> void:
	# 查找或创建纯色占位 Sprite2D
	if not sprite:
		return
	# 生成纯色占位图
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(c)
	var tex := ImageTexture.create_from_image(image)
	sprite.texture = tex
	sprite.offset = Vector2(0, -16)

func _on_egg_laid() -> void:
	super._on_egg_laid()
	# 炸弹鸡下蛋时有小抖动效果
