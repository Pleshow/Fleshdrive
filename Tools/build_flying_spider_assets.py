from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "Assets" / "enemies" / "spitter"


def build_enemy_atlas() -> None:
    source_path = ASSET_DIR / "flying_spider_keyed.png"
    output_path = ASSET_DIR / "flying_spider_atlas.png"
    source = Image.open(source_path).convert("RGBA")
    atlas = build_uniform_grid(
        source,
        columns=4,
        rows=3,
        frame_size=256,
        maximum_subject_size=(220, 210),
    )
    atlas.save(output_path)


def build_projectile_atlas() -> None:
    source_path = ASSET_DIR / "flying_spider_projectile_keyed.png"
    output_path = ASSET_DIR / "flying_spider_projectile_atlas.png"
    source = Image.open(source_path).convert("RGBA")
    atlas = build_uniform_grid(
        source,
        columns=4,
        rows=1,
        frame_size=128,
        maximum_subject_size=(112, 82),
    )
    atlas.save(output_path)


def build_uniform_grid(
    source: Image.Image,
    columns: int,
    rows: int,
    frame_size: int,
    maximum_subject_size: tuple[int, int],
) -> Image.Image:
    subjects: list[Image.Image] = []
    subject_sizes: list[tuple[int, int]] = []
    for row in range(rows):
        top = round(row * source.height / rows)
        bottom = round((row + 1) * source.height / rows)
        for column in range(columns):
            left = round(column * source.width / columns)
            right = round((column + 1) * source.width / columns)
            cell = source.crop((left, top, right, bottom))
            bounds = cell.getchannel("A").getbbox()
            if bounds is None:
                raise RuntimeError(
                    f"Source contains an empty frame at {column}, {row}."
                )
            subject = cell.crop(bounds)
            subjects.append(subject)
            subject_sizes.append(subject.size)

    maximum_width = max(size[0] for size in subject_sizes)
    maximum_height = max(size[1] for size in subject_sizes)
    scale = min(
        maximum_subject_size[0] / maximum_width,
        maximum_subject_size[1] / maximum_height,
    )
    atlas = Image.new(
        "RGBA",
        (columns * frame_size, rows * frame_size),
        (0, 0, 0, 0),
    )
    for frame_index, subject in enumerate(subjects):
        width = max(round(subject.width * scale), 1)
        height = max(round(subject.height * scale), 1)
        resized = subject.resize((width, height), Image.Resampling.LANCZOS)
        column = frame_index % columns
        row = frame_index // columns
        destination_x = column * frame_size + (frame_size - width) // 2
        destination_y = row * frame_size + (frame_size - height) // 2
        atlas.alpha_composite(resized, (destination_x, destination_y))
    return atlas


def validate_atlas(
    path: Path,
    columns: int,
    rows: int,
    frame_size: int,
) -> None:
    image = Image.open(path).convert("RGBA")
    expected_size = (columns * frame_size, rows * frame_size)
    if image.size != expected_size:
        raise RuntimeError(
            f"{path.name}: expected {expected_size}, got {image.size}"
        )
    alpha = image.getchannel("A")
    for row in range(rows):
        for column in range(columns):
            frame = alpha.crop(
                (
                    column * frame_size,
                    row * frame_size,
                    (column + 1) * frame_size,
                    (row + 1) * frame_size,
                )
            )
            bounds = frame.getbbox()
            if bounds is None:
                raise RuntimeError(
                    f"{path.name}: empty frame at {column}, {row}"
                )
            if (
                bounds[0] <= 1
                or bounds[1] <= 1
                or bounds[2] >= frame_size - 1
                or bounds[3] >= frame_size - 1
            ):
                raise RuntimeError(
                    f"{path.name}: frame content touches edge at "
                    f"{column}, {row}: {bounds}"
                )


if __name__ == "__main__":
    build_enemy_atlas()
    build_projectile_atlas()
    validate_atlas(
        ASSET_DIR / "flying_spider_atlas.png",
        4,
        3,
        256,
    )
    validate_atlas(
        ASSET_DIR / "flying_spider_projectile_atlas.png",
        4,
        1,
        128,
    )
    print("Flying spider atlases built and validated.")
