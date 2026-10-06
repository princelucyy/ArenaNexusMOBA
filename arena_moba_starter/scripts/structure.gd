extends Node2D
class_name ArenaStructure

@export var team := 0
@export var max_hp := 1500.0
@export var hp := 1500.0
@export var attack_damage := 90.0
@export var attack_range := 320.0
@export var attack_cooldown := 1.2

var attack_timer := 0.0
var dead := false
var is_base := false

func configure(new_team: int, base := false) -> void:
    team = new_team
    is_base = base
    if is_base:
        max_hp = 6000.0
        hp = max_hp
        attack_damage = 140.0
        attack_range = 430.0
        attack_cooldown = 1.0
    else:
        max_hp = 2200.0
        hp = max_hp
        attack_damage = 105.0
        attack_range = 360.0
        attack_cooldown = 1.15
    add_to_group("structures")
    z_index = 8
    queue_redraw()

func _process(delta: float) -> void:
    attack_timer = maxf(0.0, attack_timer - delta)
    if dead:
        queue_redraw()
        return
    var target := find_target()
    if target and global_position.distance_to(target.global_position) <= attack_range and attack_timer <= 0.0:
        target.take_damage(attack_damage, team)
        attack_timer = attack_cooldown
    queue_redraw()

func find_target() -> Node2D:
    var best: Node2D = null
    var best_d := attack_range + 1.0
    var best_priority := 99
    for node in get_tree().get_nodes_in_group("units"):
        if not is_instance_valid(node) or node.dead or node.team == team:
            continue
        var d := global_position.distance_to(node.global_position)
        if d > attack_range:
            continue
        var priority := 2
        if node is ArenaMinion:
            priority = 1
        elif node is ArenaHero:
            priority = 3
        if priority < best_priority or (priority == best_priority and d < best_d):
            best_priority = priority
            best_d = d
            best = node
    return best

func take_damage(amount: float, source_team: int = -1) -> void:
    if dead:
        return
    hp = maxf(0.0, hp - amount)
    if hp <= 0.0:
        dead = true
        if source_team == 0:
            GameState.blue_gold += 150 if is_base else 90
        elif source_team == 1:
            GameState.red_gold += 150 if is_base else 90
        if is_base and not GameState.match_over:
            GameState.match_over = true
            GameState.winner_team = source_team
    queue_redraw()

func _draw() -> void:
    var c := Color("4c9fe8") if team == 0 else Color("d94d60")
    if dead:
        draw_circle(Vector2.ZERO, 34.0 if is_base else 24.0, Color(0.2, 0.2, 0.2, 0.6))
        return
    if is_base:
        draw_rect(Rect2(-58, -70, 116, 140), c)
        draw_circle(Vector2(0, -18), 34, Color("f1d0a3"))
    else:
        draw_rect(Rect2(-28, -58, 56, 116), c)
        draw_circle(Vector2(0, -32), 12, Color("e7e7e7"))
    var w := 116.0 if is_base else 82.0
    var y := -92.0 if is_base else -74.0
    draw_rect(Rect2(-w / 2.0, y, w, 8), Color("252525"))
    draw_rect(Rect2(-w / 2.0, y, w * clampf(hp / max_hp, 0.0, 1.0), 8), Color("5ee36d"))
