extends Node

var move_input := Vector2.ZERO
var attack_requested := false
var skill_requested := false
var match_time := 0.0
var match_over := false
var winner_team := -1

func _process(delta: float) -> void:
    match_time += delta
