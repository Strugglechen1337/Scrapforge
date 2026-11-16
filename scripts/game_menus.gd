class_name GameMenus
extends RefCounted


static func button(game, text: String, action: Callable, accent: Color = ScrapUI.ORANGE, min_size := Vector2(380, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	ScrapUI.style_button(b, accent, min_size)
	b.pressed.connect(func():
		game.ui_confirmed.emit(b)
		action.call()
	)
	return b


static func heading(text: String, size := 36, color: Color = ScrapUI.ORANGE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func wire_vertical_focus(buttons: Array[Control]) -> void:
	var count := buttons.size()
	for i in range(count):
		buttons[i].focus_neighbor_top = buttons[(i - 1 + count) % count].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % count].get_path()


static func wire_horizontal_focus(buttons: Array[Button]) -> void:
	var count := buttons.size()
	for i in range(count):
		buttons[i].focus_neighbor_left = buttons[(i - 1 + count) % count].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % count].get_path()


static func show_menu(game) -> void:
	game.play_music("menu")
	game.mode = "menu"
	game.clear_ui()
	game.menu_buttons.clear()
	var left_col := VBoxContainer.new()
	left_col.position = Vector2(54, 34)
	left_col.add_theme_constant_override("separation", 18)
	game.panel.add_child(left_col)

	var logo := ScrapUI.LogoControl.new(Vector2(450, 134))
	left_col.add_child(logo)

	var menu_frame := PanelContainer.new()
	var frame_style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.88), ScrapUI.BORDER_STEEL, 2, 12, 5)
	frame_style.content_margin_left = 22
	frame_style.content_margin_right = 22
	frame_style.content_margin_top = 20
	frame_style.content_margin_bottom = 20
	menu_frame.add_theme_stylebox_override("panel", frame_style)
	left_col.add_child(menu_frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	menu_frame.add_child(box)

	var open_settings := func():
		game.resume_mode = "menu"
		game.show_settings()
	var entries := [
		["START", game.start_game, ScrapUI.ORANGE],
		["DEIN HANGAR", game.show_hangar, ScrapUI.CYAN],
		["EINSTELLUNGEN", open_settings, ScrapUI.ORANGE],
		["NACH UPDATES SUCHEN", func(): game.updater.check(true), ScrapUI.CYAN],
		["MITWIRKENDE", game.show_credits, ScrapUI.CYAN],
		["BEENDEN", func(): game.get_tree().quit(), ScrapUI.ORANGE],
	]
	var focus_controls: Array[Control] = []
	for entry in entries:
		var b := button(game, entry[0], entry[1], entry[2], Vector2(400, 54))
		box.add_child(b)
		game.menu_buttons.append(b)
		focus_controls.append(b)
	wire_vertical_focus(focus_controls)

	# Right side Mech platform badge & version label
	var skin_res: SkinDefinition = game.get_selected_skin_resource()
	var skin_title := skin_res.title.to_upper() if skin_res else "STANDARD"
	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.82), ScrapUI.ORANGE, 1, 8, 4))
	badge_panel.position = Vector2(740, 36)
	game.panel.add_child(badge_panel)
	ScrapUI.anchor_horizontal(badge_panel, 1.0)
	var badge_lbl := heading("HANGAR-EINHEIT  //  SKIN: " + skin_title, 15, ScrapUI.CYAN)
	badge_panel.add_child(badge_lbl)

	var ver_str := "v" + str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	var ver_lbl := heading("SCRAPFORGE " + ver_str, 15, ScrapUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	ver_lbl.position = Vector2(980, 756)
	ver_lbl.custom_minimum_size = Vector2(268, 28)
	game.panel.add_child(ver_lbl)
	ScrapUI.anchor_horizontal(ver_lbl, 1.0)

	if not game.menu_buttons.is_empty():
		game.menu_buttons[0].grab_focus()
	if is_instance_valid(game.world_3d):
		game.world_3d.update_view()
	game.queue_redraw()


static func show_credits(game) -> void:
	game.mode = "credits"
	game.clear_ui()
	var frame := PanelContainer.new()
	frame.position = Vector2(54, 34)
	frame.custom_minimum_size = Vector2(1100, 720)
	frame.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.96), ScrapUI.CYAN, 2, 12, 6))
	game.panel.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	box.add_child(heading("MITWIRKENDE", 28, ScrapUI.CYAN))
	var credits := RichTextLabel.new()
	credits.custom_minimum_size = Vector2(1000, 560)
	credits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	credits.scroll_active = true
	credits.text = FileAccess.get_file_as_string("res://CREDITS.md")
	credits.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(credits)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	var up := button(game, "▲", func(): credits.get_v_scroll_bar().value -= 180, ScrapUI.CYAN, Vector2(90, 52))
	var down := button(game, "▼", func(): credits.get_v_scroll_bar().value += 180, ScrapUI.CYAN, Vector2(90, 52))
	var back := button(game, "ZURÜCK (ESC / B)", game.show_menu, ScrapUI.ORANGE, Vector2(300, 52))
	for control in [up, down, back]:
		controls.add_child(control)
	wire_horizontal_focus([up, down, back])
	down.grab_focus()
	if is_instance_valid(game.world_3d):
		game.world_3d.update_view()
	game.queue_redraw()


static func show_hangar(game) -> void:
	game.mode = "hangar"
	game.clear_ui()
	game.hangar_buttons.clear()
	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.90), ScrapUI.CYAN, 2, 12, 6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(20, 36)
	frame.custom_minimum_size = Vector2(350, 720)
	game.panel.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	frame.add_child(box)

	box.add_child(heading("DEIN HANGAR", 28, ScrapUI.ORANGE))
	box.add_child(heading("CHASSIS · ARENA · LACKIERUNG", 13, ScrapUI.CYAN))

	var focus_controls: Array[Control] = []
	var chassis_row := HBoxContainer.new()
	chassis_row.add_theme_constant_override("separation", 6)
	box.add_child(chassis_row)
	var visible_chassis: Array[String] = []
	for cid: String in ChassisCatalog.CHASSIS_IDS:
		if ChassisCatalog.has_unique_model(cid):
			visible_chassis.append(cid)
	var chassis_w := int((310 - 6 * maxi(0, visible_chassis.size() - 1)) / maxi(1, visible_chassis.size()))
	for cid: String in visible_chassis:
		var cdef: Dictionary = ChassisCatalog.get_def(cid)
		var unlocked: bool = game.progress.is_chassis_unlocked(cid)
		var is_sel: bool = (game.progress.selected_chassis == cid)
		var label_txt: String = cdef["title"].split(" ")[0] if unlocked else ("🔒 " + cdef["title"].split(" ")[0])
		var cb := button(game, label_txt, func():
			if unlocked:
				game.progress.selected_chassis = cid
				game.progress.save()
				game.show_hangar()
		, ScrapUI.CYAN if is_sel else (ScrapUI.ORANGE if unlocked else ScrapUI.BORDER_STEEL), Vector2(chassis_w, 38))
		cb.disabled = not unlocked
		cb.set_meta("chassis_id", cid)
		chassis_row.add_child(cb)
		focus_controls.append(cb)

	var arena_row := HBoxContainer.new()
	arena_row.add_theme_constant_override("separation", 6)
	box.add_child(arena_row)
	var visible_arenas: Array[String] = []
	for aid: String in ArenaCatalog.ARENA_IDS:
		if ArenaCatalog.has_unique_scene(aid):
			visible_arenas.append(aid)
	var arena_w := int((310 - 6 * maxi(0, visible_arenas.size() - 1)) / maxi(1, visible_arenas.size()))
	for aid: String in visible_arenas:
		var adef: Dictionary = ArenaCatalog.get_def(aid)
		var unlocked_a: bool = game.progress.is_arena_unlocked(aid)
		var is_sel_a: bool = (game.progress.selected_arena == aid)
		var a_txt: String = adef["title"] if unlocked_a else ("🔒 " + adef["title"])
		var ab := button(game, a_txt, func():
			if unlocked_a:
				game.progress.selected_arena = aid
				game.progress.save()
				game.show_hangar()
		, ScrapUI.CYAN if is_sel_a else (ScrapUI.ORANGE if unlocked_a else ScrapUI.BORDER_STEEL), Vector2(arena_w, 38))
		ab.disabled = not unlocked_a
		ab.set_meta("arena_id", aid)
		arena_row.add_child(ab)
		focus_controls.append(ab)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(1.0, 0.48, 0.10, 0.65)
	box.add_child(sep)

	for skin_id: String in game.SKIN_IDS:
		var skin_def: SkinDefinition = game.skins[skin_id]
		var is_active: bool = (skin_id == game.selected_skin)
		var suffix: String = "   [ AKTIV ]" if is_active else ("   · TARN" if skin_def.camouflage else "")
		var b := button(game, "      " + skin_def.title.to_upper() + suffix, func():
			game.select_skin(skin_id)
			game.show_hangar()
		, ScrapUI.CYAN if is_active else ScrapUI.ORANGE, Vector2(310, 42))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Color swatches inside button
		var swatch_armor := ColorRect.new()
		swatch_armor.color = skin_def.armor_color
		swatch_armor.position = Vector2(18, 9)
		swatch_armor.size = Vector2(20, 26)
		swatch_armor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(swatch_armor)
		var swatch_accent := ColorRect.new()
		swatch_accent.color = skin_def.accent_color
		swatch_accent.position = Vector2(38, 9)
		swatch_accent.size = Vector2(12, 26)
		swatch_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(swatch_accent)
		b.focus_entered.connect(func():
			game.select_skin(skin_id)
		)
		box.add_child(b)
		game.hangar_buttons.append(b)
		focus_controls.append(b)

	var unlocks_btn := button(game, "ZIELE & FREISCHALTUNGEN", game.show_unlocks, ScrapUI.CYAN, Vector2(310, 42))
	unlocks_btn.set_meta("open_unlocks", true)
	box.add_child(unlocks_btn)
	focus_controls.append(unlocks_btn)

	var back := button(game, "ZURÜCK ZUM HAUPTMENÜ", game.show_menu, ScrapUI.ORANGE, Vector2(310, 44))
	box.add_child(back)
	focus_controls.append(back)

	# Right panel: permanent Hangar upgrades
	var upg_frame := PanelContainer.new()
	var upg_style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.90), ScrapUI.ORANGE, 2, 12, 6)
	upg_style.content_margin_left = 18
	upg_style.content_margin_right = 18
	upg_style.content_margin_top = 18
	upg_style.content_margin_bottom = 18
	upg_frame.add_theme_stylebox_override("panel", upg_style)
	upg_frame.position = Vector2(884, 36)
	upg_frame.custom_minimum_size = Vector2(376, 700)
	game.panel.add_child(upg_frame)
	ScrapUI.anchor_horizontal(upg_frame, 1.0)

	var ubox := VBoxContainer.new()
	ubox.add_theme_constant_override("separation", 7)
	upg_frame.add_child(ubox)
	ubox.add_child(heading("DAUERHAFTE UPGRADES", 22, ScrapUI.ORANGE))
	ubox.add_child(heading("SCHROTT-KONTO: %d" % game.progress.scrap, 15, ScrapUI.CYAN))

	var usep := ColorRect.new()
	usep.custom_minimum_size = Vector2(0, 2)
	usep.color = Color(0.20, 0.96, 1.0, 0.45)
	ubox.add_child(usep)

	var any_bought := false
	for uid: String in ProgressState.UPGRADE_IDS:
		var cfg: Dictionary = ProgressState.UPGRADES[uid]
		var lv: int = game.progress.level(uid)
		var max_lv: int = int(cfg["max_level"])
		if lv > 0:
			any_bought = true
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.03, 0.048, 0.08, 0.92), ScrapUI.CYAN if lv > 0 else ScrapUI.BORDER_STEEL, 1, 8))
		ubox.add_child(row)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		var t_lbl := heading("%s  (S%d/%d)" % [cfg["title"], lv, max_lv], 13, Color.WHITE)
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_lbl.custom_minimum_size = Vector2(168, 0)
		info.add_child(t_lbl)
		var d_lbl := heading(cfg["desc"], 11, ScrapUI.TEXT_MUTED)
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.custom_minimum_size = Vector2(168, 0)
		info.add_child(d_lbl)
		hbox.add_child(info)
		var can_buy: bool = game.progress.can_buy(uid)
		var btn_txt := "MAX" if lv >= max_lv else ("%d SCHROTT" % game.progress.cost(uid))
		var buy_btn := button(game, btn_txt, func():
			if game.progress.buy(uid):
				game.progress.save()
				game.play_sfx(&"upgrade")
				game.show_hangar()
		, ScrapUI.CYAN if can_buy else ScrapUI.BORDER_STEEL, Vector2(118, 38))
		buy_btn.disabled = not can_buy
		buy_btn.set_meta("progress_buy_id", uid)
		hbox.add_child(buy_btn)
		focus_controls.append(buy_btn)

	var uspacer := Control.new()
	uspacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ubox.add_child(uspacer)

	var reset_btn := button(game, "ALLE ZURÜCKSETZEN (100 %)", func():
		if game.progress.reset_upgrades() > 0:
			game.progress.save()
			game.play_sfx(&"upgrade")
			game.show_hangar()
	, ScrapUI.ORANGE, Vector2(316, 40))
	reset_btn.disabled = not any_bought
	reset_btn.set_meta("progress_reset", true)
	ubox.add_child(reset_btn)
	focus_controls.append(reset_btn)

	wire_vertical_focus(focus_controls)

	var active_idx := maxi(0, game.SKIN_IDS.find(game.selected_skin))
	game.hangar_buttons[active_idx].grab_focus()
	if is_instance_valid(game.world_3d):
		game.world_3d.update_view()
	game.queue_redraw()


static func show_unlocks(game) -> void:
	game.mode = "unlocks"
	game.clear_ui()
	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.94), ScrapUI.CYAN, 2, 12, 6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(180, 48)
	frame.custom_minimum_size = Vector2(920, 704)
	game.panel.add_child(frame)
	ScrapUI.anchor_horizontal(frame, 0.5)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	box.add_child(heading("FREISCHALT-ZIELE", 34, ScrapUI.ORANGE))
	box.add_child(heading("MEILENSTEINE FÜR CHASSIS, ARENEN & BONUS-SCHROTT", 15, ScrapUI.CYAN))

	for gid: String in UnlockCatalog.GOAL_IDS:
		var cfg: Dictionary = UnlockCatalog.GOALS[gid]
		var done: bool = gid in game.progress.unlocked_goals
		var cur: int = int(game.progress.stats.get(cfg["stat"], 0))
		var target: int = int(cfg["target"])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.03, 0.048, 0.08, 0.92), ScrapUI.CYAN if done else ScrapUI.BORDER_STEEL, 2 if done else 1, 8))
		row.set_meta("unlock_goal_id", gid)
		box.add_child(row)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		row.add_child(hbox)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 2)
		left.add_child(heading(cfg["title"] + "  —  " + cfg["desc"], 17, Color.WHITE))
		left.add_child(heading(cfg["reward"], 14, ScrapUI.CYAN if done else ScrapUI.TEXT_MUTED))
		hbox.add_child(left)
		var status_txt := "[ FREIGESCHALTET ]" if done else ("%d / %d" % [mini(cur, target), target])
		hbox.add_child(heading(status_txt, 17, ScrapUI.CYAN if done else ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_RIGHT))

	var back := button(game, "ZURÜCK ZUM HANGAR", game.show_hangar, ScrapUI.ORANGE, Vector2(360, 52))
	box.add_child(back)
	back.grab_focus()
	game.queue_redraw()


static func show_settings(game) -> void:
	game.mode = "settings"
	game.clear_ui()
	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.92), ScrapUI.ORANGE, 2, 12, 6)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(54, 38)
	frame.custom_minimum_size = Vector2(550, 720)
	game.panel.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	box.add_child(heading("EINSTELLUNGEN", 34, ScrapUI.ORANGE))
	box.add_child(heading("AUDIO · ANZEIGE · SYSTEM", 15, ScrapUI.CYAN))

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.2, 0.96, 1.0, 0.55)
	box.add_child(sep)

	var focus_controls: Array[Control] = []

	var am = game.get_node_or_null("/root/AudioManager")
	var slider_defs := [
		["GESAMTLAUTSTÄRKE", am.get_volume("Master") if am else 0.85, func(v: float): if am: am.set_volume("Master", v)],
		["MUSIKLAUTSTÄRKE", am.get_volume("Musik") if am else 0.75, func(v: float): if am: am.set_volume("Musik", v)],
		["EFFEKTLAUTSTÄRKE", am.get_volume("Effekte") if am else 0.85, func(v: float): if am: am.set_volume("Effekte", v)],
	]
	for sdef in slider_defs:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var top_row := HBoxContainer.new()
		var title_lbl := heading(sdef[0], 17, ScrapUI.TEXT_LIGHT)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val_lbl := heading("%d %%" % int(round(float(sdef[1]) * 100.0)), 17, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
		top_row.add_child(title_lbl)
		top_row.add_child(val_lbl)
		row.add_child(top_row)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(sdef[1])
		slider.custom_minimum_size = Vector2(480, 38)
		var cb: Callable = sdef[2]
		slider.value_changed.connect(func(v: float):
			val_lbl.text = "%d %%" % int(round(v * 100.0))
			cb.call(v)
		)
		row.add_child(slider)
		box.add_child(row)
		focus_controls.append(slider)

	var shake_button := CheckButton.new()
	shake_button.text = "BILDSCHIRMWACKELN UND TREFFERSTOPP"
	shake_button.button_pressed = game.shake_enabled
	shake_button.custom_minimum_size = Vector2(480, 52)
	shake_button.toggled.connect(func(v: bool):
		game.ui_confirmed.emit(shake_button)
		game.shake_enabled = v
		game.save_settings()
	)
	box.add_child(shake_button)
	focus_controls.append(shake_button)

	var fullscreen := CheckButton.new()
	fullscreen.text = "VOLLBILDMODUS"
	fullscreen.button_pressed = game.fullscreen_enabled
	fullscreen.custom_minimum_size = Vector2(480, 52)
	fullscreen.toggled.connect(func(v: bool):
		game.ui_confirmed.emit(fullscreen)
		game.fullscreen_enabled = v
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
		game.save_settings()
	)
	box.add_child(fullscreen)
	focus_controls.append(fullscreen)

	if not OS.has_feature("mobile"):
		var quality_button := OptionButton.new()
		quality_button.custom_minimum_size = Vector2(480, 48)
		for label in ["GRAFIK: HOCH", "GRAFIK: MITTEL", "GRAFIK: NIEDRIG"]:
			quality_button.add_item(label)
		quality_button.select(["hoch", "mittel", "niedrig"].find(game.graphics_quality))
		quality_button.item_selected.connect(func(index: int):
			game.graphics_quality = ["hoch", "mittel", "niedrig"][index]
			ScrapEnvironment3D.apply_quality(game.world_3d.lighting.environment, game.world_3d.lighting.sun, game.graphics_quality)
			game.save_settings()
		)
		box.add_child(quality_button)
		focus_controls.append(quality_button)

	var lang_btn := button(game, "SPRACHE: DEUTSCH", func():
		game.language = "de"
		game.save_settings()
	, ScrapUI.CYAN, Vector2(480, 52))
	box.add_child(lang_btn)
	focus_controls.append(lang_btn)

	var back_target := func():
		if game.resume_mode == "pause":
			game.show_pause()
		else:
			game.show_menu()
	var back := button(game, "ZURÜCK (ESC / B)", back_target, ScrapUI.ORANGE, Vector2(480, 54))
	box.add_child(back)
	focus_controls.append(back)

	wire_vertical_focus(focus_controls)
	focus_controls[0].grab_focus()
	if is_instance_valid(game.world_3d):
		game.world_3d.update_view()
	game.queue_redraw()


static func show_pause(game) -> void:
	game.mode = "pause"
	game.clear_ui()
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.055, 0.78)
	game.panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.panel.add_child(center)

	var frame := PanelContainer.new()
	var style := ScrapUI.make_chamfer_style(Color(0.05, 0.075, 0.118, 0.95), ScrapUI.ORANGE, 2, 12, 6, Color(1.0, 0.48, 0.1, 0.35), 12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(460, 0)
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	frame.add_child(box)

	box.add_child(heading("PAUSE", 38, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(heading("SYSTEME IN BEREITSCHAFT", 15, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var b_resume := button(game, "WEITER", game.resume_game, ScrapUI.ORANGE, Vector2(390, 54))
	var b_settings := button(game, "EINSTELLUNGEN", func():
		game.resume_mode = "pause"
		game.show_settings()
	, ScrapUI.CYAN, Vector2(390, 54))
	var b_quit := button(game, "AUFGEBEN", func(): game.show_end(false), ScrapUI.ORANGE, Vector2(390, 54))
	box.add_child(b_resume)
	box.add_child(b_settings)
	box.add_child(b_quit)
	wire_vertical_focus([b_resume, b_settings, b_quit])
	b_resume.grab_focus()


static func show_end(game, victory: bool) -> void:
	game.play_sfx(&"victory" if victory else &"game_over")
	game.play_music("menu")
	game.mode = "end"
	game.clear_ui()
	if is_instance_valid(game.world_3d):
		game.world_3d.update_view()

	# Left side: "DEIN ROBOTER" showcase header above the rotating 3D Mech on the platform
	var left_badge := PanelContainer.new()
	left_badge.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.88), ScrapUI.ORANGE, 2, 10, 5))
	left_badge.position = Vector2(54, 36)
	left_badge.custom_minimum_size = Vector2(440, 82)
	game.panel.add_child(left_badge)

	var lb_box := VBoxContainer.new()
	lb_box.add_theme_constant_override("separation", 2)
	left_badge.add_child(lb_box)
	lb_box.add_child(heading("DEIN ROBOTER", 28, ScrapUI.ORANGE))
	var skin_res: SkinDefinition = game.get_selected_skin_resource()
	var skin_name := skin_res.title.to_upper() if skin_res else "STANDARD"
	lb_box.add_child(heading("ENDKONFIGURATION  ·  SKIN: " + skin_name, 14, ScrapUI.CYAN))

	# Right side: Victory/Game-Over Banner, Statistics, Equipped Modules List, and Action Buttons
	var right_frame := PanelContainer.new()
	var rstyle := ScrapUI.make_chamfer_style(Color(0.045, 0.068, 0.105, 0.92), ScrapUI.CYAN if victory else ScrapUI.ORANGE, 2, 12, 6)
	rstyle.content_margin_left = 26
	rstyle.content_margin_right = 26
	rstyle.content_margin_top = 20
	rstyle.content_margin_bottom = 20
	right_frame.add_theme_stylebox_override("panel", rstyle)
	right_frame.position = Vector2(560, 36)
	right_frame.custom_minimum_size = Vector2(666, 728)
	game.panel.add_child(right_frame)
	ScrapUI.anchor_horizontal(right_frame, 1.0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	right_frame.add_child(box)

	box.add_child(heading("SIEG  //  ARENA GESICHERT" if victory else "SYSTEM AUSGEFALLEN", 34, ScrapUI.CYAN if victory else ScrapUI.ORANGE))
	box.add_child(heading("EINSATZBERICHT & BAUTEIL-ÜBERSICHT", 15, ScrapUI.TEXT_MUTED))

	# Stats Grid
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.03, 0.045, 0.075, 0.92), ScrapUI.BORDER_STEEL, 1, 8))
	box.add_child(stats_panel)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 6)
	stats_panel.add_child(stats_grid)

	var equipped_ids: Array = (game.EVO_IDS + game.IDS).filter(func(id): return game.state.level(id) > 0)
	for pair in [
		["ZEIT", "%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60], ScrapUI.TEXT_LIGHT],
		["ABSCHÜSSE", str(game.kills), ScrapUI.ORANGE],
		["SCHROTT", str(game.total_scrap), ScrapUI.CYAN],
		["STUFE", "LEVEL %d" % game.level, ScrapUI.ORANGE],
	]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(heading(pair[0], 13, ScrapUI.TEXT_MUTED))
		cell.add_child(heading(pair[1], 22, pair[2]))
		stats_grid.add_child(cell)

	box.add_child(heading("INSTALLIERTE BAUTEILE (%d)" % equipped_ids.size(), 16, ScrapUI.CYAN))

	var module_scroll := ScrollContainer.new()
	module_scroll.custom_minimum_size = Vector2(0, 240)
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(module_scroll)
	var mod_grid := GridContainer.new()
	mod_grid.columns = 2
	mod_grid.add_theme_constant_override("h_separation", 10)
	mod_grid.add_theme_constant_override("v_separation", 8)
	module_scroll.add_child(mod_grid)

	for id: String in equipped_ids:
		var def: UpgradeDefinition = game.definitions[id]
		var lv: int = game.state.level(id)
		var mcard := PanelContainer.new()
		var maccent := ScrapUI.module_accent(id)
		var mstyle := ScrapUI.make_chamfer_style(Color(0.035, 0.055, 0.088, 0.92), maccent, 1, 6, 3)
		mstyle.content_margin_left = 10
		mstyle.content_margin_right = 10
		mstyle.content_margin_top = 6
		mstyle.content_margin_bottom = 6
		mcard.add_theme_stylebox_override("panel", mstyle)
		mcard.custom_minimum_size = Vector2(298, 52)
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 10)
		mcard.add_child(mrow)
		mrow.add_child(ScrapUI.ModuleIcon.new(id, true))
		var mtxt := VBoxContainer.new()
		mtxt.add_theme_constant_override("separation", 0)
		mtxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mtxt.add_child(heading(def.title.to_upper(), 15, ScrapUI.TEXT_LIGHT))
		mtxt.add_child(heading(ScrapUI.socket_label(id, def.socket), 11, ScrapUI.TEXT_MUTED))
		mrow.add_child(mtxt)
		mrow.add_child(heading("EVO" if id in game.EVO_IDS else ("STUFE %d" % lv), 15, maccent, HORIZONTAL_ALIGNMENT_RIGHT))
		mod_grid.add_child(mcard)

	var saved := heading("", 14, ScrapUI.CYAN)
	var btn_save := button(game, "SCREENSHOT SPEICHERN", func():
		var path := "user://scrapforge-%d.png" % int(Time.get_unix_time_from_system())
		game.save_image(path)
		saved.text = "GESPEICHERT: " + ProjectSettings.globalize_path(path)
	, ScrapUI.CYAN, Vector2(600, 52))
	var btn_retry := button(game, "NOCHMAL SPIELEN", game.start_game, ScrapUI.ORANGE, Vector2(600, 52))
	var btn_menu := button(game, "HAUPTMENÜ", game.show_menu, ScrapUI.CYAN, Vector2(600, 52))
	box.add_child(btn_save)
	box.add_child(saved)
	box.add_child(btn_retry)
	box.add_child(btn_menu)
	wire_vertical_focus([btn_save, btn_retry, btn_menu])
	btn_save.grab_focus()
