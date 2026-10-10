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
