"""Build beveled, UV-mapped enemy & boss silhouette/weakspot meshes (.glb) for Scrapforge.

Run with Blender 5.2.3:
  blender --background --factory-startup --python tools/blender/build_enemies.py
"""
import math
import os
import bmesh
import bpy
from mathutils import Matrix

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "enemies"))

MAT_SPECS = {
    "mat_gunmetal": ((0.18, 0.21, 0.25, 1.0), 0.55, 0.48, (0.0, 0.0, 0.0), 0.0),
    "mat_dark": ((0.09, 0.11, 0.14, 1.0), 0.68, 0.44, (0.0, 0.0, 0.0), 0.0),
    "mat_red": ((0.98, 0.04, 0.04, 1.0), 0.1, 0.25, (1.0, 0.08, 0.08), 3.2),
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def get_mat(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    col, met, rough, em_col, em_str = MAT_SPECS[name]
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Metallic"].default_value = met
    bsdf.inputs["Roughness"].default_value = rough
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*em_col, 1.0)
        bsdf.inputs["Emission Strength"].default_value = em_str
    return mat


def mat_idx(name):
    return list(MAT_SPECS.keys()).index(name)


def add_beveled_box(bm, size, center=(0, 0, 0), rot=(0, 0, 0), bevel=0.014, m_idx=0):
    before = set(bm.faces)
    verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    mat_t = (
        Matrix.Translation(center)
        @ Matrix.Rotation(rot[2], 4, "Z")
        @ Matrix.Rotation(rot[1], 4, "Y")
        @ Matrix.Rotation(rot[0], 4, "X")
        @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    )
    bmesh.ops.transform(bm, matrix=mat_t, verts=verts)
    edges = list({e for v in verts for e in v.link_edges})
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    for f in bm.faces:
        if f not in before:
            f.material_index = m_idx


def add_cylinder(bm, r1, r2, depth, segs=14, center=(0, 0, 0), rot=(0, 0, 0), bevel=0.006, m_idx=0):
    before = set(bm.faces)
    verts = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth
    )["verts"]
    mat_t = (
        Matrix.Translation(center)
        @ Matrix.Rotation(rot[2], 4, "Z")
        @ Matrix.Rotation(rot[1], 4, "Y")
        @ Matrix.Rotation(rot[0], 4, "X")
    )
    bmesh.ops.transform(bm, matrix=mat_t, verts=verts)
    if bevel > 0:
        cap_edges = [e for v in verts for e in v.link_edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.7]
        if cap_edges:
            bmesh.ops.bevel(bm, geom=list(set(cap_edges)), offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    for f in bm.faces:
        if f not in before:
            f.material_index = m_idx


def finalize_and_export(bm, filename):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(filename)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(filename, mesh)
    bpy.context.collection.objects.link(obj)
    for m_name in MAT_SPECS:
        obj.data.materials.append(get_mat(m_name))
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bm_uv = bmesh.new()
    bm_uv.from_mesh(obj.data)
    uv_layer = bm_uv.loops.layers.uv.verify()
    for f in bm_uv.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if ay >= ax and ay >= az:
                loop[uv_layer].uv = (co.x * 1.5 + 0.5, co.z * 1.5 + 0.5)
            elif ax >= az:
                loop[uv_layer].uv = (co.z * 1.5 + 0.5, co.y * 1.5 + 0.5)
            else:
                loop[uv_layer].uv = (co.x * 1.5 + 0.5, co.y * 1.5 + 0.5)
    bm_uv.to_mesh(obj.data)
    bm_uv.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, filename + ".glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True)
    print(f"Exported {filename}.glb ({len(obj.data.polygons)} polys)")


def build_brute_armor():
    reset_scene()
    bm = bmesh.new()
    m_gun, m_drk = mat_idx("mat_gunmetal"), mat_idx("mat_dark")
    # Heavy broad shoulder & dorsal carapace
    add_beveled_box(bm, (0.72, 0.20, 0.56), center=(0, 0.52, -0.04), rot=(0.10, 0, 0), bevel=0.025, m_idx=m_gun)
    for side in (-1, 1):
        add_beveled_box(bm, (0.34, 0.24, 0.62), center=(side * 0.44, 0.42, 0.02), rot=(0.08, 0, side * -0.35), bevel=0.022, m_idx=m_gun)
        add_beveled_box(bm, (0.14, 0.12, 0.46), center=(side * 0.52, 0.48, 0.04), rot=(0.08, 0, side * -0.35), bevel=0.012, m_idx=m_drk)
    # Front ram brow
    add_beveled_box(bm, (0.56, 0.14, 0.22), center=(0, 0.46, 0.30), rot=(0.30, 0, 0), bevel=0.016, m_idx=m_drk)
    finalize_and_export(bm, "brute_armor")


def build_ranged_cannon():
    reset_scene()
    bm = bmesh.new()
    m_gun, m_drk, m_red = mat_idx("mat_gunmetal"), mat_idx("mat_dark"), mat_idx("mat_red")
    # Dorsal turret housing
    add_beveled_box(bm, (0.36, 0.18, 0.42), center=(0, 0.56, -0.05), bevel=0.018, m_idx=m_gun)
    # Long twin-rail barrel extending forward (+Z)
    for side in (-1, 1):
        add_beveled_box(bm, (0.08, 0.12, 0.68), center=(side * 0.10, 0.58, 0.34), bevel=0.008, m_idx=m_drk)
    # Glowing red energy core & muzzle slit
    add_cylinder(bm, 0.055, 0.045, 0.62, segs=10, center=(0, 0.58, 0.36), rot=(math.pi / 2, 0, 0), bevel=0.003, m_idx=m_red)
    add_beveled_box(bm, (0.28, 0.05, 0.24), center=(0, 0.66, 0.04), bevel=0.006, m_idx=m_red)
    finalize_and_export(bm, "ranged_cannon")


def build_boss_turret():
    reset_scene()
    bm = bmesh.new()
    m_gun, m_drk, m_red = mat_idx("mat_gunmetal"), mat_idx("mat_dark"), mat_idx("mat_red")
    add_beveled_box(bm, (0.85, 0.38, 0.88), center=(0, 0.0, 0.0), bevel=0.03, m_idx=m_gun)
    add_beveled_box(bm, (0.68, 0.24, 0.30), center=(0, 0.18, 0.36), bevel=0.02, m_idx=m_drk)
    for side in (-1, 1):
        add_cylinder(bm, 0.095, 0.085, 1.05, segs=12, center=(side * 0.22, 0.02, 0.68), rot=(math.pi / 2, 0, 0), bevel=0.006, m_idx=m_drk)
        add_cylinder(bm, 0.055, 0.055, 0.12, segs=10, center=(side * 0.22, 0.02, 1.22), rot=(math.pi / 2, 0, 0), bevel=0.003, m_idx=m_red)
    add_beveled_box(bm, (0.46, 0.08, 0.12), center=(0, 0.22, 0.38), bevel=0.008, m_idx=m_red)
    finalize_and_export(bm, "boss_turret")


def build_boss_weakspot():
    reset_scene()
    bm = bmesh.new()
    m_drk, m_red = mat_idx("mat_dark"), mat_idx("mat_red")
    add_beveled_box(bm, (0.34, 0.32, 0.42), center=(0, 0, 0), bevel=0.02, m_idx=m_drk)
    add_cylinder(bm, 0.13, 0.11, 0.38, segs=12, center=(0, 0.04, 0), rot=(0, 0, math.pi / 2), bevel=0.005, m_idx=m_red)
    for z in (-0.12, 0.0, 0.12):
        add_beveled_box(bm, (0.40, 0.04, 0.06), center=(0, 0.05, z), bevel=0.004, m_idx=m_drk)
    finalize_and_export(bm, "boss_weakspot")


def build_boss_armor_plate():
    reset_scene()
    bm = bmesh.new()
    m_gun, m_drk = mat_idx("mat_gunmetal"), mat_idx("mat_dark")
    add_beveled_box(bm, (0.24, 0.54, 0.92), center=(0, 0, 0), bevel=0.025, m_idx=m_gun)
    for z in (-0.28, 0.28):
        add_beveled_box(bm, (0.28, 0.12, 0.14), center=(0, 0.06, z), bevel=0.01, m_idx=m_drk)
    finalize_and_export(bm, "boss_armor_plate")


def main():
    build_brute_armor()
    build_ranged_cannon()
    build_boss_turret()
    build_boss_weakspot()
    build_boss_armor_plate()


if __name__ == "__main__":
    main()
