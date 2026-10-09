class_name AstroGameStateService
extends AstroServiceBase

var state: Dictionary = {}

func set_state(value: Dictionary) -> void:
    state = value.duplicate(true)

func clear() -> void:
    state = {}

func active() -> bool:
    return not state.is_empty() and str(state.get("status", "idle")) == "running"

func finished() -> bool:
    return not state.is_empty() and str(state.get("status", "idle")) == "finished"

func match_id() -> String:
    return str(state.get("match_id", ""))

func health() -> Dictionary:
    return {
        "status": "running" if active() else ("finished" if finished() else "idle"),
        "match_id": match_id(),
        "authoritative": not state.is_empty(),
        "version": int(state.get("version", 0))
    }
