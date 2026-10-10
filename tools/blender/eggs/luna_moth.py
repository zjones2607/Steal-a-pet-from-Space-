"""Luna Moth egg (Rare): two luna moth wings wrapped round the egg like a bat's. They start together on the
front left; the front wing wraps across the front, the back wing round the back, and its tip tucks under
the front wing's scalloped edge, which runs diagonally from the top centre to the lower right. The wings are
sage green with veins fanning out from their bases, light margins with a row of pale spots, and a glowing
yellow eyespot each. A dark, almost black stem runs down the line on the left where the wings meet, pointed
at both ends, with the veins fanning out from beside it. Three star-shaped purple flowers sit on the wings
as in the artwork, their hearts glowing (Glow_FlowerHearts, Neon in Roblox).
Later Roblox effects: fireflies, drifting purple petals.

Texture layout: wings fill y 0.12..1 (front wing x 0..0.5, back wing x 0.5..1; across a wing s runs from
its base (0) to its tip (1), and t up it from bottom (0) to top (1)). The strip below holds the petals
(x 0..0.5, every petal shares it), the stem (x 0.5..0.75) and the dark underside (x 0.8..1:
the core, and every wing's underside and rims). Masks use texture u = x - 0.5 and v = y, which is what
egg_common's mask helpers pass.

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/luna_moth.py", run_name="__main__")
"""
import importlib
import math
import os
import sys

import bmesh
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "luna_moth"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.62, pointiness=0.10)

# The wings: bases together on the front left, wrapping round to meet on the right
BASE_U = -0.2                            # turns round from the front: where both wings start
SPAN_TOP, SPAN_BOTTOM = 0.2, 0.45        # turns the front wing reaches round from its base, at the top and bottom:
                                         # its tip edge runs from the top centre to the lower right, as in the art
OVERLAP, BASE_OVERLAP = 0.05, 0.03       # turns the back wing tucks under the front wing's tip and its base
TOP_AT_BASE, TOP_AT_TIP, TOP_MAX = 0.88, 0.92, 0.985   # wing-top heights: at the base, at the tip, highest
WING_BOTTOM, BOTTOM_ROUND = 0.035, 0.06  # wings wrap under to this height, rounding up this much at the ends
SCALLOPS, SCALLOP_DEPTH = 4, 0.012       # bumps along the front wing's tip edge, and their depth in turns
WING_LIFT, THICKNESS = 0.04, 0.022       # studs: the back wing's height off the core; each wing's thickness
SEG_S, SEG_T = 14, 18                    # wing grid: across (base to tip) and up

# The dark stem down the line where the wings meet (at BASE_U)
STEM_TOP, STEM_BOTTOM = 0.87, 0.1        # heights it runs between
STEM_WIDTH, STEM_RAISE = 0.2, 0.045      # studs at its widest (it tapers to points at both ends); its middle
STEM_LIFT = WING_LIFT + 2 * THICKNESS + 0.012   # stands STEM_RAISE proud, so it reads as a rounded stem

# The flowers, as in the artwork: (u, v, petal length in studs, turn in radians)
FLOWERS = [(0.1, 0.8, 0.33, 0.3), (0.25, 0.3, 0.29, 1.2), (-0.3, 0.86, 0.26, 0.8)]
PETALS, PETAL_WIDTH, CUP = 6, 0.62, 0.3   # petals per flower; widest point and tip lift, as fractions of length
FLOWER_LIFT = WING_LIFT + 2 * THICKNESS + 0.035
HEART_R = 0.05

# Texture layout
WING_Y = 0.12
PETAL_RECT = (0.0, 0.0, 0.5, 0.1)        # x0, y0, x1, y1
STEM_RECT = (0.5, 0.0, 0.75, 0.1)
UNDER_RECT = (0.8, 0.0, 1.0, 0.1)
HIDDEN_UV = (0.9, 0.05)                  # undersides and rims: inside the dark underside

# Colours are linear, as Blender's shader sockets are, so they look lighter on screen:
# (0.21, 0.45, 0.21) shows as a soft sage green (0.5, 0.7, 0.5).
GREEN, GREEN_DEEP = (0.21, 0.45, 0.21), (0.11, 0.26, 0.12)
EDGE = (0.48, 0.71, 0.32)                # lighter wing margins
SPOT = (0.60, 0.83, 0.45)                # the row of pale spots inside them
VEIN = (0.06, 0.15, 0.065)
UNDERSIDE = (0.035, 0.09, 0.045)
EYE, EYE_GLOW = (1.0, 0.83, 0.17), (0.69, 0.83, 0.21)
STEM_DARK, STEM_EDGE = (0.01, 0.025, 0.015), (0.04, 0.09, 0.05)   # a sorta black stem, a little lighter at its sides
STEM_SPOT = (0.16, 0.30, 0.15)           # a row of pale spots down it
STEM_SPOTS = 7
HEART, ORCHID, VIOLET = (1.0, 0.78, 0.95), (0.74, 0.22, 0.86), (0.44, 0.24, 0.92)   # petal base, middle, tip
PETAL_EDGE = (0.16, 0.05, 0.42)
HEART_GLOW = (1.0, 0.72, 0.92)           # the glowing hearts (Neon in Roblox)

EYES = [(True, 0.55, 0.35), (False, 0.86, 0.62)]   # (front wing?, s, t)
EYE_R = 0.07                             # studs
T_BASE = 0.82                            # veins fan out from around this height up each wing's base
VEIN_ENDS = [(0.28, 1.0), (0.55, 1.0), (0.8, 1.0), (1.0, 0.82), (1.0, 0.58), (1.0, 0.34), (1.0, 0.12),
             (0.75, 0.0), (0.45, 0.0)]    # (s, t) round each wing's top, tip and bottom margins
VEIN_WIDTH, VEIN_RAISE = 0.035, 0.35
SPOT_SIZE, SPOT_GAP = 0.09, 0.15         # studs
ROUGH_WING, ROUGH_PETAL, ROUGH_STEM = 0.6, 0.35, 0.45


# --- where things are ------------------------------------------------------------------------------

def span(v):
    """Turns the front wing reaches round from its base at height v: further at the bottom, so its tip edge
    runs diagonally from the top centre to the lower right."""
    return SPAN_TOP + (SPAN_BOTTOM - SPAN_TOP) * (1 - v)


def scallop(v):
    return SCALLOP_DEPTH * abs(math.sin(math.pi * SCALLOPS * v))


def wing_u(front, s, v):
    """Where round the egg (u) a wing point is: s from 0 at the wing's base to 1 at its tip, at height v.
    The front wing wraps one way round from BASE_U, the back wing the other; their tips meet."""
    if front:
        return BASE_U + s * (span(v) + scallop(v))
    return BASE_U + BASE_OVERLAP - s * (1 - span(v) + OVERLAP + BASE_OVERLAP)


def wing_v(s, t):
    """Height of a wing point: t from 0 at the wing's bottom edge to 1 at its rounded top edge."""
    top = (1 - s) * TOP_AT_BASE + s * TOP_AT_TIP + (TOP_MAX - (TOP_AT_BASE + TOP_AT_TIP) / 2) * math.sin(math.pi * s)
    bottom = WING_BOTTOM + BOTTOM_ROUND * (1 - math.sin(math.pi * s))
    return bottom + t * (top - bottom)


def wing_point(front, s, t, lift=0.0):
    v = wing_v(s, t)
    return SHAPE.point(wing_u(front, s, v), v, lift)


def wing_scale(front, s, t):
    """Studs per unit of s and of t on a wing near (s, t)."""
    e = 1e-3
    p = wing_point(front, s, t)[0]
    return (wing_point(front, s + e, t)[0] - p).length / e, (wing_point(front, s, t + e)[0] - p).length / e


def tex_point(front, s, t):
    """Texture (u, v), as the mask helpers use them, of a wing point."""
    return (0.0 if front else 0.5) + 0.5 * s - 0.5, WING_Y + (1 - WING_Y) * t


def stem_path(steps=24):
    """The stem's centre line [(u, v, width in studs)]: straight down the line where the wings meet, widest
    in the middle and pointed at both ends."""
    return [(BASE_U, STEM_TOP + (STEM_BOTTOM - STEM_TOP) * i / steps,
             STEM_WIDTH * math.sin(math.pi * i / steps) ** 0.5 if 0 < i < steps else 0.0) for i in range(steps + 1)]


# --- geometry --------------------------------------------------------------------------------------

def _uvs(face, uv, coords):
    for loop, t in zip(face.loops, coords):
        loop[uv].uv = t


def add_wing(bm, front):
    """One wing as a curved slab from its base to its tip. The outer face is mapped to the wing's half of the
    texture; the underside and rims show the dark underside."""
    uv = bm.loops.layers.uv.get("UVMap")
    lift = WING_LIFT + (THICKNESS + 0.006 if front else 0.0)
    outer, inner, tex = {}, {}, {}
    for i in range(SEG_T + 1):
        t = i / SEG_T
        for j in range(SEG_S + 1):
            s = j / SEG_S
            p, n = wing_point(front, s, t, lift)
            outer[i, j], inner[i, j] = bm.verts.new(p), bm.verts.new(p - n * THICKNESS)
            u_tex, v_tex = tex_point(front, s, t)
            tex[i, j] = (u_tex + 0.5, v_tex)
    faces = []

    def face(verts, coords, smooth=True):
        f = bm.faces.new(verts)
        f.smooth = smooth
        _uvs(f, uv, coords)
        faces.append(f)

    hidden = [HIDDEN_UV] * 4
    for i in range(SEG_T):
        for j in range(SEG_S):
            quad = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            face([outer[k] for k in quad], [tex[k] for k in quad])
            face([inner[k] for k in reversed(quad)], hidden)
    border = ([(0, j) for j in range(SEG_S)] + [(i, SEG_S) for i in range(SEG_T)]
              + [(SEG_T, j) for j in range(SEG_S, 0, -1)] + [(i, 0) for i in range(SEG_T, 0, -1)])
    for a, b in zip(border, border[1:] + border[:1]):
        face([outer[a], outer[b], inner[b], inner[a]], hidden, smooth=False)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def add_stem(bm):
    """The dark stem lying over the line where the wings meet: rounded on top (its middle stands up) and
    pointed at both ends, mapped to STEM_RECT (across, then along)."""
    uv = bm.loops.layers.uv.get("UVMap")
    path = stem_path()
    rows, normals = [], []
    for i, (u, v, w) in enumerate(path):
        p, n = SHAPE.point(u, v, STEM_LIFT)
        after, before = path[min(i + 1, len(path) - 1)], path[max(i - 1, 0)]
        ahead = SHAPE.point(after[0], after[1])[0] - SHAPE.point(before[0], before[1])[0]
        side = n.cross(ahead).normalized()
        rows.append([bm.verts.new(p - side * w / 2), bm.verts.new(p + n * STEM_RAISE * w / STEM_WIDTH),
                     bm.verts.new(p + side * w / 2)])
        normals.append(n)
    x0, y0, x1, y1 = STEM_RECT
    for i in range(len(rows) - 1):
        ya, yb = y0 + (y1 - y0) * i / (len(rows) - 1), y0 + (y1 - y0) * (i + 1) / (len(rows) - 1)
        for c in range(2):
            xa, xb = x0 + (x1 - x0) * c / 2, x0 + (x1 - x0) * (c + 1) / 2
            f = bm.faces.new([rows[i][c], rows[i][c + 1], rows[i + 1][c + 1], rows[i + 1][c]])
            _uvs(f, uv, [(xa, ya), (xb, ya), (xb, yb), (xa, yb)])
            f.smooth = True
            f.normal_update()
            if f.normal.dot(normals[i]) < 0:
                f.normal_flip()


def add_flower(bm, u, v, length, turn):
    """A star flower of pointed petals lying on the wings, cupped upward. Every petal has a back face too
    (Roblox draws one side only), and all petals share the petal strip of the texture."""
    uv = bm.loops.layers.uv.get("UVMap")
    c, n = SHAPE.point(u, v, FLOWER_LIFT)
    a = n.cross(Vector((0, 0, 1))).normalized()
    b = n.cross(a)
    x0, y0, x1, y1 = PETAL_RECT
    rows, cols = 5, (-1.0, 0.0, 1.0)
    for k in range(PETALS):
        angle = turn + 2 * math.pi * k / PETALS
        d = a * math.cos(angle) + b * math.sin(angle)
        side = n.cross(d)
        for facing in (1, -1):                     # front, then back (a hair lower)
            grid = {}
            for i in range(rows + 1):
                t = i / rows
                half = PETAL_WIDTH * length / 2 * math.sin(math.pi * t) ** 0.7
                for jx, x in enumerate(cols):
                    grid[i, jx] = bm.verts.new(c + d * (0.025 + t * length) + side * (x * half)
                                               + n * (CUP * length * t * t + 0.003 * k - (0.002 if facing < 0 else 0)))
            for i in range(rows):
                for jx in range(len(cols) - 1):
                    quad = [(i, jx), (i, jx + 1), (i + 1, jx + 1), (i + 1, jx)]
                    f = bm.faces.new([grid[q] for q in quad])
                    _uvs(f, uv, [(x0 + (x1 - x0) * (cols[q[1]] + 1) / 2, y0 + (y1 - y0) * q[0] / rows) for q in quad])
                    f.normal_update()
                    if f.normal.dot(n) * facing < 0:
                        f.normal_flip()
                    f.smooth = True


# --- texture masks (numpy, over texture u = x - 0.5 and v = y) ------------------------------------

def in_rect(u, v, rect):
    x0, y0, x1, y1 = rect
    return ((u + 0.5 >= x0) & (u + 0.5 < x1) & (v >= y0) & (v < y1)).astype(np.float32)


def rect_coords(u, v, rect):
    """(across, along) inside a rect, each 0..1."""
    x0, y0, x1, y1 = rect
    return (u + 0.5 - x0) / (x1 - x0), (v - y0) / (y1 - y0)


def wing_st(u, v):
    x = u + 0.5
    front = x < 0.5
    return np.where(front, x * 2, x * 2 - 1), (v - WING_Y) / (1 - WING_Y), front


def edge_mask(u, v):
    s, t, _ = wing_st(u, v)
    edge = np.maximum.reduce([np.clip(1 - (1 - t) / 0.05, 0, 1), np.clip(1 - (1 - s) / 0.04, 0, 1),
                              np.clip(1 - t / 0.035, 0, 1)])
    return edge * (v >= WING_Y)


def eye_mask(radius):
    def fn(u, v):
        s, t, front = wing_st(u, v)
        out = np.zeros_like(u)
        for is_front, es, et in EYES:
            ks, kt = wing_scale(is_front, es, et)
            spot = np.clip((radius - np.hypot((s - es) * ks, (t - et) * kt)) / 0.015, 0, 1)
            out = np.maximum(out, np.where((front == is_front) & (v >= WING_Y), spot, 0))
        return out
    return fn


def petal_along(u, v):
    return in_rect(u, v, PETAL_RECT) * rect_coords(u, v, PETAL_RECT)[1]


def petal_side(u, v):
    return in_rect(u, v, PETAL_RECT) * np.abs(2 * rect_coords(u, v, PETAL_RECT)[0] - 1)


def stem_side(u, v):
    return in_rect(u, v, STEM_RECT) * np.abs(2 * rect_coords(u, v, STEM_RECT)[0] - 1)


def stem_spots(u, v):
    """Pale spots spaced down the stem's middle (an along-unit is the stem's length, an across-unit its width)."""
    across, along = rect_coords(u, v, STEM_RECT)
    length = (STEM_TOP - STEM_BOTTOM) * SHAPE.arc_length
    centres = [(k + 1) / (STEM_SPOTS + 1) for k in range(STEM_SPOTS)]
    d = np.min([np.hypot((along - c) * length / 0.035, (2 * across - 1) * STEM_WIDTH / 2 / 0.035) for c in centres], axis=0)
    return in_rect(u, v, STEM_RECT) * np.clip((1 - d) / 0.3, 0, 1)


def vein_strokes():
    """Veins fanning from each wing's base out to its top, tip and bottom margins."""
    strokes = []
    for front in (True, False):
        for k, end in enumerate(VEIN_ENDS):
            start = (0.06, T_BASE + 0.08 - 0.25 * k / (len(VEIN_ENDS) - 1))   # spread along the base, not one point
            bend = ((start[0] + end[0]) / 2 + 0.05, (start[1] + end[1]) / 2 + 0.08)
            points = []
            for i in range(15):
                k2 = i / 14
                s, t = ((1 - k2) ** 2 * a + 2 * (1 - k2) * k2 * c + k2 * k2 * e for a, c, e in zip(start, bend, end))
                points.append(tex_point(front, min(max(s, 0.03), 0.96), min(max(t, 0.03), 0.96)))
            strokes.append((points, VEIN_WIDTH))
    return strokes


def spot_strokes():
    """A row of pale spots just inside each wing's top and tip margins (dots: zero-length strokes)."""
    spots = []
    for front in (True, False):
        s = 0.1
        while s < 0.92:
            spots.append(tex_point(front, s, 0.93))
            s += SPOT_GAP / wing_scale(front, s, 0.93)[0]
        t = 0.86
        while t > 0.12:
            spots.append(tex_point(front, 0.94, t))
            t -= SPOT_GAP / wing_scale(front, 0.94, t)[1]
    return [([p, p], SPOT_SIZE) for p in spots]


# --- build -----------------------------------------------------------------------------------------

def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    bm = bmesh.new()
    core = ec.add_egg(bm, SHAPE, segments=16, rings=10, lift=0.015)          # just under the back wing
    uv = bm.loops.layers.uv.get("UVMap")
    x0, y0, x1, y1 = UNDER_RECT
    for f in core:
        for loop in f.loops:
            x, y = loop[uv].uv
            loop[uv].uv = (x0 + (x1 - x0) * x, y0 + (y1 - y0) * y)
    add_wing(bm, front=False)
    add_wing(bm, front=True)
    add_stem(bm)
    for flower in FLOWERS:
        add_flower(bm, *flower)
    shell = ec.object_from_bmesh(ID, scene, "Shell", bm)
    hearts = ec.make_dots(ID, scene, "Glow_FlowerHearts", SHAPE, [(u, v, HEART_R) for u, v, _, _ in FLOWERS],
                          lift=FLOWER_LIFT + 0.025)
    hearts.data.materials.append(ec.glow_material(ID, "Glow_FlowerHearts", HEART_GLOW))

    mat, nt, bsdf = ec.lookdev_material(ID)
    region = {name: ec.mask(nt, ec.mask_image(ID, name, fn, size=512)) for name, fn in (
        ("wing_area", lambda u, v: (v >= WING_Y).astype(np.float32)),
        ("petal_area", lambda u, v: in_rect(u, v, PETAL_RECT)),
        ("stem_area", lambda u, v: in_rect(u, v, STEM_RECT)))}
    shade = ec.add(nt, "ShaderNodeTexNoise", Scale=1.2, Detail=1.0, Vector=ec.coords(nt))
    wing = ec.mix(nt, ec.ramp(nt, shade.outputs["Fac"], [(0.38, (0, 0, 0)), (0.62, (1, 1, 1))]), GREEN_DEEP, GREEN)
    wing = ec.mix(nt, ec.mask(nt, ec.mask_image(ID, "edge", edge_mask)), wing, EDGE)
    spots = ec.mask(nt, ec.paint_strokes(ID, "spots", SHAPE, spot_strokes()))
    wing = ec.mix(nt, spots, wing, SPOT)
    vein = ec.mask(nt, ec.paint_strokes(ID, "veins", SHAPE, vein_strokes()))
    wing = ec.mix(nt, vein, wing, VEIN)
    glow = ec.mask(nt, ec.mask_image(ID, "eye_glow", eye_mask(EYE_R * 2.2)))
    wing = ec.mix(nt, ec.calc(nt, "MULTIPLY", glow, 0.6), wing, EYE_GLOW)
    wing = ec.mix(nt, ec.mask(nt, ec.mask_image(ID, "eye", eye_mask(EYE_R))), wing, EYE)
    along = ec.mask(nt, ec.mask_image(ID, "petal_along", petal_along))
    edgeish = ec.mask(nt, ec.mask_image(ID, "petal_side", petal_side))
    petal = ec.ramp(nt, along, [(0.0, HEART), (0.35, ORCHID), (1.0, VIOLET)])
    petal = ec.mix(nt, ec.calc(nt, "MULTIPLY", ec.calc(nt, "POWER", edgeish, 3.0), 0.5), petal, PETAL_EDGE)
    stem_edge = ec.mask(nt, ec.mask_image(ID, "stem_side", stem_side))
    stem = ec.mix(nt, ec.calc(nt, "POWER", stem_edge, 2.0), STEM_DARK, STEM_EDGE)
    stem = ec.mix(nt, ec.mask(nt, ec.mask_image(ID, "stem_spots", stem_spots)), stem, STEM_SPOT)
    colour = ec.mix(nt, region["wing_area"], UNDERSIDE, wing)
    colour = ec.mix(nt, region["stem_area"], colour, stem)
    colour = ec.mix(nt, region["petal_area"], colour, petal)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    rough = ec.calc(nt, "ADD", ROUGH_WING, ec.calc(nt, "MULTIPLY", region["petal_area"], ROUGH_PETAL - ROUGH_WING))
    rough = ec.calc(nt, "ADD", rough, ec.calc(nt, "MULTIPLY", region["stem_area"], ROUGH_STEM - ROUGH_WING))
    nt.links.new(rough, bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0
    fuzz = ec.add(nt, "ShaderNodeTexNoise", Scale=40.0, Detail=2.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "ADD", vein, ec.calc(nt, "MULTIPLY", spots, 0.6))
    relief = ec.calc(nt, "ADD", relief, ec.calc(nt, "MULTIPLY", fuzz.outputs["Fac"],
                                                ec.calc(nt, "MULTIPLY", region["wing_area"], 0.1)))
    relief = ec.calc(nt, "ADD", relief, ec.calc(nt, "MULTIPLY", ec.calc(nt, "SUBTRACT", region["petal_area"], edgeish), 0.3))
    nt.links.new(ec.bump(nt, relief, VEIN_RAISE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell, [hearts])


if __name__ == "__main__":
    print(build())
