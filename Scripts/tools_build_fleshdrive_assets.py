"""Build production Fleshdrive assets from generated source sheets.

This is intentionally deterministic: generated art supplies the visual design,
while this script enforces exact Godot atlas sizes, transparency and card text.
"""

from __future__ import annotations

import colorsys
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
SOURCE = ASSETS / "_generated_source"
FONT_BOLD = ASSETS / "fonts" / "PixeloidSans-Bold.ttf"
FONT_MONO = ASSETS / "fonts" / "PixeloidMono.ttf"
CARD_SIZE = (1024, 1536)


def ensure_dirs() -> None:
    for relative in (
        "ui/fleshdrives",
        "ui/weapons/fire",
        "ui/weapons/electric",
        "ui/items/fire",
        "ui/organs/fire",
        "vfx/fleshdrive",
        "player/fire",
    ):
        (ASSETS / relative).mkdir(parents=True, exist_ok=True)


def fit_rgba(image: Image.Image, size: tuple[int, int], pad: int = 0) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 28 else 0).getbbox()
    if bbox:
        image = image.crop(bbox)
    target = (max(size[0] - pad * 2, 1), max(size[1] - pad * 2, 1))
    image.thumbnail(target, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size)
    result.alpha_composite(
        image,
        ((size[0] - image.width) // 2, (size[1] - image.height) // 2),
    )
    return result


def remove_generated_magenta(image: Image.Image) -> Image.Image:
    """Key variable hot-pink while preserving orange/red fire pixels."""
    source = image.convert("RGBA")
    result = Image.new("RGBA", source.size)
    src = source.load()
    dst = result.load()
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, original_alpha = src[x, y]
            magenta_strength = min(r, b) - g
            if r > 145 and b > 118 and magenta_strength > 54:
                # The generated background varies across a wide pink range.
                # A short soft ramp keeps pixel-art edge coverage intact.
                alpha = int(
                    255
                    * max(
                        0.0,
                        min(1.0, (92.0 - magenta_strength) / 30.0),
                    )
                )
                dst[x, y] = (r, min(g, max(r, b) // 3), b, min(alpha, original_alpha))
            else:
                dst[x, y] = (r, g, b, original_alpha)
    return result


def split_icon_sheet() -> list[Image.Image]:
    sheet = remove_generated_magenta(
        Image.open(SOURCE / "fleshdrive_icons_key.png")
    )
    cell_w = sheet.width // 4
    cell_h = sheet.height // 2
    result: list[Image.Image] = []
    for index in range(7):
        col = index % 4
        row = index // 4
        cell = sheet.crop(
            (col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)
        )
        result.append(fit_rgba(cell, (512, 512), 34))
    return result


def draw_card(
    output_path: Path,
    title: str,
    description: str,
    art: Image.Image,
    accent: tuple[int, int, int],
    category: str,
) -> None:
    random.seed(title)
    image = Image.new("RGBA", CARD_SIZE, (28, 21, 24, 255))
    pixels = image.load()
    for y in range(image.height):
        tone = int(118 + 12 * (1.0 - y / image.height))
        for x in range(image.width):
            noise = random.randint(-8, 8)
            pixels[x, y] = (
                max(0, tone + 26 + noise),
                max(0, tone + 4 + noise),
                max(0, tone - 2 + noise),
                255,
            )

    draw = ImageDraw.Draw(image)
    dark = (25, 22, 25, 255)
    rust = (63, 43, 43, 255)
    accent_rgba = (*accent, 255)
    parchment = (177, 139, 119, 244)

    # Layered biomechanical frame.
    draw.rounded_rectangle((16, 16, 1008, 1520), 34, fill=dark, outline=(6, 8, 10), width=12)
    draw.rounded_rectangle((42, 42, 982, 1494), 28, fill=parchment, outline=rust, width=18)
    draw.rounded_rectangle((66, 66, 958, 1470), 22, outline=accent_rgba, width=6)
    for y in (78, 1418):
        draw.line((96, y, 928, y), fill=dark, width=18)
        for x in range(116, 920, 82):
            draw.ellipse((x, y - 10, x + 20, y + 10), fill=rust, outline=accent_rgba, width=3)

    draw.rounded_rectangle((120, 112, 904, 270), 30, fill=(38, 31, 34, 245), outline=accent_rgba, width=5)
    title_font = ImageFont.truetype(str(FONT_BOLD), 64)
    small_font = ImageFont.truetype(str(FONT_MONO), 31)
    desc_font = ImageFont.truetype(str(FONT_BOLD), 34)
    category_font = ImageFont.truetype(str(FONT_BOLD), 42)

    title_box = draw.textbbox((0, 0), title, font=title_font)
    title_x = (1024 - (title_box[2] - title_box[0])) // 2
    draw.text((title_x + 3, 147), title, font=title_font, fill=(0, 0, 0), stroke_width=2)
    draw.text((title_x, 144), title, font=title_font, fill=(245, 232, 214), stroke_width=1, stroke_fill=dark)

    art_panel = Image.new("RGBA", (760, 790), (0, 0, 0, 0))
    art_fit = fit_rgba(art, art_panel.size, 54)
    art_panel.alpha_composite(art_fit)
    image.alpha_composite(art_panel, (132, 292))
    draw.rounded_rectangle((112, 282, 912, 1092), 26, outline=dark, width=12)
    draw.rounded_rectangle((122, 292, 902, 1082), 22, outline=accent_rgba, width=4)

    draw.rounded_rectangle((116, 1112, 908, 1328), 24, fill=(202, 166, 142, 242), outline=dark, width=9)
    words = description.split()
    lines: list[str] = []
    line = ""
    for word in words:
        candidate = f"{line} {word}".strip()
        if draw.textlength(candidate, font=desc_font) > 704 and line:
            lines.append(line)
            line = word
        else:
            line = candidate
    if line:
        lines.append(line)
    total_h = len(lines) * 48
    for idx, line in enumerate(lines):
        line_w = draw.textlength(line, font=desc_font)
        draw.text(
            ((1024 - line_w) / 2, 1180 - total_h / 2 + idx * 48),
            line,
            font=desc_font,
            fill=(24, 20, 22),
        )

    category_w = draw.textlength(category, font=category_font)
    draw.text(
        ((1024 - category_w) / 2, 1372),
        category,
        font=category_font,
        fill=dark,
    )
    draw.text((78, 88), "FLESHDRIVE", font=small_font, fill=accent_rgba)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)


def build_icons_and_cards() -> None:
    icons = split_icon_sheet()
    icons[0].resize((256, 256), Image.Resampling.LANCZOS).save(
        ASSETS / "ui/fleshdrives/electric_core.png"
    )
    icons[1].resize((256, 256), Image.Resampling.LANCZOS).save(
        ASSETS / "ui/fleshdrives/fire_core.png"
    )

    fire_weapons = [
        ("cinder_volley", "CINDER VOLLEY", "Barbed embers ignite several targets.", icons[2]),
        ("blazing_stride", "BLAZING STRIDE", "Your dash leaves a burning trail.", icons[3]),
        ("inferno_ring", "INFERNO RING", "A close ring of fire controls the horde.", icons[4]),
        ("magma_spear", "MAGMA SPEAR", "A slow molten spear pierces and burns.", icons[5]),
        ("ashen_eruption", "ASHEN ERUPTION", "Burning enemies erupt into spreading ash.", icons[6]),
    ]
    for file_name, title, description, art in fire_weapons:
        draw_card(
            ASSETS / f"ui/weapons/fire/{file_name}.png",
            title,
            description,
            art,
            (242, 82, 28),
            "PYRE WEAPON",
        )

    fire_support = [
        ("thermal_lattice", "THERMAL LATTICE", "Burns last longer and deal more damage.", icons[4], "ITEM"),
        ("cauterizing_blood", "CAUTERIZING BLOOD", "Fire kills periodically restore health.", icons[1], "ITEM"),
        ("flashpoint_nodes", "FLASHPOINT NODES", "Burning deaths trigger violent explosions.", icons[6], "ITEM"),
    ]
    for file_name, title, description, art, category in fire_support:
        draw_card(
            ASSETS / f"ui/items/fire/{file_name}.png",
            title,
            description,
            art,
            (242, 82, 28),
            category,
        )
    draw_card(
        ASSETS / "ui/organs/fire/combustion_sac.png",
        "COMBUSTION SAC",
        "Unlocks stacking burns and combustion.",
        icons[1],
        (242, 82, 28),
        "HEART ORGAN",
    )

    electric_sources = [
        ("ion_quill", "ION QUILL", "Charged quills arc into several targets.", "01_quill_burst.png"),
        ("shock_ram", "SHOCK RAM", "Dash impacts discharge chain lightning.", "02_shock_ram.png"),
        ("tesla_lash", "TESLA LASH", "An electrified tail sweep repels the horde.", "03_tail_lash.png"),
        ("arc_spear", "ARC SPEAR", "A piercing lightning spear overloads targets.", "04_arc_spear.png"),
        ("volt_shard_volley", "VOLT SHARD VOLLEY", "Conductive shards fan out in a wide cone.", "05_bone_shard_volley.png"),
    ]
    for file_name, title, description, source_name in electric_sources:
        source = Image.open(ASSETS / "ui/weapons" / source_name).convert("RGBA")
        art = source.crop((150, 320, 874, 1060))
        draw_card(
            ASSETS / f"ui/weapons/electric/{file_name}.png",
            title,
            description,
            art,
            (28, 194, 240),
            "VOLTAIC WEAPON",
        )


def build_atlases() -> None:
    fire_vfx = Image.open(SOURCE / "fire_vfx_alpha.png").convert("RGBA")
    fire_vfx = fire_vfx.resize((1024, 1024), Image.Resampling.LANCZOS)
    vfx_pixels = fire_vfx.load()
    for boundary in (0, 255, 256, 511, 512, 767, 768, 1023):
        for offset in (-1, 0, 1):
            coordinate = boundary + offset
            if 0 <= coordinate < 1024:
                for other in range(1024):
                    vfx_pixels[coordinate, other] = (0, 0, 0, 0)
                    vfx_pixels[other, coordinate] = (0, 0, 0, 0)
    fire_vfx.save(
        ASSETS / "vfx/fleshdrive/fire_combat_vfx_atlas.png"
    )
    projectiles = Image.open(SOURCE / "fire_projectiles_alpha.png").convert("RGBA")
    projectiles.resize((512, 512), Image.Resampling.LANCZOS).save(
        ASSETS / "vfx/fleshdrive/fire_projectiles_atlas.png"
    )


def fire_recolor(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    result = Image.new("RGBA", source.size)
    src_pixels = source.load()
    dst_pixels = result.load()
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, a = src_pixels[x, y]
            if a == 0:
                dst_pixels[x, y] = (r, g, b, a)
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            is_implant_blue = 0.43 <= h <= 0.64 and s >= 0.22 and v >= 0.18
            if is_implant_blue:
                new_h = 0.035 if v > 0.68 else 0.985
                new_s = min(1.0, max(0.68, s * 1.18))
                new_v = min(1.0, v * 1.14 + 0.05)
                nr, ng, nb = colorsys.hsv_to_rgb(new_h, new_s, new_v)
                dst_pixels[x, y] = (
                    int(nr * 255),
                    int(ng * 255),
                    int(nb * 255),
                    a,
                )
            else:
                dst_pixels[x, y] = (r, g, b, a)
    return result


def build_fire_koda() -> None:
    sheets = (
        "koda_run_4dir_12f.png",
        "koda_idle_8dir.png",
        "koda_jump_8dir.png",
        "koda_attack_8dir.png",
        "koda_hurt_8dir.png",
        "koda_death_8dir.png",
    )
    for name in sheets:
        image = Image.open(ASSETS / "player" / name)
        fire_recolor(image).save(ASSETS / "player/fire" / name)


def main() -> None:
    ensure_dirs()
    build_icons_and_cards()
    build_atlases()
    build_fire_koda()
    print("Fleshdrive assets built.")


if __name__ == "__main__":
    main()
