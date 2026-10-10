"""Tests for egg_common. Run headless from the repo root:
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python tools/blender/eggs/test_egg_common.py
"""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh
import bpy
import numpy as np

import egg_common as ec


def pixels(img):
    """An image's pixels as a (height, width, 4) array, row 0 at the bottom."""
    a = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


class Shape(unittest.TestCase):
    def test_tips_and_width(self):
        s = ec.EggShape(height=3, width=0.74, pointiness=0.16)
        self.assertAlmostEqual(s.point(0, 0)[0].z, -1.5)
        self.assertAlmostEqual(s.point(0, 1)[0].z, 1.5)
        widest = max(range(1001), key=lambda i: s.radius(i / 1000)) / 1000
        self.assertLess(widest, 0.5)                                   # fattest below the middle
        self.assertAlmostEqual(2 * s.radius(widest), 3 * 0.74, delta=0.1)

    def test_front_is_minus_y_and_normals_point_out(self):
        s = ec.EggShape()
        p, _ = s.point(0, 0.5)
        self.assertLess(p.y, -1)
        self.assertAlmostEqual(p.x, 0, places=6)
        for u in (0, 0.13, 0.5, 0.77):
            for v in (0.01, 0.3, 0.5, 0.9, 0.99):
                p, n = s.point(u, v)
                self.assertAlmostEqual(n.length, 1, places=5)
                self.assertGreater(n.dot(p), 0)


class Mesh(unittest.TestCase):
    def test_shell_budget_size_and_uvs(self):
        scene = ec.new_egg_scene("tmesh")
        shell = ec.make_egg_mesh("tmesh", scene, ec.EggShape())
        self.assertEqual(shell.name, "tmesh_Shell")
        self.assertLessEqual(tris(shell), ec.TRI_TARGET)
        zs = [v.co.z for v in shell.data.vertices]
        self.assertAlmostEqual(max(zs), 1.5, places=4)
        self.assertAlmostEqual(min(zs), -1.5, places=4)
        uvs = np.empty(len(shell.data.loops) * 2)
        shell.data.uv_layers[0].data.foreach_get("uv", uvs)
        self.assertGreaterEqual(uvs.min(), 0)
        self.assertLessEqual(uvs.max(), 1)

    def test_shell_is_closed_and_faces_outward(self):
        scene = ec.new_egg_scene("tclosed")
        shell = ec.make_egg_mesh("tclosed", scene, ec.EggShape())
        bm = bmesh.new()
        bm.from_mesh(shell.data)
        self.assertTrue(all(e.is_manifold for e in bm.edges))
        self.assertTrue(all(f.normal.dot(f.calc_center_median()) > 0 for f in bm.faces))
        bm.free()


class Scenes(unittest.TestCase):
    def test_rebuild_replaces_only_its_own_data(self):
        s = ec.EggShape()
        for _ in range(2):
            scene = ec.new_egg_scene("trebuild")
            ec.make_egg_mesh("trebuild", scene, s)
            ec.paint_strokes("trebuild", "veins", s, [([(0, 0.2), (0, 0.8)], 0.05)], size=64)
        self.assertEqual([x.name for x in bpy.data.scenes if x.name.startswith("egg_trebuild")], ["egg_trebuild"])
        self.assertEqual([o.name for o in bpy.data.scenes["egg_trebuild"].objects], ["trebuild_Shell"])
        for blocks in (bpy.data.objects, bpy.data.meshes, bpy.data.images):
            self.assertEqual([b.name for b in blocks if b.name.startswith("trebuild") and "." in b.name], [])
        self.assertIn("Cube", bpy.data.scenes["Scene"].objects)       # the owner's things are untouched
        self.assertIn("Material", bpy.data.materials)


class Decals(unittest.TestCase):
    def test_dots_and_strips_sit_just_above_the_surface(self):
        s = ec.EggShape()
        scene = ec.new_egg_scene("tdecal")
        dots = ec.make_dots("tdecal", scene, "Glow_A", s, [(0, 0.5, 0.05), (0.3, 0.8, 0.03)], lift=0.012)
        strips = ec.make_strips("tdecal", scene, "Glow_B", s, [[(-0.1, 0.4), (0.1, 0.6)]], width=0.03, lift=0.012)
        self.assertEqual(dots.name, "tdecal_Glow_A")
        self.assertEqual(tris(dots), 2 * 6)
        for obj in (dots, strips):
            for vert in obj.data.vertices:
                p = vert.co
                gap = math.hypot(p.x, p.y) - s.radius(p.z / 3 + 0.5)
                self.assertGreater(gap, 0)
                self.assertLess(gap, 0.03)
            for poly in obj.data.polygons:
                self.assertGreater(poly.normal.dot(poly.center), 0)

    def test_join_into_merges_and_removes(self):
        s = ec.EggShape()
        scene = ec.new_egg_scene("tjoin")
        a = ec.make_strips("tjoin", scene, "Glow_A", s, [[(0, 0.4), (0, 0.6)]])
        b = ec.make_dots("tjoin", scene, "Glow_B", s, [(0.2, 0.5, 0.05)])
        before = tris(a) + tris(b)
        ec.join_into(a, b)
        self.assertEqual(tris(a), before)
        self.assertEqual([o.name for o in scene.objects], ["tjoin_Glow_A"])
        self.assertNotIn("tjoin_Glow_B", bpy.data.meshes)


class Masks(unittest.TestCase):
    def test_strokes_paint_lines_and_wrap_the_back_seam(self):
        s = ec.EggShape()
        img = ec.paint_strokes("tmask", "a", s, [([(0, 0.2), (0, 0.8)], 0.3), ([(0.45, 0.5), (0.55, 0.5)], 0.3)], size=256)
        px = pixels(img)[..., 0]
        self.assertGreater(px[128, 128], 0.95)       # the front line (texture x 0.5 is the front)
        self.assertLess(px[128, 64], 0.01)           # a quarter turn away: blank
        self.assertGreater(px[128, 2], 0.9)          # the line across the back seam shows at both edges
        self.assertGreater(px[128, 253], 0.9)
        self.assertEqual(img.colorspace_settings.name, "Non-Color")

    def test_mask_image_from_function(self):
        img = ec.mask_image("tmask", "b", lambda u, v: (np.abs(u) < 0.1) * 1.0, size=64)
        px = pixels(img)[..., 0]
        self.assertAlmostEqual(px[32, 32], 1.0, places=2)
        self.assertAlmostEqual(px[32, 0], 0.0, places=2)
        self.assertEqual(img.name, "tmask_mask_b")


if __name__ == "__main__":
    result = unittest.main(argv=["blender"], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
