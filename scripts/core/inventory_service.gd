class_name AstroInventoryService
extends AstroServiceBase

func owns(item_id: String) -> bool:
    return item_id in app.data.inventory

func add(item_id: String) -> void:
    if not owns(item_id):
        app.data.inventory.append(item_id)
        app.save_data()

func remove(item_id: String) -> void:
    var idx := app.data.inventory.find(item_id)
    if idx >= 0:
        app.data.inventory.remove_at(idx)
        app.save_data()

func purchase(item: Dictionary) -> bool:
    if owns(str(item.id)):
        return true
    if not app.data.has("coins"):
        return false
    if not spend_price(int(item.price)):
        return false
    add(str(item.id))
    return true

func spend_price(price: int) -> bool:
    if price <= 0 or int(app.data.coins) < price:
        return false
    app.data.coins = int(app.data.coins) - price
    app.save_data()
    return true

func health() -> Dictionary:
    return {"status":"ready", "items": app.data.inventory.size()}
