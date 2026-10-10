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
    "moon_mouse": [],
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
