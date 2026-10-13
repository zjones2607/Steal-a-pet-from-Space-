"""Rebuild every Moon egg (each build exports its own files to assets/eggs/<id>/) and save them all, one
scene each, into assets/eggs/moon_eggs.blend, so they can be opened together in Blender.

Run in Blender: runpy.run_path(r"<repo>/tools/blender/eggs/build_all.py", run_name="__main__")
or headless:    blender --background --factory-startup --python tools/blender/eggs/build_all.py
"""
import importlib
import os
import runpy
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import egg_common as ec  # noqa: E402

importlib.reload(ec)

EGGS = ["moon_mouse", "moon_rabbit", "luna_moth", "lunar_wolf", "eclipse_phoenix"]


def build_all():
    for egg in EGGS:
        runpy.run_path(os.path.join(HERE, egg + ".py"), run_name="__main__")
    path = os.path.join(ec.ASSETS, "moon_eggs.blend")
    bpy.data.libraries.write(path, {bpy.data.scenes["egg_" + egg] for egg in EGGS}, path_remap="RELATIVE_ALL",
                             compress=True)
    return path


if __name__ == "__main__":
    print(build_all())
