extends Node
# 背景音乐（autoload 单例）：加载 default.mp3 循环播放，跨场景不中断。
# 暴露 set_enabled/set_volume 供系统面板调用，状态记到配置文件持久化。


const BGM_PATH := "res://assets/music/default.mp3"
const CONFIG_PATH := "user://settings.cfg"
const SECTION := "audio"
const KEY_ENABLED := "bgm_enabled"
const KEY_VOLUME := "bgm_volume"

var _player: AudioStreamPlayer
var _enabled: bool = true
var _volume: float = 1.0                     # 0.0 ~ 1.0，映射到 dB。

func _ready() -> void:
	_load_settings()
	var stream := load(BGM_PATH) as AudioStreamMP3
	if stream == null:
		push_error("BGM: 无法加载 %s" % BGM_PATH)
		return
	stream.loop = true
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	add_child(_player)
	_player.play()
	_apply_state()                            # 必须在 play() 之后：stream_paused 只能暂停已启动的播放。

func set_enabled(v: bool) -> void:
	_enabled = v
	_apply_state()
	_save_settings()

func set_volume(v: float) -> void:
	_volume = clamp(v, 0.0, 1.0)
	_apply_state()
	_save_settings()

func is_enabled() -> bool:
	return _enabled

func get_volume() -> float:
	return _volume

func _apply_state() -> void:
	if _player == null:
		return
	_player.volume_db = linear_to_db(_volume) if _volume > 0.0 else -80.0
	_player.stream_paused = not _enabled

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_enabled = cfg.get_value(SECTION, KEY_ENABLED, true)
	_volume = cfg.get_value(SECTION, KEY_VOLUME, 1.0)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_ENABLED, _enabled)
	cfg.set_value(SECTION, KEY_VOLUME, _volume)
	cfg.save(CONFIG_PATH)
