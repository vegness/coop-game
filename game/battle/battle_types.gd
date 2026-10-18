# battle/battle_types.gd
# 对战玩法类型定义（框架层，与关卡内容解耦）
# 场景路径约定：battle/<type_name>/<type_name>.tscn
# 玩法场景（关卡）由关卡作者自行创建，本文件只做枚举/名称/路径映射
class_name BattleTypes
extends RefCounted

enum Type {
	EGG_BALL,     # 蛋球赛：下蛋踢进对方球门
	KNOCK_OUT,    # 挤出局：把对手挤下屏幕视野
	RACE,         # 竞速赛：先到终点
	HATCH_RACE,   # 孵化赛：比谁孵化的蛋多
	PECK_MOLE,    # 啄米地鼠：啄人 vs 探头吃米
	IMPOSTER,     # 真假小鸡：捉捕者 vs 模仿者
	MIXED,        # 混合模式：多玩法轮换（BattleDirector 编排）
}

const TYPE_NAMES: Dictionary = {
	Type.EGG_BALL: "蛋球赛",
	Type.KNOCK_OUT: "挤出局",
	Type.RACE: "竞速赛",
	Type.HATCH_RACE: "孵化赛",
	Type.PECK_MOLE: "啄米地鼠",
	Type.IMPOSTER: "真假小鸡",
	Type.MIXED: "混合模式",
}

## 一句话规则（预览图占位 / 提示用）
const TYPE_DESCS: Dictionary = {
	Type.EGG_BALL: "下蛋踢进对方球门",
	Type.KNOCK_OUT: "把对手挤下屏幕",
	Type.RACE: "先到终点者胜",
	Type.HATCH_RACE: "比谁孵化的蛋多",
	Type.PECK_MOLE: "啄人 vs 探头吃米",
	Type.IMPOSTER: "捉捕者 vs 模仿者",
	Type.MIXED: "多玩法轮换，积分累加",
}

## 玩法主题色（糖果色板，预览图占位底色）
const TYPE_COLORS: Dictionary = {
	Type.EGG_BALL: Color8(255, 140, 66),    # 亮橙
	Type.KNOCK_OUT: Color8(91, 192, 235),   # 天蓝
	Type.RACE: Color8(122, 229, 130),       # 薄荷绿
	Type.HATCH_RACE: Color8(244, 211, 94),  # 柠檬黄
	Type.PECK_MOLE: Color8(247, 174, 248),  # 泡泡糖粉
	Type.IMPOSTER: Color8(180, 142, 173),   # 紫
	Type.MIXED: Color8(255, 184, 140),      # 桃色
}

## 玩法场景路径约定（关卡作者按此放置 tscn 即可被加载）
const TYPE_SCENES: Dictionary = {
	Type.EGG_BALL: "res://battle/egg_ball/egg_ball.tscn",
	Type.KNOCK_OUT: "res://battle/knock_out/knock_out.tscn",
	Type.RACE: "res://battle/race/race.tscn",
	Type.HATCH_RACE: "res://battle/hatch_race/hatch_race.tscn",
	Type.PECK_MOLE: "res://battle/peck_mole/peck_mole.tscn",
	Type.IMPOSTER: "res://battle/imposter/imposter.tscn",
	Type.MIXED: "res://battle/mixed/mixed.tscn",
}


## 玩法中文名
static func get_type_name(t: int) -> String:
	return TYPE_NAMES.get(t, "未知玩法")


## 玩法一句话规则
static func get_type_desc(t: int) -> String:
	return TYPE_DESCS.get(t, "")


## 玩法主题色（占位图底色）
static func get_type_color(t: int) -> Color:
	return TYPE_COLORS.get(t, Color8(255, 184, 140))


## 玩法场景路径（未知玩法返回空串）
static func get_scene_path(t: int) -> String:
	return TYPE_SCENES.get(t, "")


## 玩法预览图路径约定：battle/<type>/preview.png（关卡作者放置；缺失时 UI 用程序占位）
static func get_preview_path(t: int) -> String:
	var p: String = get_scene_path(t)
	if p.is_empty():
		return ""
	var scene_name: String = p.get_file().trim_suffix(".tscn")
	return "res://battle/%s/preview.png" % scene_name


## 玩法预览图是否已提供
static func has_preview(t: int) -> bool:
	var p: String = get_preview_path(t)
	return not p.is_empty() and ResourceLoader.exists(p)


## 所有可单选玩法（不含混合模式）
static func get_single_types() -> Array[int]:
	return [Type.EGG_BALL, Type.KNOCK_OUT, Type.RACE, Type.HATCH_RACE, Type.PECK_MOLE, Type.IMPOSTER]


## 玩法场景是否已由关卡作者创建
static func has_scene(t: int) -> bool:
	var p: String = get_scene_path(t)
	return not p.is_empty() and ResourceLoader.exists(p)
