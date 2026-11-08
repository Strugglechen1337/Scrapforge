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

func build(id: String, level: int, metal: Material, dark: Material, glow: Material) -> void:
    match id:
        "minigun", "laser":
            make_box(self, Vector3(0.35, 0.32, 0.45), Vector3.ZERO, metal)
            for i in range(level + 1):
                var angle := TAU * i / (level + 1)
                make_box(self, Vector3(0.07, 0.07, 0.5 + level * 0.08), Vector3(cos(angle) * 0.11, sin(angle) * 0.11, -0.36), dark)
                make_box(self, Vector3(0.08, 0.08, 0.04), Vector3(cos(angle) * 0.11, sin(angle) * 0.11, -0.64 - level * 0.04), glow)
        "rocket", "swarm":
            make_box(self, Vector3(0.52, 0.4, 0.48), Vector3.ZERO, metal)
            for i in range(level if id == "rocket" else 6):
                make_box(self, Vector3(0.12, 0.12, 0.12), Vector3((i % 3 - 1) * 0.16, (i / 3 - 0.5) * 0.16, -0.27), glow)
        _:
            for i in range(level):
                make_box(self, Vector3(0.28, 0.07, 0.22), Vector3(0, i * 0.08, 0), metal if i % 2 == 0 else glow)
