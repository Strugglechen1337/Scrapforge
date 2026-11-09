extends Node3D

var animated: Array[Node3D] = []
var blades: Array[Node3D] = []
var orbiters: Array[Node3D] = []
var time := 0.0

func cylinder(parent: Node3D, pos: Vector3, length: float, radius: float, material: Material, axis := Vector3.RIGHT) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 20
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    instance.rotation = axis * PI / 2
    parent.add_child(instance)
    return instance

func plate(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var x := size.x / 2.0
    var y := size.y / 2.0
    var z := size.z / 2.0
    var b := minf(x, y) * 0.27
    var points := [Vector2(-x+b,-y),Vector2(x-b,-y),Vector2(x,-y+b),Vector2(x,y-b),Vector2(x-b,y),Vector2(-x+b,y),Vector2(-x,y-b),Vector2(-x,-y+b)]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(8):
        var j := (i+1)%8
        for v in [Vector3(0,0,-z),Vector3(points[j].x,points[j].y,-z),Vector3(points[i].x,points[i].y,-z),Vector3(0,0,z),Vector3(points[i].x,points[i].y,z),Vector3(points[j].x,points[j].y,z),Vector3(points[i].x,points[i].y,-z),Vector3(points[j].x,points[j].y,-z),Vector3(points[j].x,points[j].y,z),Vector3(points[i].x,points[i].y,-z),Vector3(points[j].x,points[j].y,z),Vector3(points[i].x,points[i].y,z)]:
            st.set_uv(Vector2(v.x / size.x + 0.5, v.y / size.y + 0.5))
            st.add_vertex(v)
    st.generate_normals()
    var instance := MeshInstance3D.new()
    instance.mesh = st.commit()
    instance.material_override = material
    instance.position = pos
    parent.add_child(instance)
    return instance

func saw_blade(parent: Node3D, material: Material, dark: Material) -> void:
    cylinder(parent, Vector3.ZERO, 0.055, 0.28, material)
    cylinder(parent, Vector3(0,0,-0.04), 0.035, 0.085, dark)
    for i in range(18):
        var angle := TAU * i / 18.0
        var tooth := PrismMesh.new()
        tooth.size = Vector3(0.1,0.13,0.06)
        var instance := MeshInstance3D.new()
        instance.mesh = tooth
        instance.material_override = material
        instance.position = Vector3(cos(angle)*0.29,sin(angle)*0.29,0)
        instance.rotation.z = angle - PI/2
        parent.add_child(instance)

func drone(parent: Node3D, _metal: Material, _dark: Material, _cyan: Material) -> Node3D:
    var body := add_sketchfab("drone", 0.34)
    if parent != self: body.reparent(parent)
    return body

func add_sketchfab(id: String, size: float, offset := Vector3.ZERO) -> Node3D:
    var packed := load("res://assets/third_party/sketchfab/modules/" + id + ".glb") as PackedScene
    var model := packed.instantiate() as Node3D
    model.name = "asset_" + id
    model.position = offset
    model.scale = Vector3.ONE * size
    add_child(model)
    tint_asset(model)
    return model

func tint_asset(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        for surface in range(mesh_node.mesh.get_surface_count()):
            var original := mesh_node.get_active_material(surface) as StandardMaterial3D
            if original:
                var material := original.duplicate() as StandardMaterial3D
                material.albedo_color *= Color(0.82, 0.79, 0.74)
                material.roughness = maxf(material.roughness, 0.58)
                mesh_node.set_surface_override_material(surface, material)
        mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children(): tint_asset(child)

func exhaust(pos: Vector3, material: Material) -> void:
    var flame: Variant = CPUParticles3D.new() if OS.has_feature("mobile") else GPUParticles3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.045
    mesh.height = 0.09
    mesh.material = material
    if flame is GPUParticles3D:
        var process := ParticleProcessMaterial.new()
        process.direction = Vector3.DOWN
        process.spread = 15
        process.initial_velocity_min = 0.4
        process.initial_velocity_max = 1.0
        process.gravity = Vector3.ZERO
        flame.process_material = process
        flame.draw_pass_1 = mesh
    else:
        flame.mesh = mesh
        flame.direction = Vector3.DOWN
        flame.spread = 15
        flame.initial_velocity_min = 0.4
        flame.initial_velocity_max = 1.0
        flame.gravity = Vector3.ZERO
    flame.amount = 6
    flame.lifetime = 0.4
    flame.position = pos
    add_child(flame)

func build(id: String, level: int, metal: Material, dark: Material, glow: Material, accent: Material = null) -> void:
    if accent == null: accent = metal
    var cyan := StandardMaterial3D.new()
    cyan.albedo_color = Color("087b83")
    cyan.emission_enabled = true
    cyan.emission = Color("15cbd4")
    cyan.emission_energy_multiplier = 0.8
    var sensor_red := StandardMaterial3D.new()
    sensor_red.albedo_color = Color("d50913")
    sensor_red.emission_enabled = true
    sensor_red.emission = Color("ff1020")
    sensor_red.emission_energy_multiplier = 1.5
    var violet := StandardMaterial3D.new()
    violet.albedo_color = Color("8e42e8")
    violet.emission_enabled = true
    violet.emission = Color("bc51ff")
    violet.emission_energy_multiplier = 2.0
    match id:
        "laser":
            add_sketchfab("laser", 0.9 + 0.045 * level)
            cylinder(self, Vector3(0, 0, -0.48), 0.09, 0.055, violet)
            for i in range(level): plate(self, Vector3(0.04,0.025,0.03), Vector3(-0.1+i*0.05,0.12,-0.05), violet)
        "minigun":
            add_sketchfab("minigun", 0.95 + 0.05 * level)
            if level >= 4: add_sketchfab("minigun", 0.60, Vector3(0.16, -0.18, 0))
            cylinder(self, Vector3(0, 0, -0.60), 0.04, 0.055, glow)
            for i in range(level): plate(self, Vector3(0.035,0.025,0.035), Vector3(-0.1+i*0.05,0.17,0), glow)
        "rocket", "swarm":
            add_sketchfab("rocket", 0.62 + 0.025 * level)
            # Armored launcher casing around the derived turret and its tubes.
            plate(self, Vector3(0.50, 0.34, 0.35), Vector3(0, 0, -0.25), dark)
            plate(self, Vector3(0.52, 0.04, 0.32), Vector3(0, 0.18, -0.25), metal)
            var count := mini(level + 1, 6) if id == "rocket" else 6
            for i in range(count):
                var x := (float(i % 3) - 1.0) * 0.14
                var y := (float(int(i / 3)) - 0.5) * 0.14
                cylinder(self, Vector3(x,y,-0.54), 0.06, 0.06, dark)
                cylinder(self, Vector3(x,y,-0.59), 0.025, 0.04, glow)
        "flamethrower", "plasma":
            plate(self, Vector3(0.42,0.34,0.55), Vector3.ZERO, metal)
            cylinder(self, Vector3(0,0,-0.45), 0.55, 0.13, dark)
            cylinder(self, Vector3(0,0,-0.75), 0.08, 0.15, glow if id == "flamethrower" else cyan)
            for i in range(level):
                plate(self, Vector3(0.25,0.035,0.035), Vector3(0,0.2,-0.2+i*0.09), glow if id == "flamethrower" else cyan)
            if id == "flamethrower": exhaust(Vector3(0,0,-0.8), glow)
        "turret":
            add_sketchfab("turret", 0.65 + 0.025 * level)
            for i in range(level): plate(self, Vector3(0.04,0.04,0.04), Vector3(-0.1+i*0.05,0.19,0), glow)
        "sensor":
            plate(self, Vector3(0.35,0.22,0.24), Vector3(0,0.17,0), metal)
            cylinder(self, Vector3(0,0.45,0), 0.4, 0.025, dark, Vector3.ZERO)
            plate(self, Vector3(0.08,0.06,0.03), Vector3(-0.08,0.18,-0.14), cyan)
            plate(self, Vector3(0.08,0.06,0.03), Vector3(0.08,0.18,-0.14), sensor_red)
            for i in range(level): plate(self, Vector3(0.04,0.03,0.03), Vector3(-0.12+i*0.06,0.3,0), cyan)
        "drone":
            for i in range(1 + int(level / 2)):
                var d := add_sketchfab("drone", 0.30 + level * 0.025)
                d.position = Vector3((i*2-1)*0.7,0.5,0)
                orbiters.append(d)
            for i in range(level): plate(self, Vector3(0.04,0.04,0.04), Vector3(-0.1+i*0.05,0,0), cyan)
        "armor":
            for i in range(level): plate(self, Vector3(0.5+i*0.04,0.08,0.18), Vector3(0,-0.17+i*0.09,-0.08), metal)
        "radar":
            plate(self, Vector3(0.08,0.2+level*0.09,0.08), Vector3(0,0.1+level*0.045,0), dark)
            for i in range(level): plate(self, Vector3(0.18+i*0.06,0.025,0.03), Vector3(0,0.28+i*0.08,0), cyan)
            for i in range(int(level / 2)):
                var d := drone(self, metal, dark, cyan)
                d.position = Vector3((i*2-1)*0.7,0.5,0)
                orbiters.append(d)
        "thruster":
            for side in [-1,1]:
                plate(self, Vector3(0.25+level*0.02,0.42,0.32), Vector3(side*0.3,0,0), metal)
                cylinder(self, Vector3(side*0.3,-0.25,0),0.2,0.1,dark,Vector3.ZERO)
                cylinder(self, Vector3(side*0.3,-0.37,0),0.1,0.06,cyan,Vector3.ZERO)
                exhaust(Vector3(side*0.3,-0.4,0),cyan)
        "saw":
            for i in range(level):
                var pivot := Node3D.new()
                var angle := TAU*i/level
                pivot.position = Vector3(cos(angle)*0.7,sin(angle)*0.5,0)
                add_child(pivot)
                saw_blade(pivot,metal,dark)
                blades.append(pivot)
        "shield":
            add_sketchfab("shield", 0.42 + 0.025 * level, Vector3(0, 0, 0.1))
            # A perimeter and seven smaller hexagons form an open honeycomb.
            var panel := Node3D.new()
            panel.position.z = -0.32
            add_child(panel)
            hex_outline(panel, Vector2.ZERO, 0.41, cyan)
            hex_outline(panel, Vector2.ZERO, 0.13, cyan)
            for cell in range(6):
                var angle := TAU * cell / 6.0 + PI / 6.0
                hex_outline(panel, Vector2(cos(angle), sin(angle)) * 0.225, 0.13, cyan)
            for i in range(level):
                plate(self, Vector3(0.04, 0.025, 0.015), Vector3((i - 2) * 0.06, -0.46, -0.32), cyan)
        _:
            for i in range(level): plate(self, Vector3(0.28,0.07,0.22), Vector3(0,i*0.08,0), metal if i%2 == 0 else cyan)

func hex_outline(parent: Node3D, center: Vector2, radius: float, material: Material) -> void:
    for edge in range(6):
        var a := TAU * edge / 6.0
        var b := TAU * (edge + 1) / 6.0
        var p1 := center + Vector2(cos(a), sin(a)) * radius
        var p2 := center + Vector2(cos(b), sin(b)) * radius
        var midpoint := (p1 + p2) * 0.5
        var bar := plate(parent, Vector3(p1.distance_to(p2), 0.012, 0.014), Vector3(midpoint.x, midpoint.y, 0), material)
        bar.rotation.z = (p2 - p1).angle()

func _process(delta: float) -> void:
    time += delta
    for n in animated: n.rotate_y(delta * 9)
    for n in blades: n.rotate_z(delta * 9)
    for i in range(orbiters.size()):
        var angle := time * 1.1 + TAU * i / orbiters.size()
        orbiters[i].position = Vector3(cos(angle)*0.75,0.45,sin(angle)*0.55)
