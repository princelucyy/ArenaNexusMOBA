extends ArenaUnit
class_name ArenaHero

const HEROES := [
    {"name":"Astra", "role":"Mage", "color":"5fa8ff", "hp":900.0, "damage":72.0, "speed":300.0, "mana":260.0, "s1":5.0, "s2":8.0, "ult":28.0, "range":170.0},
    {"name":"Brutus", "role":"Tank", "color":"d0a252", "hp":1250.0, "damage":64.0, "speed":255.0, "mana":180.0, "s1":6.0, "s2":10.0, "ult":32.0, "range":125.0},
    {"name":"Nyx", "role":"Assassin", "color":"a874e9", "hp":820.0, "damage":88.0, "speed":330.0, "mana":220.0, "s1":4.0, "s2":7.0, "ult":24.0, "range":155.0},
    {"name":"Rook", "role":"Fighter", "color":"e56a54", "hp":1050.0, "damage":78.0, "speed":285.0, "mana":200.0, "s1":5.0, "s2":9.0, "ult":30.0, "range":145.0},
    {"name":"Lyra", "role":"Marksman", "color":"68d9bb", "hp":860.0, "damage":82.0, "speed":310.0, "mana":240.0, "s1":5.0, "s2":7.0, "ult":26.0, "range":230.0}
]

var hero_id := 0
var hero_name := "Astra"
var role := "Mage"
var is_player := false
var is_bot := false
var mana := 100.0
var max_mana := 100.0
var skill1_cooldown := 0.0
var skill2_cooldown := 0.0
var ultimate_cooldown := 0.0
var respawn_timer := 0.0
var home_position := Vector2.ZERO
var bot_lane_y := 0.0
var attack_bonus := 0.0
var hp_bonus := 0.0
var move_bonus := 0.0
var ability_power := 0.0

func _ready() -> void:
    add_to_group("units")
    z_index = 10
    queue_redraw()

func configure(new_team: int, selected_hero_id := 0, player := false, bot := true, lane_y := 0.0) -> void:
    hero_id = clampi(selected_hero_id, 0, HEROES.size() - 1)
    var data: Dictionary = HEROES[hero_id]
    hero_name = str(data["name"])
    role = str(data["role"])
    team = new_team
    is_player = player
    is_bot = bot
    bot_lane_y = lane_y
    max_mana = float(data["mana"])
    mana = max_mana
    attack_range = float(data["range"])
    attack_cooldown = 0.55 if hero_id != 4 else 0.42
    setup(team, float(data["hp"]), float(data["damage"]), float(data["speed"]))
    home_position = global_position

func _physics_process(delta: float) -> void:
    skill1_cooldown = maxf(0.0, skill1_cooldown - delta)
    skill2_cooldown = maxf(0.0, skill2_cooldown - delta)
    ultimate_cooldown = maxf(0.0, ultimate_cooldown - delta)
    mana = minf(max_mana, mana + delta * 8.0)

    if dead:
        respawn_timer += delta
        velocity = Vector2.ZERO
        if respawn_timer >= 6.0 and not GameState.match_over:
            dead = false
            hp = max_hp
            mana = max_mana
            global_position = home_position
            respawn_timer = 0.0
        queue_redraw()
        return

    if is_player:
        velocity = GameState.move_input * (move_speed + move_bonus)
        if GameState.attack_requested:
            GameState.attack_requested = false
            var target := find_nearest_enemy(attack_range + 45.0)
            if target:
                deal_hit(target, attack_bonus)
        if GameState.skill1_requested:
            GameState.skill1_requested = false
            cast_skill_1()
        if GameState.skill2_requested:
            GameState.skill2_requested = false
            cast_skill_2()
        if GameState.ultimate_requested:
            GameState.ultimate_requested = false
            cast_ultimate()
    elif is_bot:
        bot_think(delta)

    super._physics_process(delta)

func bot_think(_delta: float) -> void:
    var target := find_nearest_enemy_unit(260.0)
    if target and global_position.distance_to(target.global_position) <= attack_range:
        velocity = Vector2.ZERO
        deal_hit(target, attack_bonus)
        if randi() % 80 == 0:
            cast_skill_1()
        if randi() % 150 == 0:
            cast_skill_2()
        if randi() % 300 == 0:
            cast_ultimate()
    else:
        var goal := Vector2(1000.0 if team == 0 else -1000.0, bot_lane_y)
        if target and global_position.distance_to(target.global_position) < 420.0:
            goal = target.global_position
        velocity = global_position.direction_to(goal) * (move_speed + move_bonus) * 0.70

func cast_skill_1() -> void:
    if skill1_cooldown > 0.0 or mana < 25.0 or dead:
        return
    mana -= 25.0
    skill1_cooldown = float(HEROES[hero_id]["s1"])
    var radius := 190.0
    var damage := 105.0 + level * 12.0 + ability_power
    if hero_id == 1:
        radius = 165.0
        damage = 90.0 + level * 10.0
    if hero_id == 2:
        radius = 150.0
        damage = 145.0 + level * 14.0 + ability_power
    for node in get_tree().get_nodes_in_group("units"):
        if not is_instance_valid(node) or node == self or node.dead or node.team == team:
            continue
        if global_position.distance_to(node.global_position) <= radius:
            node.take_damage(damage, team)
    for structure in get_tree().get_nodes_in_group("structures"):
        if is_instance_valid(structure) and not structure.dead and structure.team != team and global_position.distance_to(structure.global_position) <= radius:
            structure.take_damage(damage * 0.75, team)
    queue_redraw()

func cast_skill_2() -> void:
    if skill2_cooldown > 0.0 or mana < 35.0 or dead:
        return
    mana -= 35.0
    skill2_cooldown = float(HEROES[hero_id]["s2"])
    var target := find_nearest_enemy(420.0)
    if not target:
        return
    var damage := 155.0 + level * 16.0 + ability_power
    if hero_id == 0:
        damage += 35.0
    if hero_id == 4:
        damage += 55.0
    target.take_damage(damage, team)
    if target.dead:
        xp += 60
        gold += 80
        _check_level()
    queue_redraw()

func cast_ultimate() -> void:
    if ultimate_cooldown > 0.0 or mana < 70.0 or dead:
        return
    mana -= 70.0
    ultimate_cooldown = float(HEROES[hero_id]["ult"])
    var radius := 300.0
    var damage := 330.0 + level * 24.0 + ability_power * 1.2
    if hero_id == 1:
        damage = 260.0 + level * 22.0
        radius = 340.0
        hp = minf(max_hp, hp + 180.0)
    elif hero_id == 2:
        damage = 430.0 + level * 28.0 + ability_power
        radius = 235.0
    elif hero_id == 4:
        damage = 390.0 + level * 25.0 + ability_power
        radius = 400.0
    for node in get_tree().get_nodes_in_group("units"):
        if not is_instance_valid(node) or node == self or node.dead or node.team == team:
            continue
        if global_position.distance_to(node.global_position) <= radius:
            node.take_damage(damage, team)
    for structure in get_tree().get_nodes_in_group("structures"):
        if is_instance_valid(structure) and not structure.dead and structure.team != team and global_position.distance_to(structure.global_position) <= radius:
            structure.take_damage(damage * 0.8, team)
    queue_redraw()

func apply_item(item: Dictionary) -> void:
    attack_bonus += float(item.get("attack", 0.0))
    hp_bonus += float(item.get("hp", 0.0))
    move_bonus += float(item.get("speed", 0.0))
    ability_power += float(item.get("ap", 0.0))
    max_hp += float(item.get("hp", 0.0))
    hp = minf(max_hp, hp + float(item.get("hp", 0.0)))
    max_mana += float(item.get("mana", 0.0))
    mana = max_mana
    queue_redraw()

func die(source_team: int) -> void:
    super.die(source_team)
    velocity = Vector2.ZERO

func _draw() -> void:
    var base_color := Color(str(HEROES[hero_id]["color"]))
    if team == 1:
        base_color = base_color.darkened(0.25)
    if dead:
        draw_circle(Vector2.ZERO, 24.0, Color(0.25, 0.25, 0.25, 0.55))
        return
    draw_circle(Vector2.ZERO, 25.0, base_color)
    draw_circle(Vector2(0, -7), 11.0, Color("f5d0a5"))
    draw_circle(Vector2(-4, -10), 3.0, Color("202020"))
    draw_circle(Vector2(4, -10), 3.0, Color("202020"))
    draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, Color.WHITE, 2.0)
    draw_health_bar()
    draw_string(ThemeDB.fallback_font, Vector2(-40, 45), "%s Lv%d" % [hero_name, level], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
    var mana_ratio := clampf(mana / max_mana, 0.0, 1.0)
    draw_rect(Rect2(-35, 4, 70, 4), Color("18243d"))
    draw_rect(Rect2(-35, 4, 70 * mana_ratio, 4), Color("4d9cff"))
