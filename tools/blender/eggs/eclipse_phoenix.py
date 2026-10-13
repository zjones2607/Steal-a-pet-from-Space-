"""Eclipse Phoenix egg (Legendary): a glossy, nearly black egg covered in mirrored gold filigree that reads as
a stylised phoenix: a pointed flame arch rising up the middle, tendrils sweeping out and down from the crown
like spread wings, and flame tendrils rising from the base, their ends curling into spirals. The motif
repeats three times round the egg. Glow piece Glow_Embers (Neon in Roblox): red-orange shards glowing through
the black in the middle of the front, two of them like eyes, with a faint red glow round them.
Later Roblox effects: the fiery eclipse ring, orbiting planets, a red glow beneath, rising embers.

Positions are in studs from a point on the egg (x right, y up); local() turns them into egg (u, v).

Build in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/eclipse_phoenix.py", run_name="__main__")
"""
import importlib
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import egg_common as ec  # noqa: E402

importlib.reload(ec)

ID = "eclipse_phoenix"
HEIGHT = 3.0
SHAPE = ec.EggShape(height=HEIGHT, width=0.74, pointiness=0.18)

# Colours are linear, as Blender's shader sockets are, so they look lighter on screen.
BLACK, OLIVE = (0.008, 0.008, 0.006), (0.015, 0.016, 0.009)   # glossy black with a faint dark olive cast
GOLD, GOLD_DEEP = (1.0, 0.66, 0.24), (0.45, 0.26, 0.07)       # bright on the crest of each line, deeper at its sides
EMBER = (1.0, 0.07, 0.01)                                     # the glowing shards (Neon in Roblox): red-orange
EMBER_HAZE = (0.3, 0.025, 0.0)                                # the faint red glow round them, painted on the black
LINE = 0.03                        # filigree width, studs
CROWN, FLAMES = 5, 4               # tendrils per side sweeping from the crown, and flames rising from the base
GOLD_RAISE = 0.8                   # bump strength
ROUGH_BLACK, ROUGH_GOLD = 0.14, 0.3
COPIES = (0.0, 1 / 3, 2 / 3)       # the motif's centres round the egg (turns; 0 is the front)

# The embers in the middle of the front: (x, y, size) in studs; diamonds, and thin cracks from the centre
EMBERS = [(0, 0.05, 0.06), (-0.09, 0.42, 0.035), (0.09, 0.42, 0.035), (-0.06, -0.12, 0.04), (0.06, -0.12, 0.04),
          (0, -0.3, 0.035), (-0.13, 0.15, 0.03), (0.13, 0.15, 0.03), (0, 0.25, 0.03)]
CRACKS = [[(0, 0.05), (-0.05, -0.01), (-0.08, -0.07)], [(0, 0.05), (0.05, -0.01), (0.08, -0.07)],
          [(0, 0.05), (-0.04, 0.1), (-0.11, 0.13)], [(0, 0.05), (0.04, 0.1), (0.11, 0.13)]]
CRACK_WIDTH = 0.012


def local(x, y, uc=0.0, vc=0.5):
    """Egg (u, v) of a point x, y studs from the egg point (uc, vc)."""
    v = vc + y / SHAPE.arc_length
    return uc + x / SHAPE.studs_per_uv(v)[0], v


def bezier(p0, p1, p2, n=16):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / (n - 1) for i in range(n))]


def curl_end(points, size, direction):
    """Carry a line on into an inward spiral, so its end curls (direction 1 turns left, -1 right)."""
    (x0, y0), (x1, y1) = points[-2], points[-1]
    side = math.atan2(y1 - y0, x1 - x0) + direction * math.pi / 2
    cx, cy = x1 + size * math.cos(side), y1 + size * math.sin(side)
    start = math.atan2(y1 - cy, x1 - cx)
    spiral = [(cx + size * (1 - 0.75 * t) * math.cos(start + direction * 2 * math.pi * 1.1 * t),
               cy + size * (1 - 0.75 * t) * math.sin(start + direction * 2 * math.pi * 1.1 * t))
              for t in (i / 23 for i in range(24))]
    return points + spiral[1:]


def motif():
    """The filigree lines, mirrored left and right, in studs from the middle of one face of the egg."""
    lines = [bezier((0, -1.55), (0, -1.2), (0, -0.9))]                      # a spine below the arch
    for s in (-1, 1):
        lines.append(bezier((0, -0.9), (s * 0.42, 0.2), (0, 1.25)))        # the flame arch up the middle
        lines.append(bezier((0, -0.55), (s * 0.22, 0.25), (0, 0.95)))      # and a smaller one inside it
        for k in range(CROWN):                                              # the crown sweeping out like wings
            start, ctrl = (s * (0.03 + 0.04 * k), 1.42 - 0.07 * k), (s * (0.6 + 0.07 * k), 1.45 - 0.14 * k)
            end = (s * (0.85 + 0.04 * k), 0.75 - 0.3 * k)
            lines.append(curl_end(bezier(start, ctrl, end), 0.08 - 0.01 * k, -s))
        for j in range(2):                                                  # the wings' lower sweeps
            lines.append(curl_end(bezier((s * 0.3, -0.25 * j), (s * 0.75, 0.15 - 0.25 * j), (s * 1.0, -0.45 - 0.25 * j)),
                                  0.07, -s))
        for k in range(FLAMES):                                             # flames rising from the base
            start, ctrl = (s * (0.03 + 0.05 * k), -1.5 + 0.06 * k), (s * (0.45 + 0.08 * k), -1.4 + 0.1 * k)
            end = (s * (0.55 + 0.1 * k), -0.75 + 0.1 * k)
            lines.append(curl_end(bezier(start, ctrl, end), 0.06, s))
    return lines


def filigree():
    """The motif placed round the egg, as strokes for the gold mask."""
    return [([local(x, y, uc) for x, y in line], LINE) for uc in COPIES for line in motif()]


def ember_haze(u, v):
    """A faint red glow on the black round the embers (numpy, over the egg's texture coordinates)."""
    rows = np.array([SHAPE.studs_per_uv(t)[0] for t in (np.arange(u.shape[0]) + 0.5) / u.shape[0]])[:, None]
    x, y = u * rows, (v - 0.5) * SHAPE.arc_length
    return np.clip(sum(np.exp(-((x - ex) ** 2 + (y - ey) ** 2) / (size * 3.5) ** 2) for ex, ey, size in EMBERS), 0, 1)


def embers(scene):
    shards = ec.make_dots(ID, scene, "Glow_Embers_shards", SHAPE, [(*local(x, y), size) for x, y, size in EMBERS],
                          lift=0.012, sides=4)
    cracks = ec.make_strips(ID, scene, "Glow_Embers", SHAPE, [[local(x, y) for x, y in c] for c in CRACKS],
                            width=CRACK_WIDTH, lift=0.012)
    cracks.data.materials.append(ec.glow_material(ID, "Glow_Embers", EMBER))
    return ec.join_into(cracks, shards)


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    gold = ec.mask(nt, ec.paint_strokes(ID, "filigree", SHAPE, filigree()))
    cover = ec.add(nt, "ShaderNodeMapRange", Value=gold, From_Min=0.0, From_Max=0.35).outputs["Result"]
    cast = ec.add(nt, "ShaderNodeTexNoise", Scale=2.0, Detail=2.0, Vector=ec.coords(nt))
    black = ec.mix(nt, ec.ramp(nt, cast.outputs["Fac"], [(0.4, (0, 0, 0)), (0.6, (1, 1, 1))]), BLACK, OLIVE)
    black = ec.mix(nt, ec.calc(nt, "MULTIPLY", ec.mask(nt, ec.mask_image(ID, "haze", ember_haze)), 0.7), black, EMBER_HAZE)
    shaded = ec.ramp(nt, gold, [(0.3, GOLD_DEEP), (1.0, GOLD)])                 # deep sides, bright crest
    nt.links.new(ec.mix(nt, cover, black, shaded), bsdf.inputs["Base Color"])
    nt.links.new(cover, bsdf.inputs["Metallic"])
    rough = ec.add(nt, "ShaderNodeMapRange", Value=cover, To_Min=ROUGH_BLACK, To_Max=ROUGH_GOLD)
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    grain = ec.add(nt, "ShaderNodeTexNoise", Scale=25.0, Detail=2.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "ADD", gold, ec.calc(nt, "MULTIPLY", grain.outputs["Fac"], 0.01))
    nt.links.new(ec.bump(nt, relief, GOLD_RAISE, 0.04), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell, [embers(scene)])


if __name__ == "__main__":
    print(build())
