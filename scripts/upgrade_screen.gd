class_name UpgradeScreen
extends RefCounted


static func choose(game, force_show := false) -> void:
	if game.autoplay and not force_show:
		var auto_candidates: Array = game.IDS.filter(func(id): return game.state.can_upgrade(id) and not (game.state.level("swarm") > 0 and id in ["rocket", "radar"]))
		if not auto_candidates.is_empty():
			game.state.upgrade(auto_candidates.pick_random())
			game.play_sfx(&"upgrade")
		return
	game.mode = "upgrade"
	game.clear_ui()
	game.upgrade_cards.clear()
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.055, 0.84)
	game.panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_box := VBoxContainer.new()
	root_box.position = Vector2(60, 44)
	root_box.custom_minimum_size = Vector2(1160, 710)
	root_box.add_theme_constant_override("separation", 18)
	game.panel.add_child(root_box)
	ScrapUI.anchor_horizontal(root_box, 0.5)

	root_box.add_child(game.heading("SYSTEM-AUFSTIEG  //  LEVEL %d" % game.level, 40, ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	root_box.add_child(game.heading("WÄHLE EIN MODULARES BAUTEIL FÜR DEINEN MECH", 16, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var candidates: Array = game.IDS.filter(func(id): return game.state.can_upgrade(id))
	if not force_show:
		candidates.shuffle()
	for evo_id in game.state.available_evolutions():
		candidates.push_front(evo_id)
	if candidates.is_empty():
		game.resume_game()
		return

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 24)
	root_box.add_child(cards_row)

	var shown: Array = candidates.slice(0, 3)
	for id: String in shown:
		var definition: UpgradeDefinition = game.definitions[id]
		var is_evo: bool = UpgradeState.EVOLUTIONS.has(id)
		var cur_lv: int = game.state.level(id)
		var next_lv: int = 1 if is_evo else (cur_lv + 1)
		var card_accent: Color = Color("c65cff") if is_evo else ScrapUI.ORANGE
		var card := Button.new()
		card.custom_minimum_size = Vector2(356, 460)
		card.focus_mode = Control.FOCUS_ALL
		card.text = ""
		card.set_meta("upgrade_id", id)

		var c_normal := ScrapUI.make_chamfer_style(Color(0.055, 0.082, 0.128, 0.94), ScrapUI.CYAN if is_evo else ScrapUI.BORDER_STEEL, 3 if is_evo else 2, 12, 4)
		var c_hover := ScrapUI.make_chamfer_style(Color(0.11, 0.155, 0.225, 0.98), card_accent, 3, 12, 6, Color(card_accent.r, card_accent.g, card_accent.b, 0.42), 10)
		var c_focus := ScrapUI.make_chamfer_style(Color(0.135, 0.185, 0.265, 0.99), card_accent, 4, 12, 8, Color(card_accent.r, card_accent.g, card_accent.b, 0.65), 14)
		card.add_theme_stylebox_override("normal", c_normal)
		card.add_theme_stylebox_override("hover", c_hover)
		card.add_theme_stylebox_override("focus", c_focus)
		card.add_theme_stylebox_override("pressed", c_focus)

		var inner := VBoxContainer.new()
		inner.position = Vector2(22, 18)
		inner.custom_minimum_size = Vector2(312, 424)
		inner.add_theme_constant_override("separation", 10)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inner)

		var sock_txt := ScrapUI.socket_label(id, definition.socket)
		var sock_lbl: Label = game.heading(sock_txt, 14, ScrapUI.CYAN if is_evo else ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(sock_lbl)

		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := ScrapUI.ModuleIcon.new(id, false)
		icon_center.add_child(icon)
		inner.add_child(icon_center)

		var title_lbl: Label = game.heading(definition.title.to_upper(), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(title_lbl)

		var step_txt := "★ ENTWICKLUNG ★" if is_evo else ("NEU  ·  STUFE 1" if cur_lv == 0 else ("STUFE %d → %d" % [cur_lv, next_lv]))
		var step_lbl: Label = game.heading(step_txt, 17, ScrapUI.CYAN if (is_evo or cur_lv > 0) else ScrapUI.ORANGE, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(step_lbl)

		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(0, 2)
		sep.color = Color(card_accent.r, card_accent.g, card_accent.b, 0.5)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sep)

		var desc_lbl := Label.new()
		desc_lbl.text = definition.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.custom_minimum_size = Vector2(304, 68)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", ScrapUI.TEXT_LIGHT)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(desc_lbl)

		var stat_val := definition.values[clampi(next_lv - 1, 0, definition.values.size() - 1)] if not definition.values.is_empty() else 0.0
		if int(round(stat_val)) != 0:
			var stat_lbl: Label = game.heading("MODULLEISTUNG: %d" % int(round(stat_val)), 15, ScrapUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			inner.add_child(stat_lbl)

		var action_lbl: Label = game.heading("[ BAUTEIL MONTIEREN ]", 16, card_accent, HORIZONTAL_ALIGNMENT_CENTER)
		inner.add_child(action_lbl)

		card.pivot_offset = Vector2(178, 230)
		card.focus_entered.connect(func():
			card.scale = Vector2(1.035, 1.035)
		)
		card.focus_exited.connect(func():
			card.scale = Vector2.ONE
		)
		card.pressed.connect(func():
			game.ui_confirmed.emit(card)
			game.play_sfx(&"upgrade")
			if UpgradeState.EVOLUTIONS.has(id):
				game.state.evolve_id(id)
			else:
				game.state.upgrade(id)
			game.resume_game()
		)
		cards_row.add_child(card)
		game.upgrade_cards.append(card)

	game.wire_horizontal_focus(game.upgrade_cards)
	if not game.upgrade_cards.is_empty():
		game.upgrade_cards[0].grab_focus()


static func open_crate(game) -> void:
	var avail: Array[String] = game.state.available_evolutions()
	if avail.is_empty():
		game.total_scrap += 15
		game.hp = minf(game.max_hp(), game.hp + 20.0)
		game.world_3d.effects_3d.damage(game.player, 15, true)
		game.update_hud()
		return
	var evo_id: String = avail[0]
	if game.autoplay:
		game.state.evolve_id(evo_id)
		game.update_hud()
		return
	game.mode = "upgrade"
	game.clear_ui()
	game.upgrade_cards.clear()
	var violet := Color("c65cff")
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.015, 0.055, 0.88)
	game.panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_box := VBoxContainer.new()
	root_box.position = Vector2(60, 54)
	root_box.custom_minimum_size = Vector2(1160, 690)
	root_box.add_theme_constant_override("separation", 18)
	game.panel.add_child(root_box)
	ScrapUI.anchor_horizontal(root_box, 0.5)

	root_box.add_child(game.heading("BEUTEKISTE  //  EVOLUTION FREIGESCHALTET", 38, violet, HORIZONTAL_ALIGNMENT_CENTER))
	var recipe: Dictionary = UpgradeState.EVOLUTIONS[evo_id]
	var w_title: String = game.definitions[recipe["weapon"]].title.to_upper()
	var s_title: String = game.definitions[recipe["support"]].title.to_upper()
	root_box.add_child(game.heading("%s S5  +  %s S5" % [w_title, s_title], 18, ScrapUI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var center := CenterContainer.new()
	root_box.add_child(center)
	var definition: UpgradeDefinition = game.definitions[evo_id]
	var card := Button.new()
	card.custom_minimum_size = Vector2(420, 460)
	card.focus_mode = Control.FOCUS_ALL
	card.text = ""
	card.set_meta("upgrade_id", evo_id)
	var c_normal := ScrapUI.make_chamfer_style(Color(0.075, 0.055, 0.135, 0.96), violet, 3, 12, 6, Color(violet.r, violet.g, violet.b, 0.45), 12)
	var c_focus := ScrapUI.make_chamfer_style(Color(0.125, 0.085, 0.215, 0.99), violet, 4, 12, 8, Color(violet.r, violet.g, violet.b, 0.75), 16)
	card.add_theme_stylebox_override("normal", c_normal)
	card.add_theme_stylebox_override("hover", c_focus)
	card.add_theme_stylebox_override("focus", c_focus)
	card.add_theme_stylebox_override("pressed", c_focus)

	var inner := VBoxContainer.new()
	inner.position = Vector2(28, 22)
	inner.custom_minimum_size = Vector2(364, 416)
	inner.add_theme_constant_override("separation", 12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	inner.add_child(game.heading("★ WAFFEN-EVOLUTION ★", 16, violet, HORIZONTAL_ALIGNMENT_CENTER))
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(ScrapUI.ModuleIcon.new(evo_id, false))
	inner.add_child(icon_center)
	inner.add_child(game.heading(definition.title.to_upper(), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var desc_lbl := Label.new()
	desc_lbl.text = definition.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.custom_minimum_size = Vector2(348, 84)
	desc_lbl.add_theme_font_size_override("font_size", 17)
	desc_lbl.add_theme_color_override("font_color", ScrapUI.TEXT_LIGHT)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)
	inner.add_child(game.heading("[ EVOLUTION AKTIVIEREN ]", 18, violet, HORIZONTAL_ALIGNMENT_CENTER))
	card.pressed.connect(func():
		game.ui_confirmed.emit(card)
		game.play_sfx(&"upgrade")
		game.state.evolve_id(evo_id)
		game.resume_game()
	)
	center.add_child(card)
	game.upgrade_cards.append(card)
	card.grab_focus()
