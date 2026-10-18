# GoldenEgg.gd
# 金蛋收集物 - 关卡目标收集品
extends CollectibleBase
class_name GoldenEgg

func _on_ready() -> void:
	super._on_ready()
	collectible_name = "金蛋"
	collectible_value = 1
	collect_color = Color.GOLD


func _on_collected(chicken: ChickenBase) -> void:
	EventBus.golden_egg_collected.emit(chicken.player_id)

	# 通知关卡目标进度
	var level := _find_level()
	if level and level.has_method("add_goal_progress"):
		level.add_goal_progress(1)


func _find_level() -> Node:
	var node := get_parent()
	while node:
		if node is LevelBase:
			return node
		node = node.get_parent()
	return null
