"""Checks the exported Moon eggs in assets/eggs/, and what the owner asked of each egg's pattern.
Run headless from the repo root after building an egg:
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
    "moon_rabbit": [],
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


class RabbitBranches(unittest.TestCase):
    """The owner asked for branches that start from the bottom, spread outward, come to sharp points and
    never overlap."""

    @classmethod
    def setUpClass(cls):
        import moon_rabbit
        cls.rabbit = moon_rabbit
        cls.limbs = moon_rabbit.veins()                # [(points, widths)], one per limb
        cls.starts = {(round(p[0][0], 6), round(p[0][1], 6)) for p, _ in cls.limbs}
        cls.ends = {(round(p[-1][0], 6), round(p[-1][1], 6)) for p, _ in cls.limbs}

    def test_branches_start_from_the_bottom(self):
        trunks = [p for p, _ in self.limbs if (round(p[0][0], 6), round(p[0][1], 6)) not in self.ends]
        self.assertGreater(len(trunks), 1)
        self.assertTrue(all(p[0][1] < 0.06 for p in trunks))      # every trunk starts at the bottom tip
        self.assertGreater(max(v for p, _ in self.limbs for _, v in p), 0.7)   # and the branches climb high

    def test_branch_tips_are_sharp_points(self):
        tips = [w for p, w in self.limbs if (round(p[-1][0], 6), round(p[-1][1], 6)) not in self.starts]
        self.assertGreater(len(tips), 10)
        self.assertTrue(all(w[-1] == 0 for w in tips))

    def test_branches_never_touch(self):
        from mathutils.kdtree import KDTree
        shape = self.rabbit.SHAPE
        pts, owner, half = [], [], []
        for k, (points, widths) in enumerate(self.limbs):
            for (u0, v0), (u1, v1), w0, w1 in zip(points, points[1:], widths, widths[1:]):
                for t in (0.0, 0.5):
                    pts.append(shape.point(u0 + (u1 - u0) * t, v0 + (v1 - v0) * t)[0])
                    owner.append(k)
                    half.append((w0 + (w1 - w0) * t) / 2)
        forks = [(shape.point(*p[0])[0], self.rabbit.join_radius(w[0])) for p, w in self.limbs]

        def at_fork(p):                                # where limbs join, they meet by design
            return any((p - s).length < r for s, r in forks)

        tree = KDTree(len(pts))
        for i, p in enumerate(pts):
            tree.insert(p, i)
        tree.balance()
        widest = max(half)
        clashes = []
        for i, p in enumerate(pts):
            for _, j, d in tree.find_range(p, half[i] + widest):
                if owner[j] != owner[i] and d < half[i] + half[j] and not at_fork(p) and not at_fork(pts[j]):
                    clashes.append((owner[i], owner[j], round(d, 3)))
        self.assertEqual(clashes[:5], [])


if __name__ == "__main__":
    result = unittest.main(argv=["blender"], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
