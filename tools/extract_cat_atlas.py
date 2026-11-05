"""Extract the idle/walk cells of Leon's supplied atlas without repainting them.

The opaque checkerboard is removed using the cat's ink and colored pixels.
Enclosed light areas such as the coat are preserved, while exterior pale pixels
remain transparent. Requires Pillow. Run: python tools/extract_cat_atlas.py
"""
from collections import deque
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/cat_animation/atlas-original.png"
OUT = SOURCE.parent
# Crops stop before neighboring drawings and omit the section labels.
CELLS = {
    "idle": [(11, 40, 110, 179), (124, 40, 231, 179), (239, 40, 347, 179), (351, 40, 468, 179)],
    "walk": [(489, 40, 579, 179), (579, 40, 666, 179), (666, 40, 752, 179), (740, 40, 839, 179), (827, 40, 914, 179)],
}


def extract(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = im.crop(box).convert("RGB")
    w, h = crop.size
    pixels = crop.load()
    raw = Image.new("L", crop.size)
    mask = raw.load()
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            # Pale neutral checkerboard is outside the drawing.
            mask[x, y] = 255 if min(r, g, b) < 170 or max(r, g, b) - min(r, g, b) > 48 else 0
    # Expanding the mask here would attach pale checkerboard fragments to the cat.
    opaque = raw.load()
    # Some cells graze panel borders or an adjacent frame. Keep the cat only.
    seen = bytearray(w * h)
    largest: list[tuple[int, int]] = []
    for sy in range(h):
        for sx in range(w):
            if not opaque[sx, sy] or seen[sy * w + sx]:
                continue
            component = []
            pending = deque([(sx, sy)])
            seen[sy * w + sx] = 1
            while pending:
                x, y = pending.popleft()
                component.append((x, y))
                for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                    if 0 <= nx < w and 0 <= ny < h and opaque[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        pending.append((nx, ny))
            if len(component) > len(largest):
                largest = component
    shape = Image.new("L", crop.size)
    opaque = shape.load()
    for x, y in largest:
        opaque[x, y] = 255
    outside = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))
    while queue:
        x, y = queue.popleft()
        idx = y * w + x
        if outside[idx] or opaque[x, y]:
            continue
        outside[idx] = 1
        if x > 0: queue.append((x - 1, y))
        if x + 1 < w: queue.append((x + 1, y))
        if y > 0: queue.append((x, y - 1))
        if y + 1 < h: queue.append((x, y + 1))
    alpha = Image.new("L", crop.size)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            ap[x, y] = 255 if opaque[x, y] or not outside[y * w + x] else 0
    # Keep the sprite in a stable canvas so frames do not jump during playback.
    result = Image.new("RGBA", (128, 152), (0, 0, 0, 0))
    cutout = crop.convert("RGBA")
    cutout.putalpha(alpha)
    result.alpha_composite(cutout, ((128 - w) // 2, 152 - h))
    return result


def main() -> None:
    im = Image.open(SOURCE)
    for name, boxes in CELLS.items():
        for index, box in enumerate(boxes):
            extract(im, box).save(OUT / f"{name}_{index}.png")
    print("Extracted 4 idle and 5 walk frames to", OUT)


if __name__ == "__main__":
    main()
