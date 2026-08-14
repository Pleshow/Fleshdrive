# PixelLab Map for Godot 4

Import this ZIP from Godot Project Manager, or extract it and open `project.godot`.
Buildings exports place every download in a uniquely named editable scene. If you
extract a refreshed ZIP into the same project, the previous Buildings scene is
kept and the project opens the newly imported scene; replacing an edited scene is
therefore always an explicit choice.
The main scene creates a transparent TileMapLayer palette for every legacy top-down,
square, isometric, hex, and oblique layer, plus a renderer that follows the
painted cells with PixelLab's exact projection coordinates. Select a TileMapLayer
and use Godot's TileMap dock to paint. Use the dock's Terrains mode for connected
terrain painting; direct tile painting also keeps the exported edge/corner rules
connected. Projected stacks are separate paint layers. They are labeled
`Y0 - GROUND - ...`, `Y1 - ELEVATED +1 - ...`, and so on. The bundled
`PixelLab Stack Paint` editor plugin automatically selects the highest existing
Y layer under the cursor before Godot paints, so a tile lands on the visible
surface instead of silently going onto Y0. Ctrl+click targets the next stack
level when that layer exists. On an empty area, select the explicit Y layer you
want in the Scene tree first. Save the scene to persist your edits.
Maps without exportable tile placements use the pixel-perfect base image as a
compatibility fallback.

Gameplay annotation cells and rectangles are merged by role. Blockers export as
one `StaticBody2D`; triggers, walkable regions, and data regions export as one
`Area2D`. Their exact occupied geometry is preserved with merged
`CollisionPolygon2D` shapes, including disconnected pieces and holes.

The complete PixelLab source bundle and projection metadata remain under
`pixellab/source`.
