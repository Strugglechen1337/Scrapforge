class_name ScrapEnvironment3D
extends RefCounted

static func build(parent: Node3D, mobile: bool, quality: String) -> Dictionary:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	if mobile:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("10131b")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("798a9c")
		env.ambient_light_energy = 0.85
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.0
		env.glow_enabled = true
		env.fog_enabled = true
		env.fog_light_color = Color("202b39")
		env.fog_density = 0.008
		sun.rotation_degrees = Vector3(-55, -35, 0)
		sun.light_energy = 1.0
		sun.shadow_enabled = true
	else:
		var sky := Sky.new()
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load("res://assets/third_party/polyhaven/industrial_pipe_and_valve_01/industrial_pipe_and_valve_01_2k.hdr")
		sky.sky_material = panorama
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.background_energy_multiplier = 0.08
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.1
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.95
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.05
		env.adjustment_saturation = 0.8
		env.glow_enabled = true
		env.glow_hdr_threshold = 1.5
		env.glow_bloom = 0.0
		env.glow_intensity = 0.35
		env.ssao_radius = 0.8
		env.ssao_intensity = 0.8
		env.ssil_radius = 1.0
		env.ssil_intensity = 0.5
		env.volumetric_fog_density = 0.002
		env.volumetric_fog_albedo = Color("746c62")
		sun.rotation_degrees = Vector3(-55, -35, 0)
		sun.light_color = Color("dce1e8")
		sun.light_energy = 1.5
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 45.0
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-25, 135, 0)
		rim.light_color = Color("d6b89a")
		rim.light_energy = 0.23
		parent.add_child(rim)
		# Half-resolution screen-space effects and a smaller fog grid retain the
		# high profile while reducing GPU work in dense swarms.
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, true, 0.5, 1, 50.0, 300.0)
		RenderingServer.environment_set_volumetric_fog_volume_size(64, 32)
		apply_quality(env, sun, quality)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	parent.add_child(sun)
	return {"environment": env, "sun": sun}

static func apply_quality(env: Environment, sun: DirectionalLight3D, quality: String) -> void:
	env.ssao_enabled = quality != "niedrig"
	env.ssil_enabled = quality == "hoch"
	env.volumetric_fog_enabled = quality == "hoch"
	env.glow_enabled = quality != "niedrig"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality == "hoch" else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality == "mittel" else DirectionalLight3D.SHADOW_ORTHOGONAL)
	RenderingServer.directional_shadow_atlas_set_size(2048 if quality == "hoch" else (1024 if quality == "mittel" else 512), true)
