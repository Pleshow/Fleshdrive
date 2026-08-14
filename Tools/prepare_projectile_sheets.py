from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def normalize_sheet(source: str, target: str, frame_size: tuple[int, int], subject_size: tuple[int, int]) -> None:
    image = Image.open(ROOT / source).convert("RGBA")
    source_frame_width = image.width // 4
    output = Image.new("RGBA", (frame_size[0] * 4, frame_size[1]), (0, 0, 0, 0))
    for index in range(4):
        cell = image.crop((index * source_frame_width, 0, (index + 1) * source_frame_width, image.height))
        bbox = cell.getbbox()
        if bbox is None:
            continue
        subject = cell.crop(bbox)
        subject.thumbnail(subject_size, Image.Resampling.NEAREST)
        x = index * frame_size[0] + (frame_size[0] - subject.width) // 2
        y = (frame_size[1] - subject.height) // 2
        output.alpha_composite(subject, (x, y))
    output.save(ROOT / target)


normalize_sheet(
    "Assets/vfx/projectiles/fireball_autoattack_alpha.png",
    "Assets/vfx/projectiles/fireball_autoattack_sheet.png",
    (128, 96),
    (108, 64),
)
normalize_sheet(
    "Assets/vfx/projectiles/magma_spear_alpha.png",
    "Assets/vfx/projectiles/magma_spear_sheet.png",
    (192, 96),
    (174, 58),
)
