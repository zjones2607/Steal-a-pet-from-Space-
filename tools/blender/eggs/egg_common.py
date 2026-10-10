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
    scene.view_settings.view_transform = "Standard"   # Roblox has no AgX; AgX would wash out pastels
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


def show(scene, objs):
    """Show scene in Blender's 3D viewport: rendered shading, no overlays, framed on objs from the front.
    Returns False (and does nothing) when there's no viewport, e.g. in a headless run."""
    window = _window()
    area = window and next((a for a in window.screen.areas if a.type == "VIEW_3D"), None)
    if not area:
        return False
    window.scene = scene
    space = area.spaces.active
    space.shading.type = "RENDERED"
    space.overlay.show_overlays = False
    region = next(r for r in area.regions if r.type == "WINDOW")
    with bpy.context.temp_override(**_select_only(scene, objs), area=area, region=region):
        bpy.ops.view3d.view_axis(type="FRONT")
        bpy.ops.view3d.view_selected()
    space.region_3d.view_perspective = "PERSP"
    space.region_3d.view_distance *= 1.15
    for o in objs:
        o.select_set(False, view_layer=scene.view_layers[0])
    return True


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
    show(scene, pieces)
    return paths
