class_name AstroCoreKernel
extends Node

signal system_ready
signal transaction_committed(kind: String, amount: int)
signal match_recorded(result: String)

var app: Node
var services: Dictionary = {}
var initialized := false

func initialize(app_node: Node) -> void:
    if initialized:
        return
    app = app_node
    services["account"] = AstroAccountService.new()
    services["economy"] = AstroEconomyService.new()
    services["inventory"] = AstroInventoryService.new()
    services["progression"] = AstroProgressionService.new()
    services["settings"] = AstroSettingsService.new()
    services["history"] = AstroHistoryService.new()
    services["match"] = AstroMatchService.new()
    services["game_state"] = AstroGameStateService.new()
    services["network"] = AstroNetworkService.new()
    for service in services.values():
        add_child(service)
        service.initialize(app)
    initialized = true
    system_ready.emit()

func account() -> AstroAccountService:
    return services.get("account")

func economy() -> AstroEconomyService:
    return services.get("economy")

func inventory() -> AstroInventoryService:
    return services.get("inventory")

func progression() -> AstroProgressionService:
    return services.get("progression")

func settings() -> AstroSettingsService:
    return services.get("settings")

func history() -> AstroHistoryService:
    return services.get("history")

func match() -> AstroMatchService:
    return services.get("match")

func network() -> AstroNetworkService:
    return services.get("network")

func game_state() -> AstroGameStateService:
    return services.get("game_state")

func health_report() -> Dictionary:
    var report := {}
    for key in services.keys():
        var svc = services[key]
        report[key] = svc.health()
    return report
