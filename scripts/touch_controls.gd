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
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport_rect().size.x * 0.45 and touch_id == -1:
                touch_id = event.index
                move_center = event.position
                move_knob = move_center
                move_active = true
            elif event.position.x > get_viewport_rect().size.x * 0.72:
                if event.position.y > get_viewport_rect().size.y * 0.55:
                    GameState.attack_requested = true
                else:
                    GameState.skill_requested = true
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
        GameState.attack_requested = true
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Q or event.keycode == KEY_SPACE:
            GameState.skill_requested = true

func _draw() -> void:
    if not move_active:
        move_center = Vector2(155, get_viewport_rect().size.y - 145)
        move_knob = move_center
    draw_circle(move_center, 78.0, Color(0, 0, 0, 0.22))
    draw_circle(move_knob, 34.0, Color(1, 1, 1, 0.34))
    var size := get_viewport_rect().size
    var attack_pos := Vector2(size.x - 125, size.y - 120)
    var skill_pos := Vector2(size.x - 230, size.y - 205)
    draw_circle(attack_pos, 58.0, Color(1, 0.25, 0.25, 0.34))
    draw_circle(skill_pos, 46.0, Color(0.3, 0.55, 1.0, 0.35))
    draw_string(ThemeDB.fallback_font, attack_pos + Vector2(-26, 6), "ATK", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
    draw_string(ThemeDB.fallback_font, skill_pos + Vector2(-20, 6), "SK1", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
