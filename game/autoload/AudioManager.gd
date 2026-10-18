# AudioManager.gd
# 全局音频管理器（AutoLoad 单例）
# 管理 BGM 和 SFX 的播放、音量控制
extends Node

# ============================================================
# 音频总线
# ============================================================
var master_bus_index: int = 0
var music_bus_index: int = 1
var sfx_bus_index: int = 2

# 音量（0.0 ~ 1.0）
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(master_volume))

var music_volume: float = 0.8:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(music_bus_index, linear_to_db(music_volume))

var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(sfx_volume))


# ============================================================
# BGM 播放
# ============================================================
var current_bgm: AudioStreamPlayer


func play_bgm(stream: AudioStream) -> void:
	if current_bgm and current_bgm.stream == stream and current_bgm.playing:
		return
	if current_bgm:
		current_bgm.stop()
		current_bgm.stream = stream
	else:
		current_bgm = AudioStreamPlayer.new()
		current_bgm.bus = "Music"
		add_child(current_bgm)
	current_bgm.stream = stream
	current_bgm.play()


func stop_bgm() -> void:
	if current_bgm:
		current_bgm.stop()


# ============================================================
# SFX 播放
# ============================================================
func play_sfx(stream: AudioStream, position_2d: Vector2 = Vector2.ZERO) -> void:
	var player := AudioStreamPlayer2D.new()
	player.bus = "SFX"
	player.stream = stream
	player.global_position = position_2d
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func play_sfx_at(stream: AudioStream, node: Node2D) -> void:
	play_sfx(stream, node.global_position)
