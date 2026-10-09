class_name AstroProgressionService
extends AstroServiceBase

func add_xp(amount: int) -> void:
    var xp := int(app.data.xp) + max(amount, 0)
    var level := int(app.data.level)
    while xp >= 500:
        xp -= 500
        level += 1
    app.data.xp = xp
    app.data.level = level
    app.save_data()

func add_rank_points(amount: int) -> void:
    app.data.rank_points = max(0, int(app.data.rank_points) + amount)
    app.save_data()

func health() -> Dictionary:
    return {"status":"ready", "level": int(app.data.level), "xp": int(app.data.xp), "rank": str(app.data.rank)}
