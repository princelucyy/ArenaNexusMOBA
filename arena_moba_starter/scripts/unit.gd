extends CharacterBody2D
class_name ArenaUnit

@export var team := 0
@export var max_hp := 100.0
@export var hp := 100.0
@export var move_speed := 220.0
@export var attack_damage := 20.0
@export var attack_range := 95.0
@export var attack_cooldown := 0.65

var attack_timer := 0.0
var dead := false
var gold := 0
var xp := 0
var level := 1
var last_damage_team := -1
var last_damage_time := 0.0

func setup(new_team: int, new_hp: float, new_damage: float, new_speed: float) -> void:
    team = new_team
    max_hp = new_hp
    hp = new_hp
    attack_damage = new_damage
    move_speed = new_speed

func _physics_process(delta: float) -> void:
    attack_timer = maxf(0.0, attack_timer - delta)
    last_damage_time = maxf(0.0, last_damage_time - delta)
    if dead:
        velocity = Vector2.ZERO
        return
    move_and_slide()
    queue_redraw()

func take_damage(amount: float, source_team: int = -1) -> void:
    if dead:
        return
    hp = maxf(0.0, hp - amount)
    if source_team >= 0:
        last_damage_team = source_team
        last_damage_time = 5.0
    if hp <= 0.0:
        die(source_team)
    queue_redraw()

func die(source_team: int) -> void:
    dead = true
    hp = 0.0
    if source_team == 0:
        GameState.blue_kills += 1
        GameState.blue_gold += 50
    elif source_team == 1:
        GameState.red_kills += 1
        GameState.red_gold += 50
    queue_redraw()

func find_nearest_enemy(max_distance: float = 99999.0, include_structures := true) -> Node2D:
    var best: Node2D = null
    var best_d := max_distance
    for node in get_tree().get_nodes_in_group("units"):
        if node == self or not is_instance_valid(node):
            continue
        if node.team == team or node.dead:
            continue
        var d := global_position.distance_to(node.global_position)
        if d < best_d:
            best_d = d
            best = node
    if include_structures:
        for node in get_tree().get_nodes_in_group("structures"):
            if not is_instance_valid(node) or not node.has_method("take_damage"):
                continue
            if node.team == team or node.dead:
                continue
            var d2 := global_position.distance_to(node.global_position)
            if d2 < best_d:
                best_d = d2
                best = node
    return best

func find_nearest_enemy_unit(max_distance: float = 99999.0) -> Node2D:
    return find_nearest_enemy(max_distance, false)

func deal_hit(target: Node2D, bonus_damage := 0.0) -> bool:
    if attack_timer > 0.0 or not is_instance_valid(target):
        return false
    if target.dead:
        return false
    if global_position.distance_to(target.global_position) > attack_range:
        return false
    var before_dead := target.dead
    target.take_damage(attack_damage + bonus_damage, team)
    attack_timer = attack_cooldown
    if not before_dead and target.dead:
        xp += 60
        gold += 80
        _check_level()
    return true

func _check_level() -> void:
    var needed := 250 + (level - 1) * 100
    if xp >= needed:
        xp -= needed
        level += 1
        max_hp += 90.0
        hp = max_hp
        attack_damage += 7.0

func draw_health_bar() -> void:
    var w := 70.0
    var ratio := clampf(hp / max_hp, 0.0, 1.0)
    draw_rect(Rect2(-w / 2.0, -46, w, 7), Color("202020"))
    draw_rect(Rect2(-w / 2.0, -46, w * ratio, 7), Color("55e06d"))
