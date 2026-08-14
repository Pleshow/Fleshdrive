"""Build deterministic game-ready Telekinetic assets from ImageGen sources.

The source sheets are intentionally retained under Assets/generated_sources so
the derived card art and VFX can be reproduced without another generation.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import colorsys


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
FONT_BOLD = ASSETS / "fonts" / "PixeloidSans-Bold.ttf"
FONT_REGULAR = ASSETS / "fonts" / "PixeloidSans.ttf"

CARD_DEFINITIONS = [
    (
        "kinetic_shard",
        "KINETIC SHARD",
        "A focused psychic shard pierces the nearest target.",
        "TELEKINETIC WEAPON",
        "weapons",
    ),
    (
        "gravity_well",
        "GRAVITY WELL",
        "Compresses a crowd and drags enemies into its core.",
        "TELEKINETIC WEAPON",
        "weapons",
    ),
    (
        "repulse_wave",
        "REPULSE WAVE",
        "A defensive pulse damages and throws nearby enemies away.",
        "TELEKINETIC WEAPON",
        "weapons",
    ),
    (
        "orbiting_debris",
        "ORBITING DEBRIS",
        "Rusty laboratory fragments orbit Koda and grind through foes.",
        "TELEKINETIC WEAPON",
        "weapons",
    ),
    (
        "neural_lance",
        "NEURAL LANCE",
        "A slow, devastating lance pierces an entire enemy line.",
        "TELEKINETIC WEAPON",
        "weapons",
    ),
    (
        "projectile_reversal",
        "PROJECTILE REVERSAL",
        "Hostile projectiles are caught and redirected into nearby enemies.",
        "TELEKINETIC ORGAN",
        "organs",
    ),
]

SUPPORT_DEFINITIONS = [
    (
        "mass_amplifier",
        "MASS AMPLIFIER",
        "Pulled or pushed enemies take additional telekinetic damage.",
        "TELEKINETIC ITEM",
        "items",
        1,
    ),
    (
        "vector_cortex",
        "VECTOR CORTEX",
        "Reduces telekinetic weapon recovery and increases force.",
        "TELEKINETIC ITEM",
        "items",
        2,
    ),
    (
        "inertial_lattice",
        "INERTIAL LATTICE",
        "Orbiting debris grows faster and intercepts more threats.",
        "TELEKINETIC ITEM",
        "items",
        3,
    ),
]


def fit_icon(icon: Image.Image, size: tuple[int, int]) -> Image.Image:
    icon = icon.copy()
    bounds = icon.getbbox()
    if bounds:
        icon = icon.crop(bounds)
    icon.thumbnail(size, Image.Resampling.LANCZOS)
    return icon


def centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int],
) -> None:
    box = draw.textbbox((0, 0), text, font=font)
    x = (1024 - (box[2] - box[0])) // 2
    draw.text((x, y), text, font=font, fill=fill)


def wrap_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    max_width: int,
) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        width = draw.textbbox((0, 0), candidate, font=font)[2]
        if current and width > max_width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def build_card(icon: Image.Image, definition: tuple[str, ...]) -> Image.Image:
    _, title, description, footer, _ = definition
    card = Image.new("RGBA", (1024, 1536), (18, 14, 28, 255))
    draw = ImageDraw.Draw(card)
    violet = (172, 102, 255, 255)
    pale = (235, 222, 255, 255)
    muted = (184, 168, 205, 255)
    border = (55, 38, 70, 255)

    draw.rounded_rectangle((18, 18, 1006, 1518), 38, fill=border)
    draw.rounded_rectangle((40, 40, 984, 1496), 30, fill=(24, 19, 34, 255))
    draw.rounded_rectangle(
        (68, 68, 956, 1468), 24, outline=violet, width=6
    )
    draw.line((100, 278, 924, 278), fill=violet, width=5)
    draw.rounded_rectangle(
        (110, 315, 914, 1055),
        26,
        fill=(11, 9, 18, 255),
        outline=(105, 66, 139, 255),
        width=5,
    )
    draw.rounded_rectangle(
        (116, 1090, 908, 1325),
        24,
        fill=(35, 27, 45, 255),
        outline=(105, 66, 139, 255),
        width=5,
    )

    title_font = ImageFont.truetype(str(FONT_BOLD), 63)
    body_font = ImageFont.truetype(str(FONT_REGULAR), 35)
    footer_font = ImageFont.truetype(str(FONT_BOLD), 38)
    brand_font = ImageFont.truetype(str(FONT_REGULAR), 30)
    draw.text((82, 78), "FLESHDRIVE", font=brand_font, fill=violet)
    centered_text(draw, title, 160, title_font, pale)

    icon = fit_icon(icon, (620, 620))
    card.alpha_composite(
        icon,
        ((1024 - icon.width) // 2, 350 + (640 - icon.height) // 2),
    )

    lines = wrap_text(draw, description, body_font, 700)
    y = 1138
    for line in lines:
        centered_text(draw, line, y, body_font, muted)
        y += 48
    centered_text(draw, footer, 1382, footer_font, violet)
    return card


def recolor_koda(source: Image.Image) -> Image.Image:
    image = source.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # Convert cyan/blue implant glow to a violet psychic glow while
            # preserving highlights, sprite outlines, and Koda's fur.
            if 0.46 <= h <= 0.66 and s >= 0.30 and v >= 0.28:
                new_h = 0.755
                new_s = min(1.0, s * 0.86 + 0.16)
                new_v = min(1.0, v * 1.10)
                nr, ng, nb = colorsys.hsv_to_rgb(new_h, new_s, new_v)
                pixels[x, y] = (
                    round(nr * 255),
                    round(ng * 255),
                    round(nb * 255),
                    a,
                )
    return image


def main() -> None:
    generated = ASSETS / "generated_sources"
    core = Image.open(
        ASSETS / "ui" / "fleshdrives" / "telekinetic_core_source.png"
    ).convert("RGBA")
    core = fit_icon(core, (232, 232))
    core_canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    core_canvas.alpha_composite(
        core, ((256 - core.width) // 2, (256 - core.height) // 2)
    )
    core_canvas.save(
        ASSETS / "ui" / "fleshdrives" / "telekinetic_core.png"
    )

    atlas = Image.open(
        generated / "telekinetic_cards_alpha.png"
    ).convert("RGBA")
    cell_w = atlas.width // 3
    cell_h = atlas.height // 2
    for index, definition in enumerate(CARD_DEFINITIONS):
        col = index % 3
        row = index // 3
        icon = atlas.crop(
            (col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)
        )
        card = build_card(icon, definition)
        category = definition[4]
        output = (
            ASSETS
            / "ui"
            / category
            / "telekinetic"
            / f"{definition[0]}.png"
        )
        card.save(output)
    for definition in SUPPORT_DEFINITIONS:
        icon_index = definition[5]
        col = icon_index % 3
        row = icon_index // 3
        icon = atlas.crop(
            (col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)
        )
        card = build_card(icon, definition[:5])
        output = (
            ASSETS
            / "ui"
            / definition[4]
            / "telekinetic"
            / f"{definition[0]}.png"
        )
        card.save(output)

    vfx = Image.open(generated / "telekinetic_vfx_alpha.png").convert("RGBA")
    vfx = vfx.resize((1024, 1024), Image.Resampling.LANCZOS)
    vfx.save(
        ASSETS / "vfx" / "fleshdrive" / "telekinetic_combat_vfx_atlas.png"
    )

    source_map = {
        "koda_run_4dir_12f.png": "koda_run_4dir_12f.png",
        "koda_idle_8dir.png": "koda_idle_8dir.png",
        "koda_jump_8dir.png": "koda_jump_8dir.png",
        "koda_attack_8dir.png": "koda_attack_8dir.png",
        "koda_hurt_8dir.png": "koda_hurt_8dir.png",
        "koda_death_8dir.png": "koda_death_8dir.png",
    }
    telekinetic_dir = ASSETS / "player" / "telekinetic"
    for source_name, output_name in source_map.items():
        source = Image.open(ASSETS / "player" / source_name)
        recolor_koda(source).save(telekinetic_dir / output_name)


if __name__ == "__main__":
    main()
