#!/usr/bin/env python3
"""Draws the app icons (iPhone and Apple Watch) as flat PNGs.

A check on green and a cross on red, split on a diagonal. Purely geometric, so no
font licensing to worry about. App Store icons must be opaque RGB (no alpha).

    pip install pillow
    python3 scripts/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
SCALE = 4  # draw big, then downsample for smooth edges

GREEN = (22, 128, 67)
RED = (206, 58, 48)
WHITE = (255, 255, 255)


def thick_line(draw, points, width):
    """A polyline with round caps and joins."""
    draw.line(points, fill=WHITE, width=width, joint="curve")
    radius = width // 2
    for x, y in points:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=WHITE)


def icon(glyph_scale):
    size = SIZE * SCALE
    image = Image.new("RGB", (size, size), RED)
    draw = ImageDraw.Draw(image)

    # Green triangle over the top-left half.
    draw.polygon([(0, 0), (size, 0), (0, size)], fill=GREEN)

    center = size / 2
    stroke = int(size * 0.075 * glyph_scale)

    def at(dx, dy):
        return (center + dx * size * glyph_scale, center + dy * size * glyph_scale)

    # Check mark, top-left.
    thick_line(draw, [at(-0.30, -0.14), at(-0.20, -0.04), at(-0.02, -0.26)], stroke)
    # Cross, bottom-right.
    thick_line(draw, [at(0.06, 0.06), at(0.28, 0.28)], stroke)
    thick_line(draw, [at(0.28, 0.06), at(0.06, 0.28)], stroke)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    targets = {
        # The iPhone mask is a rounded square; glyphs can go close to the edges.
        ROOT / "YesNo/Assets.xcassets/AppIcon.appiconset/AppIcon.png": 1.0,
        # The watch mask is a circle; pull the glyphs in so nothing is clipped.
        ROOT / "YesNoWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png": 0.85,
    }
    for path, glyph_scale in targets.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        icon(glyph_scale).save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
