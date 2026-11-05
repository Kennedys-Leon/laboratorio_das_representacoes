"""Make a complete transparent celebration cloud from storyboard panel 15."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/cat_animation/potion_mix/atlas-celebration-original.png"
DESTINATION = ROOT / "assets/cat_animation/potion_mix/success_cloud.png"


def main() -> None:
    atlas = Image.open(SOURCE).convert("RGB")
    width, height = atlas.size
    column, row = 2, 2  # Panel 15 has the full cloud inside its border.
    cell = atlas.crop((
        round(column * width / 6), round(row * height / 3),
        round((column + 1) * width / 6), round((row + 1) * height / 3),
    ))

    # The cat overlaps the bottom of the painted cloud in the storyboard.
    # Soft lobes complete its silhouette behind the original lettering.
    soft = Image.new("RGBA", cell.size)
    paint = ImageDraw.Draw(soft)
    for box, color in (
        ((75, 76, 119, 114), (171, 152, 244, 225)),
        ((98, 86, 146, 123), (244, 173, 232, 240)),
        ((129, 87, 177, 126), (255, 231, 157, 245)),
        ((164, 82, 214, 121), (164, 244, 202, 245)),
        ((204, 72, 248, 108), (159, 235, 242, 225)),
    ):
        paint.ellipse(box, fill=color)
    soft = soft.filter(ImageFilter.GaussianBlur(2.2))

    original = Image.new("RGBA", cell.size)
    for y in range(12, 138):
        for x in range(12, cell.width - 12):
            # Exclude the numbered badge and the white panel frame.
            if x < 82 and y < 68:
                continue
            red, green, blue = cell.getpixel((x, y))
            high, low = max(red, green, blue), min(red, green, blue)
            alpha = max(0, min(255, int((high - 45) * 7)))
            # The pale arcs beneath the cloud belong to the cat's eyes.
            if 88 < x < 216 and y > 100:
                alpha = int(alpha * max(0.0, (115 - y) / 15))
            if y > 119:
                alpha = int(alpha * max(0.0, (138 - y) / 19))
            if alpha:
                original.putpixel((x, y), (red, green, blue, alpha))

    soft.alpha_composite(original)
    cloud = soft.crop((20, 12, 278, 142)).resize((258, 130), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (272, 273))
    result.alpha_composite(cloud, (7, 0))
    result.save(DESTINATION)
    print("Extracted complete celebration cloud")


if __name__ == "__main__":
    main()
