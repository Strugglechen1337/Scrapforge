class_name GameHUD
extends RefCounted


static func build(game) -> void:
	game.clear_ui()
	# Keep hidden legacy status label for any external script/test compatibility
	game.status = Label.new()
	game.status.visible = false
	game.panel.add_child(game.status)

	# Top-Left: Hull (Orange) & XP (Cyan) with Level badge
	var tl_panel := PanelContainer.new()
	tl_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.86), ScrapUI.BORDER_STEEL, 2, 10, 5))
	tl_panel.position = Vector2(26, 18)
	tl_panel.custom_minimum_size = Vector2(360, 104)
	game.panel.add_child(tl_panel)

	var tl_box := VBoxContainer.new()
	tl_box.add_theme_constant_override("separation", 8)
	tl_panel.add_child(tl_box)

	var hp_header := HBoxContainer.new()
	var hp_title: Label = game.heading("HÜLLE", 16, ScrapUI.ORANGE)
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.hp_value_label = game.heading("100 / 100", 16, ScrapUI.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	hp_header.add_child(hp_title)
	hp_header.add_child(game.hp_value_label)
	tl_box.add_child(hp_header)

	game.hp_bar = ProgressBar.new()
	game.hp_bar.max_value = game.max_hp()
	game.hp_bar.value = game.hp
	game.hp_bar.show_percentage = false
	game.hp_bar.custom_minimum_size = Vector2(316, 16)
	var hp_bg := ScrapUI.make_chamfer_style(Color(0.03, 0.045, 0.07, 0.95), Color("3c4e63"), 1, 4)
	var hp_fill := ScrapUI.make_chamfer_style(ScrapUI.ORANGE, Color("ffb366"), 1, 4)
	game.hp_bar.add_theme_stylebox_override("background", hp_bg)
	game.hp_bar.add_theme_stylebox_override("fill", hp_fill)
	tl_box.add_child(game.hp_bar)

	var xp_header := HBoxContainer.new()
	game.level_badge_label = game.heading("LEVEL 1", 16, ScrapUI.CYAN)
	game.level_badge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.xp_value_label = game.heading("EP 0 / 5", 15, ScrapUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	xp_header.add_child(game.level_badge_label)
	xp_header.add_child(game.xp_value_label)
	tl_box.add_child(xp_header)

	game.xp_bar = ProgressBar.new()
	game.xp_bar.max_value = 5.0
	game.xp_bar.value = 0.0
	game.xp_bar.show_percentage = false
	game.xp_bar.custom_minimum_size = Vector2(316, 12)
	var xp_bg := ScrapUI.make_chamfer_style(Color(0.03, 0.045, 0.07, 0.95), Color("2f4b5e"), 1, 4)
	var xp_fill := ScrapUI.make_chamfer_style(ScrapUI.CYAN, Color("b8fcff"), 1, 4)
	game.xp_bar.add_theme_stylebox_override("background", xp_bg)
	game.xp_bar.add_theme_stylebox_override("fill", xp_fill)
	tl_box.add_child(game.xp_bar)

	# Top-Center: Mission Timer
	var tc_panel := PanelContainer.new()
	var tc_style := ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.86), ScrapUI.ORANGE, 2, 10)
	tc_style.content_margin_top = 8
	tc_style.content_margin_bottom = 8
	tc_panel.add_theme_stylebox_override("panel", tc_style)
	tc_panel.position = Vector2(535, 18)
	tc_panel.custom_minimum_size = Vector2(210, 68)
	game.panel.add_child(tc_panel)
	ScrapUI.anchor_horizontal(tc_panel, 0.5)

	var tc_box := VBoxContainer.new()
	tc_box.add_theme_constant_override("separation", 0)
	tc_panel.add_child(tc_box)
	tc_box.add_child(game.heading("EINSATZZEIT", 12, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	game.time_label = game.heading("00:00", 28, ScrapUI.TEXT_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	tc_box.add_child(game.time_label)

	# Top-Right: Scrap & Kills + Touch Pause Button (>= 48dp)
	var tr_panel := PanelContainer.new()
	tr_panel.add_theme_stylebox_override("panel", ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.86), ScrapUI.CYAN, 2, 10, 4))
	tr_panel.position = Vector2(856, 18)
	tr_panel.custom_minimum_size = Vector2(328, 68)
	game.panel.add_child(tr_panel)
	ScrapUI.anchor_horizontal(tr_panel, 1.0)

	var tr_box := HBoxContainer.new()
	tr_box.add_theme_constant_override("separation", 18)
	tr_panel.add_child(tr_box)
	game.scrap_label = game.heading("◆ 0 SCHROTT", 18, ScrapUI.CYAN)
	game.scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.kills_label = game.heading("⌖ 0 KILLS", 18, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_RIGHT)
	tr_box.add_child(game.scrap_label)
	tr_box.add_child(game.kills_label)

	var pause_btn: Button = game.button("II", game.show_pause, ScrapUI.ORANGE, Vector2(58, 68))
	pause_btn.position = Vector2(1196, 18)
	pause_btn.focus_mode = Control.FOCUS_NONE
	game.panel.add_child(pause_btn)
	ScrapUI.anchor_horizontal(pause_btn, 1.0)

	# Bottom-Left: Equipped Module Icons Bar
	game.module_bar = HBoxContainer.new()
	game.module_bar.position = Vector2(26, 704)
	game.module_bar.add_theme_constant_override("separation", 8)
	game.panel.add_child(game.module_bar)
	game.hud_module_sig = ""

	make_boss_bar(game)
	update(game)


static func make_boss_bar(game) -> void:
	game.boss_panel = PanelContainer.new()
	var bstyle := ScrapUI.make_chamfer_style(Color(0.06, 0.03, 0.04, 0.90), ScrapUI.ORANGE, 2, 8, 5)
	bstyle.content_margin_left = 16
	bstyle.content_margin_right = 16
	bstyle.content_margin_top = 8
	bstyle.content_margin_bottom = 8
	game.boss_panel.add_theme_stylebox_override("panel", bstyle)
	game.boss_panel.position = Vector2(380, 94)
	game.boss_panel.custom_minimum_size = Vector2(520, 56)
	game.boss_panel.visible = false
	game.panel.add_child(game.boss_panel)
	ScrapUI.anchor_horizontal(game.boss_panel, 0.5)

	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 4)
	game.boss_panel.add_child(bbox)

	game.boss_label = game.heading("WARNUNG  //  BOSS: SPINNEN-MECH", 14, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
	game.boss_label.visible = false
	bbox.add_child(game.boss_label)

	game.boss_bar = ProgressBar.new()
	game.boss_bar.custom_minimum_size = Vector2(484, 18)
	game.boss_bar.max_value = 1800
	game.boss_bar.show_percentage = false
	game.boss_bar.visible = false
	var bg_style := ScrapUI.make_chamfer_style(Color("161018"), Color("6e3a32"), 1, 4)
	game.boss_bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := ScrapUI.make_chamfer_style(Color("ff3d1a"), ScrapUI.ORANGE, 1, 4)
	game.boss_bar.add_theme_stylebox_override("fill", fill_style)
	bbox.add_child(game.boss_bar)


static func update(game) -> void:
	if not is_instance_valid(game.hp_bar):
		return
	var hull_int := maxi(0, int(round(game.hp)))
	var max_hull: float = game.max_hp()
	game.hp_bar.max_value = max_hull
	game.hp_bar.value = clampf(game.hp, 0.0, max_hull)
	game.hp_value_label.text = "%d / %d" % [hull_int, int(round(max_hull))]
	game.level_badge_label.text = "LEVEL %d" % game.level
	var max_xp := maxi(1, game.level * 5)
	game.xp_bar.max_value = max_xp
	game.xp_bar.value = clampf(float(game.xp), 0.0, float(max_xp))
	game.xp_value_label.text = "EP %d / %d" % [game.xp, max_xp]
	game.time_label.text = "%02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60]
	game.scrap_label.text = "◆ %d SCHROTT" % game.total_scrap
	game.kills_label.text = "⌖ %d KILLS" % game.kills
	game.status.text = "HÜLLE %d   ·   LEVEL %d   ·   EP %d/%d   ·   %02d:%02d   ·   %d SCHROTT" % [hull_int, game.level, game.xp, max_xp, int(game.elapsed) / 60, int(game.elapsed) % 60, game.kills]

	var sig := str(game.state.levels)
	if sig != game.hud_module_sig and is_instance_valid(game.module_bar):
		game.hud_module_sig = sig
		for child in game.module_bar.get_children():
			game.module_bar.remove_child(child)
			child.queue_free()
		for id: String in game.EVO_IDS + game.IDS:
			var lv: int = game.state.level(id)
			if lv <= 0:
				continue
			var slot := PanelContainer.new()
			var accent := ScrapUI.module_accent(id)
			var sstyle := ScrapUI.make_chamfer_style(Color(0.04, 0.06, 0.095, 0.90), accent, 2, 6)
			sstyle.content_margin_left = 6
			sstyle.content_margin_right = 6
			sstyle.content_margin_top = 4
			sstyle.content_margin_bottom = 4
			slot.add_theme_stylebox_override("panel", sstyle)
			slot.custom_minimum_size = Vector2(56, 72)
			var vbox := VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 2)
			slot.add_child(vbox)
			var icon := ScrapUI.ModuleIcon.new(id, true)
			vbox.add_child(icon)
			var lv_txt := "EVO" if id in game.EVO_IDS else ("S%d" % lv)
			vbox.add_child(game.heading(lv_txt, 13, accent, HORIZONTAL_ALIGNMENT_CENTER))
			game.module_bar.add_child(slot)
