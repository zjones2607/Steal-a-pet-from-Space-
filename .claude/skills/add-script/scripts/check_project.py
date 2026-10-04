#!/usr/bin/env python3
"""Check default.project.json and src/ agree: every $path exists, every .luau file is mapped."""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[4]
project = json.loads((root / "default.project.json").read_text())

mapped = set()
errors = []


def walk(node, where):
    if not isinstance(node, dict):
        return
    path = node.get("$path")
    if path:
        mapped.add(pathlib.PurePosixPath(path).as_posix())
        if not (root / path).exists():
            errors.append(f"{where}: $path {path} does not exist")
    for name, child in node.items():
        if not name.startswith("$"):
            walk(child, f"{where}.{name}")


walk(project["tree"], "tree")

for file in sorted((root / "src").rglob("*.luau")):
    rel = file.relative_to(root).as_posix()
    if rel not in mapped and not any(rel.startswith(m + "/") for m in mapped):
        errors.append(f"{rel} is not listed in default.project.json (Rojo will not sync it)")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"OK: {len(mapped)} paths mapped, all present")
