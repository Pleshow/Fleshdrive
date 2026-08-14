"""Normalize the generated Mimichu concept grid into a Godot-ready atlas."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets" / "ui" / "mimichu_animation_keyed.png"
OUTPUT = ROOT / "Assets" / "ui" / "mimichu_animation_atlas.png"
CELL_SIZE = 320
COLUMNS = 4
ROWS = 2


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    source_cell_width = source.width // COLUMNS
    source_cell_height = source.height // ROWS
    atlas = Image.new(
        "RGBA",
        (CELL_SIZE * COLUMNS, CELL_SIZE * ROWS),
        (0, 0, 0, 0),
    )

    for row in range(ROWS):
        for column in range(COLUMNS):
            left = column * source_cell_width
            top = row * source_cell_height
            cell = source.crop(
                (
                    left,
                    top,
                    left + source_cell_width,
                    top + source_cell_height,
                )
            )
            cell = cell.resize(
                (CELL_SIZE, CELL_SIZE),
                Image.Resampling.LANCZOS,
            )
            atlas.alpha_composite(
                cell,
                (column * CELL_SIZE, row * CELL_SIZE),
            )

    atlas.save(OUTPUT, optimize=True)
    print(f"Wrote {OUTPUT} ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
    main()
