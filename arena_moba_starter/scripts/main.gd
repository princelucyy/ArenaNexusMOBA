extends Node2D

const HEROES := ArenaHero.HEROES
const ITEMS := [
    {"name":"Iron Blade", "cost":400, "attack":18.0, "desc":"+18 Attack"},
    {"name":"Vital Core", "cost":500, "hp":220.0, "desc":"+220 HP"},
    {"name":"Swift Boots", "cost":450, "speed":42.0, "desc":"+42 Move Speed"},
    {"name":"Arcane Orb", "cost":650, "ap":45.0, "mana":80.0, "desc":"+45 Power • +80 Mana"}
]
const LANE_CYCLE := [-260.0, 0.0, 260.0]

var ui_layer: CanvasLayer
var ui_root: Control
var player: ArenaHero
var camera: Camera2D
var match_started := false
var tutorial_match := false
var result_screen_shown := false
var selected_mode := "Classic AI 5v5"
var selected_hero := 0
var spawn_timer := 0.0
var wave_index := 0
var hud_label: Label
var result_label: Label
var status_label: Label
var shop_panel: Panel
var shop_buttons: Array[Button] = []
var match_tip: Panel
var lobby_content: Control

func _ready() -> void:
    randomize()
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)
    ui_root = Control.new()
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
    ui_layer.add_child(ui_root)
    call_deferred("_boot_flow")

func _boot_flow() -> void:
    await show_logo_screen()
    await show_loading_splash()
    if not AppState.terms_accepted:
        show_terms()
    elif not AppState.logged_in:
        show_login()
    elif AppState.username.is_empty():
        show_create_profile()
    elif not AppState.tutorial_complete:
        show_tutorial_intro()
    else:
        show_lobby()

func clear_ui() -> void:
    for child in ui_root.get_children():
        child.queue_free()
    lobby_content = null

func make_panel(parent: Node, rect: Rect2, color := Color("131d31"), radius := 18) -> Panel:
    var panel := Panel.new()
    panel.position = rect.position
    panel.size = rect.size
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.corner_radius_top_left = radius
    sb.corner_radius_top_right = radius
    sb.corner_radius_bottom_left = radius
    sb.corner_radius_bottom_right = radius
    sb.border_width_left = 1
    sb.border_width_right = 1
    sb.border_width_top = 1
    sb.border_width_bottom = 1
    sb.border_color = Color("2d4468")
    panel.add_theme_stylebox_override("panel", sb)
    parent.add_child(panel)
    return panel

func make_label(parent: Node, text: String, rect: Rect2, size := 18, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var label := Label.new()
    label.text = text
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = align
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label

func make_button(parent: Node, text: String, rect: Rect2, callback: Callable, accent := false) -> Button:
    var button := Button.new()
    button.text = text
    button.position = rect.position
    button.size = rect.size
    button.add_theme_font_size_override("font_size", 16)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("1a2840") if not accent else Color("d9a64f")
    normal.corner_radius_top_left = 12
    normal.corner_radius_top_right = 12
    normal.corner_radius_bottom_left = 12
    normal.corner_radius_bottom_right = 12
    normal.border_width_left = 1
    normal.border_width_right = 1
    normal.border_width_top = 1
    normal.border_width_bottom = 1
    normal.border_color = Color("395679") if not accent else Color("ffe1a0")
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate()
    hover.bg_color = Color("263c5d") if not accent else Color("efbd63")
    button.add_theme_stylebox_override("hover", hover)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func style_line_edit(edit: LineEdit) -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color("0d1627")
    sb.corner_radius_top_left = 10
    sb.corner_radius_top_right = 10
    sb.corner_radius_bottom_left = 10
    sb.corner_radius_bottom_right = 10
    sb.border_width_left = 1
    sb.border_width_right = 1
    sb.border_width_top = 1
    sb.border_width_bottom = 1
    sb.border_color = Color("385475")
    edit.add_theme_stylebox_override("normal", sb)

func show_logo_screen() -> void:
    clear_ui()
    var bg := ColorRect.new()
    bg.color = Color.BLACK
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.add_child(bg)
    var logo := TextureRect.new()
    logo.texture = load("res://assets/logo.svg")
    logo.position = Vector2(320, 185)
    logo.size = Vector2(640, 215)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ui_root.add_child(logo)
    make_label(ui_root, "STARTING NEXUS SERVICES…", Rect2(0, 540, 1280, 40), 16, Color("71809a"), HORIZONTAL_ALIGNMENT_CENTER)
    await get_tree().create_timer(1.6).timeout

func show_loading_splash() -> void:
    clear_ui()
    var image := TextureRect.new()
    image.texture = load("res://assets/splash_collab.svg")
    image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    ui_root.add_child(image)
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.18)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.add_child(shade)
    make_label(ui_root, "NEXUS COLLAB • AWAKENING", Rect2(0, 35, 1280, 45), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    var progress := ProgressBar.new()
    progress.position = Vector2(310, 612)
    progress.size = Vector2(660, 24)
    progress.min_value = 0
    progress.max_value = 100
    progress.value = 0
    progress.show_percentage = false
    ui_root.add_child(progress)
    var label := make_label(ui_root, "LOADING 0%", Rect2(0, 645, 1280, 34), 17, Color("e3edf9"), HORIZONTAL_ALIGNMENT_CENTER)
    for value in range(0, 101, 2):
        progress.value = value
        label.text = "LOADING %d%%" % value
        await get_tree().create_timer(0.035).timeout

func show_terms() -> void:
    clear_ui()
    draw_app_backdrop("USER AGREEMENT")
    make_label(ui_root, "KETENTUAN & KEBIJAKAN", Rect2(110, 62, 1060, 55), 30, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    var panel := make_panel(ui_root, Rect2(180, 132, 920, 450), Color("0e1727"), 20)
    var text := RichTextLabel.new()
    text.position = Vector2(34, 28)
    text.size = Vector2(852, 330)
    text.bbcode_enabled = true
    text.text = "[font_size=22][b]Arena Nexus MOBA — Ketentuan Pengguna[/b][/font_size]\n\nDengan menggunakan aplikasi ini, kamu menyetujui bahwa akun, nama pengguna, progres lokal, dan data pertandingan demo dapat disimpan pada perangkat. Jangan gunakan nama atau konten yang melanggar hukum. Fitur login pihak ketiga pada build ini adalah alur demo lokal; integrasi OAuth resmi memerlukan backend, SDK, dan kredensial developer.\n\n[font_size=18][b]Privasi:[/b][/font_size] build ini menyimpan profil lokal pada penyimpanan aplikasi. Tidak ada password layanan pihak ketiga yang disimpan oleh game.\n\n[font_size=18][b]Fair Play:[/b][/font_size] dilarang mengeksploitasi bug, memodifikasi klien, atau menggunakan perangkat lunak curang pada multiplayer resmi.\n\nDengan menekan [b]SETUJU & LANJUT[/b], kamu menyatakan telah membaca ketentuan ini."
    text.add_theme_color_override("default_color", Color("d4dff0"))
    panel.add_child(text)
    var agree := CheckButton.new()
    agree.text = "Saya telah membaca dan menyetujui"
    agree.position = Vector2(45, 365)
    agree.size = Vector2(420, 50)
    agree.add_theme_font_size_override("font_size", 17)
    panel.add_child(agree)
    var btn := make_button(panel, "SETUJU & LANJUT", Rect2(560, 360, 300, 54), func():
        AppState.terms_accepted = true
        AppState.save_profile()
        show_login(), true)
    btn.disabled = true
    agree.toggled.connect(func(pressed): btn.disabled = not pressed)
    make_label(ui_root, "Build original • 5v5 arena • single-player tutorial + bot match", Rect2(0, 612, 1280, 30), 14, Color("6e819e"), HORIZONTAL_ALIGNMENT_CENTER)

func show_login() -> void:
    clear_ui()
    draw_app_backdrop("ACCOUNT")
    make_label(ui_root, "MASUK KE ARENA NEXUS", Rect2(0, 62, 1280, 52), 31, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    var card := make_panel(ui_root, Rect2(390, 135, 500, 470), Color("0d1728"), 22)
    var logo := TextureRect.new()
    logo.texture = load("res://assets/logo.svg")
    logo.position = Vector2(85, 24)
    logo.size = Vector2(330, 105)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    card.add_child(logo)
    make_label(card, "Pilih metode masuk untuk profil lokal kamu", Rect2(35, 128, 430, 34), 15, Color("a9bad2"), HORIZONTAL_ALIGNMENT_CENTER)
    make_button(card, "Masuk dengan Google  • DEMO", Rect2(55, 180, 390, 52), func(): demo_login("Google"))
    make_button(card, "Masuk dengan Facebook  • DEMO", Rect2(55, 245, 390, 52), func(): demo_login("Facebook"))
    make_button(card, "Masuk dengan WhatsApp  • DEMO", Rect2(55, 310, 390, 52), func(): demo_login("WhatsApp"))
    make_button(card, "Lanjut sebagai Tamu", Rect2(55, 375, 390, 52), func(): demo_login("Guest"), true)
    make_label(card, "Integrasi OAuth asli akan ditambahkan pada backend produksi.", Rect2(35, 435, 430, 25), 12, Color("71829e"), HORIZONTAL_ALIGNMENT_CENTER)

func demo_login(provider: String) -> void:
    AppState.logged_in = true
    AppState.save_profile()
    show_toast("Login %s demo berhasil." % provider)
    await get_tree().create_timer(0.45).timeout
    show_create_profile()

func show_create_profile() -> void:
    clear_ui()
    draw_app_backdrop("CREATE PROFILE")
    var card := make_panel(ui_root, Rect2(320, 90, 640, 535), Color("0d1728"), 22)
    make_label(card, "BUAT PROFIL PEMAIN", Rect2(30, 26, 580, 48), 29, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "Nama pengguna", Rect2(50, 105, 250, 32), 16, Color("c6d6ed"))
    var username := LineEdit.new()
    username.name = "UsernameEdit"
    username.placeholder_text = "Contoh: KittownHero"
    username.position = Vector2(50, 142)
    username.size = Vector2(540, 48)
    username.max_length = 18
    style_line_edit(username)
    card.add_child(username)
    make_label(card, "Bahasa", Rect2(50, 212, 250, 32), 16, Color("c6d6ed"))
    var lang := OptionButton.new()
    lang.position = Vector2(50, 248)
    lang.size = Vector2(260, 48)
    for item in ["Indonesia", "English", "Malay"]:
        lang.add_item(item)
    card.add_child(lang)
    make_label(card, "Negara", Rect2(330, 212, 250, 32), 16, Color("c6d6ed"))
    var country := OptionButton.new()
    country.position = Vector2(330, 248)
    country.size = Vector2(260, 48)
    for item in ["Indonesia", "Malaysia", "Singapore", "Philippines", "Other"]:
        country.add_item(item)
    card.add_child(country)
    make_label(card, "Profil ini disimpan lokal untuk build demo. Kamu bisa menggantinya nanti dari Pengaturan.", Rect2(50, 318, 540, 58), 14, Color("7f91ab"), HORIZONTAL_ALIGNMENT_CENTER)
    make_button(card, "LANJUTKAN", Rect2(135, 405, 370, 60), func():
        var name := username.text.strip_edges()
        if name.is_empty():
            show_toast("Isi nama pengguna terlebih dahulu.")
            return
        AppState.username = name
        AppState.language = lang.get_item_text(lang.selected)
        AppState.country = country.get_item_text(country.selected)
        AppState.save_profile()
        show_tutorial_intro(), true)
    
func show_tutorial_intro() -> void:
    clear_ui()
    draw_app_backdrop("FIRST MATCH")
    make_label(ui_root, "TUTORIAL PERTAMA • 5V5 VS BOT", Rect2(0, 48, 1280, 54), 31, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    var card := make_panel(ui_root, Rect2(220, 125, 840, 470), Color("0d1728"), 22)
    make_label(card, "Selamat datang, %s" % AppState.username, Rect2(30, 24, 780, 44), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "Kamu akan menjalankan pertandingan latihan 5v5 melawan bot.", Rect2(30, 72, 780, 32), 16, Color("a9bad2"), HORIZONTAL_ALIGNMENT_CENTER)
    var tips := [
        "1. Gerakkan hero dengan joystick di kiri.",
        "2. ATK untuk serangan dasar, S1/S2 untuk skill, ULT untuk kemampuan utama.",
        "3. Hancurkan turret dan base lawan untuk menang.",
        "4. Gold dipakai di Item Shop. XP menaikkan level hero.",
        "5. Tutorial dapat diselesaikan kapan saja dari tombol SELESAIKAN TUTORIAL."
    ]
    for i in range(tips.size()):
        make_label(card, tips[i], Rect2(65, 128 + i * 48, 710, 38), 16, Color("d6e3f5"))
    make_button(card, "PILIH HERO & MULAI 5V5", Rect2(210, 370, 420, 58), func(): show_hero_select(true), true)
    make_label(ui_root, "16:9 landscape • UI skala otomatis sesuai layar", Rect2(0, 635, 1280, 28), 13, Color("6d7f9d"), HORIZONTAL_ALIGNMENT_CENTER)

func draw_app_backdrop(section: String) -> void:
    var bg := ColorRect.new()
    bg.color = Color("07101d")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.add_child(bg)
    var top := ColorRect.new()
    top.color = Color("0d1a2d")
    top.position = Vector2(0, 0)
    top.size = Vector2(1280, 8)
    ui_root.add_child(top)
    make_label(ui_root, "ARENA NEXUS", Rect2(32, 18, 250, 38), 19, Color("b6d6ff"))
    make_label(ui_root, section, Rect2(980, 18, 260, 38), 14, Color("687a95"), HORIZONTAL_ALIGNMENT_RIGHT)

func show_lobby() -> void:
    clear_ui()
    var bg := ColorRect.new()
    bg.color = Color("07111f")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.add_child(bg)
    var hero_glow := ColorRect.new()
    hero_glow.color = Color("182a4a")
    hero_glow.position = Vector2(0, 0)
    hero_glow.size = Vector2(1280, 220)
    ui_root.add_child(hero_glow)
    
    make_label(ui_root, "ARENA NEXUS", Rect2(28, 18, 190, 35), 20, Color("d9eaff"))
    make_label(ui_root, AppState.username, Rect2(30, 58, 210, 32), 18, Color("ffffff"))
    make_label(ui_root, "LV %d  •  %s, %s" % [AppState.level, AppState.country, AppState.language], Rect2(30, 88, 330, 25), 12, Color("8294af"))
    make_label(ui_root, "◈ %d" % AppState.coins, Rect2(1040, 22, 100, 34), 16, Color("f6cd72"), HORIZONTAL_ALIGNMENT_RIGHT)
    make_label(ui_root, "◆ %d" % AppState.diamonds, Rect2(1150, 22, 100, 34), 16, Color("8fe7ff"), HORIZONTAL_ALIGNMENT_RIGHT)
    
    var banner := TextureRect.new()
    banner.texture = load("res://assets/splash_collab.svg")
    banner.position = Vector2(300, 112)
    banner.size = Vector2(680, 360)
    banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    ui_root.add_child(banner)
    make_label(ui_root, "NEXUS COLLAB • AWAKENING", Rect2(340, 134, 600, 36), 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    make_label(ui_root, "Original heroes • tactical 5v5 • tutorial + bot match", Rect2(350, 435, 580, 30), 15, Color("c2d1e7"), HORIZONTAL_ALIGNMENT_CENTER)
    
    var queue := make_panel(ui_root, Rect2(300, 482, 680, 110), Color("0e1a2b"), 18)
    make_label(queue, "MODE  •  %s" % selected_mode, Rect2(24, 18, 270, 30), 15, Color("cbdaf0"))
    make_label(queue, "5V5 AI MATCH", Rect2(24, 50, 270, 25), 14, Color("7789a3"))
    make_button(queue, "PLAY", Rect2(385, 22, 255, 62), func(): show_hero_select(false), true)
    
    var nav := make_panel(ui_root, Rect2(30, 520, 235, 155), Color("0c1727"), 18)
    make_button(nav, "HEROES", Rect2(15, 15, 95, 54), func(): show_heroes())
    make_button(nav, "RANK", Rect2(120, 15, 95, 54), func(): show_rank())
    make_button(nav, "HISTORY", Rect2(15, 78, 95, 54), func(): show_history())
    make_button(nav, "PROFILE", Rect2(120, 78, 95, 54), func(): show_profile())
    
    var right := make_panel(ui_root, Rect2(1000, 112, 250, 563), Color("0c1727"), 18)
    make_label(right, "EVENTS", Rect2(15, 15, 220, 30), 20, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(right, "NEXUS COLLAB", Rect2(15, 68, 220, 28), 17, Color("e2ebf7"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(right, "Daily mission\n• Win 1 AI match\n• Use any skill 10x\n• Play 1 classic", Rect2(25, 108, 200, 120), 14, Color("9fb2cc"), HORIZONTAL_ALIGNMENT_CENTER)
    make_button(right, "EVENT CENTER", Rect2(25, 250, 200, 48), func(): show_events())
    make_button(right, "SETTINGS", Rect2(25, 315, 200, 48), func(): show_settings())
    make_button(right, "SERVER STATUS  •  ONLINE", Rect2(25, 380, 200, 48), func(): show_toast("Training server status: ONLINE"))
    make_label(ui_root, "Local demo build • third-party social login is simulated • online multiplayer comes in the network layer", Rect2(280, 680, 720, 24), 12, Color("657791"), HORIZONTAL_ALIGNMENT_CENTER)
    lobby_content = ui_root

func show_hero_select(is_tutorial: bool) -> void:
    clear_ui()
    draw_app_backdrop("HERO SELECTION")
    make_label(ui_root, "PILIH HERO", Rect2(0, 50, 1280, 45), 30, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(ui_root, "Pilih salah satu hero original untuk %s" % ("tutorial 5v5" if is_tutorial else "match AI 5v5"), Rect2(0, 92, 1280, 30), 15, Color("8ca0bc"), HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(HEROES.size()):
        var data: Dictionary = HEROES[i]
        var card := make_panel(ui_root, Rect2(52 + i * 240, 165, 220, 340), Color("0d1828"), 18)
        var swatch := ColorRect.new()
        swatch.color = Color(str(data["color"]))
        swatch.position = Vector2(20, 22)
        swatch.size = Vector2(180, 115)
        card.add_child(swatch)
        make_label(card, str(data["name"]), Rect2(20, 150, 180, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
        make_label(card, str(data["role"]), Rect2(20, 186, 180, 28), 14, Color("99abc5"), HORIZONTAL_ALIGNMENT_CENTER)
        make_label(card, "HP %d\nDMG %d   SPD %d\nMana %d" % [int(data["hp"]), int(data["damage"]), int(data["speed"]), int(data["mana"])], Rect2(20, 218, 180, 70), 13, Color("c6d4e9"), HORIZONTAL_ALIGNMENT_CENTER)
        make_button(card, "PILIH", Rect2(35, 300, 150, 42), _select_hero.bind(i, is_tutorial))
    make_button(ui_root, "← KEMBALI", Rect2(40, 35, 170, 44), func(): show_lobby())

func _select_hero(hero_id: int, is_tutorial: bool) -> void:
    AppState.preferred_hero = hero_id
    AppState.save_profile()
    start_match(hero_id, is_tutorial)

func start_match(hero_id: int, tutorial := false) -> void:
    clear_ui()
    _cleanup_world()
    GameState.reset_match()
    match_started = true
    tutorial_match = tutorial
    result_screen_shown = false
    selected_hero = hero_id
    spawn_timer = 0.0
    wave_index = 0
    _spawn_match(hero_id)
    _spawn_wave(0)
    _spawn_wave(1)
    _build_match_hud()
    if tutorial:
        match_tip.visible = true
        make_label(match_tip, "Tutorial: dorong lane, beli item, dan hancurkan base lawan.", Rect2(18, 50, 430, 38), 14, Color("d3e2f5"))

func _spawn_match(hero_id: int) -> void:
    _create_structure(Vector2(-1130, 0), 0, true)
    _create_structure(Vector2(1130, 0), 1, true)
    for y in LANE_CYCLE:
        _create_structure(Vector2(-790, y), 0, false)
        _create_structure(Vector2(-485, y), 0, false)
        _create_structure(Vector2(790, y), 1, false)
        _create_structure(Vector2(485, y), 1, false)
    player = _create_hero(Vector2(-340, 0), 0, hero_id, true, false, 0)
    camera = Camera2D.new()
    player.add_child(camera)
    camera.enabled = true
    for i in range(4):
        var aid := (hero_id + i + 1) % HEROES.size()
        var lane := LANE_CYCLE[i % LANE_CYCLE.size()]
        _create_hero(Vector2(-260 - i * 30, lane), 0, aid, false, true, lane)
    for i in range(5):
        var enemy_id := (i + 1) % HEROES.size()
        var lane2 := LANE_CYCLE[i % LANE_CYCLE.size()]
        _create_hero(Vector2(340 + i * 28, lane2), 1, enemy_id, false, true, lane2)

func _create_hero(pos: Vector2, team: int, hero_id: int, is_player: bool, is_bot: bool, lane_y: float) -> ArenaHero:
    var hero := ArenaHero.new()
    add_child(hero)
    hero.global_position = pos
    hero.configure(team, hero_id, is_player, is_bot, lane_y)
    return hero

func _create_structure(pos: Vector2, team: int, is_base: bool) -> ArenaStructure:
    var structure := ArenaStructure.new()
    add_child(structure)
    structure.global_position = pos
    structure.configure(team, is_base)
    return structure

func _spawn_wave(team: int) -> void:
    if GameState.match_over:
        return
    wave_index += 1
    GameState.wave_number = wave_index
    for lane in LANE_CYCLE:
        for i in range(3):
            _create_minion(team, lane, false, i)
        _create_minion(team, lane, true, 3)
        if wave_index % 3 == 0:
            _create_minion(team, lane, true, 4)

func _create_minion(team: int, lane_y: float, ranged: bool, index: int) -> void:
    var m := ArenaMinion.new()
    add_child(m)
    var x := -1040.0 + index * 42.0 if team == 0 else 1040.0 - index * 42.0
    m.global_position = Vector2(x, lane_y + (index % 2) * 16 - 8)
    m.setup_minion(team, lane_y, ranged, wave_index)

func _build_match_hud() -> void:
    var touch := TouchControls.new()
    ui_root.add_child(touch)
    touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var top := make_panel(ui_root, Rect2(18, 16, 500, 94), Color(0.04,0.08,0.13,0.88), 14)
    hud_label = make_label(top, "", Rect2(15, 10, 470, 72), 15, Color.WHITE)
    var center := make_label(ui_root, tutorial_match ? "TUTORIAL 5V5 • BOT MATCH" : "CLASSIC AI 5V5", Rect2(410, 18, 460, 36), 18, Color("dbe7f8"), HORIZONTAL_ALIGNMENT_CENTER)
    result_label = make_label(ui_root, "", Rect2(420, 54, 440, 46), 28, Color("f6cd6b"), HORIZONTAL_ALIGNMENT_CENTER)
    status_label = make_label(ui_root, "", Rect2(18, 650, 620, 38), 14, Color("c6d3e6"))
    match_tip = make_panel(ui_root, Rect2(18, 120, 470, 95), Color(0.05,0.1,0.17,0.92), 14)
    make_label(match_tip, "TUTORIAL", Rect2(18, 10, 150, 32), 18, Color("f6c96c"))
    match_tip.visible = tutorial_match
    if tutorial_match:
        make_button(ui_root, "SELESAIKAN TUTORIAL", Rect2(1000, 20, 250, 48), func(): finish_match(true), true)
    shop_panel = make_panel(ui_root, Rect2(855, 100, 380, 470), Color("0a1423"), 18)
    shop_panel.visible = false
    make_label(shop_panel, "ITEM SHOP", Rect2(20, 18, 340, 34), 23, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(ITEMS.size()):
        var button := make_button(shop_panel, "", Rect2(20, 66 + i * 76, 340, 62), _on_item_pressed.bind(i))
        shop_buttons.append(button)
    make_button(shop_panel, "CLOSE", Rect2(130, 386, 120, 44), func(): shop_panel.visible = false)
    _update_shop()

func _on_item_pressed(index: int) -> void:
    if not is_instance_valid(player) or player.dead:
        return
    var item: Dictionary = ITEMS[index]
    var cost := int(item["cost"])
    if player.gold < cost:
        status_label.text = "Not enough gold for %s" % item["name"]
        return
    player.gold -= cost
    player.apply_item(item)
    status_label.text = "Purchased %s" % item["name"]
    _update_shop()

func _update_shop() -> void:
    for i in range(shop_buttons.size()):
        var item: Dictionary = ITEMS[i]
        shop_buttons[i].text = "%s • %d G\n%s" % [item["name"], int(item["cost"]), item["desc"]]

func _update_match_hud() -> void:
    if not is_instance_valid(player):
        return
    var mins := int(GameState.match_time) / 60
    var secs := int(GameState.match_time) % 60
    hud_label.text = "%s • %s   HP %d/%d   MP %d/%d\nLV %d   Gold %d   XP %d   K/D %d/%d   %02d:%02d" % [player.hero_name, player.role, int(player.hp), int(player.max_hp), int(player.mana), int(player.max_mana), player.level, player.gold, player.xp, GameState.blue_kills, GameState.red_kills, mins, secs]
    if not GameState.match_over:
        result_label.text = ""

func finish_match(from_tutorial_button := false) -> void:
    if result_screen_shown:
        return
    result_screen_shown = true
    match_started = false
    if from_tutorial_button:
        GameState.match_over = true
        GameState.winner_team = 0
    var winner := "VICTORY" if GameState.winner_team == 0 else "DEFEAT"
    var mins := int(GameState.match_time) / 60
    var secs := int(GameState.match_time) % 60
    var result_text := "%s • %s • %d/%d • %02d:%02d" % [winner, player.hero_name if is_instance_valid(player) else "Hero", GameState.blue_kills, GameState.red_kills, mins, secs]
    AppState.add_match_result(result_text)
    AppState.coins += 120 if winner == "VICTORY" else 40
    if tutorial_match:
        AppState.tutorial_complete = true
        AppState.save_profile()
    _show_result_screen(winner, result_text)

func _show_result_screen(winner: String, result_text: String) -> void:
    _cleanup_world()
    clear_ui()
    draw_app_backdrop("MATCH RESULT")
    var card := make_panel(ui_root, Rect2(290, 105, 700, 495), Color("0d1728"), 22)
    make_label(card, winner, Rect2(30, 32, 640, 70), 40, Color("f6cb6c") if winner == "VICTORY" else Color("e98a8a"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, tutorial_match ? "Tutorial pertama selesai" : "Pertandingan selesai", Rect2(30, 102, 640, 34), 16, Color("a6bad5"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "Hasil: %s" % result_text, Rect2(30, 154, 640, 48), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "KDA\nKills: %d\nDeaths: %d\nTeam gold: %d" % [GameState.blue_kills, GameState.red_kills, GameState.blue_gold], Rect2(110, 222, 220, 125), 17, Color("d3e0f2"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "REWARDS\n+%d Coins\nRiwayat pertandingan tersimpan" % (120 if winner == "VICTORY" else 40), Rect2(370, 222, 220, 125), 17, Color("f6d27b"), HORIZONTAL_ALIGNMENT_CENTER)
    make_button(card, "KEMBALI KE LOBBY", Rect2(160, 385, 380, 58), func(): show_lobby(), true)
    make_button(card, "LIHAT RIWAYAT", Rect2(220, 450, 260, 34), func(): show_history())

func show_history() -> void:
    clear_ui()
    draw_app_backdrop("MATCH HISTORY")
    make_label(ui_root, "RIWAYAT PERTANDINGAN", Rect2(0, 55, 1280, 48), 29, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    var card := make_panel(ui_root, Rect2(205, 125, 870, 485), Color("0d1728"), 22)
    if AppState.match_history.is_empty():
        make_label(card, "Belum ada pertandingan. Selesaikan tutorial pertama untuk membuat riwayat.", Rect2(30, 190, 810, 50), 17, Color("8194ad"), HORIZONTAL_ALIGNMENT_CENTER)
    else:
        for i in range(AppState.match_history.size()):
            var row := make_panel(card, Rect2(24, 20 + i * 50, 822, 42), Color("111e31"), 10)
            make_label(row, "#%02d" % (i + 1), Rect2(12, 0, 50, 42), 14, Color("7b8da7"), HORIZONTAL_ALIGNMENT_CENTER)
            make_label(row, AppState.match_history[i], Rect2(68, 0, 735, 42), 14, Color("d7e3f3"))
            if i >= 8:
                break
    make_button(ui_root, "← KEMBALI KE LOBBY", Rect2(40, 620, 220, 48), func(): show_lobby())

func show_heroes() -> void:
    clear_ui()
    draw_app_backdrop("HERO GALLERY")
    make_label(ui_root, "HERO GALLERY", Rect2(0, 52, 1280, 48), 30, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(HEROES.size()):
        var data: Dictionary = HEROES[i]
        var card := make_panel(ui_root, Rect2(55 + i * 240, 150, 220, 350), Color("0d1828"), 18)
        var swatch := ColorRect.new()
        swatch.color = Color(str(data["color"]))
        swatch.position = Vector2(18, 18)
        swatch.size = Vector2(184, 110)
        card.add_child(swatch)
        make_label(card, str(data["name"]), Rect2(18, 140, 184, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
        make_label(card, str(data["role"]), Rect2(18, 174, 184, 26), 14, Color("9eafc5"), HORIZONTAL_ALIGNMENT_CENTER)
        make_label(card, "Basic %.0f\nSkill %s / %s / %s" % [float(data["damage"]), str(data["s1"]), str(data["s2"]), str(data["ult"])], Rect2(18, 220, 184, 72), 14, Color("d0dcf0"), HORIZONTAL_ALIGNMENT_CENTER)
        make_button(card, "PILIH", Rect2(35, 298, 150, 42), _set_preferred_hero.bind(i))
    make_button(ui_root, "← KEMBALI", Rect2(40, 620, 180, 46), func(): show_lobby())

func _set_preferred_hero(hero_id: int) -> void:
    AppState.preferred_hero = hero_id
    AppState.save_profile()
    show_lobby()

func show_rank() -> void:
    clear_ui()
    draw_app_backdrop("RANK")
    var card := make_panel(ui_root, Rect2(280, 120, 720, 470), Color("0d1728"), 22)
    make_label(card, "RANKED", Rect2(0, 28, 720, 50), 32, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "BRONZE III", Rect2(0, 100, 720, 65), 42, Color("d4c0a1"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "0 / 100 Rating\nSeason 01 • Nexus Awakening\nRanked multiplayer membutuhkan backend authoritative.", Rect2(70, 190, 580, 110), 17, Color("c2d1e6"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "Target berikutnya: implementasi server 5v5 + matchmaking.", Rect2(70, 315, 580, 40), 14, Color("7487a4"), HORIZONTAL_ALIGNMENT_CENTER)
    make_button(card, "← KEMBALI", Rect2(230, 380, 260, 52), func(): show_lobby())

func show_profile() -> void:
    clear_ui()
    draw_app_backdrop("PROFILE")
    var card := make_panel(ui_root, Rect2(300, 105, 680, 500), Color("0d1728"), 22)
    make_label(card, "PLAYER PROFILE", Rect2(0, 26, 680, 46), 29, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, AppState.username, Rect2(70, 100, 540, 42), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "Level %d\n%s • %s\n%02d Matches\nTutorial: %s" % [AppState.level, AppState.country, AppState.language, AppState.match_history.size(), "COMPLETE" if AppState.tutorial_complete else "PENDING"], Rect2(110, 170, 460, 150), 19, Color("c5d3e6"), HORIZONTAL_ALIGNMENT_CENTER)
    make_button(card, "HISTORY", Rect2(70, 355, 160, 50), func(): show_history())
    make_button(card, "SETTINGS", Rect2(260, 355, 160, 50), func(): show_settings())
    make_button(card, "LOBBY", Rect2(450, 355, 160, 50), func(): show_lobby(), true)

func show_events() -> void:
    clear_ui()
    draw_app_backdrop("EVENT CENTER")
    make_label(ui_root, "NEXUS COLLAB EVENTS", Rect2(0, 55, 1280, 45), 30, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    var cards := [
        ["DAILY TRAINING", "Win 1 AI match", "+120 Coins"],
        ["SKILL MASTER", "Use skills 10 times", "+80 Coins"],
        ["FIRST VICTORY", "Finish tutorial or match", "+1 Chest"]
    ]
    for i in range(cards.size()):
        var card := make_panel(ui_root, Rect2(180 + i * 315, 160, 285, 300), Color("0d1828"), 18)
        make_label(card, cards[i][0], Rect2(18, 22, 249, 40), 20, Color("e7eef9"), HORIZONTAL_ALIGNMENT_CENTER)
        make_label(card, cards[i][1], Rect2(25, 95, 235, 55), 16, Color("9eb1cb"), HORIZONTAL_ALIGNMENT_CENTER)
        make_label(card, cards[i][2], Rect2(25, 190, 235, 45), 18, Color("f6cd74"), HORIZONTAL_ALIGNMENT_CENTER)
        make_button(card, "DETAIL", Rect2(68, 245, 150, 38), func(): show_toast("Event detail akan diperluas di season system."))
    make_button(ui_root, "← KEMBALI", Rect2(40, 620, 180, 46), func(): show_lobby())

func show_settings() -> void:
    clear_ui()
    draw_app_backdrop("SETTINGS")
    var card := make_panel(ui_root, Rect2(300, 100, 680, 510), Color("0d1728"), 22)
    make_label(card, "PENGATURAN", Rect2(0, 24, 680, 45), 29, Color("f6c96c"), HORIZONTAL_ALIGNMENT_CENTER)
    make_label(card, "Bahasa", Rect2(55, 100, 250, 35), 16, Color("c4d3e7"))
    var lang := OptionButton.new()
    lang.position = Vector2(340, 98)
    lang.size = Vector2(270, 45)
    for item in ["Indonesia", "English", "Malay"]:
        lang.add_item(item)
    for i in range(lang.item_count):
        if lang.get_item_text(i) == AppState.language:
            lang.select(i)
    card.add_child(lang)
    make_label(card, "Kualitas", Rect2(55, 165, 250, 35), 16, Color("c4d3e7"))
    make_label(card, "FHD • 16:9 • Mobile", Rect2(340, 165, 270, 35), 16, Color("82a1c4"), HORIZONTAL_ALIGNMENT_RIGHT)
    make_label(card, "Audio", Rect2(55, 230, 250, 35), 16, Color("c4d3e7"))
    var audio := HSlider.new()
    audio.min_value = 0
    audio.max_value = 100
    audio.value = 70
    audio.position = Vector2(340, 235)
    audio.size = Vector2(270, 35)
    card.add_child(audio)
    make_button(card, "SIMPAN", Rect2(55, 320, 270, 50), func():
        AppState.language = lang.get_item_text(lang.selected)
        AppState.save_profile()
        show_toast("Pengaturan disimpan."))
    make_button(card, "RESET DATA DEMO", Rect2(350, 320, 270, 50), func():
        AppState.reset_local_profile()
        show_terms())
    make_button(card, "← LOBBY", Rect2(195, 410, 290, 54), func(): show_lobby())

func show_toast(message: String) -> void:
    var toast := make_panel(ui_root, Rect2(420, 610, 440, 56), Color("111e31"), 14)
    make_label(toast, message, Rect2(12, 0, 416, 56), 14, Color("e4edf9"), HORIZONTAL_ALIGNMENT_CENTER)
    await get_tree().create_timer(2.2).timeout
    if is_instance_valid(toast):
        toast.queue_free()

func _cleanup_world() -> void:
    var targets := get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("structures")
    for node in targets:
        if is_instance_valid(node):
            node.queue_free()
    player = null
    camera = null

func _process(delta: float) -> void:
    if not match_started:
        return
    spawn_timer += delta
    if spawn_timer >= 18.0 and not GameState.match_over:
        spawn_timer = 0.0
        _spawn_wave(0)
        _spawn_wave(1)
    if GameState.match_over:
        if not result_screen_shown:
            finish_match(false)
        return
    _update_match_hud()
    if GameState.shop_requested:
        GameState.shop_requested = false
        if is_instance_valid(shop_panel):
            shop_panel.visible = not shop_panel.visible

func _draw() -> void:
    if match_started:
        draw_rect(Rect2(-1450, -560, 2900, 1120), Color("16231f"))
        draw_rect(Rect2(-1450, -330, 2900, 660), Color("1b3427"))
        draw_rect(Rect2(-1400, -95, 2800, 190), Color("193d51"))
        for y in LANE_CYCLE:
            draw_line(Vector2(-1250, y), Vector2(1250, y), Color(0.8,0.9,1.0,0.12), 65.0)
            draw_line(Vector2(-1250, y), Vector2(1250, y), Color(0.95,0.85,0.55,0.13), 3.0)
