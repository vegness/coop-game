# haystack.gd
# 草垛掩体（啄米地鼠模式 + 真假小鸡视线遮挡）
# 布局：根 StaticBody2D 含 Sprite2D 视觉 + 整矩形碰撞体（鸡可站上草垛顶部）
#       + 子 Area2D "PeekArea" 对应顶部开洞（探头点）
# 接入：关卡在 _ready() 把 PeekArea.body_entered 连到关卡的 spawn_mole(...)
class_name Haystack
extends StaticBody2D

## 顶部探头区 Area2D 路径
@export var peek_path: NodePath = ^"PeekArea"
## 是否允许鸡站上草垛顶部（true=整矩形碰撞顶面可站；false=仅当视觉装饰）
@export var is_climbable: bool = true

signal body_peeked(body: Node)

var _peek: Area2D = null


func _ready() -> void:
	_peek = get_node_or_null(peek_path) as Area2D
	if _peek == null:
		push_warning("Haystack: 缺少 PeekArea 节点：" + str(peek_path))
		return
	_peek.body_entered.connect(_on_peeked)


func _on_peeked(body: Node) -> void:
	body_peeked.emit(body)
