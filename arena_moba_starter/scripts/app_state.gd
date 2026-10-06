extends Node

const SAVE_PATH := "user://arena_nexus_profile.cfg"

var terms_accepted := false
var logged_in := false
var username := ""
var language := "Indonesia"
var country := "Indonesia"
var tutorial_complete := false
var preferred_hero := 0
var match_history: Array[String] = []
var coins := 1280
var diamonds := 120
var level := 1

func _ready() -> void:
    load_profile()

func load_profile() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    terms_accepted = bool(cfg.get_value("account", "terms_accepted", false))
    logged_in = bool(cfg.get_value("account", "logged_in", false))
    username = str(cfg.get_value("account", "username", ""))
    language = str(cfg.get_value("account", "language", "Indonesia"))
    country = str(cfg.get_value("account", "country", "Indonesia"))
    tutorial_complete = bool(cfg.get_value("account", "tutorial_complete", false))
    preferred_hero = int(cfg.get_value("account", "preferred_hero", 0))
    coins = int(cfg.get_value("wallet", "coins", 1280))
    diamonds = int(cfg.get_value("wallet", "diamonds", 120))
    level = int(cfg.get_value("wallet", "level", 1))
    var packed := cfg.get_value("history", "matches", PackedStringArray())
    match_history.clear()
    if packed is PackedStringArray:
        for item in packed:
            match_history.append(str(item))

func save_profile() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("account", "terms_accepted", terms_accepted)
    cfg.set_value("account", "logged_in", logged_in)
    cfg.set_value("account", "username", username)
    cfg.set_value("account", "language", language)
    cfg.set_value("account", "country", country)
    cfg.set_value("account", "tutorial_complete", tutorial_complete)
    cfg.set_value("account", "preferred_hero", preferred_hero)
    cfg.set_value("wallet", "coins", coins)
    cfg.set_value("wallet", "diamonds", diamonds)
    cfg.set_value("wallet", "level", level)
    cfg.set_value("history", "matches", PackedStringArray(match_history))
    cfg.save(SAVE_PATH)

func add_match_result(result_text: String) -> void:
    match_history.push_front(result_text)
    if match_history.size() > 20:
        match_history.resize(20)
    save_profile()

func reset_local_profile() -> void:
    terms_accepted = false
    logged_in = false
    username = ""
    language = "Indonesia"
    country = "Indonesia"
    tutorial_complete = false
    preferred_hero = 0
    match_history.clear()
    coins = 1280
    diamonds = 120
    level = 1
    save_profile()
