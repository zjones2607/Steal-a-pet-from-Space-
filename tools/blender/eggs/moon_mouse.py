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
FLASHES = [(0.40, (0.96, 0.62, 0.80)), (0.47, (0.74, 0.66, 0.98)), (0.53, (0.52, 0.86, 0.96)),
           (0.60, (0.98, 0.84, 0.52))]                  # pink, lilac, teal, gold (noise Fac clusters near 0.5)
FLASH_AMOUNT = 0.85                                    # how strongly the rainbow shows through the pearl
PATCH_EDGES = (0.43, 0.58)                             # noise range over which a flash fades in
ROUGHNESS = 0.12
METALLIC = 0.25
RIPPLE = 0.06                                          # faint surface ripple in the normal map


def build():
    scene = ec.new_egg_scene(ID)
    ec.add_preview_rig(ID, scene)
    shell = ec.make_egg_mesh(ID, scene, SHAPE)
    mat, nt, bsdf = ec.lookdev_material(ID)
    hue = ec.add(nt, "ShaderNodeTexNoise", Scale=HUE_SCALE, Detail=0.5, Vector=ec.coords(nt))
    patches = ec.add(nt, "ShaderNodeTexNoise", Scale=PATCH_SCALE, Detail=0.5, Vector=ec.coords(nt))
    amount = ec.ramp(nt, patches.outputs["Fac"], [(PATCH_EDGES[0], (0, 0, 0)), (PATCH_EDGES[1], (FLASH_AMOUNT,) * 3)])
    nt.links.new(ec.mix(nt, amount, PEARL, ec.ramp(nt, hue.outputs["Fac"], FLASHES)), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = ROUGHNESS
    bsdf.inputs["Metallic"].default_value = METALLIC
    ripple = ec.add(nt, "ShaderNodeTexNoise", Scale=7.0, Detail=1.0, Vector=ec.coords(nt))
    nt.links.new(ec.bump(nt, ripple.outputs["Fac"], RIPPLE), bsdf.inputs["Normal"])
    shell.data.materials.append(mat)
    return ec.finish(ID, scene, SHAPE, shell)


if __name__ == "__main__":
    print(build())
