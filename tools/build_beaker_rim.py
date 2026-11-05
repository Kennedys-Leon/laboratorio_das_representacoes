"""Keep a complete stationary glass edge above the animated potion liquid."""

from pathlib import Path
import cv2
import numpy as np
from PIL import Image

assets = Path(__file__).resolve().parents[1] / "assets/cat_animation/potion_mix"
source = np.array(Image.open(assets / "beaker_18.png").convert("RGBA"))
alpha = source[:, :, 3]
solid = (alpha > 8).astype(np.uint8)
inner = cv2.erode(solid, np.ones((13, 13), np.uint8))
edge = np.clip(solid - inner, 0, 1)
edge[200:217] = solid[200:217]
source[:, :, 3] = np.uint8(alpha * edge)
Image.fromarray(source).save(assets / "beaker_rim.png", optimize=True)
