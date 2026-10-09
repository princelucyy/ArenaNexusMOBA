class_name AstroServiceBase
extends Node

var app: Node

func initialize(app_node: Node) -> void:
    app = app_node

func health() -> Dictionary:
    return {"status":"ready", "service": get_class()}
