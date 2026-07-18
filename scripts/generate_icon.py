#!/usr/bin/env python3
"""Generate Budgets app icon — dark card with teal accent."""

from pathlib import Path

from PIL import Image, ImageDraw

DARK = (14, 14, 17)
CARD = (30, 30, 36)
TEAL = (42, 157, 143)
TEAL_LIGHT = (72, 187, 170)
NOTCH = (20, 20, 24)


def create_icon(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (*DARK, 255))
    draw = ImageDraw.Draw(image)

    margin = size * 0.14
    card_left = margin
    card_top = size * 0.22
    card_right = size - margin
    card_bottom = size * 0.78
    radius = size * 0.08

    draw.rounded_rectangle(
        [card_left, card_top, card_right, card_bottom],
        radius=radius,
        fill=(*CARD, 255),
        outline=(*TEAL, 255),
        width=max(2, size // 48),
    )

    notch_width = size * 0.22
    notch_height = size * 0.06
    notch_left = (size - notch_width) / 2
    notch_top = card_top - notch_height * 0.35
    draw.rounded_rectangle(
        [notch_left, notch_top, notch_left + notch_width, notch_top + notch_height],
        radius=notch_height / 2,
        fill=(*NOTCH, 255),
        outline=(*TEAL_LIGHT, 255),
        width=max(1, size // 96),
    )

    stripe_y = card_top + (card_bottom - card_top) * 0.55
    draw.line(
        [(card_left + size * 0.08, stripe_y), (card_right - size * 0.08, stripe_y)],
        fill=(*TEAL, 255),
        width=max(2, size // 40),
    )

    return image


def main() -> None:
    script_dir = Path(__file__).parent
    out_dir = script_dir.parent / "assets" / "icon"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "app_icon.png"
    create_icon(1024).save(out_path, "PNG")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
