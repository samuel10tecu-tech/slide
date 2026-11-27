#!/usr/bin/env python3
"""Google Play listing graphics for Slide.

Writes appstore/play/: icon-512.png (32-bit), feature-graphic.png (1024x500) and phone screenshots cropped to 9:18
from the emulator captures of the "Android screens" workflow (download them into build/screens-ci first).
Needs Pillow and macOS system fonts.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "appstore" / "play"
SCREENS = ROOT / "build" / "screens-ci"
ORDER = ["track", "map", "history", "day", "freestyle", "trick"]

NIGHT = (7, 21, 38)
DEEP = (18, 52, 76)
ACCENT = (126, 231, 255)
SNOW = (247, 251, 255)
MUTED = (197, 212, 228)


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    name = "Avenir Next.ttc"
    try:
        return ImageFont.truetype(f"/System/Library/Fonts/{name}", size, index=2 if bold else 0)
    except OSError:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", size)


def icon() -> None:
    source = Image.open(ROOT / "appstore" / "icon-1024.png").convert("RGBA")
    source.resize((512, 512), Image.LANCZOS).save(OUT / "icon-512.png")


def mountains(draw: ImageDraw.ImageDraw, width: int, height: int, top: int, color) -> None:
    h = height - top
    points = [(0, height), (0, top + h * 0.78), (width * 0.16, top + h * 0.46), (width * 0.28, top + h * 0.62),
              (width * 0.48, top + h * 0.18), (width * 0.64, top + h * 0.55), (width * 0.8, top + h * 0.32),
              (width, top + h * 0.7), (width, height)]
    draw.polygon(points, fill=color)


def feature_graphic() -> None:
    width, height = 1024, 500
    image = Image.new("RGB", (width, height), NIGHT)
    pixels = image.load()
    for y in range(height):
        t = y / (height - 1)
        row = tuple(int(NIGHT[i] + (DEEP[i] - NIGHT[i]) * t) for i in range(3))
        for x in range(width):
            pixels[x, y] = row
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    mountains(draw, width, height, 250, (255, 255, 255, 18))
    mountains(draw, width, height, 330, (255, 255, 255, 34))
    image = Image.alpha_composite(image.convert("RGBA"), overlay)

    logo = Image.open(ROOT / "appstore" / "icon-1024.png").convert("RGBA").resize((260, 260), Image.LANCZOS)
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 259, 259), radius=58, fill=255)
    image.paste(logo, (80, 120), mask)

    draw = ImageDraw.Draw(image)
    draw.text((390, 112), "SKI · SNOWBOARD · FREESTYLE", font=font(26), fill=ACCENT)
    draw.text((386, 150), "Slide", font=font(118), fill=SNOW)
    draw.text((390, 300), "Every run, on your phone.", font=font(40), fill=SNOW)
    draw.text((390, 352), "Speed, vertical, runs. No signal needed.", font=font(30, bold=False), fill=MUTED)
    image.convert("RGB").save(OUT / "feature-graphic.png")


def screenshots() -> None:
    for language in ("en", "fr"):
        folder = SCREENS / f"android-screens-{language}"
        if not folder.exists():
            continue
        target = OUT / "screenshots" / language
        target.mkdir(parents=True, exist_ok=True)
        for index, name in enumerate(ORDER, start=1):
            path = folder / f"{language}-{name}.png"
            if not path.exists():
                continue
            shot = Image.open(path).convert("RGB")
            w, h = shot.size
            # Google Play allows at most 2:1; trim the status bar and the gesture bar equally.
            keep = min(h, w * 2)
            top = (h - keep) // 2
            shot.crop((0, top, w, top + keep)).save(target / f"{index:02d}-{name}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    icon()
    feature_graphic()
    screenshots()
    for path in sorted(OUT.rglob("*.png")):
        with Image.open(path) as image:
            print(path.relative_to(ROOT), image.size, image.mode)


if __name__ == "__main__":
    main()
