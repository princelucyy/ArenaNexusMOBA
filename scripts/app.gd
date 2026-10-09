extends Control

const SAVE_PATH := "user://astro_royale_v38.cfg"
const LEGACY_SAVE_PATHS := ["user://astro_royale_v37.cfg", "user://astro_royale_v36.cfg", "user://astro_royale_v35.cfg", "user://astro_royale_v34.cfg", "user://astro_royale_v33.cfg", "user://astro_royale_v32.cfg", "user://astro_royale_v31.cfg", "user://astro_royale_v30.cfg"]

const APP_PERMISSION_ROWS := [
    {"label": "Kalender • baca", "permission": "android.permission.READ_CALENDAR"},
    {"label": "Kalender • tambah/edit", "permission": "android.permission.WRITE_CALENDAR"},
    {"label": "Kamera", "permission": "android.permission.CAMERA"},
    {"label": "Kontak • baca", "permission": "android.permission.READ_CONTACTS"},
    {"label": "Lokasi perkiraan", "permission": "android.permission.ACCESS_COARSE_LOCATION"},
    {"label": "Lokasi presisi", "permission": "android.permission.ACCESS_FINE_LOCATION"},
    {"label": "Mikrofon / voice chat", "permission": "android.permission.RECORD_AUDIO"},
    {"label": "Notifikasi", "permission": "android.permission.POST_NOTIFICATIONS"},
    {"label": "Perangkat sekitar • scan", "permission": "android.permission.BLUETOOTH_SCAN"},
    {"label": "Perangkat sekitar • koneksi", "permission": "android.permission.BLUETOOTH_CONNECT"},
    {"label": "Wi-Fi perangkat sekitar", "permission": "android.permission.NEARBY_WIFI_DEVICES"},
    {"label": "Ponsel • status", "permission": "android.permission.READ_PHONE_STATE"}
]

@onready var terms_panel: Control = $TermsPanel
@onready var login_panel: Control = $LoginPanel
@onready var lobby_panel: Control = $LobbyPanel
@onready var match_panel: Control = $MatchPanel
@onready var result_panel: Control = $ResultPanel
@onready var history_panel: Control = $HistoryPanel
@onready var username_edit: LineEdit = $LoginPanel/Panel/VBox/Username
@onready var password_edit: LineEdit = $LoginPanel/Panel/VBox/Password
@onready var login_status: Label = $LoginPanel/Panel/VBox/Status
@onready var lobby_user: Label = $LobbyPanel/Header/User
@onready var lobby_stats: Label = $LobbyPanel/Body/Stats
@onready var match_status: Label = $MatchPanel/Center/Status
@onready var match_timer: Timer = $MatchPanel/MatchTimer

var data: Dictionary = {
    "terms": false,
    "logged_in": false,
    "username": "",
    "password_hash": "",
    "profile_complete": false,
    "tutorial_complete": false,
    "language": "Bahasa Indonesia",
    "country": "Indonesia",
    "server": "Asia Tenggara",
    "wins": 0,
    "losses": 0,
    "coins": 2500,
    "diamonds": 100,
    "matches": 0,
    "level": 1,
    "xp": 0,
    "rank": "Bronze V",
    "rank_points": 0,
    "last_result": "Belum ada pertandingan",
    "backend_url": "",
    "session_token": "",
    "cloud_user_id": -1,
    "cloud_account": false,
    "active_match_id": "",
    "remote_game_mode": false,
    "game_lane": "mid",
    "game_target": "enemy_hero",
    "selected_hero": "Astra",
    "inventory_items": [],
    "daily_claim_date": "",
    "graphics_quality": "High",
    "render_fps": 60,
    "master_volume": 0.8,
    "control_layout": "Classic",
    "left_handed_controls": false,
    "vibration_enabled": true,
    "privacy_mode": "Friends",
    "show_damage_numbers": true
}

var extended_root: Control
var profile_panel: Control
var tutorial_panel: Control
var screen_panel: Control
var screen_body: VBoxContainer
var battle_ui: VBoxContainer
var player_hp := 100
var player_mana := 100
var enemy_hp := 100
var match_seconds := 0
var skill1_cd := 0
var skill2_cd := 0
var ult_cd := 0
var first_match := false
var core_kernel: AstroCoreKernel
var remote_game_mode := false
var active_match_id := ""
var game_lane := "mid"
var game_target := "enemy_hero"
var enemy_hero_hp := 1000
var enemy_tower_hp := 1200
var player_gold := 500
var game_state_version := 0

var modern_login_root: Control
var modern_lobby_root: Control
var modern_login_username: LineEdit
var modern_login_password: LineEdit
var modern_login_status: Label
var modern_backend_url: LineEdit
var modern_lobby_user: Label
var modern_lobby_rank: Label
var modern_lobby_wallet: Label
var modern_lobby_network: Label
var modern_lobby_status: Label
var modern_play_button: Button
var oauth_poll_timer: Timer
var oauth_provider := ""
var oauth_nonce := ""
var v34_queue_panel: PanelContainer
var v34_queue_status: Label
var v34_queue_slots: Label
var v34_queue_cancel: Button
var v34_match_found_label: Label
var v34_queue_active := false
var v34_target_user_id := ""
var permission_buttons: Dictionary = {}
var permission_status_label: Label
var selected_game_mode := "Classic 5v5"
var mode_select_panel: Control
var mode_select_status: Label
var mode_select_start: Button
var v38_arena_container: SubViewportContainer
var v38_arena_viewport: SubViewport
var v38_arena_root: Node3D
var v38_player_model: Node3D
var v38_enemy_model: Node3D
var v38_enemy_mid_tower: Node3D
var v38_enemy_towers: Dictionary = {}
var v38_enemy_core_model: Node3D
var v38_minion_models: Array[Node3D] = []
var v38_arena_clock := 0.0
var v38_exit_button: Button
var v38_joystick_panel: PanelContainer

func _ready() -> void:
    load_data()
    active_match_id = str(data.get("active_match_id", ""))
    remote_game_mode = bool(data.get("remote_game_mode", false))
    game_lane = str(data.get("game_lane", "mid"))
    game_target = str(data.get("game_target", "enemy_hero"))
    # Re-bind the core buttons defensively. V18 is the last proven working core.
    _bind_core_button("$TermsPanel/Panel/VBox/Accept", _on_accept_terms)
    _bind_core_button("$LoginPanel/Panel/VBox/Login", _on_login)
    _bind_core_button("$LoginPanel/Panel/VBox/Register", _on_register)
    _bind_core_button("$LoginPanel/Panel/VBox/Guest", _on_guest)
    hide_app_panels()
    _build_extended_ui()
    _build_v33_ui()
    _build_v38_mode_selector()
    _restyle_terms_panel()
    if not bool(data.terms):
        terms_panel.visible = true
    elif not bool(data.logged_in):
        _show_modern_login()
    else:
        _route_after_login()
        if bool(data.cloud_account) and not str(data.session_token).is_empty():
            _ensure_core_kernel()
            if core_kernel.network().configured():
                core_kernel.network().sync_me()

func _bind_core_button(path: NodePath, callback: Callable) -> void:
    var button := get_node_or_null(path) as Button
    if button == null:
        return
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    if not button.pressed.is_connected(callback):
        button.pressed.connect(callback)

func hide_app_panels() -> void:
    for panel in [terms_panel, login_panel, lobby_panel, match_panel, result_panel, history_panel]:
        panel.visible = false
    if is_instance_valid(profile_panel):
        profile_panel.visible = false
    if is_instance_valid(tutorial_panel):
        tutorial_panel.visible = false
    if is_instance_valid(screen_panel):
        screen_panel.visible = false
    if is_instance_valid(modern_login_root):
        modern_login_root.visible = false
    if is_instance_valid(modern_lobby_root):
        modern_lobby_root.visible = false

func _on_accept_terms() -> void:
    data.terms = true
    save_data()
    hide_app_panels()
    _show_modern_login()

func _on_login() -> void:
    var user := username_edit.text.strip_edges()
    var password := password_edit.text
    if user.is_empty() or password.is_empty():
        login_status.text = "Isi username dan password."
        return
    # V33 fixes the previous login lock: local credentials are checked first,
    # so a bad/offline backend can never block an already-created account.
    if not str(data.username).is_empty() and user.to_lower() == str(data.username).to_lower() and password.sha256_text() == str(data.password_hash):
        data.logged_in = true
        save_data()
        login_status.text = "Masuk berhasil. Memuat Astro Royale..."
        _route_after_login()
        _ensure_core_kernel()
        if core_kernel.network().configured():
            core_kernel.network().sync_me()
        return
    _ensure_core_kernel()
    if core_kernel.network().configured():
        login_status.text = "Menghubungkan ke akun cloud..."
        core_kernel.network().login_remote(user, password)
        return
    login_status.text = "Akun lokal tidak cocok. Periksa username/password atau gunakan DAFTAR AKUN."

func _on_register() -> void:
    var user := username_edit.text.strip_edges()
    var password := password_edit.text
    if user.length() < 3 or password.length() < 8:
        login_status.text = "Username minimal 3 karakter dan password minimal 8 karakter."
        return
    if not str(data.username).is_empty() and user.to_lower() == str(data.username).to_lower():
        login_status.text = "Username lokal sudah digunakan. Gunakan username lain."
        return
    # Local account is created immediately so registration never waits on network.
    data.username = user
    data.password_hash = password.sha256_text()
    data.logged_in = true
    data.cloud_account = false
    data.session_token = ""
    data.profile_complete = false
    save_data()
    _route_after_login()
    _ensure_core_kernel()
    if core_kernel.network().configured():
        core_kernel.network().register_remote(user, password)

func _on_guest() -> void:
    data.username = "Guest"
    data.logged_in = true
    data.profile_complete = false
    save_data()
    _route_after_login()

func _route_after_login() -> void:
    _ensure_core_kernel()
    if not bool(data.profile_complete):
        show_profile()
    elif not bool(data.tutorial_complete):
        show_tutorial()
    elif remote_game_mode and not active_match_id.is_empty() and data.cloud_account and not str(data.session_token).is_empty():
        hide_app_panels()
        match_panel.visible = true
        _ensure_battle_ui()
        match_status.text = "RESUMING SERVER MATCH..."
        core_kernel.network().game_state(active_match_id)
    else:
        show_lobby()

func _ensure_core_kernel() -> void:
    if is_instance_valid(core_kernel):
        return
    core_kernel = AstroCoreKernel.new()
    core_kernel.name = "AstroCoreKernel"
    add_child(core_kernel)
    core_kernel.initialize(self)
    var net := core_kernel.network()
    if net and not net.remote_result.is_connected(_on_remote_result):
        net.remote_result.connect(_on_remote_result)
    if net and not net.remote_game_result.is_connected(_on_remote_game_result):
        net.remote_game_result.connect(_on_remote_game_result)
    if net and not net.realtime_event.is_connected(_on_v34_realtime_event):
        net.realtime_event.connect(_on_v34_realtime_event)
    if net and not net.realtime_status.is_connected(_on_v34_realtime_status):
        net.realtime_status.connect(_on_v34_realtime_status)

func show_profile() -> void:
    hide_app_panels()
    profile_panel.visible = true
    var user_edit: LineEdit = profile_panel.get_node("Card/Body/Username")
    user_edit.text = str(data.username)

func _on_profile_continue() -> void:
    var user_edit: LineEdit = profile_panel.get_node("Card/Body/Username")
    var language: OptionButton = profile_panel.get_node("Card/Body/Language")
    var country: OptionButton = profile_panel.get_node("Card/Body/Country")
    var server: OptionButton = profile_panel.get_node("Card/Body/Server")
    var user := user_edit.text.strip_edges()
    if user.length() < 3:
        profile_panel.get_node("Card/Body/Status").text = "Nama pengguna minimal 3 karakter."
        return
    data.username = user
    data.language = language.get_item_text(language.selected)
    data.country = country.get_item_text(country.selected)
    data.server = server.get_item_text(server.selected)
    data.profile_complete = true
    save_data()
    _ensure_core_kernel()
    if data.cloud_account and core_kernel.network().configured() and not str(data.session_token).is_empty():
        core_kernel.network().update_profile(data.username, data.language, data.country, data.server)
    show_tutorial()

func show_tutorial() -> void:
    hide_app_panels()
    tutorial_panel.visible = true
    var step_label: Label = tutorial_panel.get_node("Card/Body/Step")
    step_label.text = "1 / 4\nGERAKAN — Gunakan kontrol kiri untuk bergerak.\n\n2 / 4\nSERANG — Gunakan basic attack dan skill.\n\n3 / 4\nOBJECTIVE — Dorong lane, hancurkan turret, dan lindungi base.\n\n4 / 4\nMENANG — Hancurkan core lawan.\n\nSetelah tutorial, pertandingan 5v5 bot pertama akan dimulai."

func _on_start_tutorial_match() -> void:
    first_match = true
    _start_match()

func show_lobby() -> void:
    hide_app_panels()
    if is_instance_valid(modern_lobby_root):
        modern_lobby_root.visible = true
        modern_lobby_user.text = "%s  •  Lv.%d" % [str(data.username), int(data.level)]
        modern_lobby_rank.text = "%s  •  %d RP" % [str(data.rank), int(data.rank_points)]
        modern_lobby_wallet.text = "🪙 %d    💎 %d" % [int(data.coins), int(data.diamonds)]
        modern_lobby_network.text = "● CLOUD ONLINE" if (data.cloud_account and not str(data.session_token).is_empty()) else "● LOCAL MODE"
        modern_lobby_status.text = "%s • REALTIME QUEUE READY" % selected_game_mode.to_upper() if data.cloud_account else "%s • LOCAL / AI READY" % selected_game_mode.to_upper()
        if v34_queue_panel == null:
            _build_v34_matchmaking_ui()
        v34_queue_panel.visible = false
        return
    lobby_panel.visible = true
    lobby_user.text = "%s  •  Level %d" % [str(data.username), int(data.level)]
    lobby_stats.text = "COINS  %d    DIAMONDS  %d    WINS %d    LOSSES %d    RANK %s" % [int(data.coins), int(data.diamonds), int(data.wins), int(data.losses), str(data.rank)]

func _on_play() -> void:
    first_match = false
    # Only modes supported by the live matchmaker use the online queue; all other modes remain playable locally.
    if selected_game_mode in ["Classic 5v5", "Ranked 5v5"] and data.cloud_account and not str(data.session_token).is_empty():
        _ensure_core_kernel()
        if core_kernel.network().configured():
            _open_v34_matchmaking()
            return
    _start_local_match()

func _build_v34_matchmaking_ui() -> void:
    if is_instance_valid(v34_queue_panel):
        return
    v34_queue_panel = PanelContainer.new()
    v34_queue_panel.name = "V34Matchmaking"
    v34_queue_panel.position = Vector2(270, 110)
    v34_queue_panel.size = Vector2(740, 500)
    v34_queue_panel.add_theme_stylebox_override("panel", _v33_style(Color(0.012, 0.032, 0.065, 0.97), 22, Color(0.35, 0.86, 1.0, 0.48)))
    modern_lobby_root.add_child(v34_queue_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    v34_queue_panel.add_child(box)
    var title := Label.new()
    title.text = "%s • REALTIME MATCHMAKING" % selected_game_mode.to_upper()
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    box.add_child(title)
    v34_match_found_label = Label.new()
    v34_match_found_label.text = "SERVER-AUTHORITATIVE • 10 REAL PLAYERS"
    v34_match_found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v34_match_found_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1))
    box.add_child(v34_match_found_label)
    v34_queue_status = Label.new()
    v34_queue_status.text = "Belum masuk queue."
    v34_queue_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(v34_queue_status)
    v34_queue_slots = Label.new()
    v34_queue_slots.text = "0 / 10 PLAYERS"
    v34_queue_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v34_queue_slots.add_theme_font_size_override("font_size", 42)
    box.add_child(v34_queue_slots)
    var info := Label.new()
    info.text = "Queue default membutuhkan 10 pemain nyata. Tidak ada bot palsu yang dimasukkan ke queue."
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_color_override("font_color", Color(0.64, 0.72, 0.84, 1))
    box.add_child(info)
    v34_queue_cancel = _v33_button("BATALKAN MATCHMAKING", 360, 52)
    v34_queue_cancel.pressed.connect(_cancel_v34_matchmaking)
    box.add_child(v34_queue_cancel)
    v34_queue_panel.visible = false

func _open_v34_matchmaking() -> void:
    _ensure_core_kernel()
    if not is_instance_valid(v34_queue_panel):
        _build_v34_matchmaking_ui()
    hide_app_panels()
    modern_lobby_root.visible = true
    v34_queue_panel.visible = true
    v34_queue_active = true
    v34_queue_status.text = "CONNECTING TO REALTIME SERVER..."
    v34_queue_slots.text = "0 / 10 PLAYERS"
    core_kernel.network().join_matchmaking(selected_game_mode, str(data.get("selected_hero", "Astra")), game_lane)

func _cancel_v34_matchmaking() -> void:
    if is_instance_valid(core_kernel):
        core_kernel.network().leave_matchmaking()
        core_kernel.network().disconnect_realtime()
    v34_queue_active = false
    if is_instance_valid(v34_queue_panel):
        v34_queue_panel.visible = false
    show_lobby()

func _on_v34_realtime_status(status: String, detail: String) -> void:
    if not v34_queue_active:
        return
    if status == "connected":
        v34_queue_status.text = "REALTIME CONNECTED • AUTHENTICATING..."
    elif status == "authenticated":
        v34_queue_status.text = "SESSION VERIFIED • JOINING QUEUE..."
    elif status == "connecting":
        v34_queue_status.text = "CONNECTING..."
    elif status == "reconnecting":
        v34_queue_status.text = detail.to_upper()
    elif status in ["error", "closed"]:
        v34_queue_status.text = "REALTIME ERROR: %s" % detail

func _on_v34_realtime_event(event: Dictionary) -> void:
    var event_type := str(event.get("type", ""))
    if event_type == "auth_ok":
        data.cloud_user_id = int(event.get("user_id", -1))
        save_data()
        return
    if event_type == "resume_ok":
        active_match_id = str(event.get("match_id", ""))
        data.active_match_id = active_match_id
        data.remote_game_mode = true
        remote_game_mode = true
        v34_queue_active = false
        save_data()
        if is_instance_valid(v34_queue_panel):
            v34_queue_panel.visible = false
        hide_app_panels()
        match_panel.visible = true
        _ensure_battle_ui()
        match_status.text = "RECONNECTED • MATCH SESSION RESUMED\nREALTIME SERVER STATE RESTORED"
        _apply_v34_match_state(event.get("state", {}))
        return
    if event_type == "resume_failed":
        match_status.text = "RECONNECT FAILED • %s" % str(event.get("reason", "match_unavailable"))
        return
    if event_type == "queue_status":
        var queued := int(event.get("queued", 0))
        var required := int(event.get("required", 10))
        v34_queue_slots.text = "%d / %d PLAYERS" % [queued, required]
        v34_queue_status.text = "MATCHMAKING • MENUNGGU PEMAIN LAIN..."
        return
    if event_type == "queue_left":
        v34_queue_status.text = "MATCHMAKING DIBATALKAN."
        return
    if event_type == "action_rejected":
        match_status.text = "ACTION REJECTED: %s" % str(event.get("reason", "unknown"))
        return
    if event_type == "match_found":
        v34_target_user_id = ""
        active_match_id = str(event.get("match_id", ""))
        data.active_match_id = active_match_id
        data.remote_game_mode = true
        remote_game_mode = true
        v34_queue_active = false
        data.game_lane = game_lane
        save_data()
        if is_instance_valid(v34_queue_panel):
            v34_queue_panel.visible = false
        hide_app_panels()
        match_panel.visible = true
        _ensure_battle_ui()
        if is_instance_valid(battle_ui): battle_ui.visible = true
        if is_instance_valid(v38_joystick_panel): v38_joystick_panel.visible = true
        if is_instance_valid(v38_exit_button): v38_exit_button.visible = true
        match_status.text = "MATCH FOUND • %s TEAM • SLOT %d\nREALTIME 10-PLAYER SERVER" % [str(event.get("team", "?")), int(event.get("slot", 0))]
        match_timer.stop()
        _apply_v34_match_state(event.get("state", {}))
        return
    if event_type == "match_state":
        _apply_v34_match_state(event.get("state", {}))
        return

func _apply_v34_match_state(state_value) -> void:
    if not (state_value is Dictionary):
        return
    var state: Dictionary = state_value
    match_seconds = int(state.get("elapsed_seconds", 0))
    var players: Array = state.get("players", [])
    var me: Dictionary = {}
    for p in players:
        if int(p.get("user_id", -1)) == int(core_kernel.network().current_user_id()):
            me = p
        elif str(p.get("team", "")) != str(me.get("team", "")) and v34_target_user_id.is_empty():
            v34_target_user_id = str(p.get("user_id", ""))
    if not me.is_empty():
        player_hp = int(me.get("hp", player_hp))
        player_mana = int(me.get("mana", player_mana))
        player_gold = int(me.get("gold", player_gold))
        game_lane = str(me.get("lane", game_lane))
        if remote_game_mode and is_instance_valid(v38_player_model):
            var server_x := float(me.get("x", 640.0))
            var server_y := float(me.get("y", 360.0))
            var server_pos := v38_player_model.position
            server_pos.x = clampf(server_x / 1280.0 * 48.0 - 24.0, -23.0, 23.0)
            server_pos.z = clampf(server_y / 720.0 * 26.0 - 13.0, -13.0, 13.0)
            v38_player_model.position = server_pos
    var cores: Dictionary = state.get("cores", {})
    var my_team := str(me.get("team", "blue"))
    var enemy_team := "red" if my_team == "blue" else "blue"
    enemy_hp = int(cores.get(enemy_team, enemy_hp))
    var towers: Dictionary = state.get("towers", {})
    var enemy_towers: Dictionary = towers.get(enemy_team, {})
    enemy_tower_hp = int(enemy_towers.get(game_lane, enemy_tower_hp))
    modern_lobby_status.text = "MATCH %s • %d PLAYERS CONNECTED • %s" % [str(state.get("match_id", "")), players.size(), str(state.get("status", "running")).to_upper()]
    match_status.text = "REALTIME 5V5 • %s\nPlayers: %d / 10 • Core: %d\nTower[%s]: %d" % [my_team.to_upper(), players.size(), enemy_hp, game_lane.to_upper(), enemy_tower_hp]
    _refresh_battle_ui()
    if is_instance_valid(battle_ui): battle_ui.visible = true
    if is_instance_valid(v38_joystick_panel): v38_joystick_panel.visible = true
    if is_instance_valid(v38_exit_button): v38_exit_button.visible = true
    if remote_game_mode and str(state.get("status", "")) == "finished":
        var winner := str(state.get("winner", ""))
        var victory := winner == my_team
        _show_remote_result({"result": "win" if victory else "loss", "elapsed_seconds": match_seconds, "status": "finished", "player": me}, {})

func _start_match() -> void:
    _ensure_core_kernel()
    if data.cloud_account and core_kernel.network().configured() and not str(data.session_token).is_empty():
        remote_game_mode = true
        data.remote_game_mode = true
        hide_app_panels()
        match_panel.visible = true
        _ensure_battle_ui()
        if is_instance_valid(battle_ui): battle_ui.visible = true
        if is_instance_valid(v38_joystick_panel): v38_joystick_panel.visible = true
        if is_instance_valid(v38_exit_button): v38_exit_button.visible = true
        match_status.text = "CONNECTING TO AUTHORITATIVE GAME SERVER...\nServer akan membuat match state."
        match_timer.stop()
        core_kernel.network().start_game("Classic 5v5 AI", "Astra", game_lane)
        return
    _start_local_match()

func _start_local_match() -> void:
    remote_game_mode = false
    data.remote_game_mode = false
    hide_app_panels()
    match_panel.visible = true
    _ensure_v38_arena_visual()
    _ensure_battle_ui()
    battle_ui.visible = true
    if is_instance_valid(v38_joystick_panel): v38_joystick_panel.visible = true
    if is_instance_valid(v38_exit_button): v38_exit_button.visible = true
    player_hp = 100
    player_mana = 100
    enemy_hp = 350
    enemy_hero_hp = 180
    enemy_tower_hp = 160
    player_gold = 500
    match_seconds = 0
    skill1_cd = 0
    skill2_cd = 0
    ult_cd = 0
    game_lane = "mid"
    game_target = "enemy_hero"
    match_status.text = "%s • PRACTICE BATTLE\nDefeat enemy hero, destroy tower, then attack core." % selected_game_mode.to_upper()
    match_timer.start()
    _refresh_battle_ui()

func _on_match_tick() -> void:
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().game_state(active_match_id)
        return
    match_seconds += 1
    if skill1_cd > 0:
        skill1_cd -= 1
    if skill2_cd > 0:
        skill2_cd -= 1
    if ult_cd > 0:
        ult_cd -= 1
    if match_seconds % 5 == 0:
        player_hp = max(0, player_hp - 2)
        player_mana = min(100, player_mana + 8)
    if player_hp <= 0:
        _finish_battle(false)
        return
    match_status.text = "%s • %02d:%02d\nHERO %d • TOWER %d • CORE %d" % [selected_game_mode.to_upper(), match_seconds / 60, match_seconds % 60, enemy_hero_hp, enemy_tower_hp, enemy_hp]
    _refresh_battle_ui()

func _battle_attack() -> void:
    if not match_panel.visible:
        return
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().realtime_action(active_match_id, "basic_attack", game_target, game_lane, 0.0, 0.0, v34_target_user_id)
        return
    _v38_local_damage(15)
    player_mana = min(100, player_mana + 3)
    _after_action()

func _battle_skill1() -> void:
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().realtime_action(active_match_id, "skill1", game_target, game_lane, 0.0, 0.0, v34_target_user_id)
        return
    if skill1_cd > 0 or player_mana < 15:
        return
    skill1_cd = 5
    player_mana -= 15
    _v38_local_damage(30)
    _after_action()

func _battle_skill2() -> void:
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().realtime_action(active_match_id, "skill2", game_target, game_lane, 0.0, 0.0, v34_target_user_id)
        return
    if skill2_cd > 0 or player_mana < 20:
        return
    skill2_cd = 7
    player_mana -= 20
    _v38_local_damage(40)
    _after_action()

func _battle_ultimate() -> void:
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().realtime_action(active_match_id, "ultimate", game_target, game_lane, 0.0, 0.0, v34_target_user_id)
        return
    if ult_cd > 0 or player_mana < 35:
        return
    ult_cd = 14
    player_mana -= 35
    _v38_local_damage(60)
    _after_action()

func _battle_recall() -> void:
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().realtime_action(active_match_id, "recall", game_target, game_lane, 0.0, 0.0, v34_target_user_id)
        return
    player_hp = min(100, player_hp + 30)
    player_mana = min(100, player_mana + 40)
    _refresh_battle_ui()

func _after_action() -> void:
    if enemy_hp <= 0:
        _finish_battle(true)
        return
    _refresh_battle_ui()

func _finish_battle(victory: bool = true) -> void:
    match_timer.stop()
    data.matches = int(data.matches) + 1
    data.last_result = "Victory" if victory else "Defeat"
    if victory:
        data.wins = int(data.wins) + 1
        data.coins = int(data.coins) + 450
        data.xp = int(data.xp) + 120
        data.rank_points = int(data.rank_points) + 10
        if int(data.xp) >= 500:
            data.level = int(data.level) + 1
            data.xp = int(data.xp) - 500
    else:
        data.losses = int(data.losses) + 1
        data.xp = int(data.xp) + 50
    if first_match:
        data.tutorial_complete = true
    save_data()
    _ensure_core_kernel()
    if data.cloud_account and core_kernel.network().configured() and not str(data.session_token).is_empty():
        core_kernel.network().submit_match_result(victory, match_seconds)
    hide_app_panels()
    result_panel.visible = true
    var title: Label = result_panel.get_node("Panel/VBox/Title")
    var body: Label = result_panel.get_node("Panel/VBox/Body")
    title.text = "VICTORY" if victory else "DEFEAT"
    body.text = ("+450 Coins • +120 XP • +10 Rank • Match saved" if victory else "+50 XP • Match saved")

func _on_finish_match() -> void:
    if remote_game_mode:
        match_status.text = "MATCH DIKELOLA SERVER\nTidak ada hasil manual; server yang menentukan victory/defeat."
        return
    _finish_battle(true)

func _on_history() -> void:
    hide_app_panels()
    history_panel.visible = true
    var history: Label = $HistoryPanel/Panel/VBox/History
    history.text = "MATCH HISTORY\n\nLast result: %s\nMatches: %d\nWins: %d\nLosses: %d\nRank: %s\nXP: %d / 500\n\nData tersimpan lokal di perangkat." % [str(data.last_result), int(data.matches), int(data.wins), int(data.losses), str(data.rank), int(data.xp)]

func _on_back_to_lobby() -> void:
    match_timer.stop()
    if remote_game_mode and is_instance_valid(core_kernel):
        core_kernel.network().leave_matchmaking()
        core_kernel.network().disconnect_realtime()
    remote_game_mode = false
    data.remote_game_mode = false
    data.active_match_id = ""
    active_match_id = ""
    if is_instance_valid(v38_joystick_panel):
        v38_joystick_panel.visible = false
    if is_instance_valid(v38_exit_button):
        v38_exit_button.visible = false
    if is_instance_valid(battle_ui):
        battle_ui.visible = false
    save_data()
    show_lobby()

func _on_logout() -> void:
    _ensure_core_kernel()
    if data.cloud_account and not str(data.session_token).is_empty() and core_kernel.network().configured():
        core_kernel.network().leave_matchmaking()
        core_kernel.network().disconnect_realtime()
        core_kernel.network().logout_remote()
        core_kernel.network().clear_session()
    data.logged_in = false
    data.cloud_account = false
    data.session_token = ""
    data.cloud_user_id = -1
    data.active_match_id = ""
    data.remote_game_mode = false
    active_match_id = ""
    remote_game_mode = false
    save_data()
    hide_app_panels()
    _show_modern_login()




func _restyle_terms_panel() -> void:
    var artwork := load("res://assets/astro_royale_logo.png") as Texture2D
    if terms_panel.get_node_or_null("V33ArtBG") != null:
        return
    var art := TextureRect.new()
    art.name = "V33ArtBG"
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.texture = artwork
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.modulate = Color(0.52, 0.68, 0.94, 0.78)
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    terms_panel.add_child(art)
    terms_panel.move_child(art, 0)
    var veil := ColorRect.new()
    veil.name = "V33ArtVeil"
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.008, 0.018, 0.045, 0.72)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    terms_panel.add_child(veil)
    terms_panel.move_child(veil, 1)

func _restyle_legacy_screens(artwork: Texture2D) -> void:
    for panel in [profile_panel, tutorial_panel, screen_panel, match_panel, result_panel, history_panel]:
        if not is_instance_valid(panel):
            continue
        var key := "V33ArtBG"
        if panel.get_node_or_null(key) != null:
            continue
        var art := TextureRect.new()
        art.name = key
        art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        art.texture = artwork
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.modulate = Color(0.55, 0.67, 0.9, 0.72)
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(art)
        panel.move_child(art, 0)
        var veil := ColorRect.new()
        veil.name = "V33ArtVeil"
        veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        veil.color = Color(0.008, 0.018, 0.045, 0.68)
        veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(veil)
        panel.move_child(veil, 1)

func _show_modern_login() -> void:
    if not is_instance_valid(modern_login_root):
        return
    hide_app_panels()
    modern_login_root.visible = true
    modern_login_username.text = ""
    modern_login_password.text = ""
    modern_login_status.text = ""
    if not str(data.backend_url).is_empty():
        modern_backend_url.text = str(data.backend_url)

func _build_v33_ui() -> void:
    if is_instance_valid(modern_login_root):
        return
    var artwork := load("res://assets/astro_royale_logo.png") as Texture2D
    modern_login_root = _modern_root("V33Login")
    add_child(modern_login_root)
    _build_modern_login(modern_login_root, artwork)
    oauth_poll_timer = Timer.new()
    oauth_poll_timer.name = "OAuthPollTimer"
    oauth_poll_timer.wait_time = 2.0
    oauth_poll_timer.one_shot = false
    oauth_poll_timer.timeout.connect(_poll_oauth)
    add_child(oauth_poll_timer)
    modern_lobby_root = _modern_root("V33Lobby")
    add_child(modern_lobby_root)
    _build_modern_lobby(modern_lobby_root, artwork)
    _restyle_legacy_screens(artwork)
    modern_login_root.visible = false
    modern_lobby_root.visible = false

func _modern_root(root_name: String) -> Control:
    var root := Control.new()
    root.name = root_name
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    return root

func _make_image_background(parent: Control, artwork: Texture2D, dark_alpha: float = 0.48) -> void:
    var bg := TextureRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.texture = artwork
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.modulate = Color(0.72, 0.82, 1.0, 1.0)
    parent.add_child(bg)
    var overlay := ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.01, 0.025, 0.06, dark_alpha)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(overlay)

func _build_modern_login(root: Control, artwork: Texture2D) -> void:
    _make_image_background(root, artwork, 0.55)
    var side := ColorRect.new()
    side.position = Vector2(0, 0)
    side.size = Vector2(520, 720)
    side.color = Color(0.012, 0.025, 0.055, 0.86)
    root.add_child(side)

    var title := Label.new()
    title.position = Vector2(56, 30)
    title.size = Vector2(420, 54)
    title.text = "ASTRO ROYALE"
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color(0.72, 0.93, 1.0, 1.0))
    root.add_child(title)
    var sub := Label.new()
    sub.position = Vector2(58, 84)
    sub.size = Vector2(400, 32)
    sub.text = "REAL ACCOUNT • REAL ENGINE • REAL MATCH STATE"
    sub.add_theme_font_size_override("font_size", 13)
    sub.add_theme_color_override("font_color", Color(0.58, 0.68, 0.8, 1.0))
    root.add_child(sub)

    var card := PanelContainer.new()
    card.position = Vector2(38, 120)
    card.size = Vector2(450, 580)
    card.add_theme_stylebox_override("panel", _v33_style(Color(0.025, 0.055, 0.11, 0.88), 16, Color(0.35, 0.86, 1.0, 0.22)))
    root.add_child(card)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    card.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    margin.add_child(box)

    var heading := Label.new()
    heading.text = "MASUK KE ASTRO ROYALE"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 24)
    box.add_child(heading)
    var hint := Label.new()
    hint.text = "Login/register dibuat tidak bergantung pada koneksi cloud.\nCloud akan disinkronkan setelah akun aktif."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 11)
    hint.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78, 1))
    box.add_child(hint)

    modern_login_username = LineEdit.new()
    modern_login_username.placeholder_text = "Username"
    modern_login_username.custom_minimum_size.y = 44
    box.add_child(modern_login_username)
    modern_login_password = LineEdit.new()
    modern_login_password.placeholder_text = "Password"
    modern_login_password.secret = true
    modern_login_password.custom_minimum_size.y = 44
    box.add_child(modern_login_password)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    box.add_child(actions)
    var login := _v33_button("MASUK", 196, 48)
    login.pressed.connect(_on_login)
    actions.add_child(login)
    var register := _v33_button("DAFTAR", 196, 48)
    register.pressed.connect(_on_register)
    actions.add_child(register)
    var guest := _v33_button("LANJUT SEBAGAI TAMU", 414, 40)
    guest.pressed.connect(_on_guest)
    box.add_child(guest)

    var sep := Label.new()
    sep.text = "────────  LOGIN DENGAN  ────────"
    sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sep.add_theme_color_override("font_color", Color(0.4, 0.52, 0.67, 1))
    box.add_child(sep)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    box.add_child(grid)
    for item in [["G  Google", "google"], ["f  Facebook", "facebook"], ["▶  Google Play Games", "google_play"], ["◉  WhatsApp", "whatsapp"]]:
        var b := _v33_button(str(item[0]), 205, 38)
        b.pressed.connect(_on_provider_login.bind(str(item[1])))
        grid.add_child(b)

    modern_backend_url = LineEdit.new()
    modern_backend_url.placeholder_text = "Cloud server URL (opsional)"
    modern_backend_url.text = str(data.backend_url)
    modern_backend_url.custom_minimum_size.y = 34
    box.add_child(modern_backend_url)
    var cloud_row := HBoxContainer.new()
    cloud_row.add_theme_constant_override("separation", 8)
    box.add_child(cloud_row)
    var save_server := _v33_button("SIMPAN SERVER", 199, 34)
    save_server.pressed.connect(_on_modern_save_server)
    cloud_row.add_child(save_server)
    var reset := _v33_button("RESET SESI", 199, 34)
    reset.pressed.connect(_on_reset_local_session)
    cloud_row.add_child(reset)
    modern_login_status = Label.new()
    modern_login_status.custom_minimum_size.y = 32
    modern_login_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    modern_login_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    modern_login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modern_login_status.add_theme_font_size_override("font_size", 12)
    box.add_child(modern_login_status)

    username_edit = modern_login_username
    password_edit = modern_login_password
    login_status = modern_login_status

    var note := Label.new()
    note.position = Vector2(560, 600)
    note.size = Vector2(650, 58)
    note.text = "Google/Facebook/WhatsApp menjadi login cloud sungguhan setelah provider credential + callback server dikonfigurasi. Google Play Games membutuhkan Android Play Games plugin/signing."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    note.add_theme_font_size_override("font_size", 12)
    note.add_theme_color_override("font_color", Color(0.8, 0.87, 0.96, 0.85))
    root.add_child(note)

func _build_modern_lobby(root: Control, artwork: Texture2D) -> void:
    _make_image_background(root, artwork, 0.46)
    var shade := ColorRect.new()
    shade.position = Vector2(0, 0)
    shade.size = Vector2(1280, 720)
    shade.color = Color(0.015, 0.035, 0.08, 0.42)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)

    var top := ColorRect.new()
    top.position = Vector2(0, 0)
    top.size = Vector2(1280, 78)
    top.color = Color(0.01, 0.025, 0.055, 0.84)
    root.add_child(top)
    var avatar := TextureRect.new()
    avatar.position = Vector2(18, 10)
    avatar.size = Vector2(56, 56)
    avatar.texture = artwork
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    root.add_child(avatar)
    modern_lobby_user = Label.new()
    modern_lobby_user.position = Vector2(88, 10)
    modern_lobby_user.size = Vector2(340, 28)
    modern_lobby_user.add_theme_font_size_override("font_size", 20)
    root.add_child(modern_lobby_user)
    modern_lobby_rank = Label.new()
    modern_lobby_rank.position = Vector2(88, 40)
    modern_lobby_rank.size = Vector2(340, 24)
    modern_lobby_rank.add_theme_font_size_override("font_size", 13)
    modern_lobby_rank.add_theme_color_override("font_color", Color(1, 0.84, 0.42, 1))
    root.add_child(modern_lobby_rank)
    modern_lobby_wallet = Label.new()
    modern_lobby_wallet.position = Vector2(860, 14)
    modern_lobby_wallet.size = Vector2(250, 28)
    modern_lobby_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    modern_lobby_wallet.add_theme_font_size_override("font_size", 17)
    root.add_child(modern_lobby_wallet)
    modern_lobby_network = Label.new()
    modern_lobby_network.position = Vector2(1110, 16)
    modern_lobby_network.size = Vector2(150, 24)
    modern_lobby_network.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    modern_lobby_network.add_theme_font_size_override("font_size", 12)
    modern_lobby_network.add_theme_color_override("font_color", Color(0.4, 1.0, 0.76, 1))
    root.add_child(modern_lobby_network)

    var left_scroll := ScrollContainer.new()
    left_scroll.name = "LobbySystemNavigation"
    left_scroll.position = Vector2(16, 104)
    left_scroll.size = Vector2(178, 528)
    left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(left_scroll)
    var left := VBoxContainer.new()
    left.name = "LobbySystemNavigationItems"
    left.add_theme_constant_override("separation", 4)
    left.custom_minimum_size.x = 172
    left_scroll.add_child(left)
    var menu_items := [
        ["DAILY / EVENTS", "events"], ["MISSIONS", "quests"], ["HERO GALLERY", "heroes"],
        ["HERO LOADOUT", "hero_loadout"], ["RANKED", "rank"], ["LEADERBOARD", "leaderboard"],
        ["SHOP", "shop"], ["INVENTORY", "inventory"], ["STARFALL PASS", "battle_pass"],
        ["FRIENDS / PARTY", "social"], ["MAIL / NEWS", "mail"], ["REPLAY CENTER", "replay"],
        ["CONTROLS", "controls"], ["GRAPHICS / FPS", "graphics"], ["AUDIO", "audio"],
        ["ACCOUNT CENTER", "account_center"], ["PRIVACY / SECURITY", "privacy"],
        ["APP PERMISSIONS", "permissions"], ["SYSTEM MONITOR", "system_monitor"], ["SETTINGS", "settings"]
    ]
    for item in menu_items:
        var b := _v33_button(str(item[0]), 166, 36)
        b.pressed.connect(Callable(self, "_open_generic_screen").bind(str(item[1])))
        left.add_child(b)

    var center_title := Label.new()
    center_title.position = Vector2(420, 100)
    center_title.size = Vector2(430, 44)
    center_title.text = "STARFALL FRONTIER"
    center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center_title.add_theme_font_size_override("font_size", 28)
    center_title.add_theme_color_override("font_color", Color(0.78, 0.93, 1, 1))
    root.add_child(center_title)
    var hero := TextureRect.new()
    hero.position = Vector2(340, 125)
    hero.size = Vector2(560, 490)
    hero.texture = artwork
    hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    hero.modulate = Color(1, 1, 1, 0.92)
    root.add_child(hero)
    var glow := ColorRect.new()
    glow.position = Vector2(300, 515)
    glow.size = Vector2(640, 90)
    glow.color = Color(0.02, 0.06, 0.12, 0.78)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(glow)
    modern_lobby_status = Label.new()
    modern_lobby_status.position = Vector2(320, 535)
    modern_lobby_status.size = Vector2(600, 28)
    modern_lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    modern_lobby_status.add_theme_font_size_override("font_size", 14)
    root.add_child(modern_lobby_status)

    var mode_card := PanelContainer.new()
    mode_card.position = Vector2(930, 160)
    mode_card.size = Vector2(300, 286)
    mode_card.add_theme_stylebox_override("panel", _v33_style(Color(0.018, 0.05, 0.095, 0.88), 18, Color(1, 0.82, 0.35, 0.34)))
    root.add_child(mode_card)
    var mb := VBoxContainer.new()
    mb.add_theme_constant_override("separation", 10)
    mode_card.add_child(mb)
    var mode := Label.new()
    mode.text = "CLASSIC 5V5"
    mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode.add_theme_font_size_override("font_size", 28)
    mb.add_child(mode)
    var mode_info := Label.new()
    mode_info.text = "3 LANE  •  RIVER  •  JUNGLE\nSERVER-AUTHORITATIVE STATE"
    mode_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_info.add_theme_font_size_override("font_size", 13)
    mode_info.add_theme_color_override("font_color", Color(0.63, 0.73, 0.86, 1))
    mb.add_child(mode_info)
    modern_play_button = _v33_button("PILIH MODE", 260, 58)
    modern_play_button.pressed.connect(_open_v38_mode_select)
    mb.add_child(modern_play_button)
    var history_btn := _v33_button("MATCH HISTORY", 260, 44)
    history_btn.pressed.connect(_on_history)
    mb.add_child(history_btn)
    var logout := _v33_button("LOG OUT", 260, 42)
    logout.pressed.connect(_on_logout)
    mb.add_child(logout)

    var bottom := ColorRect.new()
    bottom.position = Vector2(0, 650)
    bottom.size = Vector2(1280, 70)
    bottom.color = Color(0.01, 0.025, 0.055, 0.88)
    root.add_child(bottom)
    var nav := HBoxContainer.new()
    nav.position = Vector2(30, 660)
    nav.size = Vector2(1220, 50)
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    nav.add_theme_constant_override("separation", 10)
    root.add_child(nav)
    for item in [["HOME", "core"], ["HEROES", "heroes"], ["BATTLE", "rank"], ["INVENTORY", "inventory"], ["SHOP", "shop"], ["EVENT", "events"], ["SOCIAL", "social"]]:
        var b := _v33_button(str(item[0]), 155, 42)
        b.pressed.connect(Callable(self, "_open_generic_screen").bind(str(item[1])))
        nav.add_child(b)

func _v33_button(text_value: String, width_value: float, height_value: float) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size = Vector2(width_value, height_value)
    b.add_theme_font_size_override("font_size", 14)
    b.add_theme_stylebox_override("normal", _v33_style(Color(0.035, 0.09, 0.16, 0.86), 10, Color(0.35, 0.86, 1.0, 0.18)))
    b.add_theme_stylebox_override("hover", _v33_style(Color(0.07, 0.15, 0.24, 0.96), 10, Color(1, 0.84, 0.35, 0.45)))
    b.add_theme_stylebox_override("pressed", _v33_style(Color(0.1, 0.19, 0.3, 0.98), 10, Color(0.42, 0.95, 1.0, 0.65)))
    return b

func _v33_style(color_value: Color, radius: int = 12, border_color_value: Color = Color(0.35, 0.86, 1.0, 0.25)) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color_value
    s.border_width_left = 1
    s.border_width_top = 1
    s.border_width_right = 1
    s.border_width_bottom = 1
    s.border_color = border_color_value
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    s.content_margin_left = 12
    s.content_margin_right = 12
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _on_modern_save_server() -> void:
    _ensure_core_kernel()
    core_kernel.network().configure_url(modern_backend_url.text)
    if core_kernel.network().configured():
        modern_login_status.text = "Cloud server tersimpan."
        core_kernel.network().get_health()
    else:
        modern_login_status.text = "Backend URL dikosongkan — LOCAL MODE aktif."

func _on_reset_local_session() -> void:
    data.logged_in = false
    data.cloud_account = false
    data.session_token = ""
    data.cloud_user_id = -1
    data.active_match_id = ""
    data.remote_game_mode = false
    data.username = ""
    data.password_hash = ""
    data.profile_complete = false
    data.tutorial_complete = false
    save_data()
    _show_modern_login()
    modern_login_status.text = "Sesi lokal direset."

func _on_provider_login(provider: String) -> void:
    _ensure_core_kernel()
    if provider == "google_play":
        if Engine.has_singleton("PlayGames"):
            var play_games = Engine.get_singleton("PlayGames")
            if play_games.has_method("sign_in"):
                play_games.sign_in()
                modern_login_status.text = "Google Play Games sign-in dimulai..."
            else:
                modern_login_status.text = "Plugin Play Games ditemukan tetapi API sign_in belum tersedia."
        else:
            modern_login_status.text = "Google Play Games membutuhkan Android Play Games plugin + OAuth project. Hook native V33 sudah siap."
        return
    if provider == "whatsapp":
        modern_login_status.text = "WhatsApp memakai alur OTP Business API. Backend harus dikonfigurasi dengan token, phone number ID, dan OTP template."
        return
    if not core_kernel.network().configured():
        modern_login_status.text = "%s login membutuhkan Cloud Backend. Isi Cloud server URL terlebih dahulu." % provider.capitalize()
        return
    oauth_provider = provider
    randomize()
    oauth_nonce = (str(Time.get_unix_time_from_system()).replace(".", "") + str(randi()))
    modern_login_status.text = "Menyiapkan %s login..." % provider.capitalize()
    core_kernel.network().oauth_start(provider, oauth_nonce)

func _poll_oauth() -> void:
    if oauth_provider.is_empty() or oauth_nonce.is_empty():
        if is_instance_valid(oauth_poll_timer):
            oauth_poll_timer.stop()
        return
    if not is_instance_valid(core_kernel):
        _ensure_core_kernel()
    core_kernel.network().oauth_poll(oauth_provider, oauth_nonce)

func _build_extended_ui() -> void:
    if is_instance_valid(extended_root):
        return
    extended_root = Control.new()
    extended_root.name = "ExtendedUI"
    extended_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    $LobbyPanel.add_child(extended_root)
    _build_lobby_nav()
    _build_profile_panel()
    _build_tutorial_panel()
    _build_generic_screen()
    _ensure_battle_ui()

func _build_lobby_nav() -> void:
    var nav := HBoxContainer.new()
    nav.name = "Nav"
    nav.position = Vector2(56, 610)
    nav.size = Vector2(1168, 56)
    nav.add_theme_constant_override("separation", 8)
    extended_root.add_child(nav)
    var items := [
        ["HEROES", "heroes"], ["RANK", "rank"], ["SHOP", "shop"], ["INVENTORY", "inventory"],
        ["EVENTS", "events"], ["MAIL", "mail"], ["SOCIAL", "social"], ["QUESTS", "quests"],
        ["SETTINGS", "settings"], ["SYSTEM CORE", "core"], ["SYSTEM MONITOR", "system_monitor"]
    ]
    for item in items:
        var b := Button.new()
        b.text = str(item[0])
        b.custom_minimum_size = Vector2(120, 48)
        b.pressed.connect(Callable(self, "_open_generic_screen").bind(str(item[1])))
        nav.add_child(b)

func _build_profile_panel() -> void:
    profile_panel = _make_full_panel("ProfileSetup")
    add_child(profile_panel)
    var card := PanelContainer.new()
    card.name = "Card"
    card.position = Vector2(250, 80)
    card.size = Vector2(780, 560)
    card.add_theme_stylebox_override("panel", _make_style(Color(0.047, 0.106, 0.18, 0.98)))
    profile_panel.add_child(card)
    var body := VBoxContainer.new()
    body.name = "Body"
    body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    body.add_theme_constant_override("separation", 14)
    card.add_child(body)
    _add_title(body, "CREATE YOUR PROFILE", 34)
    var info := Label.new()
    info.text = "Siapkan identitas pemain sebelum masuk tutorial pertama."
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_child(info)
    var username := LineEdit.new()
    username.name = "Username"
    username.placeholder_text = "Nama pengguna"
    username.custom_minimum_size.y = 52
    body.add_child(username)
    body.add_child(_make_label("BAHASA"))
    var language := OptionButton.new()
    language.name = "Language"
    for v in ["Bahasa Indonesia", "English", "Malay"]:
        language.add_item(v)
    body.add_child(language)
    body.add_child(_make_label("NEGARA"))
    var country := OptionButton.new()
    country.name = "Country"
    for v in ["Indonesia", "Malaysia", "Singapore", "Thailand", "Philippines"]:
        country.add_item(v)
    body.add_child(country)
    body.add_child(_make_label("SERVER"))
    var server := OptionButton.new()
    server.name = "Server"
    for v in ["Asia Tenggara", "Asia Timur", "Asia Selatan"]:
        server.add_item(v)
    body.add_child(server)
    var status := Label.new()
    status.name = "Status"
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_child(status)
    var cont := Button.new()
    cont.text = "SIMPAN & LANJUTKAN"
    cont.custom_minimum_size.y = 54
    cont.pressed.connect(_on_profile_continue)
    body.add_child(cont)
    profile_panel.visible = false

func _build_tutorial_panel() -> void:
    tutorial_panel = _make_full_panel("Tutorial")
    add_child(tutorial_panel)
    var card := PanelContainer.new()
    card.name = "Card"
    card.position = Vector2(220, 70)
    card.size = Vector2(840, 580)
    card.add_theme_stylebox_override("panel", _make_style(Color(0.047, 0.106, 0.18, 0.98)))
    tutorial_panel.add_child(card)
    var body := VBoxContainer.new()
    body.name = "Body"
    body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    body.add_theme_constant_override("separation", 18)
    card.add_child(body)
    _add_title(body, "FIRST BATTLE TRAINING", 34)
    var step := Label.new()
    step.name = "Step"
    step.custom_minimum_size.y = 300
    step.add_theme_font_size_override("font_size", 20)
    step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body.add_child(step)
    var start := Button.new()
    start.text = "MULAI 5V5 PERTAMA"
    start.custom_minimum_size.y = 58
    start.pressed.connect(_on_start_tutorial_match)
    body.add_child(start)
    var skip := Button.new()
    skip.text = "LANJUT KE LOBBY"
    skip.pressed.connect(_on_tutorial_skip)
    body.add_child(skip)
    tutorial_panel.visible = false

func _on_tutorial_skip() -> void:
    data.tutorial_complete = true
    save_data()
    show_lobby()

func _build_generic_screen() -> void:
    screen_panel = _make_full_panel("GenericScreen")
    add_child(screen_panel)
    var card := PanelContainer.new()
    card.position = Vector2(130, 35)
    card.size = Vector2(1020, 650)
    card.add_theme_stylebox_override("panel", _make_style(Color(0.047, 0.106, 0.18, 0.98)))
    screen_panel.add_child(card)
    var body := VBoxContainer.new()
    body.name = "Body"
    body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    body.add_theme_constant_override("separation", 14)
    card.add_child(body)
    var title := Label.new()
    title.name = "Title"
    title.add_theme_font_size_override("font_size", 38)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_child(title)
    screen_body = body
    var cloud_sync := Button.new()
    cloud_sync.name = "CloudSync"
    cloud_sync.text = "SYNC DATA CLOUD"
    cloud_sync.custom_minimum_size.y = 50
    cloud_sync.pressed.connect(_on_sync_cloud)
    body.add_child(cloud_sync)
    var back := Button.new()
    back.name = "Back"
    back.text = "KEMBALI KE LOBBY"
    back.custom_minimum_size.y = 56
    back.pressed.connect(_on_back_to_lobby)
    body.add_child(back)
    screen_panel.visible = false

func _open_generic_screen(which: String) -> void:
    hide_app_panels()
    screen_panel.visible = true
    var title: Label = screen_body.get_node("Title")
    title.text = "APP ACTIVITY CONTROLS" if which == "app_activity" else which.replace("_", " ").to_upper()
    # Remove only dynamic content; keep the title, Cloud Sync, and Back buttons.
    for child in screen_body.get_children():
        if child.name not in ["Title", "CloudSync", "Back"]:
            screen_body.remove_child(child)
            child.queue_free()
    permission_buttons.clear()
    permission_status_label = null
    var cloud_sync := screen_body.get_node("CloudSync") as Button
    cloud_sync.visible = which in ["settings", "core"]
    if which == "permissions":
        _build_permissions_screen()
        return
    if which == "app_activity":
        _build_unused_app_guide()
        return
    var content := Label.new()
    content.name = "ScreenContent"
    content.add_theme_font_size_override("font_size", 22)
    content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.text = _generic_content(which)
    screen_body.add_child(content)
    screen_body.move_child(content, cloud_sync.get_index())
    if which in ["graphics", "audio", "controls", "heroes", "hero_loadout", "shop", "events", "quests", "privacy"]:
        _build_v37_screen_actions(which)
    if which == "settings":
        var endpoint := LineEdit.new()
        endpoint.name = "BackendURL"
        endpoint.placeholder_text = "Backend URL, contoh https://server.example"
        endpoint.text = str(data.backend_url)
        endpoint.custom_minimum_size.y = 48
        screen_body.add_child(endpoint)
        screen_body.move_child(endpoint, cloud_sync.get_index())
        var save_endpoint := Button.new()
        save_endpoint.name = "SaveBackendURL"
        save_endpoint.text = "SIMPAN BACKEND URL"
        save_endpoint.custom_minimum_size.y = 48
        save_endpoint.pressed.connect(_on_save_backend_url)
        screen_body.add_child(save_endpoint)
        screen_body.move_child(save_endpoint, cloud_sync.get_index())
        var permission_link := Button.new()
        permission_link.name = "OpenPermissions"
        permission_link.text = "KELOLA IZIN PERANGKAT"
        permission_link.custom_minimum_size.y = 44
        permission_link.pressed.connect(Callable(self, "_open_generic_screen").bind("permissions"))
        screen_body.add_child(permission_link)
        screen_body.move_child(permission_link, cloud_sync.get_index())

func _build_v37_screen_actions(which: String) -> void:
    if which == "graphics":
        var quality := OptionButton.new()
        quality.name = "GraphicsQuality"
        quality.custom_minimum_size.y = 42
        for value in ["Low", "Medium", "High"]:
            quality.add_item(value)
        quality.select(max(0, ["Low", "Medium", "High"].find(str(data.graphics_quality))))
        quality.item_selected.connect(func(index: int):
            data.graphics_quality = quality.get_item_text(index)
            save_data()
        )
        screen_body.add_child(quality)
        var fps := OptionButton.new()
        fps.name = "FPSCap"
        fps.custom_minimum_size.y = 42
        for value in [30, 60, 90, 120]:
            fps.add_item("%d FPS" % value)
        var fps_values := [30, 60, 90, 120]
        fps.select(max(0, fps_values.find(int(data.render_fps))))
        fps.item_selected.connect(func(index: int):
            data.render_fps = fps_values[index]
            Engine.max_fps = int(data.render_fps)
            save_data()
        )
        screen_body.add_child(fps)
    elif which == "audio":
        var label := Label.new()
        label.text = "MASTER VOLUME"
        screen_body.add_child(label)
        var volume := HSlider.new()
        volume.name = "MasterVolume"
        volume.min_value = 0.0
        volume.max_value = 1.0
        volume.step = 0.05
        volume.value = clampf(float(data.master_volume), 0.0, 1.0)
        volume.custom_minimum_size.y = 38
        volume.value_changed.connect(func(value: float):
            data.master_volume = value
            if AudioServer.bus_count > 0:
                AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))
                AudioServer.set_bus_mute(0, value <= 0.001)
            save_data()
        )
        screen_body.add_child(volume)
    elif which == "controls":
        var layout := OptionButton.new()
        layout.name = "ControlLayout"
        layout.custom_minimum_size.y = 42
        for value in ["Classic", "Fixed", "Floating"]:
            layout.add_item(value)
        layout.select(max(0, ["Classic", "Fixed", "Floating"].find(str(data.control_layout))))
        layout.item_selected.connect(func(index: int):
            data.control_layout = layout.get_item_text(index)
            save_data()
        )
        screen_body.add_child(layout)
        var handed := CheckBox.new()
        handed.text = "LEFT-HANDED PREFERENCE"
        handed.button_pressed = bool(data.left_handed_controls)
        handed.toggled.connect(func(value: bool):
            data.left_handed_controls = value
            save_data()
        )
        screen_body.add_child(handed)
        var vibration := CheckBox.new()
        vibration.text = "HAPTIC / VIBRATION PREFERENCE"
        vibration.button_pressed = bool(data.vibration_enabled)
        vibration.toggled.connect(func(value: bool):
            data.vibration_enabled = value
            save_data()
        )
        screen_body.add_child(vibration)
    elif which in ["heroes", "hero_loadout"]:
        var pick := OptionButton.new()
        pick.name = "SelectedHero"
        pick.custom_minimum_size.y = 42
        for value in ["Astra", "Brutus", "Nyx", "Rook", "Lyra", "Nova"]:
            pick.add_item(value)
        pick.select(max(0, ["Astra", "Brutus", "Nyx", "Rook", "Lyra", "Nova"].find(str(data.selected_hero))))
        screen_body.add_child(pick)
        var equip := Button.new()
        equip.text = "TETAPKAN HERO"
        equip.custom_minimum_size.y = 42
        equip.pressed.connect(func():
            data.selected_hero = pick.get_item_text(pick.selected)
            save_data()
            content_refresh_lobby()
            _open_generic_screen(which)
        )
        screen_body.add_child(equip)
    elif which == "shop":
        for item in [{"name":"Iron Blade", "cost":500}, {"name":"Vital Core", "cost":650}, {"name":"Swift Boots", "cost":700}, {"name":"Arcane Orb", "cost":800}]:
            var item_button := Button.new()
            item_button.text = "BELI %s • %d COINS" % [str(item.name), int(item.cost)]
            item_button.custom_minimum_size.y = 38
            item_button.pressed.connect(Callable(self, "_purchase_v37_item").bind(str(item.name), int(item.cost)))
            screen_body.add_child(item_button)
    elif which in ["events", "quests"]:
        var claim := Button.new()
        claim.name = "ClaimDailyReward"
        claim.text = "CLAIM DAILY REWARD • 300 COINS + 50 XP"
        claim.custom_minimum_size.y = 44
        claim.pressed.connect(_claim_v37_daily_reward)
        screen_body.add_child(claim)
        var claimed_today := str(data.get("daily_claim_date", "")) == Time.get_date_string_from_system()
        claim.disabled = claimed_today
        if claimed_today:
            claim.text = "DAILY REWARD SUDAH DIKLAIM HARI INI"
    elif which == "privacy":
        var privacy := OptionButton.new()
        privacy.name = "PrivacyMode"
        privacy.custom_minimum_size.y = 42
        for value in ["Everyone", "Friends", "Private"]:
            privacy.add_item(value)
        privacy.select(max(0, ["Everyone", "Friends", "Private"].find(str(data.privacy_mode))))
        privacy.item_selected.connect(func(index: int):
            data.privacy_mode = privacy.get_item_text(index)
            save_data()
        )
        screen_body.add_child(privacy)

func content_refresh_lobby() -> void:
    if is_instance_valid(modern_lobby_root) and modern_lobby_root.visible:
        modern_lobby_status.text = "CLASSIC 5V5 • HERO %s • %s" % [str(data.selected_hero).to_upper(), "CLOUD" if data.cloud_account else "LOCAL / BOT"]

func _purchase_v37_item(item_name: String, cost: int) -> void:
    var inventory: Array = data.get("inventory_items", [])
    if inventory.has(item_name):
        _set_screen_feedback("Item %s sudah ada di inventory." % item_name)
        return
    if int(data.coins) < cost:
        _set_screen_feedback("Coins tidak cukup untuk %s." % item_name)
        return
    data.coins = int(data.coins) - cost
    inventory.append(item_name)
    data.inventory_items = inventory
    save_data()
    _set_screen_feedback("Pembelian berhasil: %s. Sisa %d Coins." % [item_name, int(data.coins)])
    if is_instance_valid(modern_lobby_wallet):
        modern_lobby_wallet.text = "🪙 %d    💎 %d" % [int(data.coins), int(data.diamonds)]

func _claim_v37_daily_reward() -> void:
    var today := Time.get_date_string_from_system()
    if str(data.get("daily_claim_date", "")) == today:
        _set_screen_feedback("Daily reward sudah diklaim hari ini.")
        return
    data.daily_claim_date = today
    data.coins = int(data.coins) + 300
    data.xp = int(data.xp) + 50
    save_data()
    _set_screen_feedback("Daily reward berhasil diklaim: +300 Coins, +50 XP.")
    if is_instance_valid(modern_lobby_wallet):
        modern_lobby_wallet.text = "🪙 %d    💎 %d" % [int(data.coins), int(data.diamonds)]

func _set_screen_feedback(message: String) -> void:
    var feedback := screen_body.get_node_or_null("V37ActionFeedback") as Label
    if feedback == null:
        feedback = Label.new()
        feedback.name = "V37ActionFeedback"
        feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        feedback.add_theme_color_override("font_color", Color(0.55, 1.0, 0.8, 1))
        screen_body.add_child(feedback)
    feedback.text = message

func _build_permissions_screen() -> void:
    var intro := Label.new()
    intro.name = "PermissionIntro"
    intro.text = "PUSAT IZIN PERANGKAT • V38\nSemua izin bersifat opsional dan diminta satu per satu. Tolak izin yang tidak ingin kamu berikan; permainan dasar tetap dapat berjalan."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.add_theme_font_size_override("font_size", 14)
    intro.custom_minimum_size.y = 48
    screen_body.add_child(intro)
    screen_body.move_child(intro, screen_body.get_node("CloudSync").get_index())

    var scroll := ScrollContainer.new()
    scroll.name = "PermissionScroll"
    scroll.custom_minimum_size = Vector2(0, 300)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    screen_body.add_child(scroll)
    screen_body.move_child(scroll, screen_body.get_node("CloudSync").get_index())

    var grid := GridContainer.new()
    grid.name = "PermissionGrid"
    grid.columns = 3
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    scroll.add_child(grid)

    for row in APP_PERMISSION_ROWS:
        var permission_name := str(row.permission)
        var display_name := str(row.label)
        var button := Button.new()
        button.custom_minimum_size = Vector2(305, 54)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.pressed.connect(Callable(self, "_request_app_permission").bind(permission_name, display_name))
        grid.add_child(button)
        permission_buttons[permission_name] = button
        button.set_meta("permission_label", display_name)

    permission_status_label = Label.new()
    permission_status_label.name = "PermissionStatus"
    permission_status_label.text = "Pilih izin tertentu atau perbarui status. Tidak ada izin yang diminta otomatis ketika aplikasi dibuka."
    permission_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    permission_status_label.custom_minimum_size.y = 26
    permission_status_label.add_theme_font_size_override("font_size", 13)
    screen_body.add_child(permission_status_label)
    screen_body.move_child(permission_status_label, screen_body.get_node("CloudSync").get_index())

    var actions := HBoxContainer.new()
    actions.name = "PermissionActions"
    actions.add_theme_constant_override("separation", 8)
    screen_body.add_child(actions)
    screen_body.move_child(actions, screen_body.get_node("CloudSync").get_index())
    var refresh := Button.new()
    refresh.text = "PERBARUI STATUS IZIN"
    refresh.custom_minimum_size = Vector2(300, 42)
    refresh.pressed.connect(_refresh_permission_buttons)
    actions.add_child(refresh)
    var unused := Button.new()
    unused.text = "APLIKASI JIKA TIDAK DIGUNAKAN"
    unused.custom_minimum_size = Vector2(380, 42)
    unused.pressed.connect(Callable(self, "_open_generic_screen").bind("app_activity"))
    actions.add_child(unused)
    _refresh_permission_buttons()

func _permission_status(permission_name: String) -> String:
    if OS.get_name() != "Android":
        return "ANDROID SAJA"
    return "IZIN AKTIF" if OS.get_granted_permissions().has(permission_name) else "BELUM DIIZINKAN"

func _refresh_permission_buttons() -> void:
    for permission_name in permission_buttons.keys():
        var button := permission_buttons[permission_name] as Button
        if is_instance_valid(button):
            button.text = "%s\n%s" % [str(button.get_meta("permission_label", permission_name)), _permission_status(str(permission_name))]
    if is_instance_valid(permission_status_label):
        permission_status_label.text = "Status perangkat diperbarui. Izin ditolak tidak menghalangi permainan dasar; fitur terkait saja yang tidak aktif."

func _request_app_permission(permission_name: String, display_name: String) -> void:
    if OS.get_name() != "Android":
        if is_instance_valid(permission_status_label):
            permission_status_label.text = "Dialog izin asli hanya tersedia pada APK Android."
        return
    if OS.get_granted_permissions().has(permission_name):
        if is_instance_valid(permission_status_label):
            permission_status_label.text = "%s sudah diizinkan." % display_name
        _refresh_permission_buttons()
        return
    # Request only the permission the player tapped, not every declared permission.
    OS.request_permission(permission_name)
    if is_instance_valid(permission_status_label):
        permission_status_label.text = "Permintaan %s dikirim ke Android. Selesaikan dialog sistem, lalu tekan PERBARUI STATUS IZIN." % display_name

func _build_unused_app_guide() -> void:
    var guide := Label.new()
    guide.name = "UnusedAppGuide"
    guide.text = "KONTROL APLIKASI TIDAK DIGUNAKAN\n\nAndroid mengelola fitur 'Jeda aktivitas aplikasi jika tidak digunakan' dan reset izin otomatis. Ini bukan permission biasa dan Astro Royale tidak dapat mengubahnya diam-diam.\n\nUntuk mengatur manual: Setelan Android → Aplikasi → Astro Royale → jeda aktivitas aplikasi jika tidak digunakan / hapus izin jika tidak digunakan. Nama menu dapat berbeda menurut versi Android dan merek HP.\n\nJika aktif, Android dapat mencabut izin sensitif dan membatasi aktivitas/notifikasi latar belakang. Kamu tetap bisa membuka game kembali dan memberikan izin lagi."
    guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    guide.add_theme_font_size_override("font_size", 20)
    guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
    screen_body.add_child(guide)
    screen_body.move_child(guide, screen_body.get_node("CloudSync").get_index())
    var back_to_permissions := Button.new()
    back_to_permissions.name = "BackToPermissions"
    back_to_permissions.text = "KEMBALI KE PUSAT IZIN"
    back_to_permissions.custom_minimum_size.y = 48
    back_to_permissions.pressed.connect(Callable(self, "_open_generic_screen").bind("permissions"))
    screen_body.add_child(back_to_permissions)
    screen_body.move_child(back_to_permissions, screen_body.get_node("CloudSync").get_index())

func _on_save_backend_url() -> void:
    var endpoint := screen_body.get_node_or_null("BackendURL") as LineEdit
    if endpoint == null:
        return
    _ensure_core_kernel()
    core_kernel.network().configure_url(endpoint.text)
    if core_kernel.network().configured():
        core_kernel.network().get_health()

func _on_sync_cloud() -> void:
    _ensure_core_kernel()
    if not core_kernel.network().configured():
        screen_body.get_node("Title").text = "SYSTEM CORE"
        for child in screen_body.get_children():
            if child is Label and child.name != "Title":
                child.queue_free()
        var msg := Label.new()
        msg.text = "Backend belum dikonfigurasi.\n\nBuka SETTINGS lalu isi Backend URL, contoh:\nhttp://127.0.0.1:8787\n\nGunakan HTTPS untuk server publik."
        msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
        screen_body.add_child(msg)
        return
    screen_body.get_node("Title").text = "CLOUD SYNC"
    core_kernel.network().sync_me()

func _apply_remote_state(payload: Dictionary) -> void:
    if payload.has("user") and payload.user is Dictionary and payload.user.has("id"):
        data.cloud_user_id = int(payload.user.id)
    if payload.has("user"):
        data.username = str(payload.user.get("username", data.username))
    if payload.has("profile"):
        var profile: Dictionary = payload.profile
        data.language = str(profile.get("language", data.language))
        data.country = str(profile.get("country", data.country))
        data.server = str(profile.get("server", data.server))
        data.profile_complete = bool(profile.get("profile_complete", data.profile_complete))
    if payload.has("wallet"):
        data.coins = int(payload.wallet.get("coins", data.coins))
        data.diamonds = int(payload.wallet.get("diamonds", data.diamonds))
    if payload.has("progression"):
        var prog: Dictionary = payload.progression
        for key in ["level", "xp", "rank_points", "wins", "losses", "matches"]:
            if prog.has(key):
                data[key] = int(prog[key])
        if prog.has("rank"):
            data.rank = str(prog.rank)
    save_data()

func _on_remote_result(action: String, success: bool, status_code: int, payload: Dictionary) -> void:
    if action == "oauth_start":
        if success and payload.has("auth_url"):
            modern_login_status.text = "Browser dibuka. Selesaikan login %s lalu kembali ke game..." % oauth_provider.capitalize()
            OS.shell_open(str(payload.auth_url))
            oauth_poll_timer.start()
        else:
            oauth_poll_timer.stop()
            modern_login_status.text = "Provider %s belum siap di backend (%d): %s" % [oauth_provider.capitalize(), status_code, str(payload.get("error", "unknown_error"))]
        return
    if action == "oauth_poll":
        if not success:
            oauth_poll_timer.stop()
            modern_login_status.text = "OAuth poll gagal (%d): %s" % [status_code, str(payload.get("error", "unknown_error"))]
            return
        var oauth_status := str(payload.get("status", "pending"))
        if oauth_status == "complete" and payload.has("token"):
            oauth_poll_timer.stop()
            data.logged_in = true
            data.cloud_account = true
            _apply_remote_state(payload)
            modern_login_status.text = "Login %s berhasil." % oauth_provider.capitalize()
            oauth_provider = ""
            oauth_nonce = ""
            save_data()
            _route_after_login()
        elif oauth_status == "error":
            oauth_poll_timer.stop()
            modern_login_status.text = "OAuth gagal: %s" % str(payload.get("error", "provider_error"))
        return
    if action == "login" or action == "register":
        if success:
            data.logged_in = true
            data.cloud_account = true
            _apply_remote_state(payload)
            save_data()
            _route_after_login()
        else:
            if status_code == 0 or status_code >= 500:
                login_status.text = "Server cloud tidak tersedia. Kamu tetap bisa memakai akun lokal."
            else:
                login_status.text = "Server menolak login (%d): %s" % [status_code, str(payload.get("error", "unknown_error"))]
    elif action == "profile":
        if success:
            _apply_remote_state(payload)
    elif action == "sync":
        if success:
            _apply_remote_state(payload)
            show_lobby()
        else:
            screen_body.get_node("Title").text = "CLOUD SYNC GAGAL"
    elif action == "match_result":
        if success:
            _apply_remote_state(payload)
    elif action == "logout":
        data.logged_in = false
        data.cloud_account = false
        save_data()
    elif action == "history":
        pass

func _on_remote_game_result(action: String, success: bool, status_code: int, payload: Dictionary) -> void:
    if not success:
        var err := str(payload.get("error", "unknown_error"))
        match_status.text = "GAME SERVER ERROR (%d)\n%s" % [status_code, err]
        return
    if payload.has("state"):
        var state: Dictionary = payload.state
        if action == "game_start":
            active_match_id = str(state.get("match_id", ""))
            data.active_match_id = active_match_id
            data.remote_game_mode = true
            data.game_lane = str(state.get("lane", game_lane))
            data.game_target = str(state.get("target", game_target))
            save_data()
        _apply_game_state(state)
    if payload.has("profile") and payload.profile is Dictionary:
        _apply_remote_state(payload.profile)
    if action == "game_start":
        match_timer.start()
    if payload.has("reward") and payload.reward is Dictionary and payload.reward != null:
        var reward: Dictionary = payload.reward
        match_status.text = "SERVER SETTLEMENT\n+%d Coins • +%d XP" % [int(reward.get("coins", 0)), int(reward.get("xp", 0))]

    if not active_match_id.is_empty() and payload.has("state"):
        var state2: Dictionary = payload.state
        if str(state2.get("status", "")) == "finished":
            _show_remote_result(state2, payload.get("reward", {}))

func _apply_game_state(state: Dictionary) -> void:
    var game_service := core_kernel.game_state()
    game_service.set_state(state)
    game_state_version = int(state.get("version", game_state_version))
    match_seconds = int(float(state.get("elapsed_seconds", 0)))
    game_lane = str(state.get("lane", game_lane))
    game_target = str(state.get("target", game_target))
    var player: Dictionary = state.get("player", {})
    player_hp = int(player.get("hp", player_hp))
    player_mana = int(player.get("mana", player_mana))
    player_gold = int(player.get("gold", player_gold))
    var enemy: Dictionary = state.get("enemy_hero", {})
    enemy_hero_hp = int(enemy.get("hp", enemy_hero_hp))
    var lanes: Dictionary = state.get("lanes", {})
    var lane: Dictionary = lanes.get(game_lane, {})
    enemy_tower_hp = int(lane.get("enemy_tower_hp", enemy_tower_hp))
    enemy_hp = int(state.get("enemy_core_hp", enemy_hp))
    var cds: Dictionary = state.get("cooldowns", {})
    skill1_cd = int(ceil(float(cds.get("skill1", 0))))
    skill2_cd = int(ceil(float(cds.get("skill2", 0))))
    ult_cd = int(ceil(float(cds.get("ultimate", 0))))
    _refresh_battle_ui()

func _show_remote_result(state: Dictionary, reward_value) -> void:
    match_timer.stop()
    remote_game_mode = false
    data.remote_game_mode = false
    data.active_match_id = ""
    active_match_id = ""
    data.last_result = "Victory" if str(state.get("result", "loss")) == "win" else "Defeat"
    if first_match:
        data.tutorial_complete = true
    save_data()
    hide_app_panels()
    result_panel.visible = true
    var title: Label = result_panel.get_node("Panel/VBox/Title")
    var body: Label = result_panel.get_node("Panel/VBox/Body")
    var victory := str(state.get("result", "loss")) == "win"
    title.text = "VICTORY" if victory else "DEFEAT"
    var player: Dictionary = state.get("player", {})
    var reward_text := ""
    if reward_value is Dictionary:
        reward_text = "+%d Coins • +%d XP" % [int(reward_value.get("coins", 0)), int(reward_value.get("xp", 0))]
    body.text = "%s\nKills %d • Deaths %d • Assists %d • %02d:%02d\nSERVER-AUTHORITATIVE MATCH SAVED" % [reward_text, int(player.get("kills", 0)), int(player.get("deaths", 0)), int(player.get("assists", 0)), match_seconds / 60, match_seconds % 60]

func _generic_content(which: String) -> String:
    match which:
        "heroes":
            return "HERO GALLERY\n\nAstra • Mage\nBrutus • Tank\nNyx • Assassin\nRook • Fighter\nLyra • Marksman\nNova • Support\n\nHero aktif: %s\nPilih hero lalu tekan TETAPKAN HERO untuk menyimpan loadout." % str(data.get("selected_hero", "Astra"))
        "hero_loadout":
            return "HERO LOADOUT\n\nHero aktif: %s\nRole dan pilihan hero tersimpan di perangkat. Skin, emblem kompetitif, dan talent online akan disinkronkan jika endpoint backend terkait tersedia." % str(data.get("selected_hero", "Astra"))
        "rank":
            return "RANKED\n\nSeason 01\nRank: %s\nRank Points: %d\nWins: %d   Losses: %d\nWin rate: %.1f%%\n\nRank lokal diperbarui dari hasil pertandingan lokal; leaderboard/rank kompetitif online harus divalidasi server." % [str(data.rank), int(data.rank_points), int(data.wins), int(data.losses), (100.0 * float(data.wins) / max(1.0, float(data.wins + data.losses)))]
        "leaderboard":
            return "LEADERBOARD\n\nLokal: %s • %d RP\nLevel: %d • Win: %d • Loss: %d\n\nLeaderboard global baru menampilkan peringkat resmi setelah server publik menyediakan endpoint ranking; data global tidak direkayasa saat offline." % [str(data.rank), int(data.rank_points), int(data.level), int(data.wins), int(data.losses)]
        "shop":
            return "STAR MARKET\n\nBeli item untuk inventory lokal kamu. Wallet: %d Coins • %d Diamonds\n\nItem: Iron Blade (500), Vital Core (650), Swift Boots (700), Arcane Orb (800). Pembelian lokal disimpan; pembelian uang asli belum aktif tanpa sistem billing resmi." % [int(data.coins), int(data.diamonds)]
        "inventory":
            var items: Array = data.get("inventory_items", [])
            return "INVENTORY / EQUIPMENT\n\nOwned items: %d\n%s\n\nData inventory lokal disimpan pada perangkat. Cloud inventory memerlukan server akun yang aktif." % [items.size(), "\n".join(items) if not items.is_empty() else "Belum ada equipment. Buka SHOP untuk membeli item."]
        "events":
            return "EVENT CENTER\n\nSTARFALL SEASON 01\nDaily missions • Weekly rewards • Login rewards\n\nClaim daily reward melalui tombol CLAIM DAILY REWARD; satu kali per hari pada perangkat ini. Event kompetitif online memerlukan server publik." 
        "mail":
            return "NEWS & MAIL\n\nPATCH NOTES • Maintenance Announcements • Reward Inbox\n\nNotifikasi Android dapat dikonfigurasi melalui APP PERMISSIONS. Pesan resmi dan berita online akan muncul bila backend/news feed aktif." 
        "social":
            return "SOCIAL HUB\n\nFriends • Party Invite • Recent Players • Friend Requests\n\nUI sosial siap sebagai pintu masuk. Kehadiran teman, invite, dan chat realtime memerlukan server publik dan penyimpanan sosial; status online tidak dipalsukan ketika offline." 
        "quests":
            return "QUESTS & ACHIEVEMENTS\n\nDAILY: Menangkan 1 pertandingan • Reward 300 Coins\nWEEKLY: Mainkan 5 pertandingan • Reward 1000 Coins\nACHIEVEMENTS: First Blood • Lane Guardian • Core Breaker • Team Player\n\nDaily reward lokal bisa diklaim satu kali per tanggal. Reward ranked online harus disahkan server." 
        "settings":
            return "SETTINGS & ACCOUNT\n\nClient: ASTRO ROYALE V38\nLanguage: %s\nCountry: %s\nServer: %s\nBackend URL: %s\nAccount mode: %s\nGraphics: %s • FPS cap: %d\nMaster volume: %d%%\nControls: %s\n\nGunakan menu GRAPHICS / FPS, AUDIO, CONTROLS, ACCOUNT CENTER dan APP PERMISSIONS untuk mengubah pilihan." % [str(data.language), str(data.country), str(data.server), str(data.backend_url), "CLOUD" if data.cloud_account else "LOCAL", str(data.graphics_quality), int(data.render_fps), int(float(data.master_volume) * 100.0), str(data.control_layout)]
        "graphics":
            return "GRAPHICS & PERFORMANCE\n\nQuality preset: %s\nFPS cap: %d\n\nPreset dan FPS cap disimpan serta diterapkan ke loop game. Detail visual tertentu tetap bergantung pada renderer dan aset yang tersedia." % [str(data.graphics_quality), int(data.render_fps)]
        "audio":
            return "AUDIO MIXER\n\nMaster volume: %d%%\n\nVolume master memengaruhi audio bus utama. Musik/SFX terpisah dapat dikontrol saat bus aset audio masing-masing ditambahkan." % int(float(data.master_volume) * 100.0)
        "controls":
            return "CONTROL LAYOUT\n\nPreset: %s\nLeft-handed layout: %s\nHaptic preference: %s\n\nPreset tersimpan. Tata letak joystick khusus akan diterapkan ketika kontrol joystick/drag digunakan pada mode match." % [str(data.control_layout), "ON" if bool(data.left_handed_controls) else "OFF", "ON" if bool(data.vibration_enabled) else "OFF"]
        "account_center":
            return "ACCOUNT CENTER\n\nPlayer: %s\nAccount mode: %s\nProfile: %s • %s • %s\nSession: %s\n\nLocal account dapat digunakan offline. Cloud account membutuhkan backend yang aktif; social provider harus dikonfigurasi sebelum OAuth sungguhan tersedia." % [str(data.username), "CLOUD" if data.cloud_account else "LOCAL / GUEST", str(data.language), str(data.country), str(data.server), "ACTIVE" if not str(data.session_token).is_empty() else "LOCAL SESSION"]
        "privacy":
            return "PRIVACY & SECURITY\n\nMode pertemanan: %s\nPermission requests: user initiated\nSession token: %s\n\nIzin perangkat bersifat opsional. Jangan bagikan token akun. Keamanan kompetitif, rate limiting dan anti-cheat online harus ditegakkan server." % [str(data.privacy_mode), "CLOUD SESSION" if not str(data.session_token).is_empty() else "NO CLOUD TOKEN"]
        "replay":
            return "REPLAY CENTER\n\nMatch count: %d\nLast result: %s\n\nV38 menyimpan ringkasan match, bukan rekaman frame-by-frame. Replay penuh membutuhkan event stream server yang direkam dan dapat diputar ulang." % [int(data.matches), str(data.last_result)]
        "system_monitor":
            return "SYSTEM MONITOR • V38\n\nPlatform: %s\nFPS sekarang: %d\nTarget FPS: %d\nRender preset: %s\nAccount: %s\nNetwork mode: %s\nCore services: %d\n\nStatus online mengikuti koneksi yang nyata; mode lokal tidak ditampilkan sebagai cloud." % [OS.get_name(), Engine.get_frames_per_second(), int(data.render_fps), str(data.graphics_quality), str(data.username), "CLOUD" if data.cloud_account else "LOCAL", core_kernel.health_report().size() if is_instance_valid(core_kernel) else 0]
        "downloads":
            return "RESOURCE CENTER\n\nAsset yang termasuk APK tersedia offline. Unduhan patch/skin tidak diaktifkan tanpa manifest bertanda tangan, CDN dan validasi hash dari server." 
        "battle_pass":
            return "STARFALL PASS • SEASON 01\n\nFree track • Premium track • Weekly XP missions\nTier 01: 100 Coins\nTier 05: Hero Trial Card\nTier 10: Blue Rift Recall\n\nProgress lokal dapat ditambahkan bertahap. Pembayaran premium belum aktif tanpa Google Play Billing/validasi receipt." 
        "news":
            return "NEWS & MAIL\n\nPatch notes • Maintenance announcements • Reward inbox\n\nPengumuman server muncul setelah backend news feed dikonfigurasi." 
        "core":
            _ensure_core_kernel()
            var report := core_kernel.health_report()
            var lines: Array[String] = ["ASTRO ROYALE CORE SYSTEM • V38", "", "Local persistence: ACTIVE", "Permission Center: READY", "FPS cap: %d" % int(data.render_fps), "Graphics preset: %s" % str(data.graphics_quality), "Service modules: %d" % report.size()]
            for key in report.keys():
                var item: Dictionary = report[key]
                lines.append("• %s: %s" % [str(key).to_upper(), str(item.get("status", "unknown")).to_upper()])
            lines.append("")
            lines.append("Account, economy, inventory, progression, settings, history, network, and game-state services are separated.")
            lines.append("Cloud multiplayer and external identity/payment providers require live server/provider configuration.")
            return "\n".join(lines)
        _:
            return "ASTRO ROYALE V38"

func _build_v38_mode_selector() -> void:
    if is_instance_valid(mode_select_panel) or not is_instance_valid(modern_lobby_root):
        return
    mode_select_panel = Control.new()
    mode_select_panel.name = "V38GameModeSelect"
    mode_select_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mode_select_panel.visible = false
    mode_select_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    modern_lobby_root.add_child(mode_select_panel)
    var scrim := ColorRect.new()
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.color = Color(0.003, 0.012, 0.033, 0.88)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    mode_select_panel.add_child(scrim)
    var card := PanelContainer.new()
    card.position = Vector2(115, 54)
    card.size = Vector2(1050, 612)
    card.add_theme_stylebox_override("panel", _v33_style(Color(0.025, 0.065, 0.12, 0.98), 20, Color(0.2, 0.75, 1.0, 0.62)))
    mode_select_panel.add_child(card)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    card.add_child(box)
    var title := Label.new()
    title.text = "SELECT BATTLE MODE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0, 1))
    box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "Pilih mode untuk Astro Royale • Solo/local modes playable without a server"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color(0.62, 0.77, 0.91, 1))
    box.add_child(subtitle)
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    box.add_child(grid)
    var modes := [
        ["⚔ CLASSIC 5V5", "Classic 5v5", "3 lanes • online queue when server connected"],
        ["🏆 RANKED", "Ranked 5v5", "Rank points • local practice fallback"],
        ["🛡 CUSTOM ROOM", "Custom Room", "Practice room • local sandbox"],
        ["⚡ ARCADE", "Arcade", "Fast local combat"],
        ["🔥 BRAWL", "Brawl", "Compact arena skirmish"],
        ["🎯 TRAINING", "Training", "Skills, target, and movement practice"],
        ["🤖 VS AI", "VS AI", "Offline bot battle"],
        ["🧪 PRACTICE RANGE", "Practice Range", "Test attacks and cooldowns"]
    ]
    for item in modes:
        var button := _v33_button("%s\n%s" % [str(item[0]), str(item[2])], 238, 84)
        button.add_theme_font_size_override("font_size", 12)
        button.pressed.connect(Callable(self, "_select_v38_mode").bind(str(item[1])))
        grid.add_child(button)
    mode_select_status = Label.new()
    mode_select_status.text = "SELECTED: %s" % selected_game_mode.to_upper()
    mode_select_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_select_status.add_theme_font_size_override("font_size", 17)
    mode_select_status.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1))
    box.add_child(mode_select_status)
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 14)
    box.add_child(actions)
    mode_select_start = _v33_button("START %s" % selected_game_mode.to_upper(), 300, 48)
    mode_select_start.pressed.connect(_launch_v38_mode)
    actions.add_child(mode_select_start)
    var close := _v33_button("BACK TO LOBBY", 220, 48)
    close.pressed.connect(func(): mode_select_panel.visible = false)
    actions.add_child(close)

func _open_v38_mode_select() -> void:
    if not is_instance_valid(mode_select_panel):
        _build_v38_mode_selector()
    if is_instance_valid(mode_select_panel):
        mode_select_panel.visible = true
        mode_select_status.text = "SELECTED: %s" % selected_game_mode.to_upper()
        mode_select_start.text = "START %s" % selected_game_mode.to_upper()

func _select_v38_mode(mode_name: String) -> void:
    selected_game_mode = mode_name
    if is_instance_valid(mode_select_status):
        mode_select_status.text = "SELECTED: %s" % selected_game_mode.to_upper()
    if is_instance_valid(mode_select_start):
        mode_select_start.text = "START %s" % selected_game_mode.to_upper()
    if is_instance_valid(modern_lobby_status):
        modern_lobby_status.text = "%s • READY" % selected_game_mode.to_upper()

func _launch_v38_mode() -> void:
    if is_instance_valid(mode_select_panel):
        mode_select_panel.visible = false
    _on_play()

func _v38_material(color_value: Color, metallic_value: float = 0.0, glowing: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color_value
    material.metallic = metallic_value
    material.roughness = 0.36
    if glowing:
        material.emission_enabled = true
        material.emission = color_value
        material.emission_energy_multiplier = 1.15
    return material

func _v38_add_mesh(parent: Node3D, mesh_value: Mesh, material_value: Material, pos: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh_value
    instance.position = pos
    instance.scale = scale_value
    instance.material_override = material_value
    parent.add_child(instance)
    return instance

func _v38_create_character(parent: Node3D, team_color: Color, pos: Vector3, scale_value: float = 1.0) -> Node3D:
    var model := Node3D.new()
    model.position = pos
    model.scale = Vector3.ONE * scale_value
    parent.add_child(model)
    var armor := _v38_material(team_color, 0.55, true)
    var dark_armor := _v38_material(Color(0.025, 0.07, 0.14), 0.68)
    var skin := _v38_material(Color(0.82, 0.64, 0.51), 0.05)
    var gold := _v38_material(Color(1.0, 0.73, 0.25), 0.72, true)
    var body := CapsuleMesh.new()
    body.radius = 0.43
    body.height = 1.65
    _v38_add_mesh(model, body, armor, Vector3(0, 1.0, 0))
    var head := SphereMesh.new()
    head.radius = 0.38
    head.height = 0.76
    _v38_add_mesh(model, head, skin, Vector3(0, 2.02, 0))
    var shoulder := BoxMesh.new()
    shoulder.size = Vector3(1.42, 0.34, 0.72)
    _v38_add_mesh(model, shoulder, dark_armor, Vector3(0, 1.48, 0))
    var chest := BoxMesh.new()
    chest.size = Vector3(0.28, 0.40, 0.12)
    _v38_add_mesh(model, chest, gold, Vector3(0, 1.38, 0.40))
    var cape := BoxMesh.new()
    cape.size = Vector3(0.82, 0.88, 0.12)
    _v38_add_mesh(model, cape, dark_armor, Vector3(0, 1.15, -0.42))
    var blade := BoxMesh.new()
    blade.size = Vector3(0.13, 1.15, 0.18)
    var weapon := _v38_add_mesh(model, blade, gold, Vector3(0.78, 1.12, 0.0))
    weapon.rotation_degrees.z = -18.0
    var boot := BoxMesh.new()
    boot.size = Vector3(0.34, 0.22, 0.48)
    _v38_add_mesh(model, boot, dark_armor, Vector3(-0.22, 0.13, 0.03))
    _v38_add_mesh(model, boot, dark_armor, Vector3(0.22, 0.13, 0.03))
    return model

func _v38_create_tower(parent: Node3D, pos: Vector3, team_color: Color) -> Node3D:
    var tower := Node3D.new()
    tower.position = pos
    parent.add_child(tower)
    var body_mat := _v38_material(team_color.darkened(0.35), 0.48)
    var light_mat := _v38_material(team_color, 0.62, true)
    var base := CylinderMesh.new()
    base.top_radius = 0.8
    base.bottom_radius = 1.05
    base.height = 0.65
    _v38_add_mesh(tower, base, body_mat, Vector3(0, 0.34, 0))
    var shaft := CylinderMesh.new()
    shaft.top_radius = 0.43
    shaft.bottom_radius = 0.66
    shaft.height = 1.65
    _v38_add_mesh(tower, shaft, body_mat, Vector3(0, 1.38, 0))
    var crystal := SphereMesh.new()
    crystal.radius = 0.43
    crystal.height = 0.86
    _v38_add_mesh(tower, crystal, light_mat, Vector3(0, 2.38, 0))
    return tower

func _v38_ensure_arena_visual() -> void:
    # Keep one arena-construction path so the 3D scene cannot be duplicated.
    _ensure_v38_arena_visual()

func _v38_build_joystick() -> void:
    if is_instance_valid(v38_joystick_panel):
        return
    v38_joystick_panel = PanelContainer.new()
    v38_joystick_panel.name = "V38VirtualJoystick"
    v38_joystick_panel.position = Vector2(22, 520)
    v38_joystick_panel.size = Vector2(180, 164)
    v38_joystick_panel.add_theme_stylebox_override("panel", _v33_style(Color(0.015, 0.045, 0.085, 0.75), 18, Color(0.3, 0.8, 1, 0.45)))
    match_panel.add_child(v38_joystick_panel)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 3)
    grid.add_theme_constant_override("v_separation", 3)
    v38_joystick_panel.add_child(grid)
    var blank_top := Control.new()
    blank_top.custom_minimum_size = Vector2(42, 38)
    grid.add_child(blank_top)
    var up := _v33_button("▲", 42, 38)
    up.pressed.connect(Callable(self, "_v38_move_player").bind(Vector3(0, 0, -1.5)))
    grid.add_child(up)
    var blank_top_right := Control.new()
    blank_top_right.custom_minimum_size = Vector2(42, 38)
    grid.add_child(blank_top_right)
    var left := _v33_button("◀", 42, 38)
    left.pressed.connect(Callable(self, "_v38_move_player").bind(Vector3(-1.5, 0, 0)))
    grid.add_child(left)
    var center := _v33_button("✦", 42, 38)
    center.disabled = true
    grid.add_child(center)
    var right := _v33_button("▶", 42, 38)
    right.pressed.connect(Callable(self, "_v38_move_player").bind(Vector3(1.5, 0, 0)))
    grid.add_child(right)
    var blank_bottom_left := Control.new()
    blank_bottom_left.custom_minimum_size = Vector2(42, 38)
    grid.add_child(blank_bottom_left)
    var down := _v33_button("▼", 42, 38)
    down.pressed.connect(Callable(self, "_v38_move_player").bind(Vector3(0, 0, 1.5)))
    grid.add_child(down)
    var blank_bottom_right := Control.new()
    blank_bottom_right.custom_minimum_size = Vector2(42, 38)
    grid.add_child(blank_bottom_right)

func _v38_add_match_exit_button() -> void:
    if is_instance_valid(v38_exit_button):
        return
    v38_exit_button = _v33_button("EXIT MATCH", 145, 42)
    v38_exit_button.position = Vector2(1115, 18)
    v38_exit_button.pressed.connect(_on_back_to_lobby)
    match_panel.add_child(v38_exit_button)

func _v38_move_player(delta_pos: Vector3) -> void:
    if not is_instance_valid(v38_player_model) or not match_panel.visible:
        return
    var current := v38_player_model.position
    current.x = clampf(current.x + delta_pos.x, -21.0, -2.0)
    current.z = clampf(current.z + delta_pos.z, -14.0, 14.0)
    v38_player_model.position = current
    if remote_game_mode and not active_match_id.is_empty():
        var network_x := clampf((current.x + 24.0) / 48.0 * 1280.0, 0.0, 1280.0)
        var network_y := clampf((current.z + 13.0) / 26.0 * 720.0, 0.0, 720.0)
        core_kernel.network().realtime_action(active_match_id, "move", game_target, game_lane, network_x, network_y, v34_target_user_id)

func _v38_local_damage(amount: int) -> void:
    match game_target:
        "enemy_hero":
            var hero_was_alive := enemy_hero_hp > 0
            enemy_hero_hp = max(0, enemy_hero_hp - amount)
            if hero_was_alive and enemy_hero_hp == 0:
                player_gold += 120
                match_status.text = "ENEMY HERO DEFEATED • +120 GOLD\nNow pressure the enemy tower."
                if is_instance_valid(v38_enemy_model):
                    v38_enemy_model.visible = false
        "enemy_tower":
            enemy_tower_hp = max(0, enemy_tower_hp - amount)
            if enemy_tower_hp == 0:
                match_status.text = "ENEMY TOWER DESTROYED\nThe enemy core is now exposed."
                var target_tower := v38_enemy_towers.get(game_lane) as Node3D
                if is_instance_valid(target_tower):
                    target_tower.visible = false
        "enemy_core":
            if enemy_tower_hp > 0:
                match_status.text = "ENEMY TOWER STILL STANDS\nSelect TARGET TOWER first."
            else:
                enemy_hp = max(0, enemy_hp - amount)
                if enemy_hp == 0 and is_instance_valid(v38_enemy_core_model):
                    v38_enemy_core_model.visible = false

func _v38_refresh_arena_state() -> void:
    if is_instance_valid(v38_enemy_model):
        v38_enemy_model.visible = enemy_hero_hp > 0
    var target_tower := v38_enemy_towers.get(game_lane) as Node3D
    if is_instance_valid(target_tower):
        target_tower.visible = enemy_tower_hp > 0
    if is_instance_valid(v38_enemy_core_model):
        v38_enemy_core_model.visible = enemy_hp > 0

func _process(delta: float) -> void:
    var in_battle := is_instance_valid(match_panel) and match_panel.visible
    var app_bg := get_node_or_null("BG") as Control
    if is_instance_valid(app_bg):
        app_bg.visible = not in_battle
    if is_instance_valid(v38_arena_root):
        v38_arena_root.visible = in_battle
    if not is_instance_valid(v38_arena_root) or not in_battle:
        return
    v38_arena_clock += delta
    if is_instance_valid(v38_player_model):
        v38_player_model.rotation.y = sin(v38_arena_clock * 0.7) * 0.08
    if is_instance_valid(v38_enemy_model) and v38_enemy_model.visible:
        v38_enemy_model.rotation.y = PI + sin(v38_arena_clock * 0.6) * 0.08
    for i in range(v38_minion_models.size()):
        var minion := v38_minion_models[i]
        if is_instance_valid(minion):
            var direction := 1.0 if i % 2 == 0 else -1.0
            var pos := minion.position
            pos.x += delta * direction * 0.16
            if pos.x > 7.0:
                pos.x = -7.0
            elif pos.x < -7.0:
                pos.x = 7.0
            minion.position = pos

func _ensure_v38_arena_visual() -> void:
    # Hotfix: render the 3D world in the main viewport, not a nested SubViewport.
    # This avoids the Android blank-viewport issue while keeping the 2D HUD above it.
    if is_instance_valid(v38_arena_root):
        return
    for old_name in ["V33ArtBG", "V33ArtVeil"]:
        var old_node := match_panel.get_node_or_null(old_name) as Control
        if is_instance_valid(old_node):
            old_node.visible = false
    var legacy_bg := match_panel.get_node_or_null("ArenaBG") as ColorRect
    if is_instance_valid(legacy_bg):
        legacy_bg.visible = false
    var app_bg := get_node_or_null("BG") as Control
    if is_instance_valid(app_bg):
        app_bg.visible = false
    v38_arena_container = null
    v38_arena_viewport = null
    v38_arena_root = Node3D.new()
    v38_arena_root.name = "V38Battlefield3D"
    v38_arena_root.visible = true
    add_child(v38_arena_root)
    var center := match_panel.get_node_or_null("Center") as VBoxContainer
    if is_instance_valid(center):
        center.position = Vector2(18, 12)
        center.size = Vector2(820, 88)
        center.add_theme_constant_override("separation", 3)
        var title_label := center.get_node_or_null("Title") as Label
        if is_instance_valid(title_label):
            title_label.text = "ASTRO ROYALE  •  BATTLEFIELD"
            title_label.add_theme_font_size_override("font_size", 19)
        var status_label := center.get_node_or_null("Status") as Label
        if is_instance_valid(status_label):
            status_label.add_theme_font_size_override("font_size", 15)
        var legacy_finish := center.get_node_or_null("Finish") as Button
        if is_instance_valid(legacy_finish):
            legacy_finish.visible = false
    var world_env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.075, 0.15, 1)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.48, 0.64, 0.84, 1)
    environment.ambient_light_energy = 0.8
    world_env.environment = environment
    v38_arena_root.add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_color = Color(0.78, 0.88, 1.0, 1)
    sun.light_energy = 1.45
    sun.shadow_enabled = true
    v38_arena_root.add_child(sun)
    var camera := Camera3D.new()
    camera.name = "BattleCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 31.5
    camera.position = Vector3(0, 33, 27)
    camera.look_at(Vector3(0, 0, 0), Vector3.UP)
    camera.current = true
    v38_arena_root.add_child(camera)

    var grass_mat := _v38_material(Color(0.07, 0.24, 0.18), 0.0)
    var lane_mat := _v38_material(Color(0.25, 0.32, 0.36), 0.18)
    var lane_edge_mat := _v38_material(Color(0.58, 0.72, 0.76), 0.22, true)
    var river_mat := _v38_material(Color(0.03, 0.32, 0.53), 0.3, true)
    var jungle_mat := _v38_material(Color(0.025, 0.13, 0.095), 0.0)
    var ground := PlaneMesh.new()
    ground.size = Vector2(58, 38)
    _v38_add_mesh(v38_arena_root, ground, grass_mat, Vector3(0, -0.22, 0))
    for lane_z in [-10.0, 0.0, 10.0]:
        var lane := BoxMesh.new()
        lane.size = Vector3(49, 0.12, 3.4)
        _v38_add_mesh(v38_arena_root, lane, lane_mat, Vector3(0, -0.08, lane_z))
        var edge := BoxMesh.new()
        edge.size = Vector3(49, 0.035, 0.09)
        _v38_add_mesh(v38_arena_root, edge, lane_edge_mat, Vector3(0, 0.005, lane_z - 1.72))
        _v38_add_mesh(v38_arena_root, edge, lane_edge_mat, Vector3(0, 0.005, lane_z + 1.72))
    var river := BoxMesh.new()
    river.size = Vector3(2.3, 0.04, 40)
    var river_inst := _v38_add_mesh(v38_arena_root, river, river_mat, Vector3(0, 0.025, 0))
    river_inst.rotation_degrees.y = 12.0
    # Jungle islands and crystals along both sides of the lanes.
    for p in [Vector3(-7, 0, -6), Vector3(-3, 0, -6.8), Vector3(4, 0, -6.7), Vector3(8, 0, -6), Vector3(-8, 0, 6.2), Vector3(-3, 0, 7), Vector3(4, 0, 7), Vector3(8, 0, 6)]:
        var shrub := SphereMesh.new()
        shrub.radius = 1.05
        shrub.height = 1.8
        _v38_add_mesh(v38_arena_root, shrub, jungle_mat, p + Vector3(0, 0.42, 0), Vector3(1.3, 0.72, 1.0))
        var crystal_mesh := PrismMesh.new()
        crystal_mesh.size = Vector3(0.55, 1.45, 0.55)
        _v38_add_mesh(v38_arena_root, crystal_mesh, _v38_material(Color(0.05, 0.68, 1.0), 0.5, true), p + Vector3(0.0, 1.3, 0.0))
    var blue := Color(0.03, 0.42, 1.0, 1)
    var red := Color(1.0, 0.14, 0.19, 1)
    var lane_z_values := [-10.0, 0.0, 10.0]
    var lane_names := ["top", "mid", "bottom"]
    v38_enemy_towers.clear()
    for lane_index in range(lane_z_values.size()):
        var lane_z: float = lane_z_values[lane_index]
        _v38_create_tower(v38_arena_root, Vector3(-13, 0, lane_z), blue)
        var enemy_tower := _v38_create_tower(v38_arena_root, Vector3(13, 0, lane_z), red)
        v38_enemy_towers[str(lane_names[lane_index])] = enemy_tower
        if str(lane_names[lane_index]) == "mid":
            v38_enemy_mid_tower = enemy_tower
    var core_mesh := CylinderMesh.new()
    core_mesh.top_radius = 0.75
    core_mesh.bottom_radius = 1.4
    core_mesh.height = 2.4
    v38_enemy_core_model = Node3D.new()
    v38_enemy_core_model.position = Vector3(22, 0, 0)
    v38_arena_root.add_child(v38_enemy_core_model)
    _v38_add_mesh(v38_enemy_core_model, core_mesh, _v38_material(red, 0.58, true), Vector3(0, 1.25, 0))
    var player_core := Node3D.new()
    player_core.position = Vector3(-22, 0, 0)
    v38_arena_root.add_child(player_core)
    _v38_add_mesh(player_core, core_mesh, _v38_material(blue, 0.58, true), Vector3(0, 1.25, 0))
    v38_player_model = _v38_create_character(v38_arena_root, blue, Vector3(-8.5, 0, 0), 1.0)
    v38_enemy_model = _v38_create_character(v38_arena_root, red, Vector3(8.5, 0, 0), 1.0)
    v38_minion_models.clear()
    for i in range(3):
        v38_minion_models.append(_v38_create_character(v38_arena_root, blue, Vector3(-4.5 - float(i) * 1.2, 0, -0.8 + float(i) * 0.8), 0.42))
        v38_minion_models.append(_v38_create_character(v38_arena_root, red, Vector3(4.5 + float(i) * 1.2, 0, 0.8 - float(i) * 0.8), 0.42))
    _v38_build_joystick()
    _v38_add_match_exit_button()

func _ensure_battle_ui() -> void:
    _ensure_v38_arena_visual()
    if is_instance_valid(battle_ui):
        battle_ui.visible = true
        if is_instance_valid(v38_joystick_panel):
            v38_joystick_panel.visible = true
        if is_instance_valid(v38_exit_button):
            v38_exit_button.visible = true
        return
    battle_ui = VBoxContainer.new()
    battle_ui.name = "BattleUI"
    battle_ui.position = Vector2(225, 510)
    battle_ui.size = Vector2(1030, 194)
    battle_ui.add_theme_constant_override("separation", 6)
    match_panel.add_child(battle_ui)
    var info := Label.new()
    info.name = "Info"
    info.add_theme_font_size_override("font_size", 17)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    battle_ui.add_child(info)

    var actions := HBoxContainer.new()
    actions.name = "Actions"
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 4)
    battle_ui.add_child(actions)
    _add_battle_button(actions, "ATTACK", _battle_attack)
    _add_battle_button(actions, "SKILL 1", _battle_skill1)
    _add_battle_button(actions, "SKILL 2", _battle_skill2)
    _add_battle_button(actions, "ULTIMATE", _battle_ultimate)
    _add_battle_button(actions, "RECALL", _battle_recall)
    _add_battle_button(actions, "PUSH WAVE", _battle_push_wave)

    var targets := HBoxContainer.new()
    targets.name = "Targets"
    targets.alignment = BoxContainer.ALIGNMENT_CENTER
    targets.add_theme_constant_override("separation", 4)
    battle_ui.add_child(targets)
    _add_battle_button(targets, "TARGET HERO", _target_hero)
    _add_battle_button(targets, "TARGET TOWER", _target_tower)
    _add_battle_button(targets, "TARGET CORE", _target_core)
    _add_battle_button(targets, "TOP", func(): _set_game_lane("top"))
    _add_battle_button(targets, "MID", func(): _set_game_lane("mid"))
    _add_battle_button(targets, "BOTTOM", func(): _set_game_lane("bottom"))

func _battle_push_wave() -> void:
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().game_action(active_match_id, "push_wave", game_target, game_lane)
        return
    player_gold += 30
    if game_target == "enemy_tower":
        enemy_tower_hp = max(0, enemy_tower_hp - 18)
    _refresh_battle_ui()

func _set_game_lane(value: String) -> void:
    game_lane = value
    data.game_lane = value
    save_data()
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().game_action(active_match_id, "set_lane", game_target, game_lane)
    else:
        _refresh_battle_ui()

func _set_game_target(value: String) -> void:
    game_target = value
    data.game_target = value
    save_data()
    if remote_game_mode and not active_match_id.is_empty():
        core_kernel.network().game_action(active_match_id, "set_target", game_target, game_lane)
    else:
        _refresh_battle_ui()

func _target_hero() -> void:
    _set_game_target("enemy_hero")

func _target_tower() -> void:
    _set_game_target("enemy_tower")

func _target_core() -> void:
    _set_game_target("enemy_core")
    if not remote_game_mode and enemy_tower_hp > 0:
        match_status.text = "OBJECTIVE LOCKED • DESTROY ENEMY TOWER FIRST"

func _add_battle_button(parent: Node, text: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(135, 44)
    b.pressed.connect(callback)
    parent.add_child(b)

func _refresh_battle_ui() -> void:
    if not is_instance_valid(battle_ui):
        return
    var info: Label = battle_ui.get_node("Info")
    if remote_game_mode:
        info.text = "SERVER STATE v%d  •  HP %d/1000  •  MANA %d/500  •  GOLD %d  •  LANE %s  •  TARGET %s  •  HERO %d/1000  •  TOWER %d/1200  •  CORE %d/2500  •  S1 %ds S2 %ds ULT %ds" % [game_state_version, player_hp, player_mana, player_gold, game_lane.to_upper(), game_target.to_upper(), enemy_hero_hp, enemy_tower_hp, enemy_hp, skill1_cd, skill2_cd, ult_cd]
    else:
        info.text = "%s  •  HP %d/100  •  MANA %d/100  •  GOLD %d  •  HERO %d  •  TOWER %d  •  CORE %d  •  S1 %ds S2 %ds ULT %ds" % [selected_game_mode.to_upper(), player_hp, player_mana, player_gold, enemy_hero_hp, enemy_tower_hp, enemy_hp, skill1_cd, skill2_cd, ult_cd]
    _v38_refresh_arena_state()

func _make_full_panel(node_name: String) -> Control:
    var panel := Control.new()
    panel.name = node_name
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.016, 0.039, 0.074, 0.98)
    bg.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_child(bg)
    return panel

func _make_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.38, 0.9, 1, 0.45)
    style.corner_radius_top_left = 20
    style.corner_radius_top_right = 20
    style.corner_radius_bottom_left = 20
    style.corner_radius_bottom_right = 20
    style.content_margin_left = 28
    style.content_margin_top = 24
    style.content_margin_right = 28
    style.content_margin_bottom = 24
    return style

func _add_title(parent: Node, text: String, size: int) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)

func _make_label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_color_override("font_color", Color(0.38, 0.9, 1, 1))
    return label

func save_data() -> void:
    var cfg := ConfigFile.new()
    for key in data.keys():
        cfg.set_value("state", key, data[key])
    cfg.save(SAVE_PATH)

func load_data() -> void:
    var cfg := ConfigFile.new()
    var source := SAVE_PATH
    if cfg.load(source) != OK:
        for legacy in LEGACY_SAVE_PATHS:
            var legacy_cfg := ConfigFile.new()
            if legacy_cfg.load(legacy) == OK:
                cfg = legacy_cfg
                source = legacy
                break
    if not cfg.has_section("state"):
        return
    for key in data.keys():
        if cfg.has_section_key("state", key):
            data[key] = cfg.get_value("state", key)
    # Never resurrect a stale active session from an unreachable legacy build.
    if source != SAVE_PATH and not bool(data.get("cloud_account", false)):
        data.session_token = ""
        data.active_match_id = ""
        data.remote_game_mode = false
