"""Isolate the standing paws visible below the table in Leon's newer atlas."""

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/cat_animation/potion_mix/atlas-standing-reference.png"
OUTPUT = ROOT / "assets/cat_animation/potion_mix/standing_legs.png"
FRAME = 7  # Eighth pose: clear, grounded paws under the tabletop.
CROP = (100, 248, 205, 281)


def main() -> None:
    atlas = Image.open(SOURCE).convert("RGB")
    width, height = atlas.size
    col, row = FRAME % 6, FRAME // 6
    tile = atlas.crop((
        round(col * width / 6), round(row * height / 3),
        round((col + 1) * width / 6), round((row + 1) * height / 3),
    ))
    pixels = tile.load()
    selected = set()
    for y in range(256, 283):
        for x in range(105, 196):
            red, green, blue = pixels[x, y]
            if blue > green * 1.12 and blue >= red * 0.8 and red < 90:
                selected.add((x, y))
    groups = []
    while selected:
        seed = selected.pop()
        group = {seed}
        pending = deque((seed,))
        while pending:
            x, y = pending.popleft()
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in selected:
                    selected.remove(neighbor)
                    group.add(neighbor)
                    pending.append(neighbor)
        groups.append(group)
    feet = sorted(groups, key=len, reverse=True)[:2]
    assert len(feet) == 2 and all(len(group) > 350 for group in feet)
    mask = Image.new("L", tile.size)
    for group in feet:
        for point in group:
            mask.putpixel(point, 255)
    # Keep the ink fine, with antialiasing instead of a chunky expanded outline.
    mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.4))
    result = Image.new("RGBA", (CROP[2] - CROP[0], CROP[3] - CROP[1]))
    for y in range(CROP[1], CROP[3]):
        for x in range(CROP[0], CROP[2]):
            alpha = mask.getpixel((x, y))
            if not alpha:
                continue
            red, green, blue = pixels[x, y]
            if red > 20 and red > blue * 1.4:
                red, green, blue = (15, 8, 23)
            elif blue > 18 and blue > red:
                # Match the violet fur in the upper-body sprite, preserving toes.
                red, green, blue = min(255, red + 7), min(255, green + 4), min(255, blue + 10)
            result.putpixel((x - CROP[0], y - CROP[1]), (red, green, blue, alpha))
    # Extend only the shanks behind the apron; keep the toes at their original
    # proportions. The feet now reach the same floor plane as the rear supports.
    extended = Image.new("RGBA", (result.width, result.height + 5))
    extended.alpha_composite(result, (0, 5))
    shank = result.crop((0, 9, result.width, 10))
    for y in range(0, 15):
        extended.paste(shank, (0, y))
    extended.save(OUTPUT)
    print(f"Extracted two standing paws into {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
