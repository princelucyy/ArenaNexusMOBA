extends ArenaUnit
class_name ArenaMinion

var lane_y := 0.0
var ranged := false

func setup_minion(new_team: int, new_lane_y: float, is_ranged := false) -> void:
    team = new_team
    lane_y = new_lane_y
    ranged = is_ranged
    max_hp = 240.0 if not ranged else 150.0
    hp = max_hp
    move_speed = 105.0
    attack_damage = 24.0 if not ranged else 30.0
    attack_range = 100.0 if not ranged else 240.0
    attack_cooldown = 1.0 if not ranged else 1.25
    add_to_group("units")
    z_index = 5

func _physics_process(delta: float) -> void:
    if dead:
        queue_redraw()
        return
    attack_timer = maxf(0.0, attack_timer - delta)
    var target := find_nearest_enemy(attack_range + 75.0)
    if target and absf(target.global_position.y - lane_y) < 90.0:
        if global_position.distance_to(target.global_position) <= attack_range:
            velocity = Vector2.ZERO
            deal_hit(target)
        else:
            velocity = global_position.direction_to(target.global_position) * move_speed
    else:
        velocity = Vector2(1 if team == 0 else -1, 0) * move_speed
    move_and_slide()
    if absf(global_position.x) > 1200.0:
        queue_free()
    queue_redraw()

func _draw() -> void:
    var c := Color("65b7ff") if team == 0 else Color("ff6e7e")
    if ranged:
        draw_circle(Vector2.ZERO, 14.0, c)
        draw_line(Vector2(-10, 0), Vector2(10, 0), Color.WHITE, 3.0)
    else:
        draw_circle(Vector2.ZERO, 18.0, c)
        draw_line(Vector2(-8, -8), Vector2(8, 8), Color("e6e6e6"), 3.0)
    draw_health_bar()
