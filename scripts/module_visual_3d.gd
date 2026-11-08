extends Node3D

func make_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    parent.add_child(instance)
    return instance

func barrel(pos: Vector3, length: float, radius: float, material: Material) -> void:
    var instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 10
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    instance.rotation.x = PI / 2
    add_child(instance)

func build(id: String, level: int, metal: Material, dark: Material, glow: Material) -> void:
    match id:
        "minigun", "laser":
            make_box(self, Vector3(0.35, 0.32, 0.45), Vector3.ZERO, metal)
            for i in range(level + 1):
                var angle := TAU * i / (level + 1)
                barrel(Vector3(cos(angle) * 0.11, sin(angle) * 0.11, -0.36), 0.5 + level * 0.08, 0.045, dark)
                make_box(self, Vector3(0.08, 0.08, 0.04), Vector3(cos(angle) * 0.11, sin(angle) * 0.11, -0.64 - level * 0.04), glow)
        "rocket", "swarm":
            make_box(self, Vector3(0.52, 0.4, 0.48), Vector3.ZERO, metal)
            for i in range(level if id == "rocket" else 6):
                make_box(self, Vector3(0.12, 0.12, 0.12), Vector3((i % 3 - 1) * 0.16, (int(i / 3) - 0.5) * 0.16, -0.27), glow)
            if id == "swarm":
                make_box(self, Vector3(1.5, 0.22, 0.45), Vector3(-0.55, 0.18, 0.1), dark)
                for i in range(4): make_box(self, Vector3(0.12, 0.12, 0.1), Vector3(-1.0 + i * 0.14, 0.2, -0.2), glow)
        "armor":
            for i in range(level):
                make_box(self, Vector3(0.5 + i * 0.04, 0.08, 0.18), Vector3(0, -0.17 + i * 0.09, -0.08), metal)
        "radar":
            make_box(self, Vector3(0.08, 0.2 + level * 0.09, 0.08), Vector3(0, 0.1 + level * 0.045, 0), dark)
            for i in range(level): make_box(self, Vector3(0.18 + i * 0.06, 0.025, 0.03), Vector3(0, 0.28 + i * 0.08, 0), glow)
        "thruster":
            for side in [-1, 1]:
                make_box(self, Vector3(0.2 + level * 0.02, 0.35, 0.25), Vector3(side * 0.3, 0, 0), metal)
                make_box(self, Vector3(0.12, 0.12 + level * 0.06, 0.12), Vector3(side * 0.3, -0.24, 0), glow)
        "saw":
            for i in range(level):
                var a := TAU * i / level
                make_box(self, Vector3(0.15, 0.15, 0.3), Vector3(cos(a) * 0.7, sin(a) * 0.4, -0.1), metal)
        "shield":
            for i in range(level):
                var ring := MeshInstance3D.new()
                var torus := TorusMesh.new()
                torus.inner_radius = 0.36 + i * 0.04
                torus.outer_radius = 0.38 + i * 0.04
                ring.mesh = torus
                ring.material_override = glow
                ring.rotation.x = PI / 2
                add_child(ring)
        _:
            for i in range(level):
                make_box(self, Vector3(0.28, 0.07, 0.22), Vector3(0, i * 0.08, 0), metal if i % 2 == 0 else glow)
