"""Lunar Wolf egg (Epic): a dark slate stone egg with a large oval porthole on the front in an ornate gold
frame, with round medallions at its top and bottom. Through the glass you look down into a glowing star
chart built in real layers, so it shifts with the viewing angle (true parallax, no scripts): constellations
just under the glass, the orbit rings and planets deeper, the sun deeper still, and a star-dusted backdrop
bowl at the bottom.
Glow pieces (Neon in Roblox): Glow_Stars (constellations), Glow_Orbits (orbit rings), Glow_Sun. Glass: the
cover (Glass in Roblox). Later Roblox effects: the big moon glow behind it, twinkling, a soft blue PointLight
inside the porthole.

Positions in the window are studs from its centre (x right, y up); its "radius" is 1 at the window's edge;
"depth" is studs in below the egg's surface.

Texture layout: the stone shell fills y 0.35..1 (x round the window, y from its edge down to the back); the
backdrop is the disc in BOWL_RECT; the frame band runs along FRAME_RECT; both medallions share MEDAL_RECT;
each planet has a swatch in PLANET_RECT. Masks use texture u = x - 0.5 and v = y.

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/lunar_wolf.py", run_name="__main__")
"""
import importlib
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "lunar_wolf"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.76, pointiness=0.14)

# The porthole
WIN_V = 0.52                              # height of the window's centre (0..1)
WIN_W, WIN_H = 0.95, 1.25                 # window half-width and half-height, studs
FRAME_PROFILE = [(0.95, -0.04), (0.99, 0.03), (1.05, 0.06), (1.11, 0.03), (1.16, 0.004)]  # (radius, lift) across it
MEDALLION_R, MEDALLION_RISE = 0.12, 0.05  # studs: the medallions on the frame's top and bottom
GLASS_LIFT = 0.012
STARS_DEPTH, ORBIT_DEPTH, SUN_DEPTH = 0.06, 0.17, 0.27   # studs below the surface: the parallax layers
BOWL_DEPTH = 0.36                         # the backdrop bowl is this much deeper at its middle than its rim
SHELL_SEGMENTS, SHELL_RINGS = 40, 14      # stone shell: round the window, and from its edge to the back
FRAME_SEGMENTS, BOWL_SEGMENTS, BOWL_RINGS = 48, 32, 7

# The star chart, as in the artwork
CONSTELLATIONS = [
    [(-0.55, 0.62), (-0.42, 0.78), (-0.25, 0.74), (-0.12, 0.9)],
    [(0.18, 0.88), (0.32, 0.72), (0.5, 0.68), (0.58, 0.52)],
    [(-0.68, 0.18), (-0.6, -0.02), (-0.66, -0.22), (-0.56, -0.36)],
    [(0.62, 0.22), (0.7, 0.02), (0.6, -0.16), (0.66, -0.34)],
    [(-0.5, -0.6), (-0.34, -0.72), (-0.16, -0.66), (-0.06, -0.86)],
    [(0.12, -0.9), (0.28, -0.74), (0.46, -0.7), (0.52, -0.52)],
]
EXTRA_STARS, STAR_SEED = 24, 3
STAR_R, LINE_WIDTH, ORBIT_WIDTH = 0.03, 0.01, 0.008
ORBITS = [0.16, 0.26, 0.36, 0.47]         # studs; the last one bounds the solar system
PLANETS = [(0.16, 40, 0.032, 0), (0.26, 205, 0.045, 1), (0.36, 320, 0.04, 2), (0.36, 115, 0.03, 3)]
SUN_R = 0.085                             # PLANETS: (orbit, degrees round, radius, colour swatch)

# Texture layout
SHELL_Y = 0.35
BOWL_RECT = (0.0, 0.0, 0.33, 0.33)
FRAME_RECT = (0.35, 0.24, 0.97, 0.32)
MEDAL_RECT = (0.35, 0.0, 0.5, 0.15)
PLANET_RECT = (0.55, 0.0, 0.95, 0.1)

# Colours are linear, as Blender's shader sockets are, so they look lighter on screen.
STONE_DARK, STONE_LIGHT = (0.03, 0.04, 0.06), (0.075, 0.09, 0.13)
GOLD, GOLD_DEEP = (1.0, 0.68, 0.26), (0.40, 0.23, 0.06)
MEDAL_CENTRE = (0.02, 0.06, 0.2)
SPACE_DEEP, SPACE_MID, SPACE_GLOW = (0.003, 0.008, 0.045), (0.008, 0.04, 0.17), (0.1, 0.36, 0.8)
DUST = (0.6, 0.85, 1.0)
PLANET_COLOURS = [(0.45, 0.45, 0.5), (0.5, 0.65, 0.85), (0.55, 0.22, 0.1), (0.75, 0.6, 0.35)]
STAR, ORBIT, SUN = (0.75, 0.9, 1.0), (0.45, 0.75, 1.0), (1.0, 0.75, 0.25)
GLASS_TINT = (0.75, 0.85, 1.0)


# --- where things are ------------------------------------------------------------------------------

def local(x, y):
    """Egg (u, v) of a point x, y studs from the window's centre."""
    v = WIN_V + y / SHAPE.arc_length
    return x / SHAPE.studs_per_uv(v)[0], v


def window_point(rho, theta, lift=0.0):
    """(position, normal) at window radius rho and angle theta, lifted along the normal (negative: in)."""
    u, v = local(rho * WIN_W * math.cos(theta), rho * WIN_H * math.sin(theta))
    return SHAPE.point(u, v, lift)


def window_radius(u, v):
    return math.hypot(u * SHAPE.studs_per_uv(v)[0] / WIN_W, (v - WIN_V) * SHAPE.arc_length / WIN_H)


W_DIR = SHAPE.point(0, WIN_V)[0].normalized()            # from the egg's centre out through the window
E_DIR = Vector((1, 0, 0))
N_DIR = W_DIR.cross(E_DIR).normalized()                  # up, across the window


def aim(alpha, theta):
    """Direction alpha radians round from the window's centre, toward angle theta."""
    return W_DIR * math.cos(alpha) + (E_DIR * math.cos(theta) + N_DIR * math.sin(theta)) * math.sin(alpha)


def along(direction):
    """The egg's surface (u, v) straight out from its centre along direction."""
    d = direction.normalized()
    lo, hi = 0.0, HEIGHT
    for _ in range(40):
        t = (lo + hi) / 2
        p = d * t
        v = p.z / HEIGHT + 0.5
        if 0 < v < 1 and math.hypot(p.x, p.y) < SHAPE.radius(v):
            lo = t
        else:
            hi = t
    p = d * lo
    return math.atan2(p.x, -p.y) / (2 * math.pi), p.z / HEIGHT + 0.5


def edge_alpha(theta):
    """How far round from the window's centre (radians) its edge lies, toward angle theta."""
    lo, hi = 0.0, math.pi / 2
    for _ in range(40):
        mid = (lo + hi) / 2
        if window_radius(*along(aim(mid, theta))) < 1:
            lo = mid
        else:
            hi = mid
    return lo


# --- geometry --------------------------------------------------------------------------------------

def _face(bm, uv, verts, coords, facing, smooth=True):
    """A face whose front points along facing (a vector), with its UVs."""
    f = bm.faces.new(verts)
    for loop, t in zip(f.loops, coords):
        loop[uv].uv = t
    f.normal_update()
    if f.normal.dot(facing) < 0:
        f.normal_flip()
    f.smooth = smooth
    return f


def add_shell(bm):
    """The stone egg with the window cut out: a grid running from the window's edge (exactly an oval) round
    to the back, so the opening is clean."""
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    edges = [edge_alpha(2 * math.pi * j / SHELL_SEGMENTS) for j in range(SHELL_SEGMENTS)]
    grid = []
    for i in range(SHELL_RINGS):
        row = []
        for j in range(SHELL_SEGMENTS):
            alpha = edges[j] + (math.pi - edges[j]) * (i / SHELL_RINGS) ** 1.3
            row.append(bm.verts.new(SHAPE.point(*along(aim(alpha, 2 * math.pi * j / SHELL_SEGMENTS)))[0]))
        grid.append(row)
    back = bm.verts.new(SHAPE.point(*along(-W_DIR))[0])

    def y(i):
        return 1 - (1 - SHELL_Y) * (i / SHELL_RINGS) ** 1.3

    for i in range(SHELL_RINGS):
        for j in range(SHELL_SEGMENTS):
            jj, x0, x1 = (j + 1) % SHELL_SEGMENTS, j / SHELL_SEGMENTS, (j + 1) / SHELL_SEGMENTS
            if i < SHELL_RINGS - 1:
                verts = [grid[i][j], grid[i][jj], grid[i + 1][jj], grid[i + 1][j]]
                coords = [(x0, y(i)), (x1, y(i)), (x1, y(i + 1)), (x0, y(i + 1))]
            else:
                verts, coords = [grid[i][j], grid[i][jj], back], [(x0, y(i)), (x1, y(i)), ((x0 + x1) / 2, SHELL_Y)]
            centre = sum((v.co for v in verts), Vector()) / len(verts)
            _face(bm, uv, verts, coords, centre)


def add_frame(bm):
    """The gold frame: a rounded band round the window, its inner lip dipping into the opening."""
    uv = bm.loops.layers.uv.get("UVMap")
    x0, y0, x1, y1 = FRAME_RECT
    rows = [[window_point(rho, 2 * math.pi * j / FRAME_SEGMENTS, lift) for rho, lift in FRAME_PROFILE]
            for j in range(FRAME_SEGMENTS)]
    verts = [[bm.verts.new(p) for p, _ in row] for row in rows]
    for j in range(FRAME_SEGMENTS):
        jj = (j + 1) % FRAME_SEGMENTS
        for k in range(len(FRAME_PROFILE) - 1):
            xa, xb = x0 + (x1 - x0) * j / FRAME_SEGMENTS, x0 + (x1 - x0) * (j + 1) / FRAME_SEGMENTS
            ya, yb = y0 + (y1 - y0) * k / (len(FRAME_PROFILE) - 1), y0 + (y1 - y0) * (k + 1) / (len(FRAME_PROFILE) - 1)
            _face(bm, uv, [verts[j][k], verts[jj][k], verts[jj][k + 1], verts[j][k + 1]],
                  [(xa, ya), (xb, ya), (xb, yb), (xa, yb)], rows[j][k][1])


def add_medallion(bm, theta):
    """A round gold medallion (dark blue centre) sitting on the frame's crest."""
    uv = bm.loops.layers.uv.get("UVMap")
    crest = max(lift for _, lift in FRAME_PROFILE)
    c, n = window_point(1.05, theta, crest)
    a = n.cross(Vector((0, 0, 1))).normalized()
    b = n.cross(a)
    x0, y0, x1, y1 = MEDAL_RECT
    cx, cy, half = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2 * 0.98
    rings, around = 3, 12
    centre = bm.verts.new(c + n * MEDALLION_RISE)
    ring = []
    for k in range(1, rings + 1):
        r = k / rings
        ring.append([bm.verts.new(c + n * (MEDALLION_RISE * (1 - r * r) - 0.01 * (k == rings))
                                  + (a * math.cos(2 * math.pi * i / around) + b * math.sin(2 * math.pi * i / around))
                                  * MEDALLION_R * r) for i in range(around)])

    def at(k, i):
        r = k / rings
        return cx + half * r * math.cos(2 * math.pi * i / around), cy + half * r * math.sin(2 * math.pi * i / around)

    for i in range(around):
        ii = (i + 1) % around
        _face(bm, uv, [centre, ring[0][i], ring[0][ii]], [(cx, cy), at(1, i), at(1, i + 1)], n)
        for k in range(rings - 1):
            _face(bm, uv, [ring[k][i], ring[k + 1][i], ring[k + 1][ii], ring[k][ii]],
                  [at(k + 1, i), at(k + 2, i), at(k + 2, i + 1), at(k + 1, i + 1)], n)


def bowl_depth(rho):
    return 0.04 + BOWL_DEPTH * max(0.0, 1 - (rho / 0.96) ** 2) ** 0.6


def add_bowl(bm):
    """The star-dusted backdrop: a bowl sunk into the window, its rim tucked under the frame's lip."""
    uv = bm.loops.layers.uv.get("UVMap")
    x0, y0, x1, y1 = BOWL_RECT
    cx, cy, half = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2 * 0.98
    centre_p, centre_n = window_point(0, 0, -bowl_depth(0))
    centre = bm.verts.new(centre_p)
    ring = []
    for k in range(1, BOWL_RINGS + 1):
        rho = 0.96 * k / BOWL_RINGS
        ring.append([bm.verts.new(window_point(rho, 2 * math.pi * i / BOWL_SEGMENTS, -bowl_depth(rho))[0])
                     for i in range(BOWL_SEGMENTS)])

    def at(k, i):
        r = k / BOWL_RINGS
        return cx + half * r * math.cos(2 * math.pi * i / BOWL_SEGMENTS), cy + half * r * math.sin(2 * math.pi * i / BOWL_SEGMENTS)

    for i in range(BOWL_SEGMENTS):
        ii = (i + 1) % BOWL_SEGMENTS
        _face(bm, uv, [centre, ring[0][i], ring[0][ii]], [(cx, cy), at(1, i), at(1, i + 1)], centre_n)
        for k in range(BOWL_RINGS - 1):
            _face(bm, uv, [ring[k][i], ring[k + 1][i], ring[k + 1][ii], ring[k][ii]],
                  [at(k + 1, i), at(k + 2, i), at(k + 2, i + 1), at(k + 1, i + 1)], centre_n)


def add_ball(bm, centre, radius, rect=None, around=10, rings=6):
    """A small sphere; with rect, its UVs are squeezed into that swatch."""
    made = bmesh.ops.create_uvsphere(bm, u_segments=around, v_segments=rings, radius=radius, calc_uvs=rect is not None)
    bmesh.ops.translate(bm, verts=made["verts"], vec=centre)
    faces = {f for v in made["verts"] for f in v.link_faces}
    for f in faces:
        f.smooth = True
    if rect:
        uv = bm.loops.layers.uv.get("UVMap")
        x0, y0, x1, y1 = rect
        for f in faces:
            for loop in f.loops:
                s, t = loop[uv].uv
                loop[uv].uv = (x0 + (x1 - x0) * s, y0 + (y1 - y0) * t)


def planet_rect(index):
    x0, y0, x1, y1 = PLANET_RECT
    w = (x1 - x0) / len(PLANET_COLOURS)
    return x0 + w * index + 0.005, y0 + 0.005, x0 + w * (index + 1) - 0.005, y1 - 0.005


def add_planets(bm):
    for orbit, degrees, radius, colour in PLANETS:
        a = math.radians(degrees)
        u, v = local(orbit * math.cos(a), orbit * math.sin(a))
        add_ball(bm, SHAPE.point(u, v, -ORBIT_DEPTH)[0], radius, planet_rect(colour), around=8, rings=5)


def circle(r, steps=64):
    return [local(r * math.cos(2 * math.pi * k / steps), r * math.sin(2 * math.pi * k / steps)) for k in range(steps + 1)]


def glow_stars(scene):
    rng = random.Random(STAR_SEED)
    dots = [(*local(x, y), STAR_R) for line in CONSTELLATIONS for x, y in line]
    extra = 0
    while extra < EXTRA_STARS:
        x, y = rng.uniform(-WIN_W, WIN_W), rng.uniform(-WIN_H, WIN_H)
        if math.hypot(x / WIN_W, y / WIN_H) < 0.9 and math.hypot(x, y) > ORBITS[-1] + 0.05:
            dots.append((*local(x, y), rng.uniform(0.012, 0.022)))
            extra += 1
    stars = ec.make_dots(ID, scene, "Glow_Stars_dots", SHAPE, dots, lift=-STARS_DEPTH)
    lines = ec.make_strips(ID, scene, "Glow_Stars", SHAPE, [[local(x, y) for x, y in line] for line in CONSTELLATIONS],
                           width=LINE_WIDTH, lift=-STARS_DEPTH)
    lines.data.materials.append(ec.glow_material(ID, "Glow_Stars", STAR))
    return ec.join_into(lines, stars)


def glow_orbits(scene):
    rings = ec.make_strips(ID, scene, "Glow_Orbits", SHAPE, [circle(r) for r in ORBITS], width=ORBIT_WIDTH,
                           lift=-ORBIT_DEPTH)
    rings.data.materials.append(ec.glow_material(ID, "Glow_Orbits", ORBIT))
    return rings


def glow_sun(scene):
    bm = bmesh.new()
    add_ball(bm, window_point(0, 0, -SUN_DEPTH)[0], SUN_R)
    sun = ec.object_from_bmesh(ID, scene, "Glow_Sun", bm)
    sun.data.materials.append(ec.glow_material(ID, "Glow_Sun", SUN))
    return sun


def glass(scene):
    """The clear cover over the window, following the egg's curve just above its surface."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    around, rings = 24, 4
    centre_p, n = window_point(0, 0, GLASS_LIFT)
    centre = bm.verts.new(centre_p)
    ring = [[bm.verts.new(window_point(k / rings, 2 * math.pi * i / around, GLASS_LIFT)[0]) for i in range(around)]
            for k in range(1, rings + 1)]
    for i in range(around):
        ii = (i + 1) % around
        _face(bm, uv, [centre, ring[0][i], ring[0][ii]], [(0.5, 0.5)] * 3, n)
        for k in range(rings - 1):
            _face(bm, uv, [ring[k][i], ring[k + 1][i], ring[k + 1][ii], ring[k][ii]], [(0.5, 0.5)] * 4, n)
    obj = ec.object_from_bmesh(ID, scene, "Glass", bm)
    mat = bpy.data.materials.new(f"{ID}_Glass")
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = next(nd for nd in mat.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*GLASS_TINT, 1)
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Alpha"].default_value = 0.05                 # preview only: Roblox uses its Glass material
    bsdf.inputs["Specular IOR Level"].default_value = 0.25    # a light sheen, not a milky veil
    try:
        mat.surface_render_method = "BLENDED"
        mat.show_transparent_back = False
    except (AttributeError, TypeError):
        pass
    obj.data.materials.append(mat)
    return obj


# --- texture masks (numpy, over texture u = x - 0.5 and v = y) ------------------------------------

def in_rect(u, v, rect):
    x0, y0, x1, y1 = rect
    return ((u + 0.5 >= x0) & (u + 0.5 < x1) & (v >= y0) & (v < y1)).astype(np.float32)


def disc_r(u, v, rect):
    """0 at a rect's centre, 1 at the edge of the disc that fills it."""
    x0, y0, x1, y1 = rect
    return np.hypot(u + 0.5 - (x0 + x1) / 2, v - (y0 + y1) / 2) / ((x1 - x0) / 2 * 0.98)


def bowl_r(u, v):
    return in_rect(u, v, BOWL_RECT) * np.clip(disc_r(u, v, BOWL_RECT), 0, 1)


def chart_rings(u, v):
    """Faint chart circles on the backdrop."""
    r = disc_r(u, v, BOWL_RECT)
    lines = np.max([np.clip(1 - np.abs(r - c) / 0.008, 0, 1) for c in (0.3, 0.55, 0.8)], axis=0)
    return in_rect(u, v, BOWL_RECT) * lines


def frame_scroll(u, v):
    """Engraved scrollwork running round the frame (1 in the grooves)."""
    x0, y0, x1, y1 = FRAME_RECT
    along, across = (u + 0.5 - x0) / (x1 - x0), (v - y0) / (y1 - y0)
    wave = np.abs(across - 0.5 - 0.22 * np.sin(2 * math.pi * along * 18)) < 0.07
    beads = np.hypot(((along * 72) % 1 - 0.5) * 0.4, across - 0.88) < 0.05
    return in_rect(u, v, FRAME_RECT) * np.maximum(wave, beads)


def medal_parts(u, v):
    """1 on the medallions' dark blue centres, 0 on their gold rims."""
    return in_rect(u, v, MEDAL_RECT) * (disc_r(u, v, MEDAL_RECT) < 0.55)


def medal_star(u, v):
    return in_rect(u, v, MEDAL_RECT) * np.clip((0.14 - disc_r(u, v, MEDAL_RECT)) / 0.04, 0, 1)


def planet_shade(u, v):
    """Lighter on one side of every planet, so they read as little spheres."""
    x0, y0, x1, y1 = PLANET_RECT
    return in_rect(u, v, PLANET_RECT) * np.clip((v - y0) / (y1 - y0), 0, 1)


def planet_swatch(index):
    return lambda u, v: in_rect(u, v, planet_rect(index))


# --- build -----------------------------------------------------------------------------------------

def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    bm = bmesh.new()
    add_shell(bm)
    add_frame(bm)
    for theta in (math.pi / 2, -math.pi / 2):
        add_medallion(bm, theta)
    add_bowl(bm)
    add_planets(bm)
    shell = ec.object_from_bmesh(ID, scene, "Shell", bm)
    pieces = [glow_stars(scene), glow_orbits(scene), glow_sun(scene), glass(scene)]

    mat, nt, bsdf = ec.lookdev_material(ID)
    area = {name: ec.mask(nt, ec.mask_image(ID, name, fn, size=512)) for name, fn in (
        ("stone_area", lambda u, v: (v >= SHELL_Y).astype(np.float32)),
        ("bowl_area", lambda u, v: in_rect(u, v, BOWL_RECT)),
        ("frame_area", lambda u, v: in_rect(u, v, FRAME_RECT)),
        ("medal_area", lambda u, v: in_rect(u, v, MEDAL_RECT)),
        ("planet_area", lambda u, v: in_rect(u, v, PLANET_RECT)))}
    mottle = ec.add(nt, "ShaderNodeTexNoise", Scale=3.0, Detail=4.0, Vector=ec.coords(nt))
    stone = ec.ramp(nt, mottle.outputs["Fac"], [(0.35, STONE_DARK), (0.65, STONE_LIGHT)])
    uvs = nt.nodes.new("ShaderNodeTexCoord").outputs["UV"]
    dust = ec.add(nt, "ShaderNodeTexVoronoi", Scale=90.0, Vector=uvs)
    specks = ec.add(nt, "ShaderNodeMapRange", Value=dust.outputs["Distance"], From_Min=0.0, From_Max=0.08,
                    To_Min=1.0, To_Max=0.0).outputs["Result"]
    space = ec.ramp(nt, ec.mask(nt, ec.mask_image(ID, "bowl_r", bowl_r)), [(0.0, SPACE_GLOW), (0.3, SPACE_MID), (1.0, SPACE_DEEP)])
    space = ec.mix(nt, ec.calc(nt, "MULTIPLY", specks, 0.6), space, DUST)
    space = ec.mix(nt, ec.calc(nt, "MULTIPLY", ec.mask(nt, ec.mask_image(ID, "chart_rings", chart_rings)), 0.25), space, DUST)
    scroll = ec.mask(nt, ec.mask_image(ID, "frame_scroll", frame_scroll))
    gold = ec.mix(nt, scroll, GOLD, GOLD_DEEP)
    blue = ec.mask(nt, ec.mask_image(ID, "medal_parts", medal_parts))
    medal = ec.mix(nt, ec.mask(nt, ec.mask_image(ID, "medal_star", medal_star)), ec.mix(nt, blue, GOLD, MEDAL_CENTRE), STAR)
    planets = PLANET_COLOURS[0]
    for k in range(1, len(PLANET_COLOURS)):
        planets = ec.mix(nt, ec.mask(nt, ec.mask_image(ID, f"planet_{k}", planet_swatch(k), size=256)), planets, PLANET_COLOURS[k])
    planets = ec.mix(nt, ec.calc(nt, "MULTIPLY", ec.mask(nt, ec.mask_image(ID, "planet_shade", planet_shade, size=256)), 0.35),
                     planets, (1, 1, 1))
    colour = ec.mix(nt, area["stone_area"], SPACE_DEEP, stone)
    colour = ec.mix(nt, area["bowl_area"], colour, space)
    colour = ec.mix(nt, area["frame_area"], colour, gold)
    colour = ec.mix(nt, area["medal_area"], colour, medal)
    colour = ec.mix(nt, area["planet_area"], colour, planets)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    goldness = ec.calc(nt, "ADD", area["frame_area"], ec.calc(nt, "SUBTRACT", area["medal_area"], blue))
    nt.links.new(goldness, bsdf.inputs["Metallic"])
    rough = ec.add(nt, "ShaderNodeMapRange", Value=goldness, To_Min=0.55, To_Max=0.28).outputs["Result"]
    nt.links.new(rough, bsdf.inputs["Roughness"])
    grain = ec.add(nt, "ShaderNodeTexNoise", Scale=12.0, Detail=3.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "MULTIPLY", grain.outputs["Fac"], ec.calc(nt, "MULTIPLY", area["stone_area"], 0.25))
    relief = ec.calc(nt, "SUBTRACT", relief, ec.calc(nt, "MULTIPLY", scroll, 0.6))
    nt.links.new(ec.bump(nt, relief, 0.5), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell, pieces)


if __name__ == "__main__":
    print(build())
