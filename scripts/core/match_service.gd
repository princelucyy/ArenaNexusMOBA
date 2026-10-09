class_name AstroMatchService
extends AstroServiceBase

var state := "idle"
var started_at_ms := 0

func start(mode: String = "Classic 5v5 AI") -> void:
    state = "running"
    started_at_ms = Time.get_ticks_msec()
    app.data.match_mode = mode

func finish(victory: bool, kills: int, deaths: int, assists: int, gold: int, objective: int, hero: String) -> Dictionary:
    if state != "running":
        start(app.data.get("match_mode", "Classic 5v5 AI"))
    state = "finished"
    var elapsed := int((Time.get_ticks_msec() - started_at_ms) / 1000)
    var result := {
        "result": "Victory" if victory else "Defeat",
        "duration": "%02d:%02d" % [elapsed / 60, elapsed % 60],
        "kills": kills,
        "deaths": deaths,
        "assists": assists,
        "gold": gold,
        "objective": objective,
        "hero": hero,
        "timestamp": Time.get_unix_time_from_system()
    }
    return result

func health() -> Dictionary:
    return {"status":"ready", "state": state}
