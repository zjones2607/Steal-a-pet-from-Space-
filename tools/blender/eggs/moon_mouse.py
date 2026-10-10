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
PEARL = (0.87, 0.88, 0.94)
HUE_SCALE, PATCH_SCALE = 0.8, 1.1                      # bigger numbers = smaller colour areas
FLASHES = [(0.40, (0.96, 0.62, 0.80)), (0.47, (0.74, 0.66, 0.98)), (0.55, (0.52, 0.86, 0.96)),
           (0.64, (0.97, 0.91, 0.78))]                  # pink, lilac, teal, a hint of pale gold (noise Fac clusters near 0.5)
FLASH_AMOUNT = 0.85                                    # how strongly the rainbow shows through the pearl
PATCH_EDGES = (0.43, 0.58)                             # noise range over which a flash fades in
NACRE = [(0.0, (0.97, 0.80, 0.88)), (0.25, (0.97, 0.95, 0.92)), (0.5, (0.80, 0.95, 0.91)),
         (0.75, (0.78, 0.85, 1.0)), (1.0, (0.97, 0.80, 0.88))]   # mother-of-pearl bands: pink, pearl, mint, periwinkle
NACRE_AMOUNT, NACRE_SCALE, NACRE_SWIRL = 0.35, 0.25, 4.0  # band strength, size (bands repeat ~20 x scale per stud) and waviness
NACRE_DETAIL = 0.3                                     # low keeps the bands smooth (no fine squiggles)
ROUGHNESS = 0.18                                       # satin, like the Rabbit's pearl
METALLIC = 0.3                                         # a little metal gives the pearly sheen
RIPPLE = 0.06                                          # faint surface ripple in the normal map


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    hue = ec.add(nt, "ShaderNodeTexNoise", Scale=HUE_SCALE, Detail=0.5, Vector=ec.coords(nt))
    patches = ec.add(nt, "ShaderNodeTexNoise", Scale=PATCH_SCALE, Detail=0.5, Vector=ec.coords(nt))
    amount = ec.ramp(nt, patches.outputs["Fac"], [(PATCH_EDGES[0], (0, 0, 0)), (PATCH_EDGES[1], (FLASH_AMOUNT,) * 3)])
    bands = ec.add(nt, "ShaderNodeTexWave", Scale=NACRE_SCALE, Distortion=NACRE_SWIRL, Detail=NACRE_DETAIL,
                   Vector=ec.coords(nt))
    pearl = ec.mix(nt, NACRE_AMOUNT, PEARL, ec.ramp(nt, bands.outputs["Fac"], NACRE))
    nt.links.new(ec.mix(nt, amount, pearl, ec.ramp(nt, hue.outputs["Fac"], FLASHES)), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = ROUGHNESS
    bsdf.inputs["Metallic"].default_value = METALLIC
    ripple = ec.add(nt, "ShaderNodeTexNoise", Scale=7.0, Detail=1.0, Vector=ec.coords(nt))
    nt.links.new(ec.bump(nt, ripple.outputs["Fac"], RIPPLE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell)


if __name__ == "__main__":
    print(build())
