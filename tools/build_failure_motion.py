"""Build 60 FPS, motion-compensated failure panels from the 18 full poses.

Run extract_failure_storyboard.py first. Requires Pillow, NumPy, OpenCV.
Each atlas holds 24 complete frames, keeping Godot's texture count small.
"""

from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/cat_animation/potion_mix/failure"
FPS = 60
DURATION = 4.0
TIMES = np.array([
    0.0, 0.30, 0.60, 0.90, 1.10, 1.25,
    1.40, 1.50, 1.70, 2.00, 2.40, 2.80,
    3.95, 4.30, 4.65,
]) * (DURATION / 4.8)
POSE_INDICES = list(range(12)) + [15, 16, 17]
IDLE_FRAMES = 120
WIDTH, HEIGHT = 279, 303
COLS, ROWS = 6, 4
FRAMES_PER_ATLAS = COLS * ROWS
FRAME_COUNT = round(DURATION * FPS)


def match_victory_style(rgba, index):
    """Reuse the victory glassware and match fur hues without altering reactions."""
    frame = Image.fromarray(rgba)
    original = rgba.copy()
    reference = np.array(Image.open(SOURCE.parent / 'frame_18.png').convert('RGBA'))
    # Match only purple fur: white coat, eyes, lenses and facial details retain
    # their contrast and authored shape.
    def fur_mask(image):
        hsv = cv2.cvtColor(image[:, :, :3], cv2.COLOR_RGB2HSV)
        yy, xx = np.indices(image.shape[:2])
        return (image[:, :, 3] > 200) & (hsv[:, :, 0] > 120) & (hsv[:, :, 0] < 175) & (hsv[:, :, 1] > 70) & (hsv[:, :, 2] > 22) & (hsv[:, :, 2] < 145) & (yy < 160) & (xx > 65) & (xx < 230)
    mask, target_mask = fur_mask(rgba), fur_mask(reference)
    lab = cv2.cvtColor(rgba[:, :, :3], cv2.COLOR_RGB2LAB).astype(np.float32)
    target = cv2.cvtColor(reference[:, :, :3], cv2.COLOR_RGB2LAB).astype(np.float32)
    if mask.sum() and target_mask.sum():
        shift = np.median(target[target_mask], axis=0) - np.median(lab[mask], axis=0)
        lab[mask] += shift * 0.72
        rgb = cv2.cvtColor(np.uint8(np.clip(lab, 0, 255)), cv2.COLOR_LAB2RGB)
        rgba[mask, :3] = rgb[mask]
    frame = Image.fromarray(rgba)
    flasks = Image.open(SOURCE.parent / 'table_flasks.png').convert('RGBA')
    if index <= 8:
        for side in range(2):
            piece = flasks.crop((side * 136, 0, (side + 1) * 136, 273))
            piece = piece.crop(piece.getbbox()).resize((46, 62), Image.Resampling.LANCZOS)
            angle = (0 if index <= 6 else 20 if index == 7 else 52) * (1 if side == 0 else -1)
            piece = piece.rotate(angle, Image.Resampling.BICUBIC, expand=True)
            erase = (18, 160, 94, 233) if side == 0 else (204, 160, 264, 233)
            frame.paste((0, 0, 0, 0), erase)
            center = 61 if side == 0 else 233
            frame.alpha_composite(piece, (round(center - piece.width / 2), 226 - piece.height))
    # The same glass wall, rim and highlights as victory. Original foam and
    # overflow stay in front of that glass; the wooden stirrer stays visible.
    glass = Image.open(SOURCE.parent / 'celebration_beaker.png').convert('RGBA')
    glass = glass.crop(glass.getbbox()).resize((78, 63), Image.Resampling.LANCZOS)
    # Clear the old glass interior only. A rectangular cut also erased the
    # coat panels visible beside the narrower replacement beaker.
    cleared = np.array(frame)
    cleared[184:227, 117:183, 3] = 0
    frame = Image.fromarray(cleared)
    frame.alpha_composite(glass, (110, 167))
    overlay = np.zeros_like(original)
    yy, xx = np.indices(original.shape[:2])
    foam = (index >= 4) & (xx > 106) & (xx < 195) & (yy > 148) & (yy < 191)
    foam &= (original[:, :, 2] > 110) & (original[:, :, 2] > original[:, :, 1] * 1.15)
    foam = cv2.dilate(foam.astype('uint8'), np.ones((3, 3), np.uint8)) > 0
    stick = (xx > 120) & (xx < 170) & (yy > 135) & (yy < 214) & (original[:, :, 0] > 140) & (original[:, :, 1] > 60) & (original[:, :, 2] < 120)
    stick = cv2.dilate(stick.astype('uint8'), np.ones((3, 3), np.uint8)) > 0
    keep = foam | (stick if index < 4 else False)
    overlay[keep] = original[keep]
    frame.alpha_composite(Image.fromarray(overlay))
    if index >= 9:
        # Join the foam to the hanging overflow along the new glass wall.
        # Draw at 4x so the curved highlight shares the sprite's smooth outline.
        stream = Image.new("RGBA", (WIDTH * 4, HEIGHT * 4))
        draw = ImageDraw.Draw(stream)
        points = []
        for u in np.linspace(0, 1, 45):
            point = ((1-u)**3 * np.array([180., 181.]) + 3*(1-u)**2*u*np.array([184., 222.]) + 3*(1-u)*u*u*np.array([158., 225.]) + u**3*np.array([151., 240.]))
            points.append(tuple(point * 4))
        draw.line(points, fill=(62, 21, 91, 255), width=46, joint="curve")
        draw.line(points, fill=(185, 67, 239, 255), width=35, joint="curve")
        draw.line([(x-4, y) for x,y in points], fill=(238, 170, 255, 255), width=7, joint="curve")
        frame.alpha_composite(stream.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS))
    return np.array(frame)


def source_frame(index):
    a=np.array(Image.open(SOURCE / f'full_{index + 1:02d}.png'));rgb=a[:,:,:3].astype(float);y,x=np.mgrid[:303,:279]
    side=((x<112)|(x>185))&(y>175)
    hsv = cv2.cvtColor(a[:, :, :3], cv2.COLOR_RGB2HSV)
    liquid = side & (hsv[:, :, 2] > 100) & (hsv[:, :, 1] > 120) & (((hsv[:, :, 0] > 78) & (hsv[:, :, 0] < 108)) | ((hsv[:, :, 0] > 148) & (hsv[:, :, 0] < 179)))
    # Pale cyan rims of the former side puddle survive a saturation-only key.
    liquid |= side & (y > 208) & (hsv[:, :, 0] > 65) & (hsv[:, :, 0] < 115) & (hsv[:, :, 1] > 25) & (hsv[:, :, 2] > 100)
    liquid=cv2.dilate(liquid.astype('uint8'),np.ones((5,5),np.uint8))>0
    liquid[(x > 84) & (x < 207) & (y < 215)] = False
    wood=(rgb[:,:,0]>rgb[:,:,2]*1.25)&(rgb[:,:,0]>rgb[:,:,1]*1.35)&(rgb[:,:,2]<130)&(y>205)
    remove=(wood)|liquid
    # Keep only the central violet overflow below the old tabletop. The game
    # supplies the same perspective table and complete paws as the victory.
    purple=(rgb[:,:,2]>rgb[:,:,1]*1.25)&(rgb[:,:,2]>rgb[:,:,0]*.9)&(rgb[:,:,2]>85)
    spill=cv2.dilate((purple&(x>120)&(x<183)&(y>220)).astype('uint8'),np.ones((5,5),np.uint8))>0
    remove|=(y>=228)&~spill
    remove|=((x<34)|(x>246))&(y>208)
    a[remove,3]=0
    return match_victory_style(a, index).astype(np.float32) / 255.0


def flow_inputs(frame):
    alpha = frame[:, :, 3:4]
    # Uniform purple behind transparent pixels stops old panel backgrounds
    # from steering the flow around the cat's outline.
    ground = np.array([29, 12, 40], np.float32) / 255.0
    rgb = frame[:, :, :3] * alpha + ground * (1.0 - alpha)
    return cv2.cvtColor(np.uint8(np.clip(rgb * 255.0, 0, 255)), cv2.COLOR_RGB2GRAY)


def pair_flows(first, second):
    a, b = flow_inputs(first), flow_inputs(second)
    engine = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    forward = engine.calc(a, b, None)
    backward = engine.calc(b, a, None)
    # Do not bend the wooden tabletop or legs during a change of expression.
    forward[232:, :, :] = 0
    backward[232:, :, :] = 0
    return forward, backward


X, Y = np.meshgrid(np.arange(WIDTH, dtype=np.float32), np.arange(HEIGHT, dtype=np.float32))


def warp(frame, flow, amount):
    premul = frame.copy()
    premul[:, :, :3] *= premul[:, :, 3:4]
    return cv2.remap(premul, X - amount * flow[:, :, 0], Y - amount * flow[:, :, 1],
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)


def interpolate(first, second, forward, backward, fraction, pair_index):
    # Cartoon easing: settle briefly at each key pose and move faster in the
    # middle. Motion warp keeps a single body on screen at every moment.
    t = float(fraction * fraction * (3.0 - 2.0 * fraction))
    # Changes in expression need a little more time to read as a blink or
    # reaction. Glass, spill and lettered cloud changes stay crisp.
    expressive = pair_index in (0, 1, 4, 5, 6, 7, 11, 12, 13)
    blend_start, blend_end = (0.25, 0.75) if expressive else (0.45, 0.55)
    if t < blend_start:
        premul = warp(first, forward, t)
    elif t > blend_end:
        premul = warp(second, backward, 1.0 - t)
    else:
        blend = (t - blend_start) / (blend_end - blend_start)
        blend = blend * blend * (3.0 - 2.0 * blend)
        premul = warp(first, forward, t) * (1.0 - blend) + warp(second, backward, 1.0 - t) * blend
    alpha = premul[:, :, 3:4]
    rgb = np.divide(premul[:, :, :3], np.maximum(alpha, 0.001))
    return Image.fromarray(np.uint8(np.clip(np.concatenate((rgb, alpha), axis=2) * 255.0, 0, 255)))


def main():
    poses = [source_frame(i) for i in POSE_INDICES]
    flows = [pair_flows(poses[i], poses[i + 1]) for i in range(len(TIMES) - 1)]
    for atlas_index in range((FRAME_COUNT + IDLE_FRAMES) // FRAMES_PER_ATLAS):
        atlas = Image.new("RGBA", (COLS * WIDTH, ROWS * HEIGHT))
        for slot in range(FRAMES_PER_ATLAS):
            frame_number = atlas_index * FRAMES_PER_ATLAS + slot
            moment = frame_number / FPS
            index = int(np.searchsorted(TIMES, moment, side="right") - 1)
            if frame_number >= FRAME_COUNT:
                # A small upper-body breath during the five-second wait.
                # The beaker, table and paws remain anchored to their pixels.
                phase = (frame_number - FRAME_COUNT) / IDLE_FRAMES * np.pi * 2
                weight_y = 1 - np.clip((Y - 105) / 55, 0, 1)
                weight_x = np.clip((X - 65) / 20, 0, 1) * np.clip((225 - X) / 20, 0, 1)
                flow = np.zeros((HEIGHT, WIDTH, 2), np.float32)
                flow[:, :, 0] = np.sin(phase) * 0.7 * weight_y * weight_x
                flow[:, :, 1] = (1 - np.cos(phase)) * 0.6 * weight_y * weight_x
                moved = warp(poses[-1], flow, 1)
                moved[:, :, :3] /= np.maximum(moved[:, :, 3:4], 0.001)
                image = Image.fromarray(np.uint8(np.clip(moved * 255, 0, 255)))
            elif index >= len(TIMES) - 1:
                image = Image.fromarray(np.uint8(poses[-1] * 255.0))
            elif moment == TIMES[index]:
                image = Image.fromarray(np.uint8(poses[index] * 255.0))
            else:
                fraction = (moment - TIMES[index]) / (TIMES[index + 1] - TIMES[index])
                image = interpolate(poses[index], poses[index + 1], *flows[index], fraction, index)
            atlas.alpha_composite(image, ((slot % COLS) * WIDTH, (slot // COLS) * HEIGHT))
        atlas.save(SOURCE / f"motion_{atlas_index:02d}.png", optimize=True)
    print(f"Built {FRAME_COUNT} reaction frames + {IDLE_FRAMES} breathing frames")


if __name__ == "__main__":
    main()
