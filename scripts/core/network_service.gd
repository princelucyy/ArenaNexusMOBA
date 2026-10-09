class_name AstroNetworkService
extends AstroServiceBase

signal remote_result(action: String, success: bool, status_code: int, payload: Dictionary)
signal remote_game_result(action: String, success: bool, status_code: int, payload: Dictionary)
signal realtime_event(event: Dictionary)
signal realtime_status(status: String, detail: String)

var http: HTTPRequest
var base_url := ""
var token := ""
var request_queue: Array[Dictionary] = []
var busy := false
var current_action := ""
var ws: WebSocketPeer
var ws_url := ""
var ws_connected := false
var ws_token := ""
var ws_connecting := false
var ws_authenticated := false
var ws_auth_sent := false
var last_keepalive_msec := 0
var reconnect_due_msec := 0
var reconnect_attempt := 0
var reconnect_enabled := false
var active_realtime_match_id := ""
var desired_queue: Dictionary = {}

func initialize(app_node: Node) -> void:
    super.initialize(app_node)
    base_url = str(app.data.get("backend_url", "")).strip_edges()
    token = str(app.data.get("session_token", "")).strip_edges()
    http = HTTPRequest.new()
    http.name = "NetworkHTTP"
    http.timeout = 6.0
    add_child(http)
    if not http.request_completed.is_connected(_on_request_completed):
        http.request_completed.connect(_on_request_completed)

func _process(_delta: float) -> void:
    var now_msec := Time.get_ticks_msec()
    if ws == null:
        if reconnect_enabled and now_msec >= reconnect_due_msec:
            connect_realtime()
        return
    ws.poll()
    var state := ws.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not ws_connected:
            ws_connected = true
            ws_connecting = false
            last_keepalive_msec = now_msec
            realtime_status.emit("connected", "Realtime server connected")
        # Authentication is always the first application packet for every new socket.
        if not ws_auth_sent:
            ws_auth_sent = realtime_send({"type": "auth", "token": token})
        if ws_authenticated and now_msec - last_keepalive_msec >= 5000:
            if realtime_send({"type": "ping", "client_time_ms": now_msec}):
                last_keepalive_msec = now_msec
        while ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
            var packet := ws.get_packet().get_string_from_utf8()
            if packet.is_empty():
                continue
            var parsed = JSON.parse_string(packet)
            if parsed is Dictionary:
                _handle_realtime_packet(parsed)
                realtime_event.emit(parsed)
    elif state == WebSocketPeer.STATE_CLOSED:
        if ws_connected or ws_connecting:
            ws = null
            ws_connected = false
            ws_connecting = false
            ws_authenticated = false
            ws_auth_sent = false
            if reconnect_enabled and configured() and not token.is_empty():
                _schedule_ws_reconnect()
            else:
                realtime_status.emit("closed", "Realtime server disconnected")

func _handle_realtime_packet(event: Dictionary) -> void:
    var event_type := str(event.get("type", ""))
    if event_type == "auth_ok":
        ws_authenticated = true
        reconnect_attempt = 0
        realtime_status.emit("authenticated", "Realtime session authenticated")
        _send_desired_realtime_state()
    elif event_type == "match_found":
        active_realtime_match_id = str(event.get("match_id", ""))
        desired_queue.clear()
        reconnect_enabled = true
    elif event_type == "resume_ok":
        active_realtime_match_id = str(event.get("match_id", active_realtime_match_id))
        reconnect_enabled = true
    elif event_type == "resume_failed":
        active_realtime_match_id = ""
        reconnect_enabled = not desired_queue.is_empty()
        realtime_status.emit("error", "Match tidak dapat dipulihkan; silakan antre kembali")
    elif event_type == "match_state":
        var state_value = event.get("state", {})
        if state_value is Dictionary:
            active_realtime_match_id = str(state_value.get("match_id", active_realtime_match_id))
            if str(state_value.get("status", "")) == "finished":
                active_realtime_match_id = ""
                reconnect_enabled = false
    elif event_type == "queue_left":
        if active_realtime_match_id.is_empty():
            desired_queue.clear()
            reconnect_enabled = false
    elif event_type == "error":
        var reason := str(event.get("error", ""))
        if reason in ["unauthorized", "auth_required"]:
            ws_authenticated = false
            reconnect_enabled = false
            desired_queue.clear()
            active_realtime_match_id = ""
            realtime_status.emit("error", "Session realtime tidak valid; login cloud kembali")

func _send_desired_realtime_state() -> void:
    if not ws_authenticated or not realtime_open():
        return
    if not desired_queue.is_empty():
        realtime_send({
            "type": "join_queue",
            "mode": str(desired_queue.get("mode", "Classic 5v5")),
            "hero": str(desired_queue.get("hero", "Astra")),
            "lane": str(desired_queue.get("lane", "mid")),
        })
    elif not active_realtime_match_id.is_empty():
        realtime_send({"type": "resume_match", "match_id": active_realtime_match_id})

func _schedule_ws_reconnect() -> void:
    reconnect_attempt = min(reconnect_attempt + 1, 5)
    var wait_seconds := min(15.0, pow(2.0, float(reconnect_attempt - 1)))
    reconnect_due_msec = Time.get_ticks_msec() + int(wait_seconds * 1000.0)
    realtime_status.emit("reconnecting", "Koneksi putus; mencoba kembali dalam %d detik" % int(wait_seconds))

func configured() -> bool:
    return not base_url.is_empty()

func configure_url(url: String) -> void:
    base_url = url.strip_edges().trim_suffix("/")
    app.data.backend_url = base_url
    app.save_data()

func clear_session() -> void:
    token = ""
    app.data.session_token = ""
    app.save_data()

func _headers() -> PackedStringArray:
    var headers := PackedStringArray(["Content-Type: application/json"])
    if not token.is_empty():
        headers.append("Authorization: Bearer %s" % token)
    return headers

func _send(action: String, method: HTTPClient.Method, path: String, body: Dictionary = {}, is_game: bool = false) -> void:
    if not configured():
        if is_game:
            remote_game_result.emit(action, false, 0, {"error": "backend_not_configured"})
        else:
            remote_result.emit(action, false, 0, {"error": "backend_not_configured"})
        return
    if http == null:
        if is_game:
            remote_game_result.emit(action, false, 0, {"error": "http_unavailable"})
        else:
            remote_result.emit(action, false, 0, {"error": "http_unavailable"})
        return
    request_queue.append({
        "action": action,
        "method": method,
        "path": path,
        "body": body,
        "is_game": is_game,
    })
    _dispatch_next()

func _dispatch_next() -> void:
    if busy or request_queue.is_empty():
        return
    var job: Dictionary = request_queue.pop_front()
    busy = true
    current_action = str(job.action)
    var payload := ""
    if not Dictionary(job.body).is_empty():
        payload = JSON.stringify(job.body)
    var err := http.request(base_url + str(job.path), _headers(), int(job.method), payload)
    if err != OK:
        busy = false
        current_action = ""
        if bool(job.is_game):
            remote_game_result.emit(str(job.action), false, 0, {"error": "request_failed", "code": int(err)})
        else:
            remote_result.emit(str(job.action), false, 0, {"error": "request_failed", "code": int(err)})
        _dispatch_next()

func _on_request_completed(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
    var action := current_action
    var is_game := action.begins_with("game_")
    busy = false
    current_action = ""
    var payload: Dictionary = {}
    var text_body := body.get_string_from_utf8()
    if not text_body.is_empty():
        var parsed = JSON.parse_string(text_body)
        if parsed is Dictionary:
            payload = parsed
    var success := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
    if success and payload.has("token"):
        token = str(payload.token)
        app.data.session_token = token
        app.save_data()
    if is_game:
        remote_game_result.emit(action, success, response_code, payload)
    else:
        remote_result.emit(action, success, response_code, payload)
    _dispatch_next()

func health() -> Dictionary:
    return {
        "status": "cloud-configured" if configured() else "local-only",
        "endpoint": base_url,
        "authenticated": not token.is_empty(),
        "queue": request_queue.size(),
        "busy": busy,
    }

func get_health() -> void:
    _send("health", HTTPClient.METHOD_GET, "/health")


func oauth_start_url(provider: String, nonce: String = "") -> String:
    if not configured():
        return ""
    var safe := provider.strip_edges().to_lower()
    if safe not in ["google", "facebook", "whatsapp"]:
        return ""
    var url := base_url + "/api/oauth/" + safe + "/start"
    if not nonce.is_empty():
        url += "?nonce=" + nonce.uri_encode()
    return url

func oauth_start(provider: String, nonce: String) -> void:
    _send("oauth_start", HTTPClient.METHOD_GET, "/api/oauth/" + provider + "/start?nonce=" + nonce.uri_encode())

func oauth_poll(provider: String, nonce: String) -> void:
    _send("oauth_poll", HTTPClient.METHOD_GET, "/api/oauth/" + provider + "/poll?nonce=" + nonce.uri_encode())

func register_remote(username: String, password: String) -> void:
    _send("register", HTTPClient.METHOD_POST, "/api/account/register", {"username": username, "password": password})

func login_remote(username: String, password: String) -> void:
    _send("login", HTTPClient.METHOD_POST, "/api/account/login", {"username": username, "password": password})

func logout_remote() -> void:
    _send("logout", HTTPClient.METHOD_POST, "/api/account/logout")

func sync_me() -> void:
    _send("sync", HTTPClient.METHOD_GET, "/api/me")

func update_profile(username: String, language: String, country: String, server_region: String) -> void:
    _send("profile", HTTPClient.METHOD_PUT, "/api/me/profile", {
        "username": username,
        "language": language,
        "country": country,
        "server": server_region,
    })

func submit_match_result(victory: bool, duration_seconds: int, kills: int = 0, deaths: int = 0, assists: int = 0) -> void:
    _send("match_result", HTTPClient.METHOD_POST, "/api/match/result", {
        "result": "win" if victory else "loss",
        "duration_seconds": duration_seconds,
        "kills": kills,
        "deaths": deaths,
        "assists": assists,
    })

func get_match_history() -> void:
    _send("history", HTTPClient.METHOD_GET, "/api/me/matches")

func start_game(mode: String, hero: String = "Astra", lane: String = "mid") -> void:
    _send("game_start", HTTPClient.METHOD_POST, "/api/game/start", {
        "mode": mode,
        "hero": hero,
        "lane": lane,
    }, true)

func game_state(match_id: String) -> void:
    _send("game_state", HTTPClient.METHOD_GET, "/api/game/state?match_id=" + match_id.uri_encode(), {}, true)

func game_action(match_id: String, action: String, target: String = "", lane: String = "") -> void:
    var body := {"match_id": match_id, "action": action}
    if not target.is_empty():
        body["target"] = target
    if not lane.is_empty():
        body["lane"] = lane
    _send("game_action", HTTPClient.METHOD_POST, "/api/game/action", body, true)


func _make_ws_url() -> String:
    var raw_url := base_url.strip_edges().trim_suffix("/")
    var scheme_sep := raw_url.find("://")
    if scheme_sep <= 0:
        return ""
    var source_scheme := raw_url.substr(0, scheme_sep).to_lower()
    if source_scheme not in ["http", "https"]:
        return ""
    var socket_scheme := "wss" if source_scheme == "https" else "ws"
    var remainder := raw_url.substr(scheme_sep + 3)
    var slash := remainder.find("/")
    var authority := remainder if slash < 0 else remainder.substr(0, slash)
    var path_prefix := "" if slash < 0 else remainder.substr(slash).trim_suffix("/")
    if authority.is_empty():
        return ""
    # Keep IPv6 bracket syntax intact while replacing any configured API port.
    if authority.begins_with("["):
        var close_bracket := authority.find("]")
        if close_bracket >= 0:
            authority = authority.substr(0, close_bracket + 1) + ":8788"
        else:
            return ""
    else:
        var colon := authority.rfind(":")
        if colon >= 0:
            authority = authority.substr(0, colon) + ":8788"
        else:
            authority += ":8788"
    return socket_scheme + "://" + authority + path_prefix + "/ws"

func connect_realtime() -> void:
    if not configured() or token.is_empty():
        realtime_status.emit("error", "Realtime membutuhkan backend URL dan session token")
        return
    if ws != null:
        var existing_state := ws.get_ready_state()
        if existing_state == WebSocketPeer.STATE_OPEN or existing_state == WebSocketPeer.STATE_CONNECTING:
            return
    ws_url = _make_ws_url()
    if ws_url.is_empty():
        realtime_status.emit("error", "Backend URL tidak valid untuk WebSocket")
        return
    ws_token = token
    ws = WebSocketPeer.new()
    ws_connected = false
    ws_authenticated = false
    ws_auth_sent = false
    ws_connecting = true
    var err := ws.connect_to_url(ws_url)
    if err != OK:
        ws_connecting = false
        ws = null
        if reconnect_enabled:
            _schedule_ws_reconnect()
        else:
            realtime_status.emit("error", "Gagal membuka realtime socket (%d)" % int(err))
        return
    realtime_status.emit("connecting", "Menghubungkan realtime server...")

func disconnect_realtime() -> void:
    reconnect_enabled = false
    desired_queue.clear()
    active_realtime_match_id = ""
    if ws != null:
        ws.close()
    ws = null
    ws_connected = false
    ws_connecting = false
    ws_authenticated = false
    ws_auth_sent = false

func realtime_open() -> bool:
    return ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN

func realtime_send(message: Dictionary) -> bool:
    if not realtime_open():
        return false
    var payload := JSON.stringify(message)
    var err := ws.send_text(payload)
    return err == OK

func join_matchmaking(mode: String, hero: String, lane: String) -> void:
    desired_queue = {"mode": mode, "hero": hero, "lane": lane}
    reconnect_enabled = true
    reconnect_due_msec = 0
    if ws_authenticated and realtime_open():
        _send_desired_realtime_state()
        return
    connect_realtime()
    var deadline := Time.get_ticks_msec() + 12000
    while not ws_authenticated and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    if not ws_authenticated:
        realtime_status.emit("error", "Realtime belum terautentikasi; periksa server, URL, dan sesi cloud")

func leave_matchmaking() -> void:
    desired_queue.clear()
    realtime_send({"type": "leave_queue"})
    if active_realtime_match_id.is_empty():
        reconnect_enabled = false

func realtime_action(match_id: String, action: String, target: String = "", lane: String = "", x: float = 0.0, y: float = 0.0, target_user_id: String = "") -> bool:
    var body := {
        "type": "action",
        "match_id": match_id,
        "action": action,
        "target": target,
        "target_user_id": target_user_id,
        "lane": lane,
        "x": x,
        "y": y,
    }
    return realtime_send(body)


func current_user_id() -> int:
    var username := str(app.data.get("username", ""))
    if username.is_empty():
        return -1
    # The backend auth event is the canonical user ID; updated by realtime_event handling in app.
    return int(app.data.get("cloud_user_id", -1))
