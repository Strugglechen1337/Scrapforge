"""Generate the Colossus armor paint mask (assets/models/colossus_paint_mask.png) in Blender.

Reads the embedded Base Color and Metallic/Roughness textures from colossus-parts.glb
so only armor plates are paintable (R), while bare metal, joints, and cables stay
unpainted. G stores edge-wear & scratches; B stores panel-seam shading.

Run with Blender 5.2.3:
  blender --background --factory-startup --python tools/blender/build_paint_mask.py
"""
import os
import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_GLB = os.path.join(ROOT, "assets", "third_party", "sketchfab", "colossus", "colossus-parts.glb")
OUT_PNG = os.path.join(ROOT, "assets", "models", "colossus_paint_mask.png")


def find_colossus_images():
    mat = bpy.data.objects["torso"].data.materials[0]
    base_img = None
    orm_img = None
    for link in mat.node_tree.links:
        if link.to_node.type == "BSDF_PRINCIPLED" and link.to_socket.name == "Base Color":
            base_img = link.from_node.image
        elif link.to_node.type == "SEPARATE_COLOR" and link.from_node.type == "TEX_IMAGE":
            orm_img = link.from_node.image
    if not base_img or not orm_img:
        raise RuntimeError("Could not find Base Color and ORM textures on Colossus torso material")
    return base_img, orm_img


def img_to_array(img):
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    return arr.reshape((h, w, 4))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC_GLB)
    base_img, orm_img = find_colossus_images()

    base = img_to_array(base_img)
    orm = img_to_array(orm_img)

    # Downsample 2048 -> 1024 via 2x2 block average
    base = 0.25 * (base[0::2, 0::2] + base[1::2, 0::2] + base[0::2, 1::2] + base[1::2, 1::2])
    orm = 0.25 * (orm[0::2, 0::2] + orm[1::2, 0::2] + orm[0::2, 1::2] + orm[1::2, 1::2])

    lum = 0.2126 * base[..., 0] + 0.7152 * base[..., 1] + 0.0722 * base[..., 2]
    metallic = orm[..., 2]  # glTF ORM: B = metallic, G = roughness

    # Armor panels: non-metallic (metallic < 0.35) and bright enough to not be dark joints/cables/seams
    paint_mask = np.clip((0.38 - metallic) / 0.16, 0.0, 1.0) * np.clip((lum - 0.09) / 0.09, 0.0, 1.0)

    # Edge-wear detection from gradient of paint_mask + luminance seams
    gx = np.abs(np.roll(paint_mask, -1, axis=1) - np.roll(paint_mask, 1, axis=1))
    gy = np.abs(np.roll(paint_mask, -1, axis=0) - np.roll(paint_mask, 1, axis=0))
    lx = np.abs(np.roll(lum, -1, axis=1) - np.roll(lum, 1, axis=1))
    ly = np.abs(np.roll(lum, -1, axis=0) - np.roll(lum, 1, axis=0))
    edge_wear = np.clip((gx + gy) * 1.4 + (lx + ly) * 1.8, 0.0, 1.0) * paint_mask

    # Deterministic diagonal micro-scratches across armor plates
    rng = np.random.default_rng(47021)
    scratches = np.zeros_like(paint_mask)
    h, w = paint_mask.shape
    for _ in range(420):
        x0 = int(rng.integers(8, w - 24))
        y0 = int(rng.integers(8, h - 24))
        length = int(rng.integers(6, 22))
        dx = 1 if rng.random() > 0.3 else -1
        dy = int(rng.integers(-1, 2))
        strength = float(rng.uniform(0.35, 0.85))
        for j in range(length):
            xx = (x0 + j * dx) % w
            yy = (y0 + j * dy) % h
            scratches[yy, xx] = max(scratches[yy, xx], strength)

    wear_total = np.clip(edge_wear * 0.85 + scratches * paint_mask * 0.75, 0.0, 1.0)
    seam_shade = np.clip(lum * 2.2 + 0.25, 0.25, 1.0)

    out = np.ones((h, w, 4), dtype=np.float32)
    out[..., 0] = paint_mask
    out[..., 1] = wear_total
    out[..., 2] = seam_shade

    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    out_img = bpy.data.images.new("colossus_paint_mask", width=w, height=h, alpha=False)
    out_img.pixels.foreach_set(out.ravel())
    out_img.filepath_raw = OUT_PNG
    out_img.file_format = "PNG"
    out_img.save()
    print(f"Saved {OUT_PNG} ({w}x{h}), paint coverage={paint_mask.mean():.2%}, wear={wear_total.mean():.2%}")


if __name__ == "__main__":
    main()
