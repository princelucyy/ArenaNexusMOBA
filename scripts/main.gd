extends Node2D

const HEROES := ArenaHero.HEROES
const ITEMS := [
    {"name":"Iron Blade", "cost":400, "attack":18.0, "desc":"+18 attack"},
    {"name":"Vital Core", "cost":500, "hp":220.0, "desc":"+220 HP"},
    {"name":"Swift Boots", "cost":450, "speed":42.0, "desc":"+42 move speed"},
    {"name":"Arcane Orb", "cost":650, "ap":45.0, "mana":80.0, "desc":"+45 power +80 mana"}
]

var player: ArenaHero
var spawn_timer := 0.0
var lane_cycle := [-260.0, 0.0, 260.0]
var wave_index := 0
var hud_label: Label
var result_label: Label
var title_label: Label
var camera: Camera2D
var layer: CanvasLayer
var shop_panel: Panel
var selection_panel: Panel
var shop_buttons: Array[Button] = []
var status_label: Label
var match_started := false
var purchased_items: Array[String] = []

func _ready() -> void:
    randomize()
    build_hud()
    queue_redraw()
    show_hero_select()

func show_hero_select() -> void:
    selection_panel = Panel.new()
    selection_panel.position = Vector2(270, 135)
    selection_panel.size = Vector2(740, 450)
    layer.add_child(selection_panel)

    var title := Label.new()
    title.text = "CHOOSE YOUR HERO"
    title.position = Vector2(0, 24)
    title.size = Vector2(740, 48)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    selection_panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "5 original heroes • each has different stats and abilities"
    subtitle.position = Vector2(0, 70)
    subtitle.size = Vector2(740, 30)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    selection_panel.add_child(subtitle)

    for i in range(HEROES.size()):
        var data: Dictionary = HEROES[i]
        var button := Button.new()
        button.text = "%s\n%s\nHP %d  DMG %d  SPD %d" % [data["name"], data["role"], int(data["hp"]), int(data["damage"]), int(data["speed"])]
        button.position = Vector2(18 + (i % 3) * 240, 120 + (i / 3) * 150)
        button.size = Vector2(220, 125)
        button.add_theme_font_size_override("font_size", 17)
        button.pressed.connect(_on_hero_selected.bind(i))
        selection_panel.add_child(button)

func _on_hero_selected(hero_id: int) -> void:
    if is_instance_valid(selection_panel):
        selection_panel.queue_free()
    start_match(hero_id)

func start_match(hero_id: int) -> void:
    GameState.reset_match()
    match_started = true
    build_arena()
    spawn_match(hero_id)
    spawn_wave(0, true)
    spawn_wave(0, false)

func build_arena() -> void:
    queue_redraw()

func spawn_match(hero_id: int) -> void:
    create_structure(Vector2(-1130, 0), 0, true)
    create_structure(Vector2(1130, 0), 1, true)
    for y in lane_cycle:
        create_structure(Vector2(-790, y), 0, false)
        create_structure(Vector2(-485, y), 0, false)
        create_structure(Vector2(790, y), 1, false)
        create_structure(Vector2(485, y), 1, false)

    player = create_hero(Vector2(-340, 0), 0, hero_id, true, false, 0)
    camera = Camera2D.new()
    player.add_child(camera)
    camera.enabled = true

    var used_allied := [hero_id]
    for i in range(4):
        var aid := (hero_id + i + 1) % HEROES.size()
        used_allied.append(aid)
        var lane := lane_cycle[i % lane_cycle.size()]
        create_hero(Vector2(-260 - i * 30, lane), 0, aid, false, true, lane)

    for i in range(5):
        var enemy_id := (i + 1) % HEROES.size()
        var lane2 := lane_cycle[i % lane_cycle.size()]
        create_hero(Vector2(340 + i * 28, lane2), 1, enemy_id, false, true, lane2)

func create_hero(pos: Vector2, team: int, hero_id: int, is_player: bool, is_bot: bool, lane_y: float) -> ArenaHero:
    var hero := ArenaHero.new()
    add_child(hero)
    hero.global_position = pos
    hero.configure(team, hero_id, is_player, is_bot, lane_y)
    return hero

func create_structure(pos: Vector2, team: int, is_base: bool) -> ArenaStructure:
    var structure := ArenaStructure.new()
    add_child(structure)
    structure.global_position = pos
    structure.configure(team, is_base)
    return structure

func spawn_wave(team: int, allied: bool) -> void:
    if GameState.match_over:
        return
    if allied:
        team = 0
    else:
        team = 1
    wave_index += 1
    GameState.wave_number = wave_index
    for lane in lane_cycle:
        for i in range(3):
            create_minion(team, lane, false, i, wave_index)
        create_minion(team, lane, true, 3, wave_index)
        if wave_index % 3 == 0:
            create_minion(team, lane, true, 4, wave_index)

func create_minion(team: int, lane_y: float, ranged: bool, index: int, current_wave: int) -> void:
    var m := ArenaMinion.new()
    add_child(m)
    var x := -1040.0 + index * 42.0 if team == 0 else 1040.0 - index * 42.0
    m.global_position = Vector2(x, lane_y + (index % 2) * 16 - 8)
    m.setup_minion(team, lane_y, ranged, current_wave)

func _process(delta: float) -> void:
    if not match_started:
        return
    spawn_timer += delta
    if spawn_timer >= 18.0 and not GameState.match_over:
        spawn_timer = 0.0
        spawn_wave(0, true)
        spawn_wave(1, false)
    update_hud()
    update_shop()
    queue_redraw()

func build_hud() -> void:
    layer = CanvasLayer.new()
    add_child(layer)

    var controls := TouchControls.new()
    layer.add_child(controls)
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE

    hud_label = Label.new()
    hud_label.position = Vector2(24, 18)
    hud_label.size = Vector2(470, 96)
    hud_label.add_theme_font_size_override("font_size", 18)
    layer.add_child(hud_label)

    title_label = Label.new()
    title_label.text = "ARENA NEXUS  •  ORIGINAL 5v5 MOBA"
    title_label.position = Vector2(430, 12)
    title_label.size = Vector2(420, 40)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 18)
    layer.add_child(title_label)

    result_label = Label.new()
    result_label.position = Vector2(430, 52)
    result_label.size = Vector2(420, 55)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size", 30)
    layer.add_child(result_label)

    status_label = Label.new()
    status_label.position = Vector2(24, 640)
    status_label.size = Vector2(550, 40)
    status_label.add_theme_font_size_override("font_size", 15)
    layer.add_child(status_label)

    shop_panel = Panel.new()
    shop_panel.position = Vector2(860, 90)
    shop_panel.size = Vector2(380, 440)
    shop_panel.visible = false
    layer.add_child(shop_panel)

    var shop_title := Label.new()
    shop_title.text = "ITEM SHOP"
    shop_title.position = Vector2(20, 14)
    shop_title.size = Vector2(340, 36)
    shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shop_title.add_theme_font_size_override("font_size", 24)
    shop_panel.add_child(shop_title)

    for i in range(ITEMS.size()):
        var button := Button.new()
        button.position = Vector2(20, 62 + i * 78)
        button.size = Vector2(340, 64)
        shop_panel.add_child(button)
        shop_buttons.append(button)
        button.pressed.connect(_on_item_pressed.bind(i))

    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(130, 384)
    close.size = Vector2(120, 40)
    close.pressed.connect(_toggle_shop)
    shop_panel.add_child(close)

func _toggle_shop() -> void:
    if not match_started:
        return
    shop_panel.visible = not shop_panel.visible

func _on_item_pressed(index: int) -> void:
    if not is_instance_valid(player) or player.dead:
        return
    var item: Dictionary = ITEMS[index]
    var cost := int(item["cost"])
    if player.gold < cost:
        status_label.text = "Not enough gold for %s" % item["name"]
        return
    player.gold -= cost
    purchased_items.append(str(item["name"]))
    player.apply_item(item)
    status_label.text = "Purchased %s" % item["name"]

func update_shop() -> void:
    if not is_instance_valid(player):
        return
    for i in range(shop_buttons.size()):
        var item: Dictionary = ITEMS[i]
        shop_buttons[i].text = "%s  •  %d G\n%s" % [item["name"], int(item["cost"]), item["desc"]]

func update_hud() -> void:
    if not is_instance_valid(player):
        return
    var mins := int(GameState.match_time) / 60
    var secs := int(GameState.match_time) % 60
    hud_label.text = "%s [%s]  |  HP %d/%d  |  Mana %d/%d\nLv %d  Gold %d  XP %d  |  K %d/%d\nWave %d  |  Time %02d:%02d" % [player.hero_name, player.role, int(player.hp), int(player.max_hp), int(player.mana), int(player.max_mana), player.level, player.gold, player.xp, GameState.blue_kills, GameState.red_kills, GameState.wave_number, mins, secs]
    if GameState.match_over:
        var winner := "BLUE" if GameState.winner_team == 0 else "RED"
        result_label.text = "%s TEAM WINS" % winner
        status_label.text = "Match finished • restart the APK to play another round"
    else:
        result_label.text = ""

func _draw() -> void:
    draw_rect(Rect2(-1450, -560, 2900, 1120), Color("16231f"))
    draw_rect(Rect2(-1450, -78, 2900, 156), Color("28445b"))
    for y in lane_cycle:
        draw_rect(Rect2(-1250, y - 48, 2500, 96), Color("2f4036"))
        draw_line(Vector2(-1250, y), Vector2(1250, y), Color("71816f"), 2.0)
        draw_line(Vector2(-1180, y - 34), Vector2(1180, y - 34), Color(0.6, 0.7, 0.6, 0.16), 2.0)
        draw_line(Vector2(-1180, y + 34), Vector2(1180, y + 34), Color(0.6, 0.7, 0.6, 0.16), 2.0)

    # Jungle camps and foliage
    for x in [-930, -630, -300, 300, 630, 930]:
        draw_circle(Vector2(x, -150), 42, Color("1f5b41"))
        draw_circle(Vector2(x, 150), 42, Color("1f5b41"))
        draw_circle(Vector2(x + 25, -130), 18, Color("2e7653"))
        draw_circle(Vector2(x - 18, 170), 20, Color("2e7653"))

    draw_rect(Rect2(-1210, -560, 170, 1120), Color(0.18, 0.42, 0.75, 0.14))
    draw_rect(Rect2(1040, -560, 170, 1120), Color(0.75, 0.18, 0.25, 0.14))

    # River crossings
    for y in [-240.0, 240.0]:
        draw_rect(Rect2(-120, y - 18, 240, 36), Color("6a6653"))
        for x in range(-100, 100, 40):
            draw_rect(Rect2(x, y - 15, 24, 30), Color("887f66"))
