# Feather.gd
# 羽毛收集物 - 奖励/隐藏物品
extends CollectibleBase
class_name Feather

func _on_ready() -> void:
	super._on_ready()
	collectible_name = "羽毛"
	collectible_value = 5
	collect_color = Color.WHITE_SMOKE


func _on_collected(chicken: ChickenBase) -> void:
	EventBus.feather_collected.emit(chicken.player_id)
