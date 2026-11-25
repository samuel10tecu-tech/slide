#!/usr/bin/env python3
"""Compose App Store previews from the demo day (Les Crosets). Not a simulator capture."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SIZES = {
    "6.7-inch": (1290, 2796),
    "6.5-inch": (1242, 2688),
}
BG = (7, 21, 38)
SURF = (14, 36, 54)
ACCENT = (126, 231, 255)
SNOW = (247, 251, 255)
GREEN = (61, 220, 106)
BLUE = (76, 141, 255)
RED = (255, 77, 94)
MUTED = (197, 212, 228)
INK = (7, 21, 38)

def font(size, bold=False):
    path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    return ImageFont.truetype(path, size)

def mountains(draw, w, h, top):
    draw.polygon([(0, h), (0, top + 80), (int(w * 0.18), top), (int(w * 0.32), top + 70),
                  (int(w * 0.5), top - 40), (int(w * 0.68), top + 50), (int(w * 0.84), top + 10),
                  (w, top + 90), (w, h)], fill=(18, 48, 72))

def card(draw, box, fill=SURF):
    draw.rounded_rectangle(box, radius=28, fill=fill)

def screen_live(draw, w, h):
    draw.rectangle((0, 0, w, h), fill=BG)
    mountains(draw, w, int(h * 0.42), int(h * 0.22))
    draw.text((64, 120), "SLIDE", font=font(36, True), fill=ACCENT)
    draw.text((64, 170), "Les Crosets", font=font(54, True), fill=SNOW)
    cx, cy, r = w // 2, int(h * 0.46), int(w * 0.34)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 40), width=22)
    draw.arc((cx - r, cy - r, cx + r, cy + r), start=120, end=330, fill=ACCENT, width=22)
    draw.text((cx, cy - 20), "67.4", font=font(120, True), fill=SNOW, anchor="mm")
    draw.text((cx, cy + 90), "km/h", font=font(40, True), fill=SNOW, anchor="mm")
    stats = [("Max", "74.2"), ("Distance", "18.6 km"), ("Vertical", "4 280 m"), ("Time", "2:14")]
    gap = 24
    bw = (w - 80 - gap) // 2
    y = int(h * 0.68)
    for i, (label, value) in enumerate(stats):
        x = 40 + (i % 2) * (bw + gap)
        yy = y + (i // 2) * 170
        card(draw, (x, yy, x + bw, yy + 150))
        draw.text((x + 28, yy + 28), label, font=font(28), fill=MUTED)
        draw.text((x + 28, yy + 72), value, font=font(42, True), fill=SNOW)

def screen_map(draw, w, h):
    draw.rectangle((0, 0, w, h), fill=(18, 52, 74))
    for i in range(8):
        draw.arc((-200 + i * 40, 200, w + 200, h), start=200, end=340, fill=(30, 80, 110), width=8)
    draw.text((64, 120), "Where you skied", font=font(58, True), fill=SNOW)
    pins = [(int(w * 0.32), int(h * 0.38), None), (int(w * 0.62), int(h * 0.48), "3"), (int(w * 0.48), int(h * 0.66), None)]
    for x, y, count in pins:
        rad = 36 if count else 26
        draw.ellipse((x - rad, y - rad, x + rad, y + rad), fill=INK, outline=ACCENT, width=6)
        label = count or "▲"
        draw.text((x, y), label, font=font(32, True), fill=ACCENT if not count else SNOW, anchor="mm")

def screen_day(draw, w, h):
    draw.rectangle((0, 0, w, h), fill=BG)
    mountains(draw, w, int(h * 0.28), int(h * 0.16))
    draw.text((64, 130), "Les Crosets", font=font(64, True), fill=SNOW)
    draw.text((64, 210), "4 runs  ·  18.6 km  ·  4 280 m", font=font(34), fill=MUTED)
    rows = [("Run 1", "3.8 km", "74 km/h", GREEN), ("Run 2", "5.1 km", "68 km/h", BLUE),
            ("Run 3", "6.4 km", "71 km/h", RED), ("Run 4", "3.3 km", "62 km/h", (255, 225, 74))]
    y = 320
    for name, dist, speed, color in rows:
        card(draw, (48, y, w - 48, y + 180))
        draw.rounded_rectangle((68, y + 30, 84, y + 150), radius=6, fill=color)
        draw.text((110, y + 36), name, font=font(40, True), fill=SNOW)
        draw.text((110, y + 96), dist, font=font(32), fill=MUTED)
        draw.text((w - 80, y + 70), speed, font=font(40, True), fill=color, anchor="rm")
        y += 200

def screen_learn(draw, w, h):
    draw.rectangle((0, 0, w, h), fill=BG)
    draw.text((64, 130), "Learn", font=font(68, True), fill=SNOW)
    draw.text((64, 220), "6 / 26 checked", font=font(36), fill=MUTED)
    blocks = [("Beginner", GREEN, "Ollie"), ("Park", BLUE, "360"), ("Advanced", RED, "Backflip  ·  coach")]
    y = 340
    for title, color, trick in blocks:
        draw.rounded_rectangle((64, y, 80, y + 48), radius=4, fill=color)
        draw.text((100, y), title, font=font(42, True), fill=SNOW)
        y += 80
        card(draw, (48, y, w - 48, y + 140))
        draw.text((80, y + 42), trick, font=font(40, True), fill=SNOW)
        y += 180

SCREENS = [
    ("01-live", screen_live),
    ("02-map", screen_map),
    ("03-day", screen_day),
    ("04-learn", screen_learn),
]

def main():
    for folder, (w, h) in SIZES.items():
        out = ROOT / "screenshots" / folder
        out.mkdir(parents=True, exist_ok=True)
        for name, painter in SCREENS:
            image = Image.new("RGB", (w, h), BG)
            painter(ImageDraw.Draw(image), w, h)
            image.save(out / f"{name}.png", "PNG")
            print(folder, name, w, h)

if __name__ == "__main__":
    main()
