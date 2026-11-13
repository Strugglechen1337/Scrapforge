"""Prepare Sketchfab scenery props (CC BY 4.0) for Scrapforge.

Run with Blender in background mode:
    blender --background --factory-startup --python tools/blender/process_props.py -- <extracted_dir> <out_dir>

For every prop listed in PROPS (and pipe modules in PIPE_PROPS) the script
imports the glTF, drops animations, joins all meshes into one object, puts the
origin at the bottom centre, scales to the target size in metres, desaturates
and weathers albedo/roughness textures (removing bright orange/yellow surfaces
and disabling prop emission), limits textures to 1024 px and exports a single
GLB with embedded textures.
"""
import hashlib
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

# uid -> (output name, target length of the longest horizontal side in metres)
PROPS = {
    "042201dac61041fabb88f483368daa3f": ("crate_basic", 1.3),
    "8eda583592f34498a350f6cc5a650042": ("crate_scifi", 1.6),
    "ac36898521304e51a8e305aa602f1f5b": ("crate_cargo", 2.2),
    "c50d7a37b9ec483f8abfdbecd162aa35": ("crate_v2", 1.4),
    "481f7499eaf64b8792bffc59a8b4e05a": ("barrel", 0.9),
    "8a19b0e0e22c4b9ba057eab497742f61": ("container", 1.7),  # tall supply canister, not a shipping container
}
PIPES_UID = "0b8188107ef040149f2f71eb08e9ce16"
# mesh name prefix -> (output name, target longest dimension in metres)
PIPE_PROPS = {
    "straight_normalpipe1": ("pipe_straight", 3.6),
    "prefab_normalpipe3": ("pipe_cluster", 2.6),
    "curve_normalpipe3": ("pipe_bent", 1.6),
}
MAX_TEXTURE = 1024


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def find_gltf(folder):
    for root, _dirs, files in os.walk(folder):
        for name in files:
            if name.lower().endswith((".gltf", ".glb")):
                return os.path.join(root, name)
    raise FileNotFoundError(folder)


def _value_noise(h, w, grid, rng):
    """Smooth bilinearly upsampled value noise in [0, 1] of shape (h, w)."""
    small = rng.random((grid, grid), dtype=np.float32)
    y = np.linspace(0, grid - 1, h, dtype=np.float32)
    x = np.linspace(0, grid - 1, w, dtype=np.float32)
    y0 = np.floor(y).astype(np.int32)
    x0 = np.floor(x).astype(np.int32)
    y1 = np.minimum(y0 + 1, grid - 1)
    x1 = np.minimum(x0 + 1, grid - 1)
    fy = (y - y0)[:, None]
    fx = (x - x0)[None, :]
    c00 = small[y0[:, None], x0[None, :]]
    c10 = small[y0[:, None], x1[None, :]]
    c01 = small[y1[:, None], x0[None, :]]
    c11 = small[y1[:, None], x1[None, :]]
    return (c00 * (1 - fx) + c10 * fx) * (1 - fy) + (c01 * (1 - fx) + c11 * fx) * fy


def _grime_mask(h, w, seed_key):
    seed = int.from_bytes(hashlib.sha256(seed_key.encode("utf-8")).digest()[:4], "little")
    rng = np.random.default_rng(seed)
    n1 = _value_noise(h, w, 12, rng)
    n2 = _value_noise(h, w, 32, rng)
    n3 = _value_noise(h, w, 96, rng)
    return np.clip(0.55 * n1 + 0.30 * n2 + 0.15 * n3, 0.0, 1.0)


def _rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cmax = np.maximum(np.maximum(r, g), b)
    cmin = np.minimum(np.minimum(r, g), b)
    delta = cmax - cmin
    h = np.zeros_like(cmax)
    mask = delta > 1e-6
    rm = mask & (cmax == r)
    gm = mask & (cmax == g)
    bm = mask & (cmax == b)
    h[rm] = ((g[rm] - b[rm]) / delta[rm]) % 6.0
    h[gm] = ((b[gm] - r[gm]) / delta[gm]) + 2.0
    h[bm] = ((r[bm] - g[bm]) / delta[bm]) + 4.0
    h = (h / 6.0) % 1.0
    s = np.where(cmax > 1e-6, delta / np.maximum(cmax, 1e-6), 0.0)
    return h, s, cmax


def _hsv_to_rgb(h, s, v):
    h6 = (h * 6.0) % 6.0
    i = np.floor(h6).astype(np.int32)
    f = h6 - i
    p = v * (1.0 - s)
    q = v * (1.0 - f * s)
    t = v * (1.0 - (1.0 - f) * s)
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=-1)


def _collect_linked_images(socket, visited=None):
    if visited is None:
        visited = set()
    imgs = []
    for link in socket.links:
        node = link.from_node
        if node in visited:
            continue
        visited.add(node)
        if node.type == "TEX_IMAGE" and node.image is not None:
            imgs.append(node.image)
        for inp in node.inputs:
            if inp.is_linked:
                imgs.extend(_collect_linked_images(inp, visited))
    return imgs


def weather_materials(seed_prefix, max_val=0.42):
    """Desaturate and dirty all albedo/roughness maps and disable prop emission."""
    albedo_imgs = set()
    rough_imgs = set()
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                if "Base Color" in node.inputs:
                    albedo_imgs.update(_collect_linked_images(node.inputs["Base Color"]))
                if "Roughness" in node.inputs:
                    rough_imgs.update(_collect_linked_images(node.inputs["Roughness"]))
                if "Emission Strength" in node.inputs:
                    node.inputs["Emission Strength"].default_value = 0.0
                if "Emission Color" in node.inputs:
                    for lk in list(node.inputs["Emission Color"].links):
                        mat.node_tree.links.remove(lk)
                    node.inputs["Emission Color"].default_value = (0.0, 0.0, 0.0, 1.0)

    for img in albedo_imgs:
        w, h = img.size[0], img.size[1]
        if w == 0 or h == 0:
            continue
        px = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))
        rgb = np.clip(px[..., :3], 0.0, 1.0)
        hue, sat, val = _rgb_to_hsv(rgb)
        warm_paint = (hue >= 0.015) & (hue <= 0.20) & (sat > 0.25)
        hue = np.where(warm_paint, 0.065, hue)
        sat_new = sat * 0.22
        sat_new = np.where(warm_paint, np.minimum(sat_new, 0.16), sat_new)
        val_new = val * np.where(warm_paint, 0.38, 0.55)
        val_new = np.clip(val_new, 0.03, max_val)
        desat = _hsv_to_rgb(hue, sat_new, val_new)

        grime = _grime_mask(h, w, f"{seed_prefix}_{img.name}")
        rust_amt = np.clip((grime - 0.48) * 1.4, 0.0, 0.55)[..., None]
        soot_amt = np.clip((0.42 - grime) * 1.3, 0.0, 0.45)[..., None]
        rust_col = np.array([0.22, 0.12, 0.07], dtype=np.float32)
        soot_col = np.array([0.04, 0.045, 0.055], dtype=np.float32)
        out_rgb = desat * (1.0 - rust_amt) + rust_col * rust_amt
        out_rgb = out_rgb * (1.0 - soot_amt) + soot_col * soot_amt
        px[..., :3] = np.clip(out_rgb, 0.0, 1.0)
        img.pixels[:] = px.ravel()
        img.pack()

    for img in rough_imgs:
        if img in albedo_imgs:
            continue
        w, h = img.size[0], img.size[1]
        if w == 0 or h == 0:
            continue
        px = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))
        grime = _grime_mask(h, w, f"{seed_prefix}_{img.name}_r")
        delta = (grime - 0.5) * 0.28
        px[..., 1] = np.clip(px[..., 1] + delta + 0.08, 0.30, 0.96)
        img.pixels[:] = px.ravel()
        img.pack()


def finalize_and_export(obj, name, target, out_dir, max_tex=MAX_TEXTURE, horizontal_only=True):
    for other in [o for o in bpy.context.scene.objects if o != obj]:
        bpy.data.objects.remove(other, do_unlink=True)
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    size = hi - lo
    denom = max(size.x, size.y, 1e-6) if horizontal_only else max(size.x, size.y, size.z, 1e-6)
    scale = target / denom
    pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co = (obj.matrix_world @ v.co - pivot) * scale
    obj.matrix_world.identity()
    obj.name = name

    for image in bpy.data.images:
        if image.size[0] > max_tex or image.size[1] > max_tex:
            factor = max_tex / max(image.size[0], image.size[1])
            image.scale(max(1, int(image.size[0] * factor)), max(1, int(image.size[1] * factor)))

    weather_materials(name)

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=False,
                              export_image_format="JPEG", export_jpeg_quality=85)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"PROP {name}: {tris} triangles, size {tuple(round(s * scale, 2) for s in size)} -> {path}")


def process(uid, name, target, src_root, out_dir):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=find_gltf(os.path.join(src_root, uid)))
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
        obj.animation_data_clear()
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    finalize_and_export(obj, name, target, out_dir, MAX_TEXTURE, horizontal_only=True)


def process_pipes(src_root, out_dir):
    pipes_gltf = find_gltf(os.path.join(src_root, PIPES_UID))
    for prefix, (name, target) in PIPE_PROPS.items():
        reset_scene()
        bpy.ops.import_scene.gltf(filepath=pipes_gltf)
        for action in list(bpy.data.actions):
            bpy.data.actions.remove(action)
        matches = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(prefix)]
        if not matches:
            raise RuntimeError(f"Pipe mesh prefix not found: {prefix}")
        obj = matches[0]
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        obj.animation_data_clear()
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        finalize_and_export(obj, name, target, out_dir, max_tex=512, horizontal_only=False)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src_root, out_dir = args[0], args[1]
    for uid, (name, target) in PROPS.items():
        process(uid, name, target, src_root, out_dir)
    process_pipes(src_root, out_dir)


if __name__ == "__main__":
    main()
