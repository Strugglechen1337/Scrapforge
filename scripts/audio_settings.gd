extends RefCounted

static func populate(box: VBoxContainer) -> HSlider:
    var first: HSlider
    for entry in [["GESAMTLAUTSTÄRKE", "Master"], ["MUSIK", "Musik"], ["EFFEKTE", "Effekte"]]:
        var label := Label.new()
        label.text = entry[0]
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 18)
        label.add_theme_color_override("font_color", Color("46f6ef"))
        box.add_child(label)
        var slider := HSlider.new()
        slider.min_value = 0
        slider.max_value = 1
        slider.step = 0.05
        slider.value = AudioManager.get_volume(entry[1])
        slider.custom_minimum_size = Vector2(360, 35)
        var bus: String = entry[1]
        slider.value_changed.connect(func(value): AudioManager.set_volume(bus, value))
        box.add_child(slider)
        if not first: first = slider
    return first
