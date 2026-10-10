# Moon Eggs in Blender Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the five Moon eggs from the artwork as Roblox-ready Blender models, one at a time, each approved by the owner before the next.

**Architecture:** One shared Python module (`egg_common.py`) holds the egg shape, mesh builders, mask painting, material helpers and the check → bake → export pipeline. Each egg is one short build script that describes only its own shape and look, then calls `finish()`. Two headless test files check the shared module and the exported files.

**Tech Stack:** Blender 5.2.2 (Python 3.13, `bpy`, `bmesh`, `numpy`), Cycles CPU baking, FBX export, `unittest`. Builds run in the owner's open Blender through the Blender MCP tool `execute_blender_code`. Tests run in a headless Blender.

**Spec:** `docs/superpowers/specs/2026-10-10-moon-eggs-blender-design.md`

## Global Constraints

- Ids: `moon_mouse`, `moon_rabbit`, `luna_moth`, `lunar_wolf`, `eclipse_phoenix`. Build order: Mouse, Rabbit, Moth, Wolf, Phoenix.
- Each egg is approved by the owner before the next egg starts.
- Size: the whole egg, all pieces included, is 3 units tall (1 Blender unit = 1 stud), pivot at its centre. Each script has a `HEIGHT` constant.
- Pieces: `<id>_Shell` (one textured mesh) and zero or more `<id>_Glow_*` (untextured, set to Neon in Roblox).
- Triangle budget: about 2,000 per egg; hard cap 4,000 (all pieces together). Detail lives in the normal map, not the geometry.
- Textures (Shell only): `<id>_color.png` and `<id>_normal.png` at 1024 px, `<id>_roughness.png` and `<id>_metalness.png` at 512 px. The colour map is sRGB; the others are Non-Color.
- Outputs per egg in `assets/eggs/<id>/`: `<id>.fbx` (textures embedded), the four PNGs, and `<id>.blend` (PNGs linked by relative path).
- Egg only: no nests, crystals, rocks, moon discs or eclipse rings. Rings, ribbons, planets, fireflies and flames are later Roblox effects.
- Faithful to the artwork. No iridescent shader in Roblox, so rainbow sheen is painted into the colour map.
- Every build only touches its own scene `egg_<id>` and data-blocks named `<id>_...` in the owner's open file.

**Tools used throughout:**
- Headless Blender (Bash): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python <script>`
- Live build (Blender MCP `execute_blender_code`):
  ```python
  import runpy
  runpy.run_path(r"C:\Users\malaz\OneDrive\Documents\GitHub\Steal-a-pet-from-Space-\tools\blender\eggs\<id>.py", run_name="__main__")
  ```
- Looking (Blender MCP `look`): `mode="angles"`, `views=["front", "three_quarter", "back"]`, `shading="rendered"`, `target=["<id>_Shell", ...glows]`, `max_size=640`.
- Reference artwork: `assets/eggs/reference/moon_eggs_art.webp` (open it with `look(image=<path>)` to compare).

## Review Focus

1. **Re-running a build in the same Blender session** must replace the last build exactly, with no `.001` duplicates and no leftover images or materials. *(Task 1: `test_rebuild_replaces_only_its_own_data`)*
2. **The owner's own scenes, objects and materials** must survive every build untouched. *(Task 1: same test, which keeps the factory `Cube` and `Material`)*
3. **Where the outputs land** must not depend on whether, or where, the open `.blend` is saved: always `<repo>/assets/eggs/<id>/`. *(Task 2: `test_outputs_go_to_the_repo_whatever_file_is_open`)*
4. **Map colour spaces**: colour in sRGB, normal/roughness/metalness in Non-Color, or Roblox shows washed-out or wrongly-bumped eggs. *(Task 2: `test_finish_bakes_and_exports`)*
5. **The texture seam at the back** must not show as a line after baking. *(Task 2: `test_finish_bakes_and_exports`, which compares the pixels on either side of the seam)*

---

## File structure

| File | Responsibility |
|------|----------------|
| `tools/blender/eggs/egg_common.py` | Egg shape, scene isolation, mesh builders (shell, dots, strips), masks, material and node helpers, preview rig, `finish()` (check, fit, bake, save, export). |
| `tools/blender/eggs/test_egg_common.py` | Headless tests of `egg_common`. |
| `tools/blender/eggs/test_eggs.py` | Headless checks of the exported eggs in `assets/eggs/`. |
| `tools/blender/eggs/<id>.py` | One build script per egg: shape constants, look, glow pieces, then `finish()`. |
| `assets/eggs/<id>/` | Outputs per egg. |
| `assets/eggs/reference/moon_eggs_art.webp` | The owner's artwork, for comparison. |
| `CLAUDE.md` | Short "Egg models" note for future sessions (Task 8). |

---

### Task 1: Egg shape, scenes, meshes and masks

**Files:**
- Create: `tools/blender/eggs/egg_common.py`
- Create: `tools/blender/eggs/test_egg_common.py`
- Create: `assets/eggs/reference/moon_eggs_art.webp` (copy of the owner's image)

**Interfaces:**
- Consumes: nothing.
- Produces (all in `egg_common`):
  - `REPO: str`, `ASSETS: str`, `TRI_TARGET = 2000`, `TRI_CAP = 4000`, `MAP_SIZES: dict[str, int]`, `NON_COLOR: tuple[str, ...]`, `class EggCheckError(Exception)`
  - `class EggShape(height=3.0, width=0.74, pointiness=0.16)` with `.height`, `.arc_length`, `.z(v) -> float`, `.radius(v) -> float`, `.point(u, v, lift=0.0) -> (Vector, Vector)` (position, outward unit normal), `.studs_per_uv(v) -> (float, float)`
  - `new_egg_scene(egg_id) -> bpy.types.Scene`
  - `object_from_bmesh(egg_id, scene, piece, bm) -> Object` (named `<id>_<piece>`)
  - `add_egg(bm, shape, segments=40, rings=24, lift=0.0, uv_point=None) -> list[BMFace]`
  - `make_egg_mesh(egg_id, scene, shape, segments=40, rings=24) -> Object` (`<id>_Shell`, 1,840 triangles by default)
  - `make_dots(egg_id, scene, piece, shape, dots, lift=0.012, sides=8) -> Object`, where dots is `[(u, v, radius_studs)]`
  - `make_strips(egg_id, scene, piece, shape, lines, width=0.03, lift=0.012, step=0.05) -> Object`, where lines is `[[(u, v), ...], ...]`
  - `join_into(target, *others) -> Object` (merges others' meshes into target and deletes them)
  - `mask_image(egg_id, name, fn, size=1024) -> Image` (`<id>_mask_<name>`, Non-Color), where `fn(u, v)` takes numpy grids and returns values in 0..1
  - `paint_strokes(egg_id, name, shape, strokes, size=1024) -> Image`, where strokes is `[(points, width_studs)]`
  - Egg coordinates: `u` = turns around the egg (0 = front, facing -Y; 0.25 = +X side); `v` = 0 at the bottom tip to 1 at the top tip. Texture x = `u + 0.5`, so the seam is at the back.

- [ ] **Step 1: Copy the reference artwork into the repo**

```bash
mkdir -p "/c/Users/malaz/OneDrive/Documents/GitHub/Steal-a-pet-from-Space-/assets/eggs/reference"
cp "/c/Users/malaz/AppData/Local/Temp/claude/C--Users-malaz-OneDrive-Documents-GitHub-Steal-a-pet-from-Space-/e5f0145d-265c-48b7-9875-6f1a0d73b5a2/images/1.webp" "/c/Users/malaz/OneDrive/Documents/GitHub/Steal-a-pet-from-Space-/assets/eggs/reference/moon_eggs_art.webp"
```

- [ ] **Step 2: Write the failing tests**

`tools/blender/eggs/test_egg_common.py`:

```python
"""Tests for egg_common. Run headless from the repo root:
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_egg_common.py
"""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
import bpy
import numpy as np

import egg_common as ec


def pixels(img):
    """An image's pixels as a (height, width, 4) array, row 0 at the bottom."""
    a = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


class Shape(unittest.TestCase):
    def test_tips_and_width(self):
        s = ec.EggShape(height=3, width=0.74, pointiness=0.16)
        self.assertAlmostEqual(s.point(0, 0)[0].z, -1.5)
        self.assertAlmostEqual(s.point(0, 1)[0].z, 1.5)
        widest = max(range(1001), key=lambda i: s.radius(i / 1000)) / 1000
        self.assertLess(widest, 0.5)                                   # fattest below the middle
        self.assertAlmostEqual(2 * s.radius(widest), 3 * 0.74, delta=0.1)

    def test_front_is_minus_y_and_normals_point_out(self):
        s = ec.EggShape()
        p, _ = s.point(0, 0.5)
        self.assertLess(p.y, -1)
        self.assertAlmostEqual(p.x, 0, places=6)
        for u in (0, 0.13, 0.5, 0.77):
            for v in (0.01, 0.3, 0.5, 0.9, 0.99):
                p, n = s.point(u, v)
                self.assertAlmostEqual(n.length, 1, places=5)
                self.assertGreater(n.dot(p), 0)


class Mesh(unittest.TestCase):
    def test_shell_budget_size_and_uvs(self):
        scene = ec.new_egg_scene("tmesh")
        shell = ec.make_egg_mesh("tmesh", scene, ec.EggShape())
        self.assertEqual(shell.name, "tmesh_Shell")
        self.assertLessEqual(tris(shell), ec.TRI_TARGET)
        zs = [v.co.z for v in shell.data.vertices]
        self.assertAlmostEqual(max(zs), 1.5, places=4)
        self.assertAlmostEqual(min(zs), -1.5, places=4)
        uvs = np.empty(len(shell.data.loops) * 2)
        shell.data.uv_layers[0].data.foreach_get("uv", uvs)
        self.assertGreaterEqual(uvs.min(), 0)
        self.assertLessEqual(uvs.max(), 1)

    def test_shell_is_closed_and_faces_outward(self):
        scene = ec.new_egg_scene("tclosed")
        shell = ec.make_egg_mesh("tclosed", scene, ec.EggShape())
        bm = bmesh.new()
        bm.from_mesh(shell.data)
        self.assertTrue(all(e.is_manifold for e in bm.edges))
        self.assertTrue(all(f.normal.dot(f.calc_center_median()) > 0 for f in bm.faces))
        bm.free()


class Scenes(unittest.TestCase):
    def test_rebuild_replaces_only_its_own_data(self):
        s = ec.EggShape()
        for _ in range(2):
            scene = ec.new_egg_scene("trebuild")
            ec.make_egg_mesh("trebuild", scene, s)
            ec.paint_strokes("trebuild", "veins", s, [([(0, 0.2), (0, 0.8)], 0.05)], size=64)
        self.assertEqual([x.name for x in bpy.data.scenes if x.name.startswith("egg_trebuild")], ["egg_trebuild"])
        self.assertEqual([o.name for o in bpy.data.scenes["egg_trebuild"].objects], ["trebuild_Shell"])
        for blocks in (bpy.data.objects, bpy.data.meshes, bpy.data.images):
            self.assertEqual([b.name for b in blocks if b.name.startswith("trebuild") and "." in b.name], [])
        self.assertIn("Cube", bpy.data.scenes["Scene"].objects)       # the owner's things are untouched
        self.assertIn("Material", bpy.data.materials)


class Decals(unittest.TestCase):
    def test_dots_and_strips_sit_just_above_the_surface(self):
        s = ec.EggShape()
        scene = ec.new_egg_scene("tdecal")
        dots = ec.make_dots("tdecal", scene, "Glow_A", s, [(0, 0.5, 0.05), (0.3, 0.8, 0.03)], lift=0.012)
        strips = ec.make_strips("tdecal", scene, "Glow_B", s, [[(-0.1, 0.4), (0.1, 0.6)]], width=0.03, lift=0.012)
        self.assertEqual(dots.name, "tdecal_Glow_A")
        self.assertEqual(tris(dots), 2 * 6)
        for obj in (dots, strips):
            for vert in obj.data.vertices:
                p = vert.co
                gap = math.hypot(p.x, p.y) - s.radius(p.z / 3 + 0.5)
                self.assertGreater(gap, 0)
                self.assertLess(gap, 0.03)
            for poly in obj.data.polygons:
                self.assertGreater(poly.normal.dot(poly.center), 0)

    def test_join_into_merges_and_removes(self):
        s = ec.EggShape()
        scene = ec.new_egg_scene("tjoin")
        a = ec.make_strips("tjoin", scene, "Glow_A", s, [[(0, 0.4), (0, 0.6)]])
        b = ec.make_dots("tjoin", scene, "Glow_B", s, [(0.2, 0.5, 0.05)])
        before = tris(a) + tris(b)
        ec.join_into(a, b)
        self.assertEqual(tris(a), before)
        self.assertEqual([o.name for o in scene.objects], ["tjoin_Glow_A"])
        self.assertNotIn("tjoin_Glow_B", bpy.data.meshes)


class Masks(unittest.TestCase):
    def test_strokes_paint_lines_and_wrap_the_back_seam(self):
        s = ec.EggShape()
        img = ec.paint_strokes("tmask", "a", s, [([(0, 0.2), (0, 0.8)], 0.3), ([(0.45, 0.5), (0.55, 0.5)], 0.3)], size=256)
        px = pixels(img)[..., 0]
        self.assertGreater(px[128, 128], 0.95)       # the front line (texture x 0.5 is the front)
        self.assertLess(px[128, 64], 0.01)           # a quarter turn away: blank
        self.assertGreater(px[128, 2], 0.9)          # the line across the back seam shows at both edges
        self.assertGreater(px[128, 253], 0.9)
        self.assertEqual(img.colorspace_settings.name, "Non-Color")

    def test_mask_image_from_function(self):
        img = ec.mask_image("tmask", "b", lambda u, v: (np.abs(u) < 0.1) * 1.0, size=64)
        px = pixels(img)[..., 0]
        self.assertAlmostEqual(px[32, 32], 1.0, places=2)
        self.assertAlmostEqual(px[32, 0], 0.0, places=2)
        self.assertEqual(img.name, "tmask_mask_b")


if __name__ == "__main__":
    result = unittest.main(argv=["blender"], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_egg_common.py`
Expected: exits non-zero with `ModuleNotFoundError: No module named 'egg_common'`.

- [ ] **Step 4: Write the implementation**

`tools/blender/eggs/egg_common.py` (Task 2 appends the materials and `finish()` sections):

```python
"""Shared helpers for the Moon egg build scripts in this folder.

Spec: docs/superpowers/specs/2026-10-10-moon-eggs-blender-design.md

Every egg is built in its own scene, egg_<id>, and every data-block a build makes is named "<id>_...",
so re-running a build replaces exactly what the last one made and never touches anything else in the
open file. Egg surface coordinates: u = turns around the egg (0 = front, facing -Y; 0.25 = the +X
side; the texture's seam is at u = +-0.5, the back), v = 0 at the bottom tip .. 1 at the top tip.
finish() checks an egg, bakes its look into PNGs and exports assets/eggs/<id>/.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
ASSETS = os.path.join(REPO, "assets", "eggs")

TRI_TARGET = 2000
TRI_CAP = 4000
MAP_SIZES = {"color": 1024, "normal": 1024, "roughness": 512, "metalness": 512}
NON_COLOR = ("normal", "roughness", "metalness")


class EggCheckError(Exception):
    """An egg failed a check, so nothing was written."""


# --- shape -------------------------------------------------------------------------------------------

class EggShape:
    """A smooth egg standing on +Z, centred on the origin.

    width: widest diameter as a fraction of height. pointiness: how much narrower the top is (0 = ellipsoid).
    """

    def __init__(self, height=3.0, width=0.74, pointiness=0.16):
        self.height, self.width, self.pointiness = height, width, pointiness
        profile = [(self.radius(i / 400), self.z(i / 400)) for i in range(401)]
        self.arc_length = sum(math.dist(a, b) for a, b in zip(profile, profile[1:]))

    def z(self, v):
        return (v - 0.5) * self.height

    def radius(self, v):
        t = 2 * v - 1
        return 0.5 * self.height * self.width * math.sqrt(max(0.0, 1 - t * t)) * (1 - self.pointiness * t)

    def point(self, u, v, lift=0.0):
        """(position, outward unit normal) at egg coordinates (u, v), pushed out along the normal by lift."""
        if v <= 0 or v >= 1:
            n = Vector((0, 0, 1 if v >= 1 else -1))
            return Vector((0, 0, self.z(min(max(v, 0), 1)))) + n * lift, n
        a = 2 * math.pi * u
        side = Vector((math.sin(a), -math.cos(a), 0))
        lo, hi = max(v - 1e-4, 0), min(v + 1e-4, 1)
        slope = (self.radius(hi) - self.radius(lo)) / (hi - lo)
        n = (side * self.height - Vector((0, 0, slope))).normalized()
        return side * self.radius(v) + Vector((0, 0, self.z(v))) + n * lift, n

    def studs_per_uv(self, v):
        """Studs spanned by one unit of u (a full turn) and one unit of v, at height v."""
        return max(2 * math.pi * self.radius(v), 1e-3), self.arc_length


# --- scene and meshes --------------------------------------------------------------------------------

_KINDS = ("objects", "meshes", "materials", "images", "lights", "cameras", "worlds")


def _window():
    wm = bpy.context.window_manager
    return bpy.context.window or (wm.windows[0] if wm and wm.windows else None)


def new_egg_scene(egg_id):
    """A fresh, empty scene egg_<id>, shown in Blender's window. Deletes the last build of this egg."""
    old = bpy.data.scenes.get("egg_" + egg_id)
    scene = bpy.data.scenes.new("egg_" + egg_id + "_new")
    window = _window()
    if window:
        window.scene = scene
    if old:
        bpy.data.scenes.remove(old)
    for kind in _KINDS:
        blocks = getattr(bpy.data, kind)
        for block in [b for b in blocks if b.name.startswith(egg_id + "_")]:
            blocks.remove(block)
    scene.name = "egg_" + egg_id
    return scene


def object_from_bmesh(egg_id, scene, piece, bm):
    """Turn bm into the mesh object <id>_<piece> in scene (frees bm)."""
    mesh = bpy.data.meshes.new(f"{egg_id}_{piece}")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"{egg_id}_{piece}", mesh)
    scene.collection.objects.link(obj)
    return obj


def _uv_layer(bm):
    return bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")


def add_egg(bm, shape, segments=40, rings=24, lift=0.0, uv_point=None):
    """Add a closed, smooth egg surface to bm. UVs wrap round it (texture x = u + 0.5, seam at the back),
    or with uv_point=(x, y) every UV sits on that one texel (for hidden parts). Returns the new faces."""
    uv = _uv_layer(bm)
    vs = [(1 - math.cos(math.pi * i / rings)) / 2 for i in range(rings + 1)]   # denser near the tips
    us = [j / segments - 0.5 for j in range(segments + 1)]
    bottom = bm.verts.new(shape.point(0, 0, lift)[0])
    top = bm.verts.new(shape.point(0, 1, lift)[0])
    grid = [[bm.verts.new(shape.point(u, v, lift)[0]) for u in us[:-1]] for v in vs[1:-1]]
    faces = []
    for i in range(rings):
        for j in range(segments):
            k = (j + 1) % segments
            x0, x1, y0, y1 = us[j] + 0.5, us[j + 1] + 0.5, vs[i], vs[i + 1]
            if i == 0:
                verts, uvs = [bottom, grid[0][k], grid[0][j]], [((x0 + x1) / 2, 0), (x1, y1), (x0, y1)]
            elif i == rings - 1:
                verts, uvs = [grid[-1][j], grid[-1][k], top], [(x0, y0), (x1, y0), ((x0 + x1) / 2, 1)]
            else:
                verts = [grid[i - 1][j], grid[i - 1][k], grid[i][k], grid[i][j]]
                uvs = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
            face = bm.faces.new(verts)
            face.smooth = True
            for loop, t in zip(face.loops, uvs):
                loop[uv].uv = uv_point or t
            faces.append(face)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def make_egg_mesh(egg_id, scene, shape, segments=40, rings=24):
    """The textured shell <id>_Shell: segments * (rings - 1) * 2 triangles (1,840 by default)."""
    bm = bmesh.new()
    add_egg(bm, shape, segments, rings)
    return object_from_bmesh(egg_id, scene, "Shell", bm)


def _basis(n):
    t = n.cross(Vector((0, 0, 1)))
    if t.length < 1e-6:
        t = Vector((1, 0, 0))
    t.normalize()
    return t, n.cross(t)


def make_dots(egg_id, scene, piece, shape, dots, lift=0.012, sides=8):
    """Flat round discs lying on the egg, as <id>_<piece>. dots: [(u, v, radius_in_studs)]."""
    bm = bmesh.new()
    for u, v, r in dots:
        centre, n = shape.point(u, v, lift)
        a, b = _basis(n)
        ring = [bm.verts.new(centre + (a * math.cos(2 * math.pi * k / sides) + b * math.sin(2 * math.pi * k / sides)) * r)
                for k in range(sides)]
        bmesh.ops.triangulate(bm, faces=[bm.faces.new(ring)])
    return object_from_bmesh(egg_id, scene, piece, bm)


def make_strips(egg_id, scene, piece, shape, lines, width=0.03, lift=0.012, step=0.05):
    """Thin flat ribbons following the egg's surface, as <id>_<piece>. lines: [[(u, v), ...], ...];
    each segment is cut every `step` studs so the ribbon hugs the curve."""
    bm = bmesh.new()
    for line in lines:
        samples = []
        for (u0, v0), (u1, v1) in zip(line, line[1:]):
            n = max(1, math.ceil((shape.point(u1, v1)[0] - shape.point(u0, v0)[0]).length / step))
            samples += [(u0 + (u1 - u0) * i / n, v0 + (v1 - v0) * i / n) for i in range(n)]
        samples.append(line[-1])
        surface = [shape.point(u, v, lift) for u, v in samples]
        left, right = [], []
        for i, (p, n) in enumerate(surface):
            ahead = surface[min(i + 1, len(surface) - 1)][0] - surface[max(i - 1, 0)][0]
            side = n.cross(ahead).normalized() * width / 2
            left.append(bm.verts.new(p + side))
            right.append(bm.verts.new(p - side))
        for i in range(len(surface) - 1):
            bm.faces.new([right[i], right[i + 1], left[i + 1], left[i]])
    return object_from_bmesh(egg_id, scene, piece, bm)


def join_into(target, *others):
    """Merge the meshes of `others` into `target` and delete them. Returns target."""
    bm = bmesh.new()
    bm.from_mesh(target.data)
    for other in others:
        bm.from_mesh(other.data)                   # from_mesh appends to what's already in bm
        mesh = other.data
        bpy.data.objects.remove(other)
        bpy.data.meshes.remove(mesh)
    bm.to_mesh(target.data)
    bm.free()
    return target


# --- masks: greyscale images in the shell's texture space --------------------------------------------

def _image(name, size, non_color):
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(name, size, size, alpha=False)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def _grey(img, values):
    rgba = np.ones((img.size[1], img.size[0], 4), np.float32)
    rgba[..., :3] = values[..., None]
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    return img


def mask_image(egg_id, name, fn, size=1024):
    """Mask <id>_mask_<name>. fn(u, v) gets numpy grids of egg coordinates (u -0.5..0.5, v 0..1) and
    returns values 0..1."""
    t = (np.arange(size) + 0.5) / size
    u, v = np.meshgrid(t - 0.5, t)
    return _grey(_image(f"{egg_id}_mask_{name}", size, True), np.clip(fn(u, v), 0, 1))


def paint_strokes(egg_id, name, shape, strokes, size=1024):
    """Mask <id>_mask_<name> of soft-edged lines. strokes: [(points, width_in_studs)], points in egg
    (u, v). Lines wrap across the back seam and keep their width in studs all round the egg."""
    acc = np.zeros((size, size), np.float32)
    for points, width in strokes:
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            _segment(acc, shape, (u0 + 0.5, v0), (u1 + 0.5, v1), width / 2)
    return _grey(_image(f"{egg_id}_mask_{name}", size, True), acc)


def _segment(acc, shape, a, b, half):
    size = acc.shape[0]
    sx, sy = shape.studs_per_uv((a[1] + b[1]) / 2)
    dx, dy = (b[0] - a[0]) * sx, (b[1] - a[1]) * sy
    length2 = dx * dx + dy * dy
    for shift in (-1, 0, 1):                       # copies a turn either side, so lines cross the seam
        ax = a[0] + shift
        lo_x, hi_x = min(ax, ax + b[0] - a[0]) - half / sx, max(ax, ax + b[0] - a[0]) + half / sx
        lo_y, hi_y = min(a[1], b[1]) - half / sy, max(a[1], b[1]) + half / sy
        x0, x1 = max(int(lo_x * size), 0), min(int(hi_x * size) + 2, size)
        y0, y1 = max(int(lo_y * size), 0), min(int(hi_y * size) + 2, size)
        if x0 >= x1 or y0 >= y1:
            continue
        px, py = np.meshgrid((np.arange(x0, x1) + 0.5) / size, (np.arange(y0, y1) + 0.5) / size)
        qx, qy = (px - ax) * sx, (py - a[1]) * sy
        t = np.clip((qx * dx + qy * dy) / length2, 0, 1) if length2 > 0 else 0.0
        s = np.clip(1 - np.hypot(qx - t * dx, qy - t * dy) / half, 0, 1)
        acc[y0:y1, x0:x1] = np.maximum(acc[y0:y1, x0:x1], s * s * (3 - 2 * s))
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_egg_common.py`
Expected: `Ran 9 tests ... OK`, exit code 0. If `bm.from_mesh` replaces rather than appends in this Blender version, make `join_into` merge through a temporary BMesh per mesh instead, and keep the test as written.

- [ ] **Step 6: Commit**

```bash
git add tools/blender/eggs/egg_common.py tools/blender/eggs/test_egg_common.py assets/eggs/reference/moon_eggs_art.webp
git commit -m "Moon eggs: shared egg shape, meshes and masks for the Blender builds"
```

---

### Task 2: Materials, bake and export (`finish`)

**Files:**
- Modify: `tools/blender/eggs/egg_common.py` (append two sections)
- Modify: `tools/blender/eggs/test_egg_common.py` (add class `Finish`)
- Create: `tools/blender/eggs/test_eggs.py`

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces (in `egg_common`):
  - `lookdev_material(egg_id) -> (Material, NodeTree, Node)` (`<id>_lookdev`, exactly one Principled BSDF)
  - `glow_material(egg_id, piece, rgb) -> Material`
  - `add(nt, kind, **inputs) -> Node` (keyword names use `_` for spaces; values are plain values or sockets)
  - `coords(nt) -> NodeSocket`, `mask(nt, img) -> NodeSocket`, `mix(nt, fac, a, b) -> NodeSocket`, `ramp(nt, fac, stops) -> NodeSocket`, `calc(nt, op, a, b=0.0) -> NodeSocket`, `bump(nt, height, strength, distance=0.02) -> NodeSocket`
  - `add_preview_rig(egg_id, scene) -> None`
  - `finish(egg_id, scene, shape, shell, glows=(), out_dir=None, sizes=None, samples=4) -> dict[str, str]`, with keys `fbx`, `blend`, `color`, `normal`, `roughness`, `metalness`. It raises `EggCheckError` and writes nothing when the triangle cap, UVs, modifiers/transforms or the single-BSDF rule fail.
  - `test_eggs.py`: `EGGS: dict[str, list[str]]` (id → glow piece names, e.g. `"lunar_wolf": ["Glow_Stars", "Glow_Sun"]`)

- [ ] **Step 1: Write the failing tests**

Add to `tools/blender/eggs/test_egg_common.py`, above `if __name__ == "__main__":`. Also add `import tempfile` to the imports at the top.

```python
SMALL = {"color": 128, "normal": 128, "roughness": 64, "metalness": 64}


def test_egg(egg_id, segments=40, rings=24):
    """A shell with a red-to-blue colour (bottom to top), bumps, roughness 0.3, metal 0.7, and one glow dot."""
    s = ec.EggShape()
    scene = ec.new_egg_scene(egg_id)
    shell = ec.make_egg_mesh(egg_id, scene, s, segments, rings)
    mat, nt, bsdf = ec.lookdev_material(egg_id)
    height = ec.add(nt, "ShaderNodeSeparateXYZ", Vector=ec.coords(nt)).outputs["Z"]
    fac = ec.add(nt, "ShaderNodeMapRange", Value=height, From_Min=-1.5, From_Max=1.5).outputs["Result"]
    nt.links.new(ec.ramp(nt, fac, [(0, (1, 0, 0)), (1, (0, 0, 1))]), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Metallic"].default_value = 0.7
    noise = ec.add(nt, "ShaderNodeTexNoise", Scale=8.0, Vector=ec.coords(nt))
    nt.links.new(ec.bump(nt, noise.outputs["Fac"], 0.8), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    glow = ec.make_dots(egg_id, scene, "Glow_X", s, [(0, 0.5, 0.1)])
    glow.data.materials.append(ec.glow_material(egg_id, "Glow_X", (1, 0.3, 0)))
    return scene, s, shell, glow


class Finish(unittest.TestCase):
    def test_finish_bakes_and_exports(self):
        scene, s, shell, glow = test_egg("tfinish")
        for o in (shell, glow):                       # finish() must re-centre a shifted egg
            o.data.transform(ec.Matrix.Translation((0.2, 0, 0.4)))
        engine = scene.render.engine
        out = tempfile.mkdtemp()
        paths = ec.finish("tfinish", scene, s, shell, [glow], out_dir=out, sizes=SMALL, samples=1)
        self.assertEqual(scene.render.engine, engine)
        for kind, size in SMALL.items():
            self.assertEqual(tuple(bpy.data.images.load(paths[kind], check_existing=False).size), (size, size))
        normal = pixels(bpy.data.images["tfinish_normal"])
        self.assertGreater(normal[..., :3].std(axis=(0, 1)).max(), 0.01)          # bumps reached the normal map
        self.assertAlmostEqual(float(np.median(normal[..., 2])), 1.0, delta=0.15)  # mostly pointing straight out
        color = pixels(bpy.data.images["tfinish_color"])
        self.assertGreater(color[5, :, 0].mean(), color[-5, :, 0].mean())         # red at the bottom
        self.assertLess(np.abs(color[64, 0, :3] - color[64, -1, :3]).max(), 0.05)  # no seam at the back
        metal = pixels(bpy.data.images["tfinish_metalness"])
        self.assertAlmostEqual(float(np.median(metal[..., 0])), 0.7, delta=0.03)
        self.assertEqual(bpy.data.images["tfinish_color"].colorspace_settings.name, "sRGB")
        for kind in ec.NON_COLOR:
            self.assertEqual(bpy.data.images[f"tfinish_{kind}"].colorspace_settings.name, "Non-Color")
        pts = np.vstack([ec._verts(o) for o in (shell, glow)])
        self.assertAlmostEqual(float(pts[:, 2].max() - pts[:, 2].min()), 3.0, places=4)
        self.assertLess(float(np.abs((pts.max(0) + pts.min(0)) / 2).max()), 1e-4)
        self.assertTrue(os.path.exists(paths["blend"]))
        check = bpy.data.scenes.new("tfinish_check")
        with bpy.context.temp_override(scene=check, view_layer=check.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=paths["fbx"])
        self.assertEqual(sorted(o.name.split(".")[0] for o in check.objects), ["tfinish_Glow_X", "tfinish_Shell"])

    def test_over_the_cap_raises_and_writes_nothing(self):
        scene, s, shell, glow = test_egg("tcap", segments=120, rings=40)   # 9,360 triangles
        out = tempfile.mkdtemp()
        with self.assertRaises(ec.EggCheckError):
            ec.finish("tcap", scene, s, shell, [glow], out_dir=out, sizes=SMALL, samples=1)
        self.assertEqual(os.listdir(out), [])

    def test_outputs_go_to_the_repo_whatever_file_is_open(self):
        repo = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
        self.assertEqual(ec.ASSETS, os.path.join(repo, "assets", "eggs"))
        self.assertTrue(os.path.isfile(os.path.join(ec.REPO, "default.project.json")))
```

`tools/blender/eggs/test_eggs.py`:

```python
"""Checks the exported Moon eggs in assets/eggs/. Run headless from the repo root after building an egg:
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
import numpy as np

import egg_common as ec

# Each built egg -> the names of its glow pieces. Add an egg here before building it.
EGGS = {
}


class Eggs(unittest.TestCase):
    def test_every_egg(self):
        for egg_id, glows in EGGS.items():
            with self.subTest(egg=egg_id):
                self.check(egg_id, glows)

    def check(self, egg_id, glows):
        folder = os.path.join(ec.ASSETS, egg_id)
        for kind, size in ec.MAP_SIZES.items():
            path = os.path.join(folder, f"{egg_id}_{kind}.png")
            self.assertTrue(os.path.isfile(path), path)
            self.assertEqual(tuple(bpy.data.images.load(path, check_existing=False).size), (size, size))
        self.assertTrue(os.path.isfile(os.path.join(folder, f"{egg_id}.blend")))
        scene = bpy.data.scenes.new("check_" + egg_id)
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=os.path.join(folder, f"{egg_id}.fbx"))
        pieces = list(scene.objects)
        self.assertEqual(sorted(o.name for o in pieces), sorted([f"{egg_id}_Shell"] + [f"{egg_id}_{g}" for g in glows]))
        self.assertLessEqual(sum(len(p.vertices) - 2 for o in pieces for p in o.data.polygons), ec.TRI_CAP)
        pts = np.vstack([[tuple(o.matrix_world @ v.co) for v in o.data.vertices] for o in pieces])
        self.assertAlmostEqual(float(pts[:, 2].max() - pts[:, 2].min()), 3.0, delta=0.03)
        self.assertLess(float(np.abs((pts.max(0) + pts.min(0)) / 2).max()), 0.01)
        shell = scene.objects[f"{egg_id}_Shell"]
        self.assertTrue(any(n.type == "TEX_IMAGE" and n.image for n in shell.active_material.node_tree.nodes))


if __name__ == "__main__":
    result = unittest.main(argv=["blender"], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_egg_common.py`
Expected: the 3 `Finish` tests error with `AttributeError: module 'egg_common' has no attribute 'lookdev_material'`; the 9 Task 1 tests still pass.

- [ ] **Step 3: Write the implementation**

Append to `tools/blender/eggs/egg_common.py`:

```python
# --- materials ---------------------------------------------------------------------------------------

def _new_material(name):
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    if mat.node_tree is None:                     # Blender before 5.0 needs nodes switched on
        mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None) or nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    return mat, nt, bsdf


def lookdev_material(egg_id):
    """New material <id>_lookdev with one Principled BSDF: build the look on it and finish() bakes it.
    Returns (material, node_tree, bsdf)."""
    return _new_material(f"{egg_id}_lookdev")


def glow_material(egg_id, piece, rgb):
    """Bright material for a Glow piece, so previews look right. Roblox replaces it with Neon in this colour."""
    mat, _, bsdf = _new_material(f"{egg_id}_{piece}")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
    bsdf.inputs["Emission Strength"].default_value = 4.0
    return mat


def _feed(nt, socket, value):
    if isinstance(value, bpy.types.NodeSocket):
        nt.links.new(value, socket)
    elif socket.type == "RGBA":
        socket.default_value = (*value[:3], 1)
    else:
        socket.default_value = value


def add(nt, kind, **inputs):
    """New node of type kind (e.g. "ShaderNodeTexNoise"). Keyword arguments set or link inputs by name,
    with _ for spaces: add(nt, "ShaderNodeMapRange", Value=socket, From_Min=-1.5)."""
    node = nt.nodes.new(kind)
    for name, value in inputs.items():
        _feed(nt, node.inputs[name.replace("_", " ")], value)
    return node


def coords(nt):
    """Object-space position. The egg is centred on the origin, so this is position in studs."""
    return nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]


def mask(nt, img):
    """Image-texture node reading a mask; returns its colour output (use it as a 0..1 value)."""
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    return node.outputs["Color"]


def mix(nt, fac, a, b):
    """Colour from a (fac 0) to b (fac 1). Each argument is a socket or a plain value."""
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    ins = {s.identifier: s for s in node.inputs}
    _feed(nt, ins["Factor_Float"], fac)
    _feed(nt, ins["A_Color"], a)
    _feed(nt, ins["B_Color"], b)
    return next(s for s in node.outputs if s.identifier == "Result_Color")


def ramp(nt, fac, stops):
    """Colour ramp over fac; stops: [(position, (r, g, b))]. Returns its colour output."""
    node = nt.nodes.new("ShaderNodeValToRGB")
    els = node.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1)
    for pos, rgb in stops[1:]:
        els.new(pos).color = (*rgb, 1)
    _feed(nt, node.inputs["Fac"], fac)
    return node.outputs["Color"]


def calc(nt, op, a, b=0.0):
    """Math node (op e.g. "ADD", "MULTIPLY", "SUBTRACT"); returns its output."""
    node = nt.nodes.new("ShaderNodeMath")
    node.operation = op
    _feed(nt, node.inputs[0], a)
    _feed(nt, node.inputs[1], b)
    return node.outputs[0]


def bump(nt, height, strength, distance=0.02):
    """Normal output that bumps the surface by height (a 0..1 socket)."""
    return add(nt, "ShaderNodeBump", Strength=strength, Distance=distance, Height=height).outputs["Normal"]


def _aim(obj):
    obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()


def add_preview_rig(egg_id, scene):
    """Camera, three lights and a dark sky for look renders. finish() exports meshes only."""
    world = bpy.data.worlds.new(f"{egg_id}_world")
    if world.node_tree is None:
        world.use_nodes = True
    nt = world.node_tree
    bg = next((n for n in nt.nodes if n.type == "BACKGROUND"), None) or nt.nodes.new("ShaderNodeBackground")
    out = next((n for n in nt.nodes if n.type == "OUTPUT_WORLD"), None) or nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    bg.inputs["Color"].default_value = (0.04, 0.05, 0.08, 1)
    bg.inputs["Strength"].default_value = 0.5
    scene.world = world
    for name, location, power, size in (("key", (-3.5, -5, 3.5), 900, 3), ("rim", (4, 5, 3), 700, 2),
                                        ("fill", (5, -4, -1), 250, 4)):
        light = bpy.data.lights.new(f"{egg_id}_{name}", "AREA")
        light.energy, light.size = power, size
        obj = bpy.data.objects.new(f"{egg_id}_{name}", light)
        scene.collection.objects.link(obj)
        obj.location = location
        _aim(obj)
    cam = bpy.data.objects.new(f"{egg_id}_camera", bpy.data.cameras.new(f"{egg_id}_camera"))
    scene.collection.objects.link(cam)
    cam.data.lens = 85
    cam.location = (0, -13, 0.8)
    _aim(cam)
    scene.camera = cam


# --- finish: check, fit, bake, export ----------------------------------------------------------------

def _verts(obj):
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _bsdf(mat):
    found = [n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"]
    if len(found) != 1:
        raise EggCheckError(f"{mat.name} needs exactly one Principled BSDF to bake, it has {len(found)}")
    return found[0]


def _check(shell, pieces):
    for o in pieces:
        if o.modifiers or o.matrix_world != Matrix.Identity(4):
            raise EggCheckError(f"{o.name}: build pieces in place, with no modifiers or object transforms")
    tris = sum(_tris(o) for o in pieces)
    if tris > TRI_CAP:
        raise EggCheckError(f"{tris} triangles is over the cap of {TRI_CAP}")
    if not shell.data.uv_layers:
        raise EggCheckError(f"{shell.name} has no UV map")
    if len(shell.material_slots) != 1 or not shell.material_slots[0].material:
        raise EggCheckError(f"{shell.name} needs exactly one material (its look-dev material)")
    _bsdf(shell.material_slots[0].material)


def _fit(pieces, height):
    """Move and scale all pieces together so the whole egg is `height` tall, centred on the origin."""
    pts = np.vstack([_verts(o) for o in pieces])
    lo, hi = pts.min(0), pts.max(0)
    m = Matrix.Scale(height / (hi[2] - lo[2]), 4) @ Matrix.Translation(Vector(-(lo + hi) / 2))
    for o in pieces:
        o.data.transform(m)
        o.data.update()


def _select_only(scene, objs):
    """Select objs (first one active) and return a temp_override() context for operators on them."""
    layer = scene.view_layers[0]
    for o in scene.objects:
        o.select_set(o in objs, view_layer=layer)
    layer.objects.active = objs[0]
    ctx = dict(scene=scene, view_layer=layer, active_object=objs[0], object=objs[0],
               selected_objects=list(objs), selected_editable_objects=list(objs))
    if _window():
        ctx["window"] = _window()
    return ctx


_BAKE_TYPE = {"color": "EMIT", "metalness": "EMIT", "roughness": "ROUGHNESS", "normal": "NORMAL"}


def _bake_one(mat, bsdf, kind, img):
    nt = mat.node_tree
    surface = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"]
    shader = surface.links[0].from_socket
    temp = [nt.nodes.new("ShaderNodeTexImage")]
    temp[0].image = img
    for node in nt.nodes:
        node.select = False
    temp[0].select = True
    nt.nodes.active = temp[0]
    if _BAKE_TYPE[kind] == "EMIT":                # send the colour (or metalness) straight out and bake that
        emit = nt.nodes.new("ShaderNodeEmission")
        temp.append(emit)
        source = bsdf.inputs["Base Color" if kind == "color" else "Metallic"]
        if source.links:
            nt.links.new(source.links[0].from_socket, emit.inputs["Color"])
        else:
            value = source.default_value
            emit.inputs["Color"].default_value = tuple(value) if kind == "color" else (value, value, value, 1)
        nt.links.new(emit.outputs[0], surface)
    try:
        bpy.ops.object.bake(type=_BAKE_TYPE[kind], normal_space="TANGENT", margin=16, use_clear=True,
                            target="IMAGE_TEXTURES")
    finally:
        for node in temp:
            nt.nodes.remove(node)
        nt.links.new(shader, surface)


def _bake(egg_id, scene, shell, sizes, samples):
    mat = shell.material_slots[0].material
    bsdf = _bsdf(mat)
    engine = scene.render.engine
    try:
        scene.render.engine = "CYCLES"
    except TypeError as err:
        raise EggCheckError(f"can't switch the render engine to Cycles: {err}") from err
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    images = {}
    try:
        with bpy.context.temp_override(**_select_only(scene, [shell])):
            for kind, size in sizes.items():
                images[kind] = _image(f"{egg_id}_{kind}", size, kind in NON_COLOR)
                _bake_one(mat, bsdf, kind, images[kind])
    finally:
        scene.render.engine = engine
    return images


def _use_baked(egg_id, shell, images):
    """Swap the shell onto material <id>_Shell, which reads the baked images (what the FBX carries)."""
    mat, nt, bsdf = _new_material(f"{egg_id}_Shell")

    def image(kind):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = images[kind]
        return node.outputs["Color"]

    nt.links.new(image("color"), bsdf.inputs["Base Color"])
    nt.links.new(image("roughness"), bsdf.inputs["Roughness"])
    nt.links.new(image("metalness"), bsdf.inputs["Metallic"])
    normal_map = add(nt, "ShaderNodeNormalMap", Color=image("normal"))
    nt.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    shell.data.materials.clear()
    shell.data.materials.append(mat)


def finish(egg_id, scene, shape, shell, glows=(), out_dir=None, sizes=None, samples=4):
    """Check, bake and export one egg into out_dir (default assets/eggs/<id>/): <id>.fbx, <id>.blend and
    <id>_<map>.png per map. Raises EggCheckError, writing nothing, if a check fails.
    Returns {"fbx", "blend", "color", "normal", "roughness", "metalness"} -> path."""
    pieces = [shell, *glows]
    _check(shell, pieces)
    _fit(pieces, shape.height)
    images = _bake(egg_id, scene, shell, sizes or MAP_SIZES, samples)
    out_dir = out_dir or os.path.join(ASSETS, egg_id)
    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    for kind, img in images.items():
        paths[kind] = os.path.join(out_dir, f"{egg_id}_{kind}.png")
        img.filepath_raw = paths[kind]
        img.file_format = "PNG"
        img.save()
    _use_baked(egg_id, shell, images)
    paths["fbx"] = os.path.join(out_dir, f"{egg_id}.fbx")
    with bpy.context.temp_override(**_select_only(scene, pieces)):
        bpy.ops.export_scene.fbx(filepath=paths["fbx"], use_selection=True, object_types={"MESH"},
                                 mesh_smooth_type="FACE", use_tspace=True, use_mesh_modifiers=False,
                                 path_mode="COPY", embed_textures=True, axis_forward="-Z", axis_up="Y",
                                 apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
    paths["blend"] = os.path.join(out_dir, f"{egg_id}.blend")
    bpy.data.libraries.write(paths["blend"], {scene}, path_remap="RELATIVE_ALL", compress=True)
    return paths
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_egg_common.py`
Expected: `Ran 12 tests ... OK`.

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: `Ran 1 test ... OK` (`EGGS` is empty, so there's nothing to check yet).

If a Blender 5.2 API differs from these assumptions (bake context in background mode, FBX import scale round trip, colour-space names), fix `egg_common.py` until the tests pass. Keep the test assertions unchanged unless the spec allows it, and note the change in the commit message.

- [ ] **Step 5: Commit**

```bash
git add tools/blender/eggs/egg_common.py tools/blender/eggs/test_egg_common.py tools/blender/eggs/test_eggs.py
git commit -m "Moon eggs: bake and export pipeline with checks"
```

---

### Task 3: Moon Mouse (Common)

**Files:**
- Create: `tools/blender/eggs/moon_mouse.py`
- Modify: `tools/blender/eggs/test_eggs.py` (`EGGS`)
- Create (by the build): `assets/eggs/moon_mouse/` (fbx, blend, 4 PNGs)

**Interfaces:**
- Consumes: `EggShape`, `new_egg_scene`, `add_preview_rig`, `make_egg_mesh`, `lookdev_material`, `add`, `coords`, `ramp`, `mix`, `bump`, `finish`.
- Produces: `assets/eggs/moon_mouse/*`; script constants at the top for tuning.

- [ ] **Step 1: Add the egg to the export checks (failing test)**

In `tools/blender/eggs/test_eggs.py` set:

```python
EGGS = {
    "moon_mouse": [],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: FAIL: `...assets\eggs\moon_mouse\moon_mouse_color.png` is not a file.

- [ ] **Step 3: Write the build script**

`tools/blender/eggs/moon_mouse.py`:

```python
"""Moon Mouse egg (Common): a glossy pearl with soft pastel rainbow flashes. No glow pieces.
Later Roblox effects: thin blue energy rings circling it, sparkles.

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/moon_mouse.py", run_name="__main__")
"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "moon_mouse"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.74, pointiness=0.16)
PEARL = (0.93, 0.92, 0.95)
FLASHES = [(0.0, (0.98, 0.80, 0.90)), (0.35, (0.84, 0.80, 0.99)), (0.65, (0.74, 0.95, 0.96)),
           (1.0, (0.99, 0.92, 0.74))]                   # pink, lilac, teal, pale gold
FLASH_AMOUNT = 0.45                                    # how strongly the rainbow shows through the pearl
ROUGHNESS = 0.12
METALLIC = 0.25
RIPPLE = 0.06                                          # faint surface ripple in the normal map


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    hue = ec.add(nt, "ShaderNodeTexNoise", Scale=1.3, Detail=3.0, Vector=ec.coords(nt))
    patches = ec.add(nt, "ShaderNodeTexNoise", Scale=2.2, Detail=2.0, Vector=ec.coords(nt))
    amount = ec.ramp(nt, patches.outputs["Fac"], [(0.4, (0, 0, 0)), (0.7, (FLASH_AMOUNT,) * 3)])
    nt.links.new(ec.mix(nt, amount, PEARL, ec.ramp(nt, hue.outputs["Fac"], FLASHES)), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = ROUGHNESS
    bsdf.inputs["Metallic"].default_value = METALLIC
    ripple = ec.add(nt, "ShaderNodeTexNoise", Scale=7.0, Detail=1.0, Vector=ec.coords(nt))
    nt.links.new(ec.bump(nt, ripple.outputs["Fac"], RIPPLE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell)


if __name__ == "__main__":
    print(build())
```

- [ ] **Step 4: Build it in the owner's Blender**

Run with Blender MCP `execute_blender_code`:

```python
import runpy
runpy.run_path(r"C:\Users\malaz\OneDrive\Documents\GitHub\Steal-a-pet-from-Space-\tools\blender\eggs\moon_mouse.py", run_name="__main__")
```

Expected: prints a dict of six paths under `assets\eggs\moon_mouse\`.

- [ ] **Step 5: Look and tune against the artwork**

`look(mode="angles", views=["front", "three_quarter", "back"], shading="rendered", target=["moon_mouse_Shell"], max_size=640)` and `look(image=r"<repo>\assets\eggs\reference\moon_eggs_art.webp", max_size=1024)`.
Compare with the Mouse egg (far left): milky pearl white, soft pastel flashes (pink/lilac/teal/gold) that read as a sheen, not stripes; glossy. Adjust only the constants at the top of `moon_mouse.py` (`PEARL`, `FLASHES`, `FLASH_AMOUNT`, `ROUGHNESS`, `METALLIC`, `RIPPLE`, `SHAPE`) and re-run Step 4 until it matches.

- [ ] **Step 6: Run the export checks to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: `Ran 1 test ... OK`.

- [ ] **Step 7: Owner review (gate)**

Show the owner the three renders and a one-line triangle count. Wait for an OK or for tweaks; for tweaks, repeat Steps 4–6. Do not start Task 4 until the owner approves.

- [ ] **Step 8: Commit**

```bash
git add tools/blender/eggs/moon_mouse.py tools/blender/eggs/test_eggs.py assets/eggs/moon_mouse
git commit -m "Moon eggs: Moon Mouse"
```

---

### Task 4: Moon Rabbit (Uncommon)

**Files:**
- Create: `tools/blender/eggs/moon_rabbit.py`
- Modify: `tools/blender/eggs/test_eggs.py` (`EGGS`)
- Create (by the build): `assets/eggs/moon_rabbit/`

**Interfaces:**
- Consumes: as Task 3, plus `paint_strokes`, `mask`, `calc`; `EggShape.studs_per_uv`, `EggShape.arc_length`.
- Produces: `assets/eggs/moon_rabbit/*`.

- [ ] **Step 1: Add the egg to the export checks (failing test)**

```python
EGGS = {
    "moon_mouse": [],
    "moon_rabbit": [],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: FAIL in subtest `egg='moon_rabbit'`: `moon_rabbit_color.png` is not a file.

- [ ] **Step 3: Write the build script**

`tools/blender/eggs/moon_rabbit.py`:

```python
"""Moon Rabbit egg (Uncommon): frosted, milky pale-blue crystal with raised white frost veins branching
up from the bottom like a tree. No glow pieces.
Later Roblox effects: swirling gold ribbons, crystal glints.

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/moon_rabbit.py", run_name="__main__")
"""
import importlib
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "moon_rabbit"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.68, pointiness=0.12)
FROST_LOW = (0.66, 0.78, 0.93)                         # bluer near the bottom
FROST_HIGH = (0.90, 0.90, 0.98)                        # milky white-lavender near the top
TINT = (0.93, 0.82, 0.95)                              # faint pink shimmer patches
VEIN = (0.97, 0.98, 1.0)
VEIN_SEED = 7
TRUNKS = 7                                             # veins starting round the bottom
VEIN_TOP = 0.78                                        # veins fade out by this height (0..1)
VEIN_WIDTH = 0.07                                      # studs, for the trunks; branches get thinner
VEIN_RAISE = 0.5                                       # bump strength
ROUGH_FROST, ROUGH_VEIN = 0.35, 0.55


def veins():
    """Branching vein strokes [(points, width)] growing up from the bottom tip."""
    rng = random.Random(VEIN_SEED)
    strokes = []

    def grow(u, v, angle, width, depth):
        points = [(u, v)]
        while v < VEIN_TOP * rng.uniform(0.85, 1.0) and len(points) < 200:
            angle = max(-0.9, min(0.9, angle + rng.uniform(-0.35, 0.35)))
            sx, sy = SHAPE.studs_per_uv(v)
            u += math.sin(angle) * 0.03 / sx
            v += math.cos(angle) * 0.03 / sy
            points.append((u, v))
            if depth < 3 and rng.random() < 0.07:
                grow(u, v, angle + rng.choice((-1, 1)) * rng.uniform(0.4, 0.8), width * 0.65, depth + 1)
        strokes.append((points, width))

    for k in range(TRUNKS):
        grow(k / TRUNKS - 0.5 + rng.uniform(-0.03, 0.03), 0.05, rng.uniform(-0.2, 0.2), VEIN_WIDTH, 0)
    return strokes


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    vein = ec.mask(nt, ec.paint_strokes(ID, "veins", SHAPE, veins()))
    height = ec.add(nt, "ShaderNodeSeparateXYZ", Vector=ec.coords(nt)).outputs["Z"]
    up = ec.add(nt, "ShaderNodeMapRange", Value=height, From_Min=-HEIGHT / 2, From_Max=HEIGHT / 2).outputs["Result"]
    frost = ec.ramp(nt, up, [(0.1, FROST_LOW), (0.9, FROST_HIGH)])
    shimmer = ec.add(nt, "ShaderNodeTexNoise", Scale=2.0, Detail=2.0, Vector=ec.coords(nt))
    tint = ec.ramp(nt, shimmer.outputs["Fac"], [(0.55, (0, 0, 0)), (0.75, (0.35, 0.35, 0.35))])
    colour = ec.mix(nt, vein, ec.mix(nt, tint, frost, TINT), VEIN)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    rough = ec.add(nt, "ShaderNodeMapRange", Value=vein, To_Min=ROUGH_FROST, To_Max=ROUGH_VEIN)
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0
    grain = ec.add(nt, "ShaderNodeTexNoise", Scale=30.0, Detail=2.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "ADD", vein, ec.calc(nt, "MULTIPLY", grain.outputs["Fac"], 0.08))
    nt.links.new(ec.bump(nt, relief, VEIN_RAISE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell)


if __name__ == "__main__":
    print(build())
```

- [ ] **Step 4: Build it in the owner's Blender**

`execute_blender_code`: `import runpy; runpy.run_path(r"C:\Users\malaz\OneDrive\Documents\GitHub\Steal-a-pet-from-Space-\tools\blender\eggs\moon_rabbit.py", run_name="__main__")`
Expected: prints six paths under `assets\eggs\moon_rabbit\`.

- [ ] **Step 5: Look and tune against the artwork**

`look(mode="angles", views=["front", "three_quarter", "back"], shading="rendered", target=["moon_rabbit_Shell"], max_size=640)`; compare with the Rabbit egg (second from left): frosted pale blue to milky top, white tree-like veins rising from the base and thinning upward, slightly taller egg. Tune only the constants at the top (vein growth: `VEIN_SEED`, `TRUNKS`, `VEIN_TOP`, `VEIN_WIDTH`; look: colours, `VEIN_RAISE`, roughness) and rebuild until it matches.

- [ ] **Step 6: Run the export checks to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: `Ran 1 test ... OK` (both eggs pass).

- [ ] **Step 7: Owner review (gate)**

Show the three renders; wait for an OK or tweaks (repeat Steps 4–6). Do not start Task 5 until approved.

- [ ] **Step 8: Commit**

```bash
git add tools/blender/eggs/moon_rabbit.py tools/blender/eggs/test_eggs.py assets/eggs/moon_rabbit
git commit -m "Moon eggs: Moon Rabbit"
```

---

### Task 5: Luna Moth (Rare)

**Files:**
- Create: `tools/blender/eggs/luna_moth.py`
- Modify: `tools/blender/eggs/test_eggs.py` (`EGGS`)
- Create (by the build): `assets/eggs/luna_moth/`

**Interfaces:**
- Consumes: as Task 4, plus `add_egg`, `object_from_bmesh`, `mask_image`.
- Produces: `assets/eggs/luna_moth/*`.
- Texture layout differs from the other eggs: wing A (the +X side) fills texture x 0..0.5 and wing B (the -X side) fills x 0.5..1, so masks and strokes use "texture u" = x − 0.5. The hidden core, wing undersides and wing rims all sit on one texel (`HIDDEN_UV`), which takes the light wing-edge colour.

- [ ] **Step 1: Add the egg to the export checks (failing test)**

```python
EGGS = {
    "moon_mouse": [],
    "moon_rabbit": [],
    "luna_moth": [],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: FAIL in subtest `egg='luna_moth'` (missing `luna_moth_color.png`).

- [ ] **Step 3: Write the build script**

`tools/blender/eggs/luna_moth.py`:

```python
"""Luna Moth egg (Rare): a cocoon of two pale-green moth wings wrapped round a hidden core, meeting in a
seam down the front, wingtips curling out at the top. Darker raised veins, light yellow-green edges and
a small yellow eyespot on each wing. No glow pieces.
Later Roblox effects: fireflies, drifting purple petals.

Texture layout: wing A (+X side) fills texture x 0..0.5, wing B (-X side) x 0.5..1. Across a wing, s runs
0..1 from its u0 edge to its u1 edge; "front" is the distance from the wing's front edge. Masks and strokes
use texture u = x - 0.5 (what egg_common's mask helpers expect). The core, wing undersides and rims all
map to HIDDEN_UV.

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/luna_moth.py", run_name="__main__")
"""
import importlib
import math
import os
import sys

import bmesh
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "luna_moth"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.62, pointiness=0.10)
OVERLAP = 0.04                  # turns each wing reaches past the front and back seams
WING_TURNS = 0.5 + 2 * OVERLAP
WING_LIFT = 0.05                # studs off the core for wing A; wing B sits on top of it
THICKNESS = 0.025
CURL = 0.22                     # how far the wingtips flare out at the top front
WING_SEGMENTS, WING_RINGS = 16, 20
V_TIP = 0.004
HIDDEN_UV = (0.02, 0.5)         # inside the light edge band of wing A
GREEN = (0.62, 0.85, 0.52)
GREEN_DEEP = (0.38, 0.64, 0.34)
EDGE = (0.86, 0.93, 0.62)
VEIN = (0.30, 0.52, 0.28)
EYE = (0.98, 0.86, 0.42)
EYE_RING = (0.42, 0.33, 0.20)
EYE_FRONT, EYE_V, EYE_R = 0.35, 0.62, 0.11     # eyespot: distance from front edge (0..1), height, radius (studs)
VEIN_COUNT, VEIN_WIDTH, VEIN_RAISE = 7, 0.035, 0.35


def wing_s(u_tex):
    """(s across the wing, is_wing_b) for texture u (numpy)."""
    x = u_tex + 0.5
    return (x % 0.5) * 2, x >= 0.5


def front_dist(s, is_b):
    return np.where(is_b, 1 - s, s)


def to_tex_u(front, is_b):
    s = 1 - front if is_b else front
    return 0.5 * s if is_b else 0.5 * s - 0.5


def add_wing(bm, u0, u1, lift, front_at_end, tex_x0):
    """One wing: a curved slab covering u0..u1, its outer face mapped to texture x tex_x0..tex_x0 + 0.5."""
    uv = bm.loops.layers.uv.get("UVMap")
    vs = [V_TIP + (1 - 2 * V_TIP) * (1 - math.cos(math.pi * i / WING_RINGS)) / 2 for i in range(WING_RINGS + 1)]
    outer, inner = {}, {}
    for i, v in enumerate(vs):
        for j in range(WING_SEGMENTS + 1):
            s = j / WING_SEGMENTS
            front = 1 - s if front_at_end else s
            curl = CURL * max(0.0, (v - 0.7) / 0.3) ** 2 * max(0.0, 1 - front / 0.2)
            p, n = SHAPE.point(u0 + (u1 - u0) * s, v, lift + curl)
            outer[i, j] = bm.verts.new(p)
            inner[i, j] = bm.verts.new(p - n * THICKNESS)
    faces = []

    def face(verts, uvs, smooth=True):
        f = bm.faces.new(verts)
        f.smooth = smooth
        for loop, t in zip(f.loops, uvs):
            loop[uv].uv = t
        faces.append(f)

    hidden = [HIDDEN_UV] * 4
    for i in range(WING_RINGS):
        for j in range(WING_SEGMENTS):
            x0 = tex_x0 + 0.5 * j / WING_SEGMENTS
            x1 = tex_x0 + 0.5 * (j + 1) / WING_SEGMENTS
            face([outer[i, j], outer[i, j + 1], outer[i + 1, j + 1], outer[i + 1, j]],
                 [(x0, vs[i]), (x1, vs[i]), (x1, vs[i + 1]), (x0, vs[i + 1])])
            face([inner[i, j], inner[i + 1, j], inner[i + 1, j + 1], inner[i, j + 1]], hidden)
    border = ([(0, j) for j in range(WING_SEGMENTS)] + [(i, WING_SEGMENTS) for i in range(WING_RINGS)]
              + [(WING_RINGS, j) for j in range(WING_SEGMENTS, 0, -1)] + [(i, 0) for i in range(WING_RINGS, 0, -1)])
    for a, b in zip(border, border[1:] + border[:1]):
        face([outer[a], outer[b], inner[b], inner[a]], hidden, smooth=False)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def edge_mask(u, v):
    s, is_b = wing_s(u)
    edge = np.clip(1 - np.minimum(s, 1 - s) / 0.08, 0, 1)
    return np.maximum(edge, np.clip(1 - (v - V_TIP) / 0.06, 0, 1))


def eye_masks():
    """(core, ring) masks for the eyespots, measured in studs."""
    rows = np.array([SHAPE.radius(v) for v in (np.arange(1024) + 0.5) / 1024])[:, None]

    def distance(u, v):
        s, is_b = wing_s(u)
        dx = (front_dist(s, is_b) - EYE_FRONT) * WING_TURNS * 2 * math.pi * rows
        return np.hypot(dx, (v - EYE_V) * SHAPE.arc_length)

    core = ec.mask_image(ID, "eye", lambda u, v: np.clip((EYE_R * 0.6 - distance(u, v)) / 0.015, 0, 1))
    ring = ec.mask_image(ID, "eye_ring", lambda u, v: np.clip((EYE_R - distance(u, v)) / 0.015, 0, 1))
    return core, ring


def vein_strokes():
    """Veins fanning down each wing from the top, bowing outward a little."""
    strokes = []
    for is_b in (False, True):
        for k in range(VEIN_COUNT):
            end = 0.08 + 0.84 * k / (VEIN_COUNT - 1)
            points = []
            for i in range(15):
                t = i / 14
                front = (1 - t) ** 2 * 0.5 + 2 * (1 - t) * t * (0.5 + (end - 0.5) * 1.3) + t * t * end
                v = 0.95 - 0.88 * t
                points.append((to_tex_u(min(max(front, 0.02), 0.98), is_b), v))
            strokes.append((points, VEIN_WIDTH))
    return strokes


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    bm = bmesh.new()
    ec.add_egg(bm, SHAPE, segments=16, rings=10, lift=-0.02, uv_point=HIDDEN_UV)
    add_wing(bm, -OVERLAP, 0.5 + OVERLAP, WING_LIFT, False, 0.0)                         # wing A, +X side
    add_wing(bm, 0.5 - OVERLAP, 1 + OVERLAP, WING_LIFT + THICKNESS + 0.006, True, 0.5)   # wing B, on top
    shell = ec.object_from_bmesh(ID, scene, "Shell", bm)
    mat, nt, bsdf = ec.lookdev_material(ID)
    shade = ec.add(nt, "ShaderNodeTexNoise", Scale=1.6, Detail=3.0, Vector=ec.coords(nt))
    colour = ec.mix(nt, shade.outputs["Fac"], GREEN_DEEP, GREEN)
    colour = ec.mix(nt, ec.mask(nt, ec.mask_image(ID, "edge", edge_mask)), colour, EDGE)
    vein = ec.mask(nt, ec.paint_strokes(ID, "veins", SHAPE, vein_strokes()))
    colour = ec.mix(nt, vein, colour, VEIN)
    core, ring = eye_masks()
    colour = ec.mix(nt, ec.mask(nt, ring), colour, EYE_RING)
    colour = ec.mix(nt, ec.mask(nt, core), colour, EYE)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Metallic"].default_value = 0.0
    fuzz = ec.add(nt, "ShaderNodeTexNoise", Scale=40.0, Detail=2.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "ADD", vein, ec.calc(nt, "MULTIPLY", fuzz.outputs["Fac"], 0.15))
    nt.links.new(ec.bump(nt, relief, VEIN_RAISE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell)


if __name__ == "__main__":
    print(build())
```

- [ ] **Step 4: Build it in the owner's Blender**

`execute_blender_code`: `import runpy; runpy.run_path(r"C:\Users\malaz\OneDrive\Documents\GitHub\Steal-a-pet-from-Space-\tools\blender\eggs\luna_moth.py", run_name="__main__")`
Expected: prints six paths. The shell is about 3,136 triangles (wings 2 × 1,424 + core 288).

- [ ] **Step 5: Look and tune against the artwork**

`look(mode="angles", views=["front", "three_quarter", "back", "top"], shading="rendered", target=["luna_moth_Shell"], max_size=640)`; compare with the Moth (centre): two pale-green wings wrapped round, seam down the front, wingtips flaring at the top, darker veins fanning down, light edges, small eyespots. Check that no core or underside shows through gaps. Tune only the constants (`OVERLAP`, `WING_LIFT`, `CURL`, colours, eyespot, veins) and rebuild until it matches.

- [ ] **Step 6: Run the export checks to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: `Ran 1 test ... OK`.

- [ ] **Step 7: Owner review (gate)**

Show the renders; wait for an OK or tweaks (repeat Steps 4–6). Do not start Task 6 until approved.

- [ ] **Step 8: Commit**

```bash
git add tools/blender/eggs/luna_moth.py tools/blender/eggs/test_eggs.py assets/eggs/luna_moth
git commit -m "Moon eggs: Luna Moth"
```

---

### Task 6: Lunar Wolf (Epic)

**Files:**
- Create: `tools/blender/eggs/lunar_wolf.py`
- Modify: `tools/blender/eggs/test_eggs.py` (`EGGS`)
- Create (by the build): `assets/eggs/lunar_wolf/`

**Interfaces:**
- Consumes: as Task 4, plus `make_dots`, `make_strips`, `join_into`, `glow_material`, `mask_image`.
- Produces: `assets/eggs/lunar_wolf/*` with pieces `lunar_wolf_Shell`, `lunar_wolf_Glow_Stars`, `lunar_wolf_Glow_Sun`.

- [ ] **Step 1: Add the egg to the export checks (failing test)**

```python
EGGS = {
    "moon_mouse": [],
    "moon_rabbit": [],
    "luna_moth": [],
    "lunar_wolf": ["Glow_Stars", "Glow_Sun"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: FAIL in subtest `egg='lunar_wolf'` (missing `lunar_wolf_color.png`).

- [ ] **Step 3: Write the build script**

`tools/blender/eggs/lunar_wolf.py`:

```python
"""Lunar Wolf egg (Epic): dark slate-blue stone, rough and slightly cracked, with a large oval window on
the front in a raised carved frame, showing a deep-blue star map with orbit rings round a sun.
Glow pieces: Glow_Stars (pale blue stars, constellation lines, orbits, planets) and Glow_Sun (gold).
Later Roblox effects: a pale moon glow behind it, twinkling.

Positions on the front are in studs from the window's centre (x right, y up); local() turns them into
egg (u, v), and the window mask uses the same measure, so stars, orbits and window line up.

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/lunar_wolf.py", run_name="__main__")
"""
import importlib
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "lunar_wolf"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.76, pointiness=0.14)
WIN_V = 0.53                          # window centre height (0..1)
WIN_W, WIN_H = 0.80, 1.15             # window half-width and half-height, studs
FRAME_AT, FRAME_HALF = 1.09, 0.07     # frame ridge: where (in window radii) and half its width
STONE_DARK, STONE_LIGHT = (0.10, 0.12, 0.16), (0.22, 0.25, 0.31)
CRACK = (0.05, 0.06, 0.08)
FRAME = (0.34, 0.38, 0.45)
SPACE_DEEP, SPACE_MID = (0.02, 0.04, 0.14), (0.08, 0.15, 0.38)
STAR = (0.72, 0.86, 1.0)
SUN = (1.0, 0.78, 0.30)
CONSTELLATIONS = [
    [(-0.55, 0.55), (-0.40, 0.75), (-0.20, 0.70), (-0.08, 0.86)],
    [(0.22, 0.78), (0.45, 0.60), (0.52, 0.35), (0.36, 0.18)],
    [(-0.50, -0.42), (-0.30, -0.56), (-0.10, -0.50), (0.06, -0.72)],
]
ORBITS = [0.22, 0.38, 0.55]                                  # orbit radii, studs
PLANETS = [(0.22, 40, 0.03), (0.38, 200, 0.04), (0.55, 320, 0.035)]   # (orbit, degrees, radius)
EXTRA_STARS, STAR_SEED = 16, 3


def local(x, y):
    """Egg (u, v) of a point x, y studs from the window centre."""
    v = WIN_V + y / SHAPE.arc_length
    return x / SHAPE.studs_per_uv(v)[0], v


def window_radius():
    """Numpy fn(u, v) -> distance from the window centre in window radii (1 = the window's edge)."""
    rows = np.array([SHAPE.studs_per_uv(v)[0] for v in (np.arange(1024) + 0.5) / 1024])[:, None]
    return lambda u, v: np.sqrt((u * rows / WIN_W) ** 2 + ((v - WIN_V) * SHAPE.arc_length / WIN_H) ** 2)


def circle(r, n=48):
    return [local(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n)) for k in range(n + 1)]


def glow_stars(scene):
    rng = random.Random(STAR_SEED)
    dots = [(*local(x, y), 0.032) for line in CONSTELLATIONS for x, y in line]
    while len(dots) < sum(map(len, CONSTELLATIONS)) + EXTRA_STARS:
        x, y = rng.uniform(-WIN_W, WIN_W), rng.uniform(-WIN_H, WIN_H)
        if (x / WIN_W) ** 2 + (y / WIN_H) ** 2 < 0.75 and math.hypot(x, y) > 0.15:
            dots.append((*local(x, y), rng.uniform(0.014, 0.024)))
    dots += [(*local(r * math.cos(math.radians(a)), r * math.sin(math.radians(a))), size) for r, a, size in PLANETS]
    stars = ec.make_dots(ID, scene, "Glow_Stars_dots", SHAPE, dots)
    lines = [[local(x, y) for x, y in line] for line in CONSTELLATIONS] + [circle(r) for r in ORBITS]
    strips = ec.make_strips(ID, scene, "Glow_Stars", SHAPE, lines, width=0.012)
    strips.data.materials.append(ec.glow_material(ID, "Glow_Stars", STAR))
    return ec.join_into(strips, stars)


def glow_sun(scene):
    sun = ec.make_dots(ID, scene, "Glow_Sun_disc", SHAPE, [(*local(0, 0), 0.08)], sides=12)
    rays = [[local(0.11 * math.cos(a), 0.11 * math.sin(a)), local(0.17 * math.cos(a), 0.17 * math.sin(a))]
            for a in (2 * math.pi * k / 8 for k in range(8))]
    piece = ec.make_strips(ID, scene, "Glow_Sun", SHAPE, rays, width=0.02)
    piece.data.materials.append(ec.glow_material(ID, "Glow_Sun", SUN))
    return ec.join_into(piece, sun)


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    radius = window_radius()
    mat, nt, bsdf = ec.lookdev_material(ID)
    window = ec.mask(nt, ec.mask_image(ID, "window", lambda u, v: (1 - radius(u, v)) / 0.03))
    frame = ec.mask(nt, ec.mask_image(ID, "frame", lambda u, v: 1 - np.abs(radius(u, v) - FRAME_AT) / FRAME_HALF))
    depth = ec.mask(nt, ec.mask_image(ID, "depth", lambda u, v: 1 - radius(u, v)))
    stone = ec.add(nt, "ShaderNodeTexNoise", Scale=3.0, Detail=6.0, Vector=ec.coords(nt))
    cells = ec.add(nt, "ShaderNodeTexVoronoi", Scale=2.5, Vector=ec.coords(nt))
    cells.feature = "DISTANCE_TO_EDGE"
    crack = ec.add(nt, "ShaderNodeMapRange", Value=cells.outputs["Distance"], From_Min=0, From_Max=0.03,
                   To_Min=1, To_Max=0).outputs["Result"]
    nebula = ec.add(nt, "ShaderNodeTexNoise", Scale=2.5, Detail=4.0, Vector=ec.coords(nt))
    colour = ec.ramp(nt, stone.outputs["Fac"], [(0.3, STONE_DARK), (0.7, STONE_LIGHT)])
    colour = ec.mix(nt, crack, colour, CRACK)
    colour = ec.mix(nt, frame, colour, FRAME)
    space = ec.mix(nt, ec.calc(nt, "MULTIPLY", nebula.outputs["Fac"], 0.5), ec.ramp(nt, depth, [(0, SPACE_DEEP), (1, SPACE_MID)]), SPACE_MID)
    colour = ec.mix(nt, window, colour, space)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    rough = ec.add(nt, "ShaderNodeMapRange", Value=window, To_Min=0.85, To_Max=0.25)
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0
    outside = ec.calc(nt, "SUBTRACT", 1.0, window)
    rock = ec.calc(nt, "SUBTRACT", ec.calc(nt, "MULTIPLY", stone.outputs["Fac"], 0.2), ec.calc(nt, "MULTIPLY", crack, 0.4))
    relief = ec.calc(nt, "ADD", frame, ec.calc(nt, "MULTIPLY", rock, outside))
    nt.links.new(ec.bump(nt, relief, 0.6, 0.03), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell, [glow_stars(scene), glow_sun(scene)])


if __name__ == "__main__":
    print(build())
```

- [ ] **Step 4: Build it in the owner's Blender**

`execute_blender_code`: `import runpy; runpy.run_path(r"C:\Users\malaz\OneDrive\Documents\GitHub\Steal-a-pet-from-Space-\tools\blender\eggs\lunar_wolf.py", run_name="__main__")`
Expected: prints six paths; the pieces are `lunar_wolf_Shell`, `lunar_wolf_Glow_Stars` and `lunar_wolf_Glow_Sun`.

- [ ] **Step 5: Look and tune against the artwork**

`look(mode="angles", views=["front", "three_quarter", "back"], shading="rendered", target=["lunar_wolf_Shell", "lunar_wolf_Glow_Stars", "lunar_wolf_Glow_Sun"], max_size=640)`; compare with the Wolf egg (second from right): dark slate stone, a big oval window with a carved lighter frame, deep-blue space with glowing constellations, orbit rings and a gold sun. Tune only the constants and rebuild until it matches.

- [ ] **Step 6: Run the export checks to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: `Ran 1 test ... OK`.

- [ ] **Step 7: Owner review (gate)**

Show the renders; wait for an OK or tweaks (repeat Steps 4–6). Do not start Task 7 until approved.

- [ ] **Step 8: Commit**

```bash
git add tools/blender/eggs/lunar_wolf.py tools/blender/eggs/test_eggs.py assets/eggs/lunar_wolf
git commit -m "Moon eggs: Lunar Wolf"
```

---

### Task 7: Eclipse Phoenix (Legendary)

**Files:**
- Create: `tools/blender/eggs/eclipse_phoenix.py`
- Modify: `tools/blender/eggs/test_eggs.py` (`EGGS`)
- Create (by the build): `assets/eggs/eclipse_phoenix/`

**Interfaces:**
- Consumes: as Task 6 (including `join_into`).
- Produces: `assets/eggs/eclipse_phoenix/*` with pieces `eclipse_phoenix_Shell` and `eclipse_phoenix_Glow_Embers`.

- [ ] **Step 1: Add the egg to the export checks (failing test)**

```python
EGGS = {
    "moon_mouse": [],
    "moon_rabbit": [],
    "luna_moth": [],
    "lunar_wolf": ["Glow_Stars", "Glow_Sun"],
    "eclipse_phoenix": ["Glow_Embers"],
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: FAIL in subtest `egg='eclipse_phoenix'` (missing `eclipse_phoenix_color.png`).

- [ ] **Step 3: Write the build script**

`tools/blender/eggs/eclipse_phoenix.py`:

```python
"""Eclipse Phoenix egg (Legendary): glossy black obsidian with raised gold filigree whose swirls form a
phoenix with spread wings across the front, plus scrollwork round the back. Glow piece Glow_Embers:
red-orange cracks and eyes glowing through the black.
Later Roblox effects: orbiting planets, the fiery eclipse ring, rising embers.

The phoenix is drawn in studs from a point on the egg (x right, y up); local() turns that into egg (u, v).

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/eclipse_phoenix.py", run_name="__main__")
"""
import importlib
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "eclipse_phoenix"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.74, pointiness=0.18)
BLACK = (0.015, 0.014, 0.018)
GOLD = (1.0, 0.71, 0.29)
EMBER = (1.0, 0.24, 0.05)
LINE = 0.045                    # filigree width, studs
GOLD_RAISE = 0.7
SCROLLS, SCROLL_SEED = 9, 5


def local(x, y, uc=0.0, vc=0.5):
    """Egg (u, v) of a point x, y studs from egg point (uc, vc)."""
    v = vc + y / SHAPE.arc_length
    return uc + x / SHAPE.studs_per_uv(v)[0], v


def bezier(p0, p1, p2, n=14):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / (n - 1) for i in range(n))]


def spiral(cx, cy, r0, start, turns=1.25, direction=1, n=28):
    """Curl inward from radius r0 at angle `start` (radians) round (cx, cy)."""
    return [(cx + r0 * (1 - 0.8 * t) * math.cos(start + direction * 2 * math.pi * turns * t),
             cy + r0 * (1 - 0.8 * t) * math.sin(start + direction * 2 * math.pi * turns * t))
            for t in (i / (n - 1) for i in range(n))]


def phoenix():
    """Front filigree as lists of (x, y) studs from the egg's front centre."""
    lines = [[(0, -0.75), (0.04, -0.45), (-0.03, -0.1), (0.02, 0.25), (0, 0.55)],                       # body
             [(0.11 * math.cos(a), 0.66 + 0.11 * math.sin(a)) for a in (2 * math.pi * k / 16 for k in range(17))]]  # head
    for sgn in (-1, 1):
        lines.append(bezier((0, 0.77), (sgn * 0.05, 0.92), (sgn * 0.18, 1.0)) + spiral(sgn * 0.24, 0.97, 0.06, math.pi, direction=-sgn))
        for k in range(4):                                                                            # wing feathers
            start, end = (sgn * 0.06, 0.05 + 0.08 * k), (sgn * (0.8 + 0.05 * k), 0.55 + 0.12 * k)
            tip = spiral(end[0] - sgn * 0.08, end[1], 0.08, 0 if sgn > 0 else math.pi, direction=sgn)
            lines.append(bezier(start, (sgn * (0.55 + 0.1 * k), 0.25 + 0.15 * k), end) + tip)
        for k in range(1, 3):                                                                         # tail flames
            end = (sgn * 0.14 * k, -1.15 + 0.05 * k)
            lines.append(bezier((0, -0.75), (sgn * 0.05 * k, -0.95), end) + spiral(end[0] + sgn * 0.06, end[1], 0.06, math.pi, direction=sgn))
    lines.append(bezier((0, -0.75), (0, -0.95), (0, -1.2)))
    return [[local(x, y) for x, y in line] for line in lines]


def scrolls():
    """Spiral scrollwork scattered round the sides and back."""
    rng = random.Random(SCROLL_SEED)
    lines = []
    for k in range(SCROLLS):
        uc, vc = 0.22 + 0.56 * (k + rng.random()) / SCROLLS, rng.uniform(0.2, 0.85)
        start = rng.uniform(0, 2 * math.pi)
        tail = [(0.25 * math.cos(start + math.pi) * t, 0.25 * math.sin(start + math.pi) * t) for t in (1, 0.5)]
        lines.append([local(x, y, uc, vc) for x, y in tail + spiral(0, 0, 0.16, start, direction=rng.choice((-1, 1)))])
    return lines


def embers(scene):
    eyes = ec.make_dots(ID, scene, "Glow_Embers_eyes", SHAPE, [(*local(-0.04, 0.68), 0.022), (*local(0.04, 0.68), 0.022)])
    rng = random.Random(11)
    cracks = []
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.3, 0.3)
        points = [(0.0, -0.1)]
        for step in range(1, 5):
            r = 0.09 * step
            points.append((r * math.cos(a) + rng.uniform(-0.03, 0.03), -0.1 + r * math.sin(a) + rng.uniform(-0.03, 0.03)))
        cracks.append([local(x, y) for x, y in points])
    piece = ec.make_strips(ID, scene, "Glow_Embers", SHAPE, cracks, width=0.022)
    piece.data.materials.append(ec.glow_material(ID, "Glow_Embers", EMBER))
    return ec.join_into(piece, eyes)


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    gold = ec.mask(nt, ec.paint_strokes(ID, "filigree", SHAPE, [(line, LINE) for line in phoenix() + scrolls()]))
    nt.links.new(ec.mix(nt, gold, BLACK, GOLD), bsdf.inputs["Base Color"])
    rough = ec.add(nt, "ShaderNodeMapRange", Value=gold, To_Min=0.12, To_Max=0.28)
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    nt.links.new(gold, bsdf.inputs["Metallic"])
    grain = ec.add(nt, "ShaderNodeTexNoise", Scale=25.0, Detail=2.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "ADD", gold, ec.calc(nt, "MULTIPLY", grain.outputs["Fac"], 0.03))
    nt.links.new(ec.bump(nt, relief, GOLD_RAISE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell, [embers(scene)])


if __name__ == "__main__":
    print(build())
```

- [ ] **Step 4: Build it in the owner's Blender**

`execute_blender_code`: `import runpy; runpy.run_path(r"C:\Users\malaz\OneDrive\Documents\GitHub\Steal-a-pet-from-Space-\tools\blender\eggs\eclipse_phoenix.py", run_name="__main__")`
Expected: prints six paths; the pieces are `eclipse_phoenix_Shell` and `eclipse_phoenix_Glow_Embers`.

- [ ] **Step 5: Look and tune against the artwork**

`look(mode="angles", views=["front", "three_quarter", "back"], shading="rendered", target=["eclipse_phoenix_Shell", "eclipse_phoenix_Glow_Embers"], max_size=640)`; compare with the Phoenix egg (far right): glossy black, gold filigree that reads as a phoenix with spread wings, red-orange glowing cracks and eyes. Tune only the constants and stroke shapes in `phoenix()` / `scrolls()` / `embers()`, and rebuild until it matches.

- [ ] **Step 6: Run the export checks to verify they pass**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py`
Expected: `Ran 1 test ... OK` (all five eggs).

- [ ] **Step 7: Owner review (gate)**

Show the renders; wait for an OK or tweaks (repeat Steps 4–6).

- [ ] **Step 8: Commit**

```bash
git add tools/blender/eggs/eclipse_phoenix.py tools/blender/eggs/test_eggs.py assets/eggs/eclipse_phoenix
git commit -m "Moon eggs: Eclipse Phoenix"
```

---

### Task 8: Notes, final checks and merge

**Files:**
- Modify: `CLAUDE.md` (one bullet under "How the project fits together")

**Interfaces:**
- Consumes: everything above.
- Produces: the merged PR.

- [ ] **Step 1: Add the CLAUDE.md note**

Add this bullet after the "**Map changes are made with builder scripts...**" block in `CLAUDE.md`:

```markdown
- **Egg models (Blender)**: `tools/blender/eggs/` builds the five Moon eggs (`moon_mouse`, `moon_rabbit`, `luna_moth`, `lunar_wolf`, `eclipse_phoenix`) into `assets/eggs/<id>/`: an FBX with embedded textures, colour/normal/roughness/metalness PNGs (for a SurfaceAppearance), and a `.blend`.
  - Each egg is a textured `<id>_Shell` plus `<id>_Glow_*` pieces, which become Neon in Roblox. They are 3 studs tall with the pivot at the centre. They aren't in the game yet: importing them and adding their effects is the next job.
  - Rebuild one in Blender with `runpy.run_path(r"<repo>\tools\blender\eggs\<id>.py", run_name="__main__")`. It only touches the scene `egg_<id>`.
  - Tests run headless: Blender's `--background --factory-startup --python tools/blender/eggs/test_egg_common.py` (and `test_eggs.py`).
```

- [ ] **Step 2: Run the full verification**

Run both test files headless (commands as above). Expected: `test_egg_common.py` gives `Ran 12 tests ... OK`; `test_eggs.py` gives `Ran 1 test ... OK`.
Run: `rojo build -o "$TMP/check.rbxlx"`. Expected: builds (no Luau changed, but the project must still build).

- [ ] **Step 3: Commit, PR and merge**

Use superpowers:finishing-a-development-branch. Commit the CLAUDE.md note, push `moon-eggs-blender`, open a PR to `main` that lists the five eggs with their triangle counts, merge it, and tell the owner: **Fetch origin → Pull origin** in GitHub Desktop. There's no Studio step yet.
