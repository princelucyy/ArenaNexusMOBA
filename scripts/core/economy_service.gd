class_name AstroEconomyService
extends AstroServiceBase

func coins() -> int:
    return int(app.data.coins)

func diamonds() -> int:
    return int(app.data.diamonds)

func earn_coins(amount: int) -> void:
    if amount <= 0: return
    app.data.coins = int(app.data.coins) + amount
    app.save_data()

func spend_coins(amount: int) -> bool:
    if amount <= 0 or coins() < amount:
        return false
    app.data.coins = coins() - amount
    app.save_data()
    return true

func health() -> Dictionary:
    return {"status":"ready", "coins": coins(), "diamonds": diamonds()}
