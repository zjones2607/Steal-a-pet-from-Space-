# Moon eggs in Blender: design

## Goal

Model the five eggs from the "Collected from the Moon egg" artwork in Blender, one at a time, ready to
import into Roblox. This spec covers the Blender models only. Bringing them into the game (upload,
effects, which egg shows where) is a separate design that comes next.

| Id | Name | Rarity |
|----|------|--------|
| `moon_mouse` | Moon Mouse | Common |
| `moon_rabbit` | Moon Rabbit | Uncommon |
| `luna_moth` | Luna Moth | Rare |
| `lunar_wolf` | Lunar Wolf | Epic |
| `eclipse_phoenix` | Eclipse Phoenix | Legendary |

## Decisions

- **Egg only.** No nests, crystals, rocks, moon discs or eclipse rings: the pen already builds its own
  nests. The rings, ribbons, planets, fireflies and flames in the artwork become Roblox effects later.
  (Exception the owner asked for: the flowers sitting on the Luna Moth egg are modeled.)
- **Faithful to the art**, not the game's Part-built cartoon style.
- **Approach: full textures plus Neon glow pieces.** Each egg's look is baked into PBR images for a
  Roblox `SurfaceAppearance`; anything that glows is a separate untextured piece set to Neon in Roblox.

## Shared rules (every egg)

- **Size:** the whole egg, all pieces included, is 3 units tall (1 Blender unit = 1 stud, matching
  `PenEggs`' `EGG_HEIGHT = 3`), pivot at its centre. Each script has a `HEIGHT` constant at the top; in Roblox the Model's Scale resizes it.
- **Pieces** (named `<id>_Shell`, `<id>_Glow_*`, since names must be unique within a Blender file):
  - `Shell`: one textured mesh.
  - `Glow_*`: zero or more small untextured meshes, set to Neon (and their colour) in Roblox.
  - `Glass` (Lunar Wolf only): a clear cover, set to Glass with some transparency in Roblox.
- **Triangle budget:** about 2,000 per egg; hard cap 4,000 (all pieces together). Detail lives in the
  normal map, not the geometry. The build refuses to export over the cap.
- **Textures** (Shell only): `<id>_color.png` and `<id>_normal.png` at 1024 px, `<id>_roughness.png` and
  `<id>_metalness.png` at 512 px. Looks are made with Blender shader nodes, then baked with Cycles.
- **Roblox settings to use later:** `RenderFidelity = Automatic` on every MeshPart.
- **Roblox limits to respect:** no iridescent shader, so rainbow sheen is painted into the colour map;
  a MeshPart has one Material, which is why glows are separate pieces.

## Files

- `tools/blender/eggs/egg_common.py`: shared helpers (egg shape, UVs, bake, checks, export).
- `tools/blender/eggs/<id>.py`: one build script per egg. Re-running it rebuilds that egg exactly.
- `assets/eggs/<id>/`: `<id>.fbx` (import this into Roblox; textures embedded so one file carries
  everything), the four PNGs, and `<id>.blend` (links the PNGs by relative path, nothing packed).

No effect-anchor markers are exported: the Roblox effects design places effects from the egg's size
and centre.

## The eggs

The artwork only shows fronts; patterns continue around the back in the same style.

1. **Moon Mouse (Common).** A classic smooth egg. Pearly white with soft pastel rainbow flashes (pink,
   lilac, teal, a touch of gold), very glossy with a slight metallic sheen. No glow pieces.
   *Later effects:* thin blue energy rings circling it, sparkles.
2. **Moon Rabbit (Uncommon).** A slightly taller egg in frosted, milky pale-blue crystal, with raised
   white frost veins branching up from the bottom like a tree. No glow pieces.
   *Later effects:* swirling gold ribbons, crystal glints.
3. **Luna Moth (Rare).** *(Revised with the owner while building.)* Two luna moth wings wrapped round the
   egg like a bat's, with no moth body. They start together on the front left, where a dark, spotted stem
   runs down the line they meet along, and wrap round the front and the back to meet on a scalloped seam
   that runs diagonally from the top centre to the lower right. Sage green, with veins fanning out from the
   stem, light margins with a row of pale spots, and a glowing yellow eyespot on each wing. Three
   star-shaped purple flowers (real 3D petals) sit on the wings as in the artwork. Glow piece:
   `Glow_FlowerHearts` (the flowers' hearts). About 3,400 triangles, since the wings and petals are real
   shapes. *Later effects:* fireflies, drifting purple petals.
4. **Lunar Wolf (Epic).** *(Revised with the owner: real parallax.)* A dark slate stone egg with a large
   oval porthole on the front in an ornate gold frame, with round medallions at its top and bottom (the
   artwork's frame is gold). The star chart behind the glass is built in real layers at different depths,
   so it shifts with the viewing angle in Roblox with no scripts: constellations just under the glass,
   orbit rings and planets deeper, the sun deeper still, and a star-dusted backdrop bowl at the bottom.
   Pieces: `Shell` (stone, frame, medallions, backdrop bowl and planets, all textured), `Glow_Stars`
   (constellations), `Glow_Orbits` (orbit rings), `Glow_Sun`, and `Glass` (the cover; Glass material in
   Roblox). *Later effects:* a pale moon glow behind it, twinkling, and a soft blue PointLight inside the
   porthole so the backdrop glows like the art.
5. **Eclipse Phoenix (Legendary).** A glossy black, obsidian-like egg with raised gold filigree whose
   swirls form a phoenix with spread wings across the front. Glow piece `Glow_Embers`: red-orange cracks
   and eyes glowing through the black.
   *Later effects:* orbiting planets, the fiery eclipse ring, rising embers.

## Build and check (per egg)

1. Run the egg's script in the user's open Blender. It switches to Cycles only for baking, then back.
2. Checks before showing the user, any failure stops the script with a clear message and no export:
   - Renders from the front, three-quarter and back, compared with that egg's crop of the artwork.
   - Triangle count within budget (about 2,000, cap 4,000).
   - Height 3 units, pivot at the centre.
   - All four PNGs exist at the right sizes.
   - The exported FBX re-imports into an empty scene with its Shell, Glow pieces and textures.
3. Show the user the renders; tweak and re-run until they approve.
4. Commit the approved egg, then start the next: Mouse, Rabbit, Moth, Wolf, Phoenix.

## Git

Work on branch `moon-eggs-blender` from `main`; one PR merged to `main` at the end. The owner then
pulls in GitHub Desktop (Fetch origin, Pull origin).
