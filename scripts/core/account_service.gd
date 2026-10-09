class_name AstroAccountService
extends AstroServiceBase

func register_local(username: String, password: String) -> bool:
    if app == null or username.strip_edges().length() < 3 or password.length() < 8:
        return false
    app.data.username = username.strip_edges()
    app.data.password_hash = password.sha256_text()
    app.data.logged_in = true
    app.data.profile_complete = false
    app.save_data()
    return true

func login_local(username: String, password: String) -> bool:
    if app == null:
        return false
    var ok := not str(app.data.username).is_empty() \
        and username.strip_edges().to_lower() == str(app.data.username).to_lower() \
        and password.sha256_text() == str(app.data.password_hash)
    if ok:
        app.data.logged_in = true
        app.save_data()
    return ok

func guest() -> bool:
    if app == null:
        return false
    app.data.username = "Guest"
    app.data.password_hash = ""
    app.data.logged_in = true
    app.data.profile_complete = false
    app.save_data()
    return true

func logout() -> void:
    if app == null:
        return
    app.data.logged_in = false
    app.save_data()
