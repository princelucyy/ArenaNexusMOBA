extends Node

var move_input := Vector2.ZERO
var attack_requested := false
var skill1_requested := false
var skill2_requested := false
var ultimate_requested := false
var shop_requested := false
var match_time := 0.0
var match_over := false
var winner_team := -1
var blue_kills := 0
var red_kills := 0
var blue_gold := 0
var red_gold := 0
var wave_number := 0

func _process(delta: float) -> void:
    if not match_over:
        match_time += delta

func reset_match() -> void:
    move_input = Vector2.ZERO
    attack_requested = false
    skill1_requested = false
    skill2_requested = false
    ultimate_requested = false
    shop_requested = false
    match_time = 0.0
    match_over = false
    winner_team = -1
    blue_kills = 0
    red_kills = 0
    blue_gold = 0
    red_gold = 0
    wave_number = 0
