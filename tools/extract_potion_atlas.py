"""Extract the 18 supplied potion poses into aligned transparent Godot sprites."""

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets/cat_animation/potion_mix/atlas-original.png"
OUTPUT = ATLAS.parent
COLS, ROWS = 6, 3
SIZE = (272, 273)
def repair_coat(frame: Image.Image) -> Image.Image:
    """Restore the cat's torso and stitch the coat inside this animation pose."""
    patch = Image.new("RGBA", (SIZE[0] * 4, SIZE[1] * 4))
    draw = ImageDraw.Draw(patch)
    # The dark torso vanishes with the atlas's black backdrop during extraction.
    # Repaint it INSIDE each sprite, under its original arms, lapels and beaker.
    # The white coat itself is still the supplied drawing, not a runtime layer.
    torso = [
        (114, 138), (160, 138), (180, 154), (184, 174),
        (176, 205), (98, 205), (91, 174), (95, 154),
    ]
    draw.polygon([(x * 4, y * 4) for x, y in torso], fill=(30, 18, 42, 255))
    draw.polygon([(x * 4, y * 4) for x, y in [
        (116, 143), (157, 143), (174, 159), (174, 197),
        (102, 197), (101, 159),
    ]], fill=(43, 24, 58, 255))
    # Keep the original white coat and every original contour in front of the
    # restored dark torso. The table hides the original lower coat hem.
    repaired = patch.resize(SIZE, Image.Resampling.LANCZOS)
    repaired.alpha_composite(frame)
    return repaired


def connect_celebration_sleeves(frame: Image.Image, number: int) -> Image.Image:
    """Join each moving glove to the actual cuff in its own pose."""
    backing = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(backing)
    # The raised arm exposes a strip of background between the head and the
    # sleeve in the atlas. Fill it with the same dark fur as the shoulder.
    shoulders = (
        ([(75, 141), (99, 139), (111, 150), (93, 153), (76, 151)],
         [(202, 140), (215, 145), (220, 154), (205, 157), (188, 150)])
        if number == 16 else
        ([(74, 127), (100, 134), (112, 147), (91, 148), (74, 142)],
         [(198, 134), (218, 128), (220, 142), (203, 150), (184, 147)])
    )
    for points in shoulders:
        draw.polygon(points, fill=(31, 18, 44, 255))
    cuffs = (
        ([(75, 151), (80, 142), (87, 146), (86, 160), (78, 168), (72, 164)],
         [(207, 150), (214, 144), (221, 149), (222, 161), (215, 169), (207, 162)])
        if number == 16 else
        ([(66, 141), (79, 127), (87, 131), (86, 148), (75, 161), (65, 160)],
         [(207, 130), (215, 129), (224, 142), (224, 154), (216, 157), (207, 143)])
    )
    for points in cuffs:
        draw.polygon(points, fill=(14, 8, 22, 255))
        draw.polygon(points[1:-1], fill=(43, 24, 58, 255))
    backing.alpha_composite(frame)
    return backing


def separate_celebration_beaker(frame: Image.Image, lower: Image.Image) -> Image.Image:
    """Give the final pose a complete glass whose rim can stay on the table."""
    glass = Image.new("RGBA", SIZE)
    rim_mask = Image.new("1", SIZE)
    ImageDraw.Draw(rim_mask).polygon(
        [(106, 192), (170, 192), (179, 196), (185, 201),
         (185, 207), (179, 213), (99, 213), (94, 207),
         (94, 201), (98, 196)],
        fill=1,
    )
    for y in range(192, 214):
        for x in range(94, 186):
            if rim_mask.getpixel((x, y)):
                glass.putpixel((x, y), frame.getpixel((x, y)))
                frame.putpixel((x, y), (0, 0, 0, 0))
    glass.alpha_composite(lower)
    return glass


def separate_beaker(frame: Image.Image) -> Image.Image:
    """Move the glass front ahead of the table without grabbing coat panels."""
    layer = Image.new("RGBA", SIZE)
    for y in range(205, 268):
        left = 94 if y < 214 else 103
        right = 191 if y < 214 else 186
        for x in range(left, right):
            color = frame.getpixel((x, y))
            if color[3]:
                layer.putpixel((x, y), color)
                frame.putpixel((x, y), (0, 0, 0, 0))
    # The atlas has a separate dangling coat stroke immediately beside the
    # right glass wall. It must not be carried into the foreground vessel.
    for y in range(215, 245):
        for x in range(182, 186):
            layer.putpixel((x, y), (0, 0, 0, 0))
    return layer


def flask_pixels(frame: Image.Image, seed_x: int) -> set[tuple[int, int]]:
    """Find one disconnected bottle without cutting adjacent coat or whiskers."""
    pixels = frame.load()
    seed = next(
        (x, y) for y in range(205, 240) for x in range(seed_x - 8, seed_x + 9)
        if pixels[x, y][3] > 0
    )
    found = {seed}
    pending = deque((seed,))
    while pending:
        x, y = pending.popleft()
        for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            nx, ny = neighbor
            if 0 <= nx < SIZE[0] and 0 <= ny < SIZE[1] and neighbor not in found and pixels[nx, ny][3]:
                found.add(neighbor)
                pending.append(neighbor)
    assert len(found) > 2500, f"Bottle mask too small: {len(found)}"
    return found


def extract(source: Image.Image, number: int) -> Image.Image:
    column, row = number % COLS, number // COLS
    width, height = source.size
    left = round(column * width / COLS) + 12
    top = round(row * height / ROWS) + 11
    right = round((column + 1) * width / COLS) - 12
    bottom = round((row + 1) * height / ROWS) - 12
    tile = source.crop((left, top, right, bottom)).convert("RGBA")
    w, h = tile.size
    pixels = tile.load()

    # Flood only the dark backdrop connected to the tile's outside. Dark
    # details enclosed by the cat (eyes, glasses and coat seams) stay opaque.
    backdrop = bytearray(w * h)
    pending = deque()
    for x in range(w):
        pending.extend(((x, 0), (x, h - 1)))
    for y in range(h):
        pending.extend(((0, y), (w - 1, y)))
    while pending:
        x, y = pending.popleft()
        offset = y * w + x
        if backdrop[offset]:
            continue
        red, green, blue, _ = pixels[x, y]
        if max(red, green, blue) >= 35:
            continue
        backdrop[offset] = 1
        if x:
            pending.append((x - 1, y))
        if x + 1 < w:
            pending.append((x + 1, y))
        if y:
            pending.append((x, y - 1))
        if y + 1 < h:
            pending.append((x, y + 1))

    blocked = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            red, green, blue, _ = pixels[x, y]
            number_badge = x < 67 and y < 57
            frame_edge = x < 4 or x >= w - 4 or y < 4 or y >= h - 4
            frame_corner = (x < 22 or x >= w - 22) and (y < 22 or y >= h - 22)
            # The left bottle's lower outline occupies the atlas's rounded
            # bottom corner. Keep that actual artwork before isolating it.
            bottle_edge = 5 <= number < 16 and 12 <= x <= 80 and 185 <= y <= 263
            frame_corner = frame_corner and not bottle_edge
            # The brown horizontal strip belongs to the atlas, not the game.
            tabletop = (
                y > 225
                and red > green * 1.15
                and red > blue * 1.15
                and blue < 150
            )
            if number_badge or frame_edge or frame_corner or tabletop:
                blocked[y * w + x] = 1
            if backdrop[y * w + x] or blocked[y * w + x]:
                pixels[x, y] = (red, green, blue, 0)

    # Drop isolated antialias and frame remnants; keep the cat, glassware,
    # liquid glints and the small decorative reaction marks.
    visited = bytearray(w * h)
    for start_y in range(h):
        for start_x in range(w):
            index = start_y * w + start_x
            if visited[index] or pixels[start_x, start_y][3] == 0:
                continue
            group = []
            queue = deque(((start_x, start_y),))
            visited[index] = 1
            while queue:
                x, y = queue.popleft()
                group.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        neighbor = ny * w + nx
                        if not visited[neighbor] and pixels[nx, ny][3]:
                            visited[neighbor] = 1
                            queue.append((nx, ny))
            if len(group) < 35:
                for x, y in group:
                    red, green, blue, _ = pixels[x, y]
                    pixels[x, y] = (red, green, blue, 0)

    # Restore one dark ink pixel beside solid artwork. The flood-fill removes
    # the black backdrop but also some connected black contour and coat seams.
    solid = bytearray(pixels[x, y][3] > 0 for y in range(h) for x in range(w))
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            index = y * w + x
            if solid[index] or blocked[index]:
                continue
            red, green, blue, _ = pixels[x, y]
            if max(red, green, blue) > 65:
                continue
            neighbors = sum(
                solid[(y + dy) * w + x + dx]
                for dy in (-1, 0, 1)
                for dx in (-1, 0, 1)
                if dx or dy
            )
            if neighbors >= 2:
                pixels[x, y] = (red, green, blue, 220)

    canvas = Image.new("RGBA", SIZE)
    canvas.alpha_composite(tile, ((SIZE[0] - w) // 2, (SIZE[1] - h) // 2))
    # All vessels touch the same virtual floor across the pour/stir boundary.
    bounds = canvas.getbbox()
    if bounds is not None and bounds[3] != 267:
        aligned = Image.new("RGBA", SIZE)
        aligned.alpha_composite(canvas, (0, 267 - bounds[3]))
        return aligned
    return canvas


def main() -> None:
    source = Image.open(ATLAS).convert("RGB")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    frames = [extract(source, number) for number in range(COLS * ROWS)]
    # Once the empty bottles reach the table (pose 6), they stay in one fixed
    # layer. The cat and the beaker may sway without dragging the bottles.
    fixed = Image.new("RGBA", SIZE)
    # The right bottle touches the atlas crop and loses its outer lower edge.
    # Both empty bottles share the same art, so rebuild that one from the
    # complete left bottle at the right bottle's original position.
    left_bottle = flask_pixels(frames[5], 40)
    for x, y in left_bottle:
        color = frames[5].getpixel((x, y))
        fixed.putpixel((x, y), color)
        fixed.putpixel((x + 195, y), color)
    for seed_x in (40, 235):
        for frame in frames[5:16]:
            for point in flask_pixels(frame, seed_x):
                frame.putpixel(point, (0, 0, 0, 0))
    fixed.save(OUTPUT / "table_flasks.png")
    # The old atlas included orange tabletop pixels in the vessel's side rim.
    # Recolor only those side outlines; the central orange stirrer stays intact.
    for frame in frames:
        for y in range(190, 232):
            for x in list(range(80, 120)) + list(range(170, 205)):
                r, g, b, a = frame.getpixel((x, y))
                if a and r > g * 1.22 and r > b * 1.25 and b < 150:
                    frame.putpixel((x, y), (43, 27, 60, a))

    beakers = [separate_beaker(frame) for frame in frames]
    # The source draws a loose lavender coat triangle beside the right rim.
    # Once the table is drawn it reads as a second piece of the moving glass.
    for frame in frames[6:16]:
        for y in range(210, 222):
            for x in range(185, 197):
                frame.putpixel((x, y), (0, 0, 0, 0))
    for glass in beakers[6:16]:
        for y in range(209, 215):
            for x in range(182, 191):
                glass.putpixel((x, y), (0, 0, 0, 0))
    celebration_glass = separate_celebration_beaker(frames[17], beakers[17])
    celebration_glass.save(OUTPUT / "celebration_beaker.png")
    for number in range(COLS * ROWS):
        beakers[number].save(OUTPUT / f"beaker_{number + 1:02d}.png")
        repaired = repair_coat(frames[number])
        if number >= 16:
            repaired = connect_celebration_sleeves(repaired, number)
        if 5 <= number <= 15:
            # A thin detached reaction stroke from the atlas sits beside the
            # right coat panel during mixing. It is not part of the cat.
            for y in range(183, 239):
                for x in range(201, 231):
                    repaired.putpixel((x, y), (0, 0, 0, 0))
        repaired.save(OUTPUT / f"frame_{number + 1:02d}.png")
    print(f"Extracted {COLS * ROWS} potion frames and stationary table flasks")


if __name__ == "__main__":
    main()
