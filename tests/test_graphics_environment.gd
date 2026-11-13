extends SceneTree

func _initialize() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var built := ScrapEnvironment3D.build(parent, false, "hoch")
	var env: Environment = built.environment
	var sun: DirectionalLight3D = built.sun
	assert(env.sky != null and env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY)
	assert(env.glow_hdr_threshold > 1.0)
	assert(env.ssao_enabled and env.ssil_enabled and env.volumetric_fog_enabled)
	assert(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	ScrapEnvironment3D.apply_quality(env, sun, "mittel")
	assert(env.ssao_enabled and not env.ssil_enabled and not env.volumetric_fog_enabled)
	assert(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	ScrapEnvironment3D.apply_quality(env, sun, "niedrig")
	assert(not env.ssao_enabled and not env.ssil_enabled and not env.volumetric_fog_enabled)
	assert(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
	var mobile := ScrapEnvironment3D.build(parent, true, "hoch")
	var mobile_env: Environment = mobile.environment
	assert(mobile_env.sky == null and not mobile_env.ssao_enabled and not mobile_env.ssil_enabled and not mobile_env.volumetric_fog_enabled)
	# Android stays exactly as before Phase 1: flat color ambient at the old energy.
	assert(is_equal_approx(mobile_env.ambient_light_energy, 0.85) and mobile_env.background_mode == Environment.BG_COLOR)
	parent.queue_free()
	print("graphics environment OK")
	quit()
