"""Moon Rabbit egg (Uncommon): a milky crystal egg, white with opal flashes at the top and lavender-blue
lower down, with icy blue frost branches frozen inside it. The branches rise from round the bottom tip
and fork outward as they climb; every branch tapers to a sharp point and none touches another.
No glow pieces. Later Roblox effects: swirling gold ribbons, crystal glints.

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

# The crystal
FROST_LOW = (0.50, 0.55, 0.82)                         # lavender-blue near the bottom
FROST_HIGH = (0.93, 0.92, 0.97)                        # milky white near the top
OPAL = [(0.44, (0.96, 0.72, 0.84)), (0.50, (0.98, 0.93, 0.70)), (0.56, (0.68, 0.90, 0.98))]  # pink, yellow, cyan
OPAL_EDGES = (0.44, 0.56)                              # noise range over which an opal flash fades in
OPAL_AMOUNT = 0.8                                      # strongest flash, at the very top
OPAL_LOW = 0.5                                         # how strong the flashes still are at the bottom (0..1)
NACRE = [(0.0, (0.97, 0.80, 0.88)), (0.25, (0.99, 0.95, 0.82)), (0.5, (0.80, 0.95, 0.91)),
         (0.75, (0.78, 0.85, 1.0)), (1.0, (0.97, 0.80, 0.88))]   # mother-of-pearl bands: pink, cream, mint, periwinkle
NACRE_AMOUNT, NACRE_SCALE, NACRE_SWIRL = 0.35, 2.2, 7.0  # band strength, size (bigger = finer) and waviness
PEARL_METAL, VEIN_METAL = 0.3, 0.05                    # a little metal gives the crystal a pearly sheen
ROUGH_PEARL = 0.18

# The branches
VEIN_DEEP = (0.24, 0.45, 0.88)                         # deep blue down the sides of each branch
VEIN_CREST = (0.68, 0.84, 1.0)                         # light icy blue along its raised crest
HALO = (0.70, 0.83, 1.0)                               # soft glow round each branch
HALO_AMOUNT, HALO_SPREAD = 0.25, 1.8                   # glow strength, and its width as a multiple of the branch
VEIN_SEED = 11
TRUNKS = 4                                             # branches rising from round the bottom tip
BASE_V, TOP_V = 0.03, 0.9                              # they start at BASE_V and stop by TOP_V (0..1 up the egg)
TRUNK_WIDTH = 0.26                                     # studs at the base (soft edges make lines look about half this)
TRUNK_LENGTH = 0.8                                     # studs from the base to the first fork
LENGTH_DECAY, WIDTH_DECAY = 0.85, 0.75                 # each fork is this much shorter and thinner
LEVELS = 5                                             # how many times a branch can fork
SPREAD = (0.25, 0.45)                                  # radians each half of a fork turns away
CURL = 0.975                                           # branches bend back toward upright by this much per step
WIGGLE = 0.04                                          # random bend per step, radians
GAP = 0.05                                             # studs kept clear between neighbouring branches
STEP = 0.04                                            # studs per growth step
VEIN_RAISE, VEIN_HEIGHT = 1.0, 0.06                    # bump strength, and how far the branches stand out (studs)
ROUGH_VEIN = 0.15                                      # glossy crests catch highlights, so they read as raised
CELL = 0.25                                            # spatial-hash cell, studs: over 2 x widest half + GAP


def join_radius(width):
    """How far from a fork its limbs may run together before they must keep clear of each other."""
    return 2 * (width + GAP)


def veins():
    """The branches as strokes [(points, widths)], one per limb, with a width in studs at every point.
    Trunks rise from round the bottom tip; each limb that grows its full length forks in two, turning
    outward. A limb that would come within GAP of another branch steers away, or stops there. Limbs that
    don't fork taper to a sharp point."""
    rng = random.Random(VEIN_SEED)
    grid = {}                                              # cell -> [(position, half_width, limb)]
    limbs = []                                             # [points, widths, children]

    def cell(p):
        return math.floor(p.x / CELL), math.floor(p.y / CELL), math.floor(p.z / CELL)

    def clear(p, half, limb, start, join):
        cx, cy, cz = cell(p)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for q, h, other in grid.get((cx + dx, cy + dy, cz + dz), ()):
                        if other != limb and (q - p).length < half + h + GAP and (q - start).length >= join:
                            return False
        return True

    def remember(a, b, half_a, half_b, limb):
        n = max(1, math.ceil((SHAPE.point(*b)[0] - SHAPE.point(*a)[0]).length / 0.02))
        for i in range(n + 1):
            t = i / n
            p = SHAPE.point(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)[0]
            grid.setdefault(cell(p), []).append((p, half_a + (half_b - half_a) * t, limb))

    queue = [(k / TRUNKS - 0.5 + rng.uniform(-0.02, 0.02), BASE_V, rng.uniform(-0.1, 0.1), TRUNK_LENGTH,
              TRUNK_WIDTH, 0, None) for k in range(TRUNKS)]
    while queue:                                           # breadth first, so every branch gets a fair share
        u, v, angle, length, width, level, parent = queue.pop(0)
        limb, end_width = len(limbs), width * WIDTH_DECAY
        start, join = SHAPE.point(u, v)[0], join_radius(width)
        points, widths = [(u, v)], [width]
        steps = max(2, round(length / STEP))
        for i in range(1, steps + 1):
            w = width + (end_width - width) * i / steps
            for turn in (0.0, 0.2, -0.2, 0.4, -0.4):       # straight on if there's room, else steer
                a = max(-1.4, min(1.4, angle * CURL + turn + rng.uniform(-WIGGLE, WIGGLE)))
                sx, sy = SHAPE.studs_per_uv(v)
                nu, nv = u + math.sin(a) * STEP / sx, v + math.cos(a) * STEP / sy
                if nv < TOP_V and clear(SHAPE.point(nu, nv)[0], w / 2, limb, start, join):
                    break
            else:
                break                                      # boxed in: the limb ends here
            u, v, angle = nu, nv, a
            points.append((u, v))
            widths.append(w)
            remember(points[-2], points[-1], widths[-2] / 2, w / 2, limb)
        if len(points) < 2:
            continue
        limbs.append([points, widths, 0])
        if parent is not None:
            limbs[parent][2] += 1
        if len(points) == steps + 1 and level < LEVELS:     # grew its full length: fork
            for side in rng.sample((-1, 1), 2):
                queue.append((u, v, angle + side * rng.uniform(*SPREAD),
                              length * LENGTH_DECAY * rng.uniform(0.85, 1.15), end_width, level + 1, limb))
    for points, widths, children in limbs:
        if not children:                                   # a tip: taper to a sharp point
            n = len(widths) - 1
            widths[:] = [widths[0] * (1 - i / n) for i in range(n + 1)]
    return [(points, widths) for points, widths, _ in limbs]


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    branches = veins()
    vein = ec.mask(nt, ec.paint_strokes(ID, "veins", SHAPE, branches))
    halo = ec.mask(nt, ec.paint_strokes(ID, "halo", SHAPE, [(p, [x * HALO_SPREAD for x in w]) for p, w in branches]))
    height = ec.add(nt, "ShaderNodeSeparateXYZ", Vector=ec.coords(nt)).outputs["Z"]
    up = ec.add(nt, "ShaderNodeMapRange", Value=height, From_Min=-HEIGHT / 2, From_Max=HEIGHT / 2).outputs["Result"]
    colour = ec.ramp(nt, up, [(0.15, FROST_LOW), (0.85, FROST_HIGH)])
    bands = ec.add(nt, "ShaderNodeTexWave", Scale=NACRE_SCALE, Distortion=NACRE_SWIRL, Detail=2.0, Vector=ec.coords(nt))
    colour = ec.mix(nt, NACRE_AMOUNT, colour, ec.ramp(nt, bands.outputs["Fac"], NACRE))
    hue = ec.add(nt, "ShaderNodeTexNoise", Scale=1.2, Detail=0.5, Vector=ec.coords(nt))
    patches = ec.add(nt, "ShaderNodeTexNoise", Scale=1.6, Detail=0.5, Vector=ec.coords(nt))
    flash = ec.ramp(nt, patches.outputs["Fac"], [(OPAL_EDGES[0], (0, 0, 0)), (OPAL_EDGES[1], (OPAL_AMOUNT,) * 3)])
    reach = ec.add(nt, "ShaderNodeMapRange", Value=up, To_Min=OPAL_LOW, To_Max=1.0).outputs["Result"]
    colour = ec.mix(nt, ec.calc(nt, "MULTIPLY", flash, reach), colour, ec.ramp(nt, hue.outputs["Fac"], OPAL))
    colour = ec.mix(nt, ec.calc(nt, "MULTIPLY", halo, HALO_AMOUNT), colour, HALO)
    cover = ec.add(nt, "ShaderNodeMapRange", Value=vein, From_Min=0.0, From_Max=0.35).outputs["Result"]
    shaded = ec.ramp(nt, vein, [(0.3, VEIN_DEEP), (1.0, VEIN_CREST)])     # deep sides, light crest
    colour = ec.mix(nt, cover, colour, shaded)
    nt.links.new(colour, bsdf.inputs["Base Color"])
    rough = ec.add(nt, "ShaderNodeMapRange", Value=cover, To_Min=ROUGH_PEARL, To_Max=ROUGH_VEIN)
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    metal = ec.add(nt, "ShaderNodeMapRange", Value=cover, To_Min=PEARL_METAL, To_Max=VEIN_METAL)
    nt.links.new(metal.outputs["Result"], bsdf.inputs["Metallic"])
    grain = ec.add(nt, "ShaderNodeTexNoise", Scale=30.0, Detail=2.0, Vector=ec.coords(nt))
    relief = ec.calc(nt, "ADD", vein, ec.calc(nt, "MULTIPLY", grain.outputs["Fac"], 0.008))
    nt.links.new(ec.bump(nt, relief, VEIN_RAISE, VEIN_HEIGHT), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell)


if __name__ == "__main__":
    print(build())
