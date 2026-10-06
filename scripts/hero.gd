extends ArenaUnit
class_name ArenaHero

var is_player := false
var is_bot := false
var mana := 100.0
var max_mana := 100.0
var skill_cooldown := 0.0
var respawn_timer := 0.0
var home_position := Vector2.ZERO
var bot_lane_y := 0.0

func _ready() -> void:
    add_to_group("units")
    z_index = 10
    queue_redraw()

func configure(new_team: int, player := false, bot := true, lane_y := 0.0) -> void:
    team = new_team
    is_player = player
    is_bot = bot
    bot_lane_y = lane_y
    setup(team, 1000.0, 85.0, 300.0)
    attack_range = 145.0
    attack_cooldown = 0.55
    home_position = global_position

func _physics_process(delta: float) -> void:
    skill_cooldown = maxf(0.0, skill_cooldown - delta)
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
        velocity = GameState.move_input * move_speed
        if GameState.attack_requested:
            GameState.attack_requested = false
            var target := find_nearest_enemy(attack_range + 35.0)
            if target:
                deal_hit(target)
        if GameState.skill_requested:
            GameState.skill_requested = false
            cast_skill()
    elif is_bot:
        bot_think(delta)
    super._physics_process(delta)

func bot_think(_delta: float) -> void:
    var target := find_nearest_enemy(220.0)
    if target and global_position.distance_to(target.global_position) <= attack_range:
        velocity = Vector2.ZERO
        deal_hit(target)
    else:
        var goal := Vector2(1000.0 if team == 0 else -1000.0, bot_lane_y)
        if target and global_position.distance_to(target.global_position) < 360.0:
            goal = target.global_position
        velocity = global_position.direction_to(goal) * move_speed * 0.72
        if randi() % 120 == 0:
            cast_skill()

func cast_skill() -> void:
    if skill_cooldown > 0.0 or mana < 25.0 or dead:
        return
    mana -= 25.0
    skill_cooldown = 5.0
    for node in get_tree().get_nodes_in_group("units"):
        if node == self or not is_instance_valid(node) or node.dead or node.team == team:
            continue
        if global_position.distance_to(node.global_position) <= 210.0:
            node.take_damage(150.0 + level * 10.0, team)
    for node in get_tree().get_nodes_in_group("structures"):
        if not is_instance_valid(node) or node.dead or node.team == team:
            continue
        if global_position.distance_to(node.global_position) <= 210.0:
            node.take_damage(120.0 + level * 5.0, team)

func die(source_team: int) -> void:
    super.die(source_team)
    velocity = Vector2.ZERO

func _draw() -> void:
    var body := Color("4fa9ff") if team == 0 else Color("ff5a6e")
    draw_circle(Vector2.ZERO, 24.0, body)
    draw_circle(Vector2(0, -7), 11.0, Color("f5d0a5"))
    draw_circle(Vector2(-4, -10), 3.0, Color("202020"))
    draw_circle(Vector2(4, -10), 3.0, Color("202020"))
    draw_arc(Vector2.ZERO, 25.0, 0, TAU, 32, Color("ffffff"), 2.0)
    draw_health_bar()
    draw_string(ThemeDB.fallback_font, Vector2(-32, 44), "Lv %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
