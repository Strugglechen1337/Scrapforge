"""Build beveled, UV-mapped industrial PBR module meshes (.glb) for Scrapforge.

Run with Blender 5.2.3:
  blender --background --factory-startup --python tools/blender/build_modules.py
"""
import math
import os
import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "modules"))

MAT_SPECS = {
    "mat_metal": ((0.55, 0.53, 0.50, 1.0), 0.35, 0.62, (0.0, 0.0, 0.0), 0.0),
    "mat_dark": ((0.12, 0.14, 0.18, 1.0), 0.72, 0.44, (0.0, 0.0, 0.0), 0.0),
    "mat_accent": ((0.85, 0.42, 0.10, 1.0), 0.25, 0.58, (0.0, 0.0, 0.0), 0.0),
    "mat_glow": ((0.95, 0.38, 0.05, 1.0), 0.1, 0.3, (1.0, 0.45, 0.08), 2.4),
    "mat_cyan": ((0.10, 0.85, 0.92, 1.0), 0.1, 0.3, (0.15, 0.92, 1.0), 2.0),
    "mat_red": ((0.90, 0.08, 0.08, 1.0), 0.1, 0.25, (1.0, 0.10, 0.10), 2.2),
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


def make_obj(name, bm, mat_indices=None):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for m_name in MAT_SPECS:
        obj.data.materials.append(get_mat(m_name))
    if mat_indices:
        for poly, idx in zip(obj.data.polygons, mat_indices):
            poly.material_index = idx
    return obj


def mat_idx(name):
    return list(MAT_SPECS.keys()).index(name)


def add_beveled_box(bm, size, center=(0, 0, 0), rot=(0, 0, 0), bevel=0.012, m_idx=0):
    before = set(bm.faces)
    ret = bmesh.ops.create_cube(bm, size=1.0)
    verts = ret["verts"]
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


def add_cylinder(bm, r1, r2, depth, segs=16, center=(0, 0, 0), rot=(0, 0, 0), bevel=0.006, m_idx=0):
    before = set(bm.faces)
    ret = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth
    )
    verts = ret["verts"]
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


def add_bolt_ring(bm, radius, count, y_pos, bolt_r=0.015, bolt_h=0.02, m_idx=1):
    for i in range(count):
        a = math.tau * i / count
        add_cylinder(bm, bolt_r, bolt_r * 0.9, bolt_h, segs=6, center=(math.cos(a) * radius, y_pos, math.sin(a) * radius), bevel=0.002, m_idx=m_idx)


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
    # Box UV project via bmesh for clean PBR tiling without needing Edit Mode ops
    bm_uv = bmesh.new()
    bm_uv.from_mesh(obj.data)
    uv_layer = bm_uv.loops.layers.uv.verify()
    for f in bm_uv.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if ay >= ax and ay >= az:
                loop[uv_layer].uv = (co.x * 1.8 + 0.5, co.z * 1.8 + 0.5)
            elif ax >= az:
                loop[uv_layer].uv = (co.z * 1.8 + 0.5, co.y * 1.8 + 0.5)
            else:
                loop[uv_layer].uv = (co.x * 1.8 + 0.5, co.y * 1.8 + 0.5)
    bm_uv.to_mesh(obj.data)
    bm_uv.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, filename + ".glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True)
    print(f"Exported {filename}.glb ({len(obj.data.polygons)} polys)")


def build_saw():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc, m_glw = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent"), mat_idx("mat_glow")
    # Main beveled disc body
    add_cylinder(bm, 0.27, 0.27, 0.028, segs=32, bevel=0.006, m_idx=m_met)
    # Recessed dark clamping hub + top/bottom flange + hex bolts
    add_cylinder(bm, 0.115, 0.105, 0.055, segs=16, bevel=0.005, m_idx=m_drk)
    add_cylinder(bm, 0.05, 0.05, 0.075, segs=12, bevel=0.004, m_idx=m_drk)
    add_bolt_ring(bm, 0.082, 6, 0.025, 0.012, 0.016, m_idx=m_met)
    # Thermal orange ring inset around hub
    add_cylinder(bm, 0.135, 0.135, 0.032, segs=24, bevel=0.002, m_idx=m_glw)
    # 4 structural spoke ribs
    for i in range(4):
        a = math.tau * i / 4.0
        add_beveled_box(bm, (0.12, 0.036, 0.028), center=(math.cos(a) * 0.19, 0.0, math.sin(a) * 0.19), rot=(0, -a, 0), bevel=0.004, m_idx=m_drk)
    # 16 swept beveled saw teeth anchored cleanly into the rim
    teeth = 16
    for i in range(teeth):
        a = math.tau * i / teeth
        tx = math.cos(a) * 0.245
        tz = math.sin(a) * 0.245
        add_beveled_box(bm, (0.125, 0.022, 0.046), center=(tx, 0.0, tz), rot=(0, -(a - 0.30), 0), bevel=0.004, m_idx=m_met)
    finalize_and_export(bm, "saw")


def build_mount_bracket():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk = mat_idx("mat_metal"), mat_idx("mat_dark")
    add_beveled_box(bm, (0.28, 0.18, 0.22), center=(0, 0.0, 0.05), bevel=0.015, m_idx=m_drk)
    for side in (-1, 1):
        add_beveled_box(bm, (0.05, 0.22, 0.18), center=(side * 0.15, 0.0, 0.06), bevel=0.008, m_idx=m_met)
        add_cylinder(bm, 0.022, 0.022, 0.24, segs=8, center=(side * 0.11, -0.10, 0.04), rot=(math.pi / 2, 0, 0), bevel=0.003, m_idx=m_drk)
    finalize_and_export(bm, "mount_bracket")


def build_gun_drum():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent")
    add_cylinder(bm, 0.13, 0.13, 0.16, segs=18, center=(-0.18, -0.06, 0.05), rot=(0, 0, math.pi / 2), bevel=0.01, m_idx=m_drk)
    add_beveled_box(bm, (0.14, 0.12, 0.18), center=(-0.10, -0.02, 0.02), bevel=0.01, m_idx=m_met)
    add_beveled_box(bm, (0.18, 0.05, 0.24), center=(0.0, 0.14, -0.05), bevel=0.008, m_idx=m_acc)
    finalize_and_export(bm, "gun_drum")


def build_laser_coil():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_glw = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_glow")
    for side in (-1, 1):
        add_beveled_box(bm, (0.06, 0.14, 0.18), center=(side * 0.14, 0.02, -0.06), bevel=0.008, m_idx=m_drk)
        add_beveled_box(bm, (0.03, 0.05, 0.16), center=(side * 0.16, 0.03, -0.06), bevel=0.004, m_idx=m_glw)
    add_beveled_box(bm, (0.14, 0.05, 0.22), center=(0, 0.13, -0.04), bevel=0.007, m_idx=m_met)
    finalize_and_export(bm, "laser_coil")


def build_turret_pod():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent")
    add_beveled_box(bm, (0.28, 0.09, 0.24), center=(0, -0.08, 0), bevel=0.01, m_idx=m_drk)
    for side in (-1, 1):
        add_beveled_box(bm, (0.06, 0.22, 0.26), center=(side * 0.19, 0.04, -0.04), bevel=0.01, m_idx=m_met)
    add_beveled_box(bm, (0.34, 0.05, 0.12), center=(0, 0.18, -0.06), bevel=0.007, m_idx=m_acc)
    finalize_and_export(bm, "turret_pod")


def build_rocket_pod(cells, filename, is_swarm=False):
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent")
    m_tip = mat_idx("mat_cyan") if is_swarm else mat_idx("mat_glow")
    cols = 2 if cells <= 4 else 3
    rows = 1 if cells <= 2 else 2
    w = cols * 0.15 + 0.10
    h = rows * 0.15 + 0.10
    # Armored outer pod with chamfered hood
    add_beveled_box(bm, (w, h, 0.44), center=(0, 0, -0.10), bevel=0.018, m_idx=m_met)
    add_beveled_box(bm, (w + 0.04, 0.06, 0.36), center=(0, h * 0.5 + 0.01, -0.12), bevel=0.01, m_idx=m_acc)
    # Rear exhaust grille
    add_beveled_box(bm, (w * 0.85, h * 0.80, 0.06), center=(0, 0, 0.13), bevel=0.006, m_idx=m_drk)
    # Recessed launch cells + warhead noses
    for i in range(cells):
        cx = (float(i % cols) - (cols - 1) * 0.5) * 0.145
        cy = (float(i // cols) - (rows - 1) * 0.5) * 0.145
        add_cylinder(bm, 0.055, 0.055, 0.08, segs=12, center=(cx, cy, -0.32), rot=(math.pi / 2, 0, 0), bevel=0.005, m_idx=m_drk)
        add_cylinder(bm, 0.036, 0.012, 0.06, segs=10, center=(cx, cy, -0.35), rot=(-math.pi / 2, 0, 0), bevel=0.002, m_idx=m_tip)
    if is_swarm:
        for side in (-1, 1):
            add_beveled_box(bm, (0.045, 0.16, 0.42), center=(side * (w * 0.5 + 0.03), 0.04, -0.14), bevel=0.007, m_idx=m_drk)
            add_beveled_box(bm, (0.02, 0.04, 0.34), center=(side * (w * 0.5 + 0.045), 0.08, -0.14), bevel=0.004, m_idx=m_tip)
    finalize_and_export(bm, filename)


def build_flamethrower():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc, m_glw = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent"), mat_idx("mat_glow")
    # Receiver + mounting collar
    add_beveled_box(bm, (0.30, 0.26, 0.46), center=(0, 0, 0.02), bevel=0.018, m_idx=m_met)
    add_beveled_box(bm, (0.34, 0.08, 0.32), center=(0, 0.15, 0.0), bevel=0.01, m_idx=m_acc)
    # Perforated heat-shield barrel shroud
    add_cylinder(bm, 0.11, 0.095, 0.52, segs=12, center=(0, 0, -0.44), rot=(math.pi / 2, 0, 0), bevel=0.008, m_idx=m_drk)
    for z in (-0.28, -0.42, -0.56):
        add_cylinder(bm, 0.125, 0.125, 0.035, segs=12, center=(0, 0, z), rot=(math.pi / 2, 0, 0), bevel=0.004, m_idx=m_met)
    # Flared igniter nozzle + orange pilot glow
    add_cylinder(bm, 0.075, 0.115, 0.12, segs=12, center=(0, 0, -0.74), rot=(math.pi / 2, 0, 0), bevel=0.006, m_idx=m_drk)
    add_cylinder(bm, 0.055, 0.04, 0.05, segs=10, center=(0, 0, -0.79), rot=(math.pi / 2, 0, 0), bevel=0.003, m_idx=m_glw)
    # Under-barrel pilot igniter bracket
    add_beveled_box(bm, (0.05, 0.06, 0.18), center=(0, -0.11, -0.68), bevel=0.005, m_idx=m_drk)
    finalize_and_export(bm, "flamethrower")


def build_flamethrower_tank():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent")
    add_cylinder(bm, 0.105, 0.105, 0.36, segs=14, center=(0, 0, 0), rot=(math.pi / 2, 0, 0), bevel=0.015, m_idx=m_acc)
    for z in (-0.10, 0.10):
        add_cylinder(bm, 0.115, 0.115, 0.03, segs=14, center=(0, 0, z), rot=(math.pi / 2, 0, 0), bevel=0.004, m_idx=m_drk)
    add_beveled_box(bm, (0.08, 0.08, 0.24), center=(0, 0.09, 0), bevel=0.006, m_idx=m_met)
    finalize_and_export(bm, "flamethrower_tank")


def build_plasma():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc, m_glw = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent"), mat_idx("mat_glow")
    # Heavy magnetic containment housing
    add_beveled_box(bm, (0.34, 0.30, 0.46), center=(0, 0, 0.04), bevel=0.02, m_idx=m_met)
    add_beveled_box(bm, (0.38, 0.08, 0.26), center=(0, 0.17, 0.06), bevel=0.01, m_idx=m_drk)
    # Twin forward accelerator rails
    for side in (-1, 1):
        add_beveled_box(bm, (0.075, 0.18, 0.56), center=(side * 0.12, 0.0, -0.44), bevel=0.01, m_idx=m_drk)
        add_beveled_box(bm, (0.04, 0.06, 0.42), center=(side * 0.15, 0.04, -0.42), bevel=0.005, m_idx=m_acc)
    # Central glowing plasma core chamber
    add_cylinder(bm, 0.07, 0.07, 0.50, segs=12, center=(0, 0, -0.42), rot=(math.pi / 2, 0, 0), bevel=0.005, m_idx=m_glw)
    finalize_and_export(bm, "plasma")


def build_plasma_coil():
    reset_scene()
    bm = bmesh.new()
    m_drk, m_glw = mat_idx("mat_dark"), mat_idx("mat_glow")
    add_cylinder(bm, 0.16, 0.16, 0.055, segs=16, center=(0, 0, 0), rot=(math.pi / 2, 0, 0), bevel=0.008, m_idx=m_drk)
    add_cylinder(bm, 0.125, 0.125, 0.065, segs=16, center=(0, 0, 0), rot=(math.pi / 2, 0, 0), bevel=0.004, m_idx=m_glw)
    finalize_and_export(bm, "plasma_coil")


def build_thruster():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_cyn = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_cyan")
    # Central mounting bridge
    add_beveled_box(bm, (0.48, 0.16, 0.22), center=(0, 0.08, 0.04), bevel=0.015, m_idx=m_drk)
    for side in (-1, 1):
        # Armored thruster nacelle
        add_beveled_box(bm, (0.24, 0.34, 0.28), center=(side * 0.29, 0.0, 0.0), bevel=0.018, m_idx=m_met)
        # Flared vectoring nozzle bell
        add_cylinder(bm, 0.13, 0.095, 0.18, segs=16, center=(side * 0.29, -0.22, 0.02), rot=(0.15, 0, 0), bevel=0.008, m_idx=m_drk)
        # Cyan afterburner core
        add_cylinder(bm, 0.08, 0.05, 0.08, segs=12, center=(side * 0.29, -0.29, 0.03), rot=(0.15, 0, 0), bevel=0.004, m_idx=m_cyn)
    finalize_and_export(bm, "thruster")


def build_thruster_fin():
    reset_scene()
    bm = bmesh.new()
    m_met, m_acc, m_cyn = mat_idx("mat_metal"), mat_idx("mat_accent"), mat_idx("mat_cyan")
    for side in (-1, 1):
        add_beveled_box(bm, (0.04, 0.28, 0.22), center=(side * 0.44, 0.04, 0.02), rot=(0, 0, side * 0.25), bevel=0.007, m_idx=m_met)
        add_beveled_box(bm, (0.025, 0.14, 0.06), center=(side * 0.46, 0.10, 0.04), rot=(0, 0, side * 0.25), bevel=0.004, m_idx=m_acc)
        add_cylinder(bm, 0.055, 0.04, 0.09, segs=10, center=(side * 0.43, -0.14, 0.02), bevel=0.004, m_idx=m_cyn)
    finalize_and_export(bm, "thruster_fin")


def build_armor():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent")
    add_beveled_box(bm, (0.56, 0.26, 0.14), center=(0, 0.0, 0.04), rot=(0.12, 0, 0), bevel=0.018, m_idx=m_met)
    add_beveled_box(bm, (0.42, 0.10, 0.16), center=(0, -0.14, 0.02), rot=(0.05, 0, 0), bevel=0.012, m_idx=m_drk)
    add_beveled_box(bm, (0.48, 0.045, 0.06), center=(0, 0.11, 0.09), bevel=0.006, m_idx=m_acc)
    finalize_and_export(bm, "armor")


def build_armor_plate():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_acc = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_accent")
    add_beveled_box(bm, (0.24, 0.14, 0.09), center=(0, 0, 0), bevel=0.012, m_idx=m_met)
    add_beveled_box(bm, (0.18, 0.03, 0.10), center=(0, 0.05, 0.01), bevel=0.005, m_idx=m_acc)
    for sx in (-0.08, 0.08):
        add_cylinder(bm, 0.015, 0.015, 0.11, segs=6, center=(sx, -0.02, 0.01), rot=(math.pi / 2, 0, 0), bevel=0.002, m_idx=m_drk)
    finalize_and_export(bm, "armor_plate")


def build_magnet():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_cyn = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_cyan")
    # Electromagnetic yoke + copper/steel winding core
    add_beveled_box(bm, (0.38, 0.18, 0.18), center=(0, 0.0, 0.04), bevel=0.016, m_idx=m_drk)
    add_cylinder(bm, 0.11, 0.11, 0.22, segs=16, center=(0, 0.0, 0.08), rot=(math.pi / 2, 0, 0), bevel=0.01, m_idx=m_met)
    add_cylinder(bm, 0.075, 0.075, 0.25, segs=14, center=(0, 0.0, 0.10), rot=(math.pi / 2, 0, 0), bevel=0.005, m_idx=m_cyn)
    for side in (-1, 1):
        add_beveled_box(bm, (0.06, 0.14, 0.14), center=(side * 0.20, 0.0, 0.10), bevel=0.008, m_idx=m_met)
    finalize_and_export(bm, "magnet")


def build_magnet_coil():
    reset_scene()
    bm = bmesh.new()
    m_drk, m_cyn = mat_idx("mat_dark"), mat_idx("mat_cyan")
    add_cylinder(bm, 0.085, 0.085, 0.18, segs=12, center=(0, 0, 0), rot=(math.pi / 2, 0, 0), bevel=0.008, m_idx=m_drk)
    add_cylinder(bm, 0.095, 0.095, 0.04, segs=12, center=(0, 0, 0.04), rot=(math.pi / 2, 0, 0), bevel=0.004, m_idx=m_cyn)
    finalize_and_export(bm, "magnet_coil")


def build_cooldown():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_cyn = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_cyan")
    add_beveled_box(bm, (0.42, 0.28, 0.16), center=(0, 0.0, 0.0), bevel=0.015, m_idx=m_drk)
    # Angled radiator louvers
    for i in range(4):
        y = -0.09 + i * 0.06
        add_beveled_box(bm, (0.34, 0.025, 0.18), center=(0, y, 0.02), rot=(0.25, 0, 0), bevel=0.004, m_idx=m_met)
    for side in (-1, 1):
        add_beveled_box(bm, (0.04, 0.22, 0.06), center=(side * 0.18, 0, 0.08), bevel=0.005, m_idx=m_cyn)
    finalize_and_export(bm, "cooldown")


def build_cooldown_tank():
    reset_scene()
    bm = bmesh.new()
    m_drk, m_cyn = mat_idx("mat_dark"), mat_idx("mat_cyan")
    add_cylinder(bm, 0.075, 0.075, 0.28, segs=12, center=(0, 0, 0), bevel=0.01, m_idx=m_drk)
    add_cylinder(bm, 0.08, 0.08, 0.06, segs=12, center=(0, 0.04, 0), bevel=0.004, m_idx=m_cyn)
    finalize_and_export(bm, "cooldown_tank")


def build_radar():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_cyn = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_cyan")
    # Bolted mast + gimbal yoke
    add_cylinder(bm, 0.075, 0.06, 0.24, segs=12, center=(0, 0.10, 0), bevel=0.006, m_idx=m_drk)
    add_beveled_box(bm, (0.34, 0.14, 0.08), center=(0, 0.26, -0.02), rot=(-0.25, 0, 0), bevel=0.012, m_idx=m_met)
    # Dish wings
    for side in (-1, 1):
        add_beveled_box(bm, (0.14, 0.16, 0.05), center=(side * 0.18, 0.27, 0.02), rot=(-0.25, side * -0.35, 0), bevel=0.008, m_idx=m_met)
    # Feed horn
    add_cylinder(bm, 0.035, 0.02, 0.12, segs=10, center=(0, 0.28, 0.06), rot=(math.pi / 2 - 0.25, 0, 0), bevel=0.003, m_idx=m_cyn)
    finalize_and_export(bm, "radar")


def build_radar_array():
    reset_scene()
    bm = bmesh.new()
    m_met, m_cyn = mat_idx("mat_metal"), mat_idx("mat_cyan")
    add_beveled_box(bm, (0.48, 0.045, 0.07), center=(0, 0.40, 0), bevel=0.007, m_idx=m_met)
    add_beveled_box(bm, (0.42, 0.02, 0.025), center=(0, 0.40, 0.035), bevel=0.003, m_idx=m_cyn)
    finalize_and_export(bm, "radar_array")


def build_sensor():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_cyn, m_red = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_cyan"), mat_idx("mat_red")
    # Armored optical housing
    add_beveled_box(bm, (0.36, 0.18, 0.24), center=(0, 0.14, 0.02), bevel=0.016, m_idx=m_met)
    add_beveled_box(bm, (0.30, 0.10, 0.06), center=(0, 0.14, 0.14), bevel=0.008, m_idx=m_drk)
    # Recessed lenses (cyan + red)
    add_cylinder(bm, 0.042, 0.038, 0.05, segs=12, center=(-0.08, 0.14, 0.16), rot=(math.pi / 2, 0, 0), bevel=0.003, m_idx=m_cyn)
    add_cylinder(bm, 0.036, 0.032, 0.05, segs=12, center=(0.08, 0.14, 0.16), rot=(math.pi / 2, 0, 0), bevel=0.003, m_idx=m_red)
    # Tapered whip antenna + beacon
    add_cylinder(bm, 0.022, 0.008, 0.36, segs=8, center=(0.12, 0.38, -0.04), bevel=0.002, m_idx=m_drk)
    add_cylinder(bm, 0.018, 0.014, 0.04, segs=8, center=(0.12, 0.56, -0.04), bevel=0.002, m_idx=m_cyn)
    finalize_and_export(bm, "sensor")


def build_sensor_pod():
    reset_scene()
    bm = bmesh.new()
    m_drk, m_red, m_cyn = mat_idx("mat_dark"), mat_idx("mat_red"), mat_idx("mat_cyan")
    add_beveled_box(bm, (0.12, 0.14, 0.22), center=(0, 0, 0), bevel=0.01, m_idx=m_drk)
    add_cylinder(bm, 0.03, 0.025, 0.04, segs=10, center=(0, 0, 0.12), rot=(math.pi / 2, 0, 0), bevel=0.002, m_idx=m_red)
    add_cylinder(bm, 0.016, 0.006, 0.28, segs=8, center=(0, 0.20, -0.04), bevel=0.002, m_idx=m_cyn)
    finalize_and_export(bm, "sensor_pod")


def build_shield_emitter():
    reset_scene()
    bm = bmesh.new()
    m_drk, m_cyn = mat_idx("mat_dark"), mat_idx("mat_cyan")
    # Hexagonal beveled emitter ring (6 segments)
    for i in range(6):
        a = math.tau * i / 6.0 + math.pi / 6.0
        cx, cy = math.cos(a) * 0.34, math.sin(a) * 0.34
        add_beveled_box(bm, (0.24, 0.045, 0.06), center=(cx, cy, 0), rot=(0, 0, a + math.pi / 2), bevel=0.006, m_idx=m_drk)
        add_beveled_box(bm, (0.16, 0.02, 0.07), center=(cx, cy, 0), rot=(0, 0, a + math.pi / 2), bevel=0.003, m_idx=m_cyn)
    finalize_and_export(bm, "shield_emitter")


def build_shield_pylon():
    reset_scene()
    bm = bmesh.new()
    m_met, m_cyn = mat_idx("mat_metal"), mat_idx("mat_cyan")
    add_beveled_box(bm, (0.07, 0.18, 0.14), center=(0, 0, 0), bevel=0.008, m_idx=m_met)
    add_beveled_box(bm, (0.03, 0.14, 0.05), center=(0, 0.02, -0.06), bevel=0.004, m_idx=m_cyn)
    finalize_and_export(bm, "shield_pylon")


def build_drone_dock():
    reset_scene()
    bm = bmesh.new()
    m_met, m_drk, m_cyn = mat_idx("mat_metal"), mat_idx("mat_dark"), mat_idx("mat_cyan")
    add_beveled_box(bm, (0.44, 0.24, 0.18), center=(0, 0, 0.08), bevel=0.015, m_idx=m_drk)
    for side in (-1, 1):
        add_beveled_box(bm, (0.16, 0.05, 0.22), center=(side * 0.18, 0.10, 0.02), rot=(0, 0, side * -0.2), bevel=0.007, m_idx=m_met)
        add_beveled_box(bm, (0.08, 0.02, 0.12), center=(side * 0.18, 0.13, 0.02), rot=(0, 0, side * -0.2), bevel=0.003, m_idx=m_cyn)
    finalize_and_export(bm, "drone_dock")


def main():
    build_saw()
    build_mount_bracket()
    build_gun_drum()
    build_laser_coil()
    build_turret_pod()
    build_rocket_pod(2, "rocket_pod_2")
    build_rocket_pod(4, "rocket_pod_4")
    build_rocket_pod(6, "rocket_pod_6")
    build_rocket_pod(6, "swarm_pod", is_swarm=True)
    build_flamethrower()
    build_flamethrower_tank()
    build_plasma()
    build_plasma_coil()
    build_thruster()
    build_thruster_fin()
    build_armor()
    build_armor_plate()
    build_magnet()
    build_magnet_coil()
    build_cooldown()
    build_cooldown_tank()
    build_radar()
    build_radar_array()
    build_sensor()
    build_sensor_pod()
    build_shield_emitter()
    build_shield_pylon()
    build_drone_dock()


if __name__ == "__main__":
    main()
