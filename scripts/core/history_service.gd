class_name AstroHistoryService
extends AstroServiceBase

func record(result: Dictionary) -> void:
    app.data.history.push_front(result)
    if app.data.history.size() > 50:
        app.data.history.resize(50)
    app.save_data()

func all() -> Array:
    return app.data.history

func health() -> Dictionary:
    return {"status":"ready", "records": app.data.history.size()}
