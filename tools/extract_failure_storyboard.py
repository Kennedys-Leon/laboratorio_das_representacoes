"""Isolate each complete panel's cat, table and props from the supplied storyboard.

The game displays each full scene during a mistake, so no second character or
beaker can sit behind the reference animation. Requires Pillow, NumPy, OpenCV.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = np.asarray(Image.open(root / 'assets/cat_animation/potion_mix/error-storyboard.png').convert('RGB'))
out = root / 'assets/cat_animation/potion_mix/failure'
out.mkdir(exist_ok=True)
for index in range(18):
    row, col = divmod(index, 6)
    top = (0, 305, 610)[row]
    tile = source[top:top + 303, col * 279:(col + 1) * 279].copy()
    # The source is two pixels narrower than six exact 279-pixel columns.
    # Keep every pose on the same canvas so motion interpolation can align it.
    if tile.shape[1] < 279:
        tile = np.pad(tile, ((0, 0), (0, 279 - tile.shape[1]), (0, 0)))
    # Sample the unobstructed edges, rather than rows containing bottles or
    # smoke. Row samples from objects previously left horizontal purple bars.
    left = np.median(tile[:, 10:17], axis=1).astype(np.float32)
    right = np.median(tile[:, 265:270], axis=1).astype(np.float32)
    left[:65] = left[65]
    right[:65] = right[65]
    left = cv2.GaussianBlur(left, (1, 31), 0)
    right = cv2.GaussianBlur(right, (1, 31), 0)
    blend = np.linspace(0, 1, 279)[None, :, None]
    background = left[:, None, :] * (1 - blend) + right[:, None, :] * blend
    distance = np.max(np.abs(tile.astype(np.float32) - background), axis=2)
    candidates = np.uint8(distance > 14) * 255
    candidates[:12] = 0
    candidates[:63, :76] = 0
    candidates[:, :18] = 0
    candidates[:, 262:] = 0
    candidates[294:] = 0
    contours, _ = cv2.findContours(candidates, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    alpha = np.zeros(candidates.shape, np.uint8)
    for contour in contours:
        if cv2.contourArea(contour) > 35:
            cv2.drawContours(alpha, [contour], -1, 255, -1)
    # Remove the storyboard's brown floor between the table legs, while
    # preserving the purple paws, spilled potion, shards and rear supports.
    rgb = tile.astype(np.float32)
    floor = (rgb[:, :, 0] > rgb[:, :, 2] * 1.3) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.4) & (rgb[:, :, 2] < 95)
    floor_area = np.zeros_like(alpha)
    floor_area[251:294, 55:229] = 1
    floor_area[251:272, 55:80] = 0
    floor_area[251:272, 211:229] = 0
    alpha[floor & (floor_area > 0)] = 0
    Image.fromarray(np.dstack((tile, alpha)), 'RGBA').save(out / f'full_{index + 1:02d}.png')
print(f'Extracted 18 complete failure panels to {out}')

# Keep the reference lettering and cloud as one independent, crisp effect.
cloud = np.array(Image.open(out / 'full_14.png'))
mask = np.uint8((cloud[:, :, 2] > 100) & (cloud[:, :, 0] > 70) & (cloud[:, :, 3] > 0)) * 255
mask[:132] = 0
mask[244:] = 0
mask[:, :52] = 0
mask[:, 241:] = 0
contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
alpha = np.zeros_like(mask)
cv2.drawContours(alpha, [max(contours, key=cv2.contourArea)], -1, 255, -1)
alpha = cv2.dilate(alpha, np.ones((3, 3), np.uint8))
cloud[:, :, 3] = np.minimum(alpha, cloud[:, :, 3])
cloud = cloud[130:247, 50:243].copy()
cloud[:8, :62, 3] = 0
cloud[85:, :10, 3] = 0
cloud[95:, :25, 3] = 0
cloud[99:, :40, 3] = 0
cloud[108:, :70, 3] = 0
cloud[104:, 140:, 3] = 0
Image.fromarray(cloud, 'RGBA').save(out / 'retry_cloud.png')
