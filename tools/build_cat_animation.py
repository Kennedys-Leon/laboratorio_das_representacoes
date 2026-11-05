"""Bake the generated turn key poses into 60 aligned frames.

Requires Pillow, numpy and opencv-python-headless. Run from any directory.
The source art stays untouched; alpha is preserved throughout interpolation.
"""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/cat_animation/v8"
SIZE = (128, 152)
FRAMES = 60


def normalize(cell):
    alpha = np.asarray(cell.getchannel("A"))
    ys, xs = np.nonzero(alpha > 64)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    cropped = cell.crop(box)
    scale = 132 / cropped.height
    cropped = cropped.resize((round(cropped.width * scale), 132), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", SIZE)
    # Align the head, rather than the tail, so the torso does not slide sideways.
    a = np.asarray(cropped.getchannel("A"))
    hy, hx = np.nonzero(a[:70] > 96)
    head_center = (int(hx.min()) + int(hx.max())) * 0.5
    offset_x = round(73 - head_center)
    result.alpha_composite(cropped, (offset_x, 18))
    return result


def premultiplied(image):
    a = np.asarray(image).astype(np.float32) / 255
    a[:, :, :3] *= a[:, :, 3:4]
    return a


def guide(a):
    # Alpha makes the dark silhouette visible to the optical-flow estimator.
    grey = cv2.cvtColor(a[:, :, :3], cv2.COLOR_RGB2GRAY)
    return np.uint8(np.clip((grey * 0.65 + a[:, :, 3] * 0.35) * 255, 0, 255))


def flow_pair(a, b):
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    dis.setFinestScale(0)
    return dis.calc(guide(a), guide(b), None)


def tween(a, b, forward, backward, weight):
    yy, xx = np.mgrid[:a.shape[0], :a.shape[1]].astype(np.float32)
    wa = cv2.remap(a, xx - forward[:, :, 0] * weight,
                   yy - forward[:, :, 1] * weight, cv2.INTER_LINEAR,
                   borderMode=cv2.BORDER_CONSTANT)
    wb = cv2.remap(b, xx - backward[:, :, 0] * (1 - weight),
                   yy - backward[:, :, 1] * (1 - weight), cv2.INTER_LINEAR,
                   borderMode=cv2.BORDER_CONSTANT)
    result = wa * (1 - weight) + wb * weight
    result[:, :, :3] /= np.maximum(result[:, :, 3:4], 1e-6)
    return Image.fromarray(np.uint8(np.clip(result * 255, 0, 255)))


def main():
    source = Image.open(OUT / "keyposes.png").convert("RGBA")
    keys = []
    for i in range(8):
        col, row = i % 4, i // 4
        box = (round(col * source.width / 4), round(row * source.height / 4),
               round((col + 1) * source.width / 4), round((row + 1) * source.height / 4))
        keys.append(normalize(source.crop(box)))
    keys[0].save(OUT / "idle.png")
    keys[-1].save(OUT / "standing.png")
    # The walking rig now samples this exact drawing, including both original paws.
    # Never replace the endpoint with a separately generated leg design.
    normalized = Image.new("RGBA", (SIZE[0] * 8, SIZE[1]))
    for i, key in enumerate(keys):
        normalized.paste(key, (i * SIZE[0], 0))
    normalized.save(OUT / "turn-keyposes.png")
    rgba = [premultiplied(k.resize((SIZE[0] * 2, SIZE[1] * 2), Image.Resampling.LANCZOS)) for k in keys]
    flows = [(flow_pair(a, b), flow_pair(b, a)) for a, b in zip(rgba, rgba[1:])]
    atlas = Image.new("RGBA", (SIZE[0] * 10, SIZE[1] * 6))
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        phase = (t * t * t * (t * (t * 6 - 15) + 10)) * (len(keys) - 1)
        segment = min(int(phase), len(keys) - 2)
        weight = phase - segment
        frame = tween(rgba[segment], rgba[segment + 1], *flows[segment], weight).resize(SIZE, Image.Resampling.LANCZOS)
        if i == 0: frame = keys[0]
        if i == FRAMES - 1: frame = keys[-1]
        atlas.paste(frame, ((i % 10) * SIZE[0], (i // 10) * SIZE[1]))
        frames.append(frame)
    atlas.save(OUT / "turn-60.png")
    frames[0].save(OUT / "idle.png")
    (OUT / "animation.json").write_text(json.dumps({
        "turn_frames": FRAMES, "turn_fps": 60, "frame_size": SIZE,
        "columns": 10, "ground_y": 150, "silhouette_height": 132,
        "method": "premultiplied-alpha bidirectional optical flow between 8 key poses; feet rendered by runtime rig",
        "walk": "rigid original paws, articulated upper legs, world-space support"
    }, indent=2) + "\n")
    print("Baked 60 turn frames; idle and standing endpoints match exactly")


if __name__ == "__main__":
    main()
