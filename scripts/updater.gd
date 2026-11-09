extends CanvasLayer
class_name ReleaseUpdater

const API_URL := "https://api.github.com/repos/Strugglechen1337/Scrapforge/releases/latest"
var request: HTTPRequest
var manual := false
var overlay: Control
var previous_focus: Control

static func version_parts(value: String) -> Array:
    var version := value.trim_prefix("v")
    var bits := version.split(".")
    if bits.size() != 3: return []
    var result := []
    for part in bits:
        if part.is_empty() or not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"): return []
        for character in part:
            if character < "0" or character > "9": return []
        result.append(int(part))
    return result

static func is_newer(candidate: String, current: String) -> bool:
    var a := version_parts(candidate)
    var b := version_parts(current)
    if a.is_empty() or b.is_empty(): return false
    for i in range(3):
        if a[i] != b[i]: return a[i] > b[i]
    return false

static func parse_release(body: String) -> Dictionary:
    var parser := JSON.new()
    if parser.parse(body) != OK: return {}
    var data: Variant = parser.data
    if not data is Dictionary: return {}
    if not data.get("tag_name", "") is String or version_parts(data.get("tag_name", "")).is_empty(): return {}
    if not data.get("html_url", "") is String or not data.get("html_url", "").begins_with("https://github.com/"): return {}
    if not data.get("assets", []) is Array: return {}
    return {"tag_name": data.tag_name, "html_url": data.html_url, "body": str(data.get("body", "")), "assets": data.get("assets", [])}

static func asset_url(release: Dictionary, platform: String) -> String:
    if platform != "Android": return str(release.get("html_url", ""))
    for asset in release.get("assets", []):
        if asset is Dictionary and str(asset.get("name", "")).to_lower().ends_with(".apk"):
            var url := str(asset.get("browser_download_url", ""))
            if url.begins_with("https://github.com/"): return url
    return ""

func _ready() -> void:
    layer = 30
    request = HTTPRequest.new()
    request.timeout = 12.0
    add_child(request)
    request.request_completed.connect(_completed)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--fake-update="):
            var tag := arg.trim_prefix("--fake-update=")
            show_release({"tag_name":tag, "body":"Neue Bauteile, Verbesserungen und Fehlerkorrekturen.", "html_url":"https://github.com/Strugglechen1337/Scrapforge/releases/latest", "assets":[]})
            for shot_arg in OS.get_cmdline_user_args():
                if shot_arg.begins_with("--shot-dir="): capture(shot_arg.trim_prefix("--shot-dir="))
            return
    check(false)

func capture(path: String) -> void:
    DirAccess.make_dir_recursive_absolute(path)
    await get_tree().create_timer(1.5).timeout
    await RenderingServer.frame_post_draw
    print("Update-Screenshot: ", get_viewport().get_texture().get_image().save_png(path.path_join("update-dialog.png")))
    get_tree().quit()

func check(is_manual := true) -> void:
    if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        if is_manual: notice("Die Suche läuft bereits.")
        return
    manual = is_manual
    var result := request.request(API_URL, ["User-Agent: Scrapforge-Updater", "Accept: application/vnd.github+json"])
    if result != OK and manual: notice("Update-Suche derzeit nicht möglich.")

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        if manual: notice("Noch kein Release vorhanden." if code == 404 else "Update-Suche derzeit nicht möglich.")
        return
    var release := parse_release(body.get_string_from_utf8())
    if release.is_empty():
        if manual: notice("Release-Antwort konnte nicht gelesen werden.")
        return
    if is_newer(release.tag_name, str(ProjectSettings.get_setting("application/config/version"))): show_release(release)
    elif manual: notice("Du verwendest die aktuelle Version.")

func make_panel() -> VBoxContainer:
    if not is_instance_valid(overlay): previous_focus = get_viewport().gui_get_focus_owner()
    if is_instance_valid(overlay): overlay.queue_free()
    overlay = Control.new()
    add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.03, 0.06, 0.9)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("101f30")
    style.border_color = Color("46f6ef")
    style.set_border_width_all(2)
    style.set_corner_radius_all(6)
    style.content_margin_left = 28
    style.content_margin_right = 28
    style.content_margin_top = 24
    style.content_margin_bottom = 24
    panel.add_theme_stylebox_override("panel", style)
    panel.custom_minimum_size = Vector2(560, 0)
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 16)
    panel.add_child(box)
    return box

func label(text: String, font_size: int) -> Label:
    var result := Label.new()
    result.text = text
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.custom_minimum_size.x = 500
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", Color("d5f3f4"))
    return result

func add_button(box: VBoxContainer, title: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(0, 48)
    button.add_theme_font_size_override("font_size", 20)
    box.add_child(button)
    button.pressed.connect(action)
    return button

func show_release(release: Dictionary) -> void:
    var box := make_panel()
    box.add_child(label("Update verfügbar: " + str(release.tag_name), 28))
    box.add_child(label("Was ist neu?", 20))
    var notes: String = str(release.get("body", "")).strip_edges()
    if notes.is_empty(): notes = "Weitere Informationen auf der Release-Seite."
    if notes.length() > 320: notes = notes.substr(0, 317) + "..."
    box.add_child(label(notes, 18))
    var url := asset_url(release, OS.get_name())
    var download := add_button(box, "Herunterladen", func():
        if not url.is_empty(): OS.shell_open(url)
        else: notice("Keine APK für dieses Release verfügbar.")
    )
    add_button(box, "Später", close)
    download.grab_focus()

func notice(message: String) -> void:
    var box := make_panel()
    box.add_child(label(message, 22))
    var button := add_button(box, "OK", close)
    button.grab_focus()

func close() -> void:
    if is_instance_valid(overlay): overlay.queue_free()
    overlay = null
    if is_instance_valid(previous_focus): previous_focus.call_deferred("grab_focus")
