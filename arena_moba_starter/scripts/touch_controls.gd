extends Control
class_name TouchControls

var move_center := Vector2.ZERO
var move_knob := Vector2.ZERO
var move_active := false
var touch_id := -1

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    queue_redraw()

func _process(_delta: float) -> void:
    if not move_active:
        var keyboard := Vector2.ZERO
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            keyboard.x -= 1.0
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            keyboard.x += 1.0
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            keyboard.y -= 1.0
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            keyboard.y += 1.0
        GameState.move_input = keyboard.normalized()
    queue_redraw()

func _input(event: InputEvent) -> void:
    var size := get_viewport_rect().size
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < size.x * 0.45 and touch_id == -1:
                touch_id = event.index
                move_center = event.position
                move_knob = move_center
                move_active = true
            elif event.position.x >= size.x * 0.70:
                var y := event.position.y
                if y > size.y * 0.76:
                    GameState.attack_requested = true
                elif y > size.y * 0.58:
                    GameState.skill1_requested = true
                elif y > size.y * 0.40:
                    GameState.skill2_requested = true
                elif y > size.y * 0.24:
                    GameState.ultimate_requested = true
                else:
                    GameState.shop_requested = true
        elif event.index == touch_id:
            move_active = false
            touch_id = -1
            GameState.move_input = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == touch_id:
        var delta := event.position - move_center
        if delta.length() > 110.0:
            delta = delta.normalized() * 110.0
        move_knob = move_center + delta
        GameState.move_input = delta / 110.0

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var size := get_viewport_rect().size
        if event.position.x >= size.x * 0.70:
            var y := event.position.y
            if y > size.y * 0.76:
                GameState.attack_requested = true
            elif y > size.y * 0.58:
                GameState.skill1_requested = true
            elif y > size.y * 0.40:
                GameState.skill2_requested = true
            elif y > size.y * 0.24:
                GameState.ultimate_requested = true
            else:
                GameState.shop_requested = true
        else:
            GameState.attack_requested = true
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Q or event.keycode == KEY_SPACE:
            GameState.skill1_requested = true
        elif event.keycode == KEY_E:
            GameState.skill2_requested = true
        elif event.keycode == KEY_R:
            GameState.ultimate_requested = true
        elif event.keycode == KEY_B:
            GameState.shop_requested = true

func _draw() -> void:
    if not move_active:
        move_center = Vector2(155, get_viewport_rect().size.y - 145)
        move_knob = move_center
    draw_circle(move_center, 78.0, Color(0, 0, 0, 0.23))
    draw_circle(move_knob, 34.0, Color(1, 1, 1, 0.34))
    var size := get_viewport_rect().size
    var attack_pos := Vector2(size.x - 118, size.y - 90)
    var s1_pos := Vector2(size.x - 245, size.y - 145)
    var s2_pos := Vector2(size.x - 235, size.y - 255)
    var ult_pos := Vector2(size.x - 105, size.y - 255)
    var shop_pos := Vector2(size.x - 90, 80)
    draw_circle(attack_pos, 58.0, Color(1, 0.25, 0.25, 0.38))
    draw_circle(s1_pos, 44.0, Color(0.3, 0.55, 1.0, 0.38))
    draw_circle(s2_pos, 42.0, Color(0.5, 0.35, 1.0, 0.38))
    draw_circle(ult_pos, 50.0, Color(1.0, 0.65, 0.2, 0.4))
    draw_circle(shop_pos, 34.0, Color(0.2, 0.85, 0.55, 0.42))
    draw_string(ThemeDB.fallback_font, attack_pos + Vector2(-22, 6), "ATK", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
    draw_string(ThemeDB.fallback_font, s1_pos + Vector2(-16, 6), "S1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    draw_string(ThemeDB.fallback_font, s2_pos + Vector2(-16, 6), "S2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    draw_string(ThemeDB.fallback_font, ult_pos + Vector2(-18, 6), "ULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
    draw_string(ThemeDB.fallback_font, shop_pos + Vector2(-17, 5), "SHOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
