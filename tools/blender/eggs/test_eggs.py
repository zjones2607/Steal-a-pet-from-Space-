"""Checks the exported Moon eggs in assets/eggs/, and what the owner asked of each egg's pattern.
Run headless from the repo root after building an egg:
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_eggs.py
"""
import math
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
    "luna_moth": ["Glow_FlowerHearts"],
    "lunar_wolf": ["Glow_Stars", "Glow_Orbits", "Glow_Sun", "Glass"],
    "eclipse_phoenix": ["Glow_Embers"],
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


class MothWings(unittest.TestCase):
    """The owner asked for both wings to wrap round like a bat's (no moth body), dark stems at the wing ends,
    and the flowers in the art."""

    @classmethod
    def setUpClass(cls):
        import luna_moth
        cls.moth = luna_moth
        cls.scene = bpy.data.scenes.new("check_moth")
        with bpy.context.temp_override(scene=cls.scene, view_layer=cls.scene.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=os.path.join(ec.ASSETS, "luna_moth", "luna_moth.fbx"))

    def piece(self, name):
        return next(o for o in self.scene.objects if o.name.startswith("luna_moth_" + name))

    @staticmethod
    def apart(a, b):
        """Turns between two places round the egg."""
        d = (a - b) % 1
        return min(d, 1 - d)

    def test_both_wings_start_together_and_wrap_round_to_meet(self):
        m = self.moth
        for v in (0.2, 0.5, 0.8):
            tips = []
            for front in (True, False):
                self.assertLess(self.apart(m.wing_u(front, 0.0, v), m.BASE_U), 0.05)       # bases together
                tips.append(m.wing_u(front, 1.0, v))
                self.assertGreater(self.apart(tips[-1], m.BASE_U), 0.1)                    # wrapped well round
            self.assertLess(self.apart(*tips), m.OVERLAP + m.SCALLOP_DEPTH + 1e-6)         # the tips meet
            self.assertLess(self.apart(m.wing_u(True, 0.5, v), 0.0), 0.25)                 # one round the front
            self.assertLess(self.apart(m.wing_u(False, 0.5, v), 0.5), 0.25)                # one round the back

    def test_no_moth_body_just_wings(self):
        m = self.moth
        shell = self.piece("Shell")
        me, (x0, y0, x1, y1) = shell.data, m.STEM_RECT
        uvs = me.uv_layers[0].data
        stem = {me.loops[li].vertex_index for poly in me.polygons for li in poly.loop_indices   # the owner's stem
                if x0 <= uvs[li].uv[0] < x1 and y0 <= uvs[li].uv[1] < y1}                     # runs down this line
        pts = [shell.matrix_world @ vert.co for vert in me.vertices if vert.index not in stem]

        def tallest(u0, v0):
            """How far out the shell reaches straight above the egg point (u0, v0), however proud it stands."""
            out = 0.0
            for p in pts:
                u, v = math.atan2(p.x, -p.y) / (2 * math.pi), p.z / m.HEIGHT + 0.5
                if abs((u - u0 + 0.5) % 1 - 0.5) < 0.04 and abs(v - v0) < 0.05:
                    out = max(out, math.hypot(p.x, p.y) - m.SHAPE.radius(v))
            return out

        # where the body used to cling, nothing stands prouder than the wing a little further round. A body
        # stood about 0.19 prouder; plain wing reads within about 0.05 (finish() re-centring shifts the egg a
        # few hundredths of a stud, which tilts this side-by-side comparison slightly).
        self.assertLess(tallest(m.BASE_U, 0.76) - tallest(m.BASE_U + 0.1, 0.76), 0.1)

    def test_a_dark_stem_runs_down_the_line_where_the_wings_meet(self):
        m = self.moth
        self.assertLess(max(m.STEM_DARK), 0.06)            # sorta black
        path = m.stem_path()
        for u, _, _ in path:
            self.assertLess(self.apart(u, m.BASE_U), 0.01)  # right down the line
        self.assertGreater(path[0][1], 0.8)                 # from up by the wing tops
        self.assertLess(path[-1][1], 0.15)                  # down to the bottom
        self.assertEqual((path[0][2], path[-1][2]), (0, 0))  # pointed at both ends
        self.assertGreater(max(w for _, _, w in path), 0.05)

    def test_three_flowers_with_glowing_hearts(self):
        self.assertEqual(len(self.moth.FLOWERS), 3)
        hearts = self.piece("Glow_FlowerHearts")
        parent = list(range(len(hearts.data.vertices)))

        def root(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i

        for edge in hearts.data.edges:
            a, b = (root(i) for i in edge.vertices)
            parent[a] = b
        self.assertEqual(len({root(i) for i in range(len(parent))}), 3)            # one glowing heart per flower


class WolfWindow(unittest.TestCase):
    """The owner asked for the star system, planets and constellations to show parallax: real layers at
    different depths behind the glass, so what you see shifts with the viewing angle."""

    @classmethod
    def setUpClass(cls):
        import lunar_wolf
        cls.wolf = lunar_wolf
        cls.scene = bpy.data.scenes.new("check_wolf")
        with bpy.context.temp_override(scene=cls.scene, view_layer=cls.scene.view_layers[0]):
            bpy.ops.import_scene.fbx(filepath=os.path.join(ec.ASSETS, "lunar_wolf", "lunar_wolf.fbx"))

    def piece(self, name):
        return next(o for o in self.scene.objects if o.name.startswith("lunar_wolf_" + name))

    def depth(self, points):
        """Average studs below the egg's surface (negative: above it)."""
        shape = self.wolf.SHAPE
        return sum(shape.radius(p.z / self.wolf.HEIGHT + 0.5) - math.hypot(p.x, p.y) for p in points) / len(points)

    def points(self, name):
        obj = self.piece(name)
        return [obj.matrix_world @ v.co for v in obj.data.vertices]

    def test_layers_sit_at_different_depths_behind_the_glass(self):
        shell = self.piece("Shell")
        me, (x0, y0, x1, y1) = shell.data, self.wolf.BOWL_RECT
        uvs, cx, cy = me.uv_layers[0].data, (x0 + x1) / 2, (y0 + y1) / 2
        floor = {me.loops[li].vertex_index for poly in me.polygons for li in poly.loop_indices   # middle of the
                 if math.hypot(uvs[li].uv[0] - cx, uvs[li].uv[1] - cy) < (x1 - x0) * 0.15}      # backdrop bowl
        layers = [self.depth(self.points(name)) for name in ("Glass", "Glow_Stars", "Glow_Orbits", "Glow_Sun")]
        layers.append(self.depth([shell.matrix_world @ me.vertices[i].co for i in floor]))
        self.assertLess(layers[0], 0.03)                       # the glass sits at the surface
        for shallower, deeper in zip(layers, layers[1:]):
            self.assertGreater(deeper - shallower, 0.05, layers)  # each layer clearly deeper than the last


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
