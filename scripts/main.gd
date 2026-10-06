extends Node2D

const HeroScene = preload("res://scripts/hero.gd")
const MinionScene = preload("res://scripts/minion.gd")
const StructureScene = preload("res://scripts/structure.gd")
const TouchControlsScene = preload("res://scripts/touch_controls.gd")

var player: ArenaHero
var spawn_timer := 0.0
var hud_label: Label
var result_label: Label
var camera: Camera2D
var lanes := [-240.0, 0.0, 240.0]

func _ready() -> void:
    randomize()
    build_arena()
    spawn_match()
    build_hud()

func build_arena() -> void:
    queue_redraw()

func spawn_match() -> void:
    # Bases
    create_structure(Vector2(-1120, 0), 0, true)
    create_structure(Vector2(1120, 0), 1, true)
    # Turrets: 2 per lane per team
    for y in lanes:
        create_structure(Vector2(-780, y), 0, false)
        create_structure(Vector2(-470, y), 0, false)
        create_structure(Vector2(780, y), 1, false)
        create_structure(Vector2(470, y), 1, false)
    # Player hero and allied bots
    player = create_hero(Vector2(-350, 0), 0, true, false, 0)
    camera = Camera2D.new()
    player.add_child(camera)
    camera.enabled = true
    for i in range(4):
        var lane := lanes[i % lanes.size()]
        create_hero(Vector2(-260 - i * 30, lane), 0, false, true, lane)
    # Enemy team bots
    for i in range(5):
        var lane2 := lanes[i % lanes.size()]
        create_hero(Vector2(350 + i * 30, lane2), 1, false, true, lane2)
    spawn_wave(true)
    spawn_wave(false)

func create_hero(pos: Vector2, team: int, is_player: bool, is_bot: bool, lane_y: float) -> ArenaHero:
    var hero := ArenaHero.new()
    add_child(hero)
    hero.global_position = pos
    hero.configure(team, is_player, is_bot, lane_y)
    return hero

func create_structure(pos: Vector2, team: int, is_base: bool) -> ArenaStructure:
    var s := ArenaStructure.new()
    add_child(s)
    s.global_position = pos
    s.configure(team, is_base)
    return s

func spawn_wave(allied: bool) -> void:
    var team := 0 if allied else 1
    for lane in lanes:
        for i in range(3):
            create_minion(team, lane, false, i)
        create_minion(team, lane, true, 3)

func create_minion(team: int, lane_y: float, ranged: bool, index: int) -> void:
    var m := ArenaMinion.new()
    add_child(m)
    var x := -1050.0 + index * 42.0 if team == 0 else 1050.0 - index * 42.0
    m.global_position = Vector2(x, lane_y + (index % 2) * 16 - 8)
    m.setup_minion(team, lane_y, ranged)

func _process(delta: float) -> void:
    spawn_timer += delta
    if spawn_timer >= 18.0 and not GameState.match_over:
        spawn_timer = 0.0
        spawn_wave(true)
        spawn_wave(false)
    update_hud()
    queue_redraw()

func build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var controls := TouchControlsScene.new()
    layer.add_child(controls)
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_label = Label.new()
    hud_label.position = Vector2(24, 18)
    hud_label.add_theme_font_size_override("font_size", 20)
    layer.add_child(hud_label)
    result_label = Label.new()
    result_label.position = Vector2(430, 25)
    result_label.add_theme_font_size_override("font_size", 34)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.size = Vector2(420, 60)
    layer.add_child(result_label)
    var title := Label.new()
    title.text = "ARENA NEXUS  •  5v5 MVP"
    title.position = Vector2(500, 680)
    title.add_theme_font_size_override("font_size", 16)
    layer.add_child(title)

func update_hud() -> void:
    if not is_instance_valid(player):
        return
    hud_label.text = "HP %d/%d   Mana %d/%d   Lv %d   Gold %d   XP %d\nTime %02d:%02d" % [int(player.hp), int(player.max_hp), int(player.mana), int(player.max_mana), player.level, player.gold, player.xp, int(GameState.match_time) / 60, int(GameState.match_time) % 60]
    if GameState.match_over:
        var winner := "BLUE" if GameState.winner_team == 0 else "RED"
        result_label.text = "%s TEAM WINS" % winner

func _draw() -> void:
    # Arena background
    draw_rect(Rect2(-1400, -520, 2800, 1040), Color("1a2530"))
    # River
    draw_rect(Rect2(-1400, -75, 2800, 150), Color("253e55"))
    # Lanes
    for y in lanes:
        draw_rect(Rect2(-1200, y - 46, 2400, 92), Color("25332d"))
        draw_line(Vector2(-1200, y), Vector2(1200, y), Color("65715d"), 2.0)
    # Jungle blocks
    for x in [-900, -300, 300, 900]:
        draw_rect(Rect2(x - 55, -145, 110, 60), Color("1e4938"))
        draw_rect(Rect2(x - 55, 85, 110, 60), Color("1e4938"))
    # Team core zones
    draw_rect(Rect2(-1200, -520, 170, 1040), Color(0.15, 0.35, 0.55, 0.16))
    draw_rect(Rect2(1030, -520, 170, 1040), Color(0.55, 0.15, 0.22, 0.16))
