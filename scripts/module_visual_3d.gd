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

func drone(parent: Node3D, metal: Material, dark: Material, cyan: Material) -> Node3D:
    var body := Node3D.new()
    parent.add_child(body)
    plate(body, Vector3(0.3,0.14,0.3), Vector3.ZERO, metal)
    cylinder(body, Vector3(0,0,-0.17), 0.035, 0.06, cyan)
    for x in [-1,1]:
        for z in [-1,1]:
            var rotor := Node3D.new()
            rotor.position = Vector3(x*0.22,0.08,z*0.22)
            body.add_child(rotor)
            cylinder(rotor, Vector3.ZERO, 0.04, 0.045, dark, Vector3.ZERO)
            plate(rotor, Vector3(0.21,0.018,0.025), Vector3.ZERO, metal)
            animated.append(rotor)
    return body

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

func build(id: String, level: int, metal: Material, dark: Material, glow: Material) -> void:
    var cyan := StandardMaterial3D.new()
    cyan.albedo_color = Color("087b83")
    cyan.emission_enabled = true
    cyan.emission = Color("15cbd4")
    cyan.emission_energy_multiplier = 0.8
    var violet := StandardMaterial3D.new()
    violet.albedo_color = Color("8e42e8")
    violet.emission_enabled = true
    violet.emission = Color("bc51ff")
    violet.emission_energy_multiplier = 2.0
    match id:
        "chassis_core":
            plate(self, Vector3(0.92,0.48,0.19), Vector3(0,0.05,0.25), metal)
            plate(self, Vector3(0.56,0.21,0.08), Vector3(0,-0.14,0.36), dark)
            plate(self, Vector3(0.44,0.12,0.07), Vector3(0,0.08,0.37), dark)
            plate(self, Vector3(0.31,0.055,0.045), Vector3(0,0.08,0.42), glow)
            for side in [-1,1]:
                plate(self, Vector3(0.18,0.25,0.08), Vector3(side*0.35,0.02,0.34), metal)
                cylinder(self, Vector3(side*0.33,-0.12,0.40), 0.03, 0.025, dark)
                plate(self, Vector3(0.12,0.035,0.03), Vector3(side*0.34,0.13,0.40), glow)
        "chassis_shoulder":
            plate(self, Vector3(0.48,0.23,0.42), Vector3(0,0.08,0), metal)
            plate(self, Vector3(0.39,0.12,0.45), Vector3(0,-0.04,-0.04), dark)
            plate(self, Vector3(0.25,0.04,0.29), Vector3(0,0.22,0), glow)
            for side in [-1,1]: cylinder(self, Vector3(side*0.16,0.04,0.24),0.025,0.025,dark)
        "chassis_thigh":
            plate(self, Vector3(0.34,0.42,0.16), Vector3(0,-0.10,0.15), metal)
            plate(self, Vector3(0.24,0.22,0.06), Vector3(0,-0.11,0.25), dark)
            plate(self, Vector3(0.17,0.045,0.03), Vector3(0,-0.13,0.30), glow)
            for side in [-1,1]: cylinder(self,Vector3(side*0.12,-0.2,0.25),0.03,0.025,dark)
        "laser":
            plate(self, Vector3(0.42,0.34,0.55), Vector3.ZERO, metal)
            plate(self, Vector3(0.29,0.18,0.60), Vector3(0,0,-0.14), dark)
            cylinder(self, Vector3(0,0,-0.57), 0.48, 0.13, dark)
            cylinder(self, Vector3(0,0,-0.82), 0.10, 0.15, metal)
            cylinder(self, Vector3(0,0,-0.88), 0.035, 0.09, violet)
            for i in range(level):
                plate(self, Vector3(0.24,0.035,0.035), Vector3(0,0.20,-0.20+i*0.09), violet)
        "minigun":
            plate(self, Vector3(0.4,0.32,0.5), Vector3.ZERO, metal)
            cylinder(self, Vector3(0,0,-0.32), 0.28, 0.22, dark)
            cylinder(self, Vector3(0,0,-0.38), 0.12, 0.18, metal)
            var n := 3 + level
            var length := 0.45 + level * 0.07
            for i in range(n):
                var angle := TAU * i / n
                var p := Vector3(cos(angle)*0.12,sin(angle)*0.12,-0.53)
                cylinder(self, p, length, 0.045, dark)
                cylinder(self, Vector3(p.x,p.y,p.z-length/2), 0.035, 0.05, metal)
            cylinder(self, Vector3(0,0,-0.53-length/2), 0.045, 0.14, dark)
        "rocket", "swarm":
            var count := mini(level + 1, 4) if id == "rocket" else 6
            var width := 0.53 if id == "rocket" else 0.72
            plate(self, Vector3(width,0.42,0.52), Vector3.ZERO, dark)
            plate(self, Vector3(width+0.08,0.12,0.55), Vector3(0,0.2,0), metal)
            plate(self, Vector3(width*0.5,0.025,0.35), Vector3(0,0.275,0), glow)
            for side in [-1,1]:
                plate(self, Vector3(0.06,0.27,0.38), Vector3(side*(width/2+0.02),0,0), metal)
            for i in range(count):
                var columns := 2 if id == "rocket" else 3
                var x := (float(i % columns) - (columns - 1)*0.5)*0.20
                var y := (float(int(i / columns))-0.5)*0.19
                cylinder(self, Vector3(x,y,-0.29), 0.08, 0.09, metal)
                cylinder(self, Vector3(x,y,-0.34), 0.025, 0.063, dark)
                cylinder(self, Vector3(x,y,-0.36), 0.018, 0.038, glow)
            if id == "swarm":
                plate(self, Vector3(0.72,0.42,0.52), Vector3(-0.65,0,0), metal)
                for i in range(4): cylinder(self, Vector3(-0.8+(i%2)*0.22,(int(i/2)-0.5)*0.2,-0.29),0.05,0.065,glow)
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
            for i in range(level):
                var ring := MeshInstance3D.new()
                var torus := TorusMesh.new()
                torus.inner_radius = 0.36 + i * 0.04
                torus.outer_radius = 0.38 + i * 0.04
                ring.mesh = torus
                ring.material_override = cyan
                ring.rotation.x = PI / 2
                add_child(ring)
        _:
            for i in range(level): plate(self, Vector3(0.28,0.07,0.22), Vector3(0,i*0.08,0), metal if i%2 == 0 else cyan)

func _process(delta: float) -> void:
    time += delta
    for n in animated: n.rotate_y(delta * 9)
    for n in blades: n.rotate_z(delta * 9)
    for i in range(orbiters.size()):
        var angle := time * 1.1 + TAU * i / orbiters.size()
        orbiters[i].position = Vector3(cos(angle)*0.75,0.45,sin(angle)*0.55)
