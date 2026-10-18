# wall.gd
# 立墙/垂墙（视线遮挡 + 物理阻挡，通用机制）
# 用途：真假小鸡/通用关卡视线遮挡。同一 wall.png 既可作立墙也可作垂墙：
#       垂墙用 tscn 上的 Sprite2D scale = Vector2(1, -1) 或旋转 90° 实现
class_name Wall
extends StaticBody2D
