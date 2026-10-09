class_name AstroSettingsService
extends AstroServiceBase

func set_bool(key: String, value: bool) -> void:
    app.data[key] = value
    app.save_data()

func set_value(key: String, value) -> void:
    app.data[key] = value
    app.save_data()

func get_value(key: String, fallback):
    return app.data.get(key, fallback)

func health() -> Dictionary:
    return {"status":"ready", "graphics": str(app.data.get("graphics_quality", "High")), "fps": int(app.data.get("fps_cap", 60))}
