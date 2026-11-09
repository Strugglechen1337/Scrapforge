extends RefCounted
class_name ScrapUI

const ORANGE := Color("ff7a1a")
const CYAN := Color("33f5ff")
const PANEL_BG := Color(0.055, 0.078, 0.118, 0.88)
const PANEL_DARK := Color(0.035, 0.052, 0.082, 0.94)
const BORDER_STEEL := Color("4f647d")
const TEXT_LIGHT := Color("edf4fa")
const TEXT_MUTED := Color("9bb0c4")

static var _cached_theme: Theme
static var _heavy_font: FontVariation

static func get_theme() -> Theme:
	if not _cached_theme:
		_cached_theme = load("res://ui/theme.tres") as Theme
	return _cached_theme

static func get_heavy_font() -> FontVariation:
	if not _heavy_font:
		_heavy_font = FontVariation.new()
		_heavy_font.variation_embolden = 0.55
		_heavy_font.spacing_glyph = 2
	return _heavy_font

static func make_chamfer_style(bg: Color, border: Color, border_w := 2, corner := 10, accent_left := 0, glow_color := Color(0, 0, 0, 0), glow_size := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	if accent_left > 0:
		s.border_width_left = accent_left
	s.set_corner_radius_all(corner)
	s.corner_detail = 1
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	if glow_size > 0:
		s.shadow_color = glow_color
		s.shadow_size = glow_size
	return s

static func style_button(b: Button, accent: Color = ORANGE, min_size := Vector2(360, 54)) -> void:
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	var normal := make_chamfer_style(Color(0.075, 0.105, 0.155, 0.92), Color(0.32, 0.44, 0.57, 0.95), 1, 8, 4)
	var hover := make_chamfer_style(Color(0.135, 0.18, 0.25, 0.97), accent, 2, 8, 6, Color(accent.r, accent.g, accent.b, 0.35), 7)
	var focus := make_chamfer_style(Color(0.165, 0.215, 0.295, 0.99), accent, 3, 8, 7, Color(accent.r, accent.g, accent.b, 0.55), 10)
	var pressed := make_chamfer_style(Color(0.22, 0.14, 0.08, 0.99), CYAN, 3, 8, 7, Color(CYAN.r, CYAN.g, CYAN.b, 0.45), 8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", TEXT_LIGHT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color("fff4e6"))
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.pivot_offset = min_size * 0.5
	b.focus_entered.connect(func():
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(1.025, 1.025)
	)
	b.focus_exited.connect(func():
		b.scale = Vector2.ONE
	)
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(1.015, 1.015)
	)
	b.mouse_exited.connect(func():
		if not b.has_focus():
			b.scale = Vector2.ONE
	)

static func socket_label(id: String, socket: String) -> String:
	if id == "swarm":
		return "★ ENTWICKLUNG · SCHULTER-SCHWARM"
	match socket:
		"right_arm", "left_arm":
			return "WAFFENARM"
		"left_shoulder":
			return "SCHULTER LINKS"
		"right_shoulder":
			return "SCHULTER RECHTS"
		"back":
			return "RÜCKENMODUL"
		"head":
			return "KOPFSENSOR"
		"core":
			return "CHASSIS-KERN"
		"legs":
			return "BEINPANZERUNG"
		_:
			return "SYSTEMMODUL"

static func module_accent(id: String) -> Color:
	match id:
		"laser":
			return Color("c65cff")
		"plasma", "shield", "thruster", "radar", "drone", "magnet", "cooldown", "swarm":
			return CYAN
		_:
			return ORANGE


class LogoControl extends Control:
	func _init(custom_size := Vector2(460, 138)) -> void:
		custom_minimum_size = custom_size
		size = custom_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var cx := w * 0.5
		var gear_center := Vector2(cx, 50.0)
		var gear_outer := 42.0
		var gear_inner := 33.0
		# Soft orange glow behind cogwheel
		draw_circle(gear_center, 58.0, Color(1.0, 0.42, 0.05, 0.10))
		draw_circle(gear_center, 46.0, Color(1.0, 0.48, 0.10, 0.18))
		# Draw 12 cog teeth on top half + sides
		var teeth := 12
		for i in range(teeth):
			var a := TAU * float(i) / float(teeth)
			var a1 := a - 0.13
			var a2 := a + 0.13
			var a3 := a + 0.09
			var a4 := a - 0.09
			var pts := PackedVector2Array([
				gear_center + Vector2(cos(a1), sin(a1)) * (gear_inner - 2.0),
				gear_center + Vector2(cos(a4), sin(a4)) * gear_outer,
				gear_center + Vector2(cos(a3), sin(a3)) * gear_outer,
				gear_center + Vector2(cos(a2), sin(a2)) * (gear_inner - 2.0),
			])
			draw_colored_polygon(pts, Color("ff7a1a"))
			draw_polyline(pts, Color("ffb366"), 1.5, true)
		draw_arc(gear_center, gear_inner, 0, TAU, 48, Color("ff7a1a"), 7.0)
		draw_arc(gear_center, gear_inner - 4.0, 0, TAU, 48, Color("ffb067"), 1.5)
		draw_circle(gear_center, gear_inner - 7.0, Color("0b111a"))
		draw_arc(gear_center, gear_inner - 11.0, 0, TAU, 36, Color("3c4f65"), 2.0)

		# Side wings / industrial frame bars behind text
		var bar_y := 60.0
		var plate_pts := PackedVector2Array([
			Vector2(14, bar_y - 24),
			Vector2(w - 14, bar_y - 24),
			Vector2(w - 4, bar_y),
			Vector2(w - 14, bar_y + 24),
			Vector2(14, bar_y + 24),
			Vector2(4, bar_y),
		])
		draw_colored_polygon(plate_pts, Color(0.05, 0.075, 0.115, 0.94))
		draw_polyline(plate_pts, Color("4a5f78"), 2.0, true)
		draw_line(Vector2(22, bar_y - 24), Vector2(w - 22, bar_y - 24), Color(1.0, 0.48, 0.10, 0.85), 2.0)
		draw_line(Vector2(22, bar_y + 24), Vector2(w - 22, bar_y + 24), Color(0.20, 0.96, 1.0, 0.65), 1.5)
		# Glowing side sparks / rivets
		draw_circle(Vector2(16, bar_y), 4.5, Color(0.2, 0.96, 1.0, 0.9))
		draw_circle(Vector2(w - 16, bar_y), 4.5, Color(1.0, 0.48, 0.1, 0.95))

		# Metallic "SCRAPFORGE" lettering
		var font := ScrapUI.get_heavy_font()
		var title_text := "SCRAPFORGE"
		var fsize := 46
		var tsize := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var tx := (w - tsize.x) * 0.5
		var ty := bar_y + 16.0
		# Drop shadow + dark steel contour
		draw_string(font, Vector2(tx + 3, ty + 4), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.02, 0.03, 0.05, 0.95))
		draw_string_outline(font, Vector2(tx, ty), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 7, Color("141d29"))
		# Warm orange bottom rim glow
		draw_string(font, Vector2(tx, ty + 2), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color("ff7a1a"))
		# Lower metallic steel tone
		draw_string(font, Vector2(tx, ty), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color("b8c4d0"))
		# Upper metallic bright highlight
		draw_string(font, Vector2(tx, ty - 1.5), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color("f2f7fc"))

		# Subtitle with flanking orange/cyan lines
		var sub_y := 112.0
		var sub_text := "MODULARER ROGUELIKE SURVIVOR"
		var sub_size := 13
		var st_size := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size)
		var sx := (w - st_size.x) * 0.5
		draw_line(Vector2(20, sub_y - 5), Vector2(sx - 12, sub_y - 5), Color("ff7a1a"), 2.0)
		draw_line(Vector2(sx + st_size.x + 12, sub_y - 5), Vector2(w - 20, sub_y - 5), Color("ff7a1a"), 2.0)
		draw_string(font, Vector2(sx, sub_y), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color("d7e3ee"))


class ModuleIcon extends Control:
	var module_id := "minigun"
	var compact := false

	func _init(id := "minigun", is_compact := false) -> void:
		module_id = id
		compact = is_compact
		custom_minimum_size = Vector2(40, 40) if compact else Vector2(120, 82)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := 0.42 if compact else 1.0
		var accent := ScrapUI.module_accent(module_id)
		var steel := Color("9aa8b8")
		var dark := Color("243142")
		var hi := Color("dce6f2")
		if not compact:
			var bg_rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
			draw_rect(bg_rect, Color(0.03, 0.05, 0.08, 0.85), true)
			draw_rect(bg_rect, Color(accent.r, accent.g, accent.b, 0.45), false, 1.5)
			draw_circle(c, 30.0, Color(accent.r, accent.g, accent.b, 0.12))
		match module_id:
			"minigun":
				draw_rect(Rect2(c + Vector2(-34, -14) * s, Vector2(28, 28) * s), steel, true)
				draw_rect(Rect2(c + Vector2(-30, -10) * s, Vector2(20, 8) * s), ORANGE, true)
				for i in range(4):
					var by := (-11.0 + i * 7.0) * s
					draw_rect(Rect2(c + Vector2(-6, by - 2.0 * s), Vector2(36 * s, 4.2 * s)), dark, true)
					draw_circle(c + Vector2(31 * s, by), 3.2 * s, ORANGE)
			"rocket", "swarm":
				var cols := 3 if module_id == "swarm" else 2
				var w := 52.0 if module_id == "swarm" else 42.0
				draw_rect(Rect2(c + Vector2(-w * 0.5, -22) * s, Vector2(w, 44) * s), steel, true)
				draw_rect(Rect2(c + Vector2(-w * 0.5 + 4, -18) * s, Vector2(w - 8, 36) * s), dark, true)
				for row in range(2):
					for col in range(cols):
						var rx := (-10.0 + col * 20.0) if cols == 2 else (-16.0 + col * 16.0)
						var ry := -9.0 + row * 18.0
						draw_circle(c + Vector2(rx, ry) * s, 6.5 * s, ORANGE if module_id == "rocket" else CYAN)
						draw_circle(c + Vector2(rx, ry) * s, 3.2 * s, Color("fff3b0"))
			"laser":
				draw_rect(Rect2(c + Vector2(-34, -12) * s, Vector2(34, 24) * s), steel, true)
				draw_rect(Rect2(c + Vector2(0, -8) * s, Vector2(28, 16) * s), dark, true)
				draw_line(c + Vector2(-24, 0) * s, c + Vector2(36, 0) * s, Color("d46bff"), 6.0 * s)
				draw_circle(c + Vector2(30, 0) * s, 7.0 * s, Color("e8a8ff"))
			"flamethrower":
				draw_rect(Rect2(c + Vector2(-34, -11) * s, Vector2(36, 22) * s), steel, true)
				draw_rect(Rect2(c + Vector2(-28, -6) * s, Vector2(18, 12) * s), ORANGE, true)
				var flame := PackedVector2Array([
					c + Vector2(4, -7) * s,
					c + Vector2(36, -15) * s,
					c + Vector2(28, 0) * s,
					c + Vector2(38, 15) * s,
					c + Vector2(4, 7) * s,
				])
				draw_colored_polygon(flame, ORANGE)
				draw_circle(c + Vector2(16, 0) * s, 6.5 * s, Color("ffe07d"))
			"plasma":
				draw_rect(Rect2(c + Vector2(-34, -13) * s, Vector2(38, 26) * s), steel, true)
				draw_circle(c + Vector2(18, 0) * s, 14.0 * s, Color(0.2, 0.96, 1.0, 0.35))
				draw_circle(c + Vector2(18, 0) * s, 9.5 * s, CYAN)
				draw_circle(c + Vector2(18, 0) * s, 5.0 * s, Color.WHITE)
			"saw":
				for i in range(10):
					var a := TAU * float(i) / 10.0
					var p1 := c + Vector2(cos(a - 0.18), sin(a - 0.18)) * 18.0 * s
					var p2 := c + Vector2(cos(a + 0.18), sin(a + 0.18)) * 18.0 * s
					var tip := c + Vector2(cos(a + 0.08), sin(a + 0.08)) * 27.0 * s
					draw_colored_polygon(PackedVector2Array([p1, tip, p2]), hi)
				draw_circle(c, 19.0 * s, steel)
				draw_circle(c, 8.0 * s, dark)
				draw_circle(c, 4.0 * s, ORANGE)
			"drone":
				for side: float in [-1.0, 1.0]:
					draw_line(c, c + Vector2(side * 22, -14) * s, steel, 3.0 * s)
					draw_circle(c + Vector2(side * 22, -14) * s, 7.0 * s, dark)
				draw_circle(c, 14.0 * s, steel)
				draw_circle(c, 7.0 * s, CYAN)
			"turret":
				draw_rect(Rect2(c + Vector2(-24, -6) * s, Vector2(32, 22) * s), ORANGE, true)
				draw_rect(Rect2(c + Vector2(-20, -16) * s, Vector2(26, 14) * s), steel, true)
				draw_rect(Rect2(c + Vector2(6, -14) * s, Vector2(26, 5) * s), dark, true)
				draw_rect(Rect2(c + Vector2(6, -5) * s, Vector2(26, 5) * s), dark, true)
				draw_circle(c + Vector2(32, -11.5) * s, 3.0 * s, ORANGE)
				draw_circle(c + Vector2(32, -2.5) * s, 3.0 * s, ORANGE)
			"thruster":
				for side: float in [-1.0, 1.0]:
					var bx: float = side * 13.0 * s
					draw_rect(Rect2(c + Vector2(bx - 9.0 * s, -20.0 * s), Vector2(18, 26) * s), steel, true)
					var jet := PackedVector2Array([
						c + Vector2(bx - 6.0 * s, 6.0 * s),
						c + Vector2(bx + 6.0 * s, 6.0 * s),
						c + Vector2(bx, 26.0 * s),
					])
					draw_colored_polygon(jet, CYAN)
			"armor":
				var sh := PackedVector2Array([
					c + Vector2(-22, -22) * s,
					c + Vector2(22, -22) * s,
					c + Vector2(26, 4) * s,
					c + Vector2(0, 26) * s,
					c + Vector2(-26, 4) * s,
				])
				draw_colored_polygon(sh, steel)
				draw_polyline(sh, hi, 2.0 * s, true)
				draw_rect(Rect2(c + Vector2(-12, -8) * s, Vector2(24, 6) * s), ORANGE, true)
			"shield":
				var hex := PackedVector2Array()
				for i in range(7):
					var a := TAU * float(i % 6) / 6.0 - PI / 6.0
					hex.append(c + Vector2(cos(a), sin(a)) * 24.0 * s)
				draw_colored_polygon(hex.slice(0, 6), Color(0.05, 0.45, 0.55, 0.55))
				draw_polyline(hex, CYAN, 2.8 * s, true)
				var inner := PackedVector2Array()
				for i in range(7):
					var a := TAU * float(i % 6) / 6.0 - PI / 6.0
					inner.append(c + Vector2(cos(a), sin(a)) * 11.0 * s)
				draw_polyline(inner, Color.WHITE, 1.6 * s, true)
			"sensor", "radar":
				draw_rect(Rect2(c + Vector2(-20, -4) * s, Vector2(40, 20) * s), steel, true)
				draw_line(c + Vector2(12, -4) * s, c + Vector2(18, -24) * s, hi, 3.0 * s)
				draw_circle(c + Vector2(18, -24) * s, 4.0 * s, ORANGE)
				draw_circle(c + Vector2(-6, 6) * s, 6.0 * s, CYAN)
				draw_arc(c + Vector2(-6, 6) * s, 14.0 * s, -PI * 0.85, -PI * 0.15, 16, CYAN, 2.0 * s)
			"magnet":
				draw_arc(c + Vector2(0, 2) * s, 16.0 * s, PI, TAU, 24, ORANGE, 6.0 * s)
				draw_rect(Rect2(c + Vector2(-19, 2) * s, Vector2(6, 14) * s), hi, true)
				draw_rect(Rect2(c + Vector2(13, 2) * s, Vector2(6, 14) * s), CYAN, true)
			"cooldown":
				draw_arc(c, 19.0 * s, 0, TAU, 32, CYAN, 3.0 * s)
				draw_line(c, c + Vector2(0, -12) * s, Color.WHITE, 3.0 * s)
				draw_line(c, c + Vector2(10, 4) * s, ORANGE, 3.0 * s)
			_:
				draw_circle(c, 16.0 * s, accent)
