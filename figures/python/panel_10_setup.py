# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 10 — 1×2 Grid: Physical Device Layout and Cross-Section
  (a) [1×1] — FDTD 3D perspective layout
  (b) [1×1] — CHARGE YZ cross-section layout
"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from pathlib import Path

dir_sim = Path(__file__).resolve().parent
repo = dir_sim.parents[1]
path1 = dir_sim / "1.png"
path2 = dir_sim / "2.png"

# ─── RC params matching older panels ──────────────────────────────────────────
plt.rcParams.update({
    'font.family':        'serif',
    'font.size':          9,
    'axes.linewidth':     0.8,
    'axes.facecolor':     'white',
    'figure.facecolor':   'white',
    'xtick.direction':    'in',
    'ytick.direction':    'in',
    'xtick.major.width':  0.7,
    'ytick.major.width':  0.7,
    'lines.linewidth':    1.1,
})

# Load screenshots
img1 = mpimg.imread(str(path1))
img2 = mpimg.imread(str(path2))

def remove_gray_gradient_bg(img):
    out = img.copy()
    rgb = out[..., :3]
    # R, G, B are very close (neutral gray)
    max_val = np.max(rgb, axis=-1)
    min_val = np.min(rgb, axis=-1)
    is_gray = (max_val - min_val) < 0.015
    # Brightness is light gray to white (> 0.85)
    mean_val = np.mean(rgb, axis=-1)
    is_light = mean_val > 0.85
    # Apply mask
    mask = is_gray & is_light
    out[mask, :3] = 1.0
    if out.shape[-1] == 4:
        out[mask, 3] = 1.0
    return out

# Process images to make background 100% white
img1_clean = remove_gray_gradient_bg(img1)
img2_clean = remove_gray_gradient_bg(img2)

# Crop FDTD (1.png) - rows 80 to 580, cols 20 to 720 (removes the axis widget on the right!)
c1 = img1_clean[80:580, 20:720]

# Crop CHARGE (2.png) - rows 60 to 520, cols 430 to 880
c2 = img2_clean[60:520, 430:880]

# Pad CHARGE horizontally with white pixels to match FDTD aspect ratio (500/700 = 0.71428)
w_target = 644
w_current = c2.shape[1]  # 450
pad_left = (w_target - w_current) // 2      # 97
pad_right = w_target - w_current - pad_left # 97

# Create white columns padding
white_pad_left = np.ones((c2.shape[0], pad_left, c2.shape[2]))
white_pad_right = np.ones((c2.shape[0], pad_right, c2.shape[2]))

# Concatenate horizontally
c2_padded = np.hstack([white_pad_left, c2, white_pad_right])

# Create figure
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5))

# Plot FDTD
ax1.imshow(c1)
ax1.axis('off')
ax1.set_title("FDTD 3D Layout", fontsize=9.5, fontweight='bold', pad=8)
ax1.text(-0.02, 1.04, '(a)', transform=ax1.transAxes, fontsize=11, fontweight='bold', va='bottom')

# Plot CHARGE (padded to match aspect ratio)
ax2.imshow(c2_padded)
ax2.axis('off')
ax2.set_title("CHARGE YZ Cross-Section", fontsize=9.5, fontweight='bold', pad=8)
ax2.text(-0.02, 1.04, '(b)', transform=ax2.transAxes, fontsize=11, fontweight='bold', va='bottom')

plt.tight_layout()

# Save output
out_path = dir_sim / "panel_10_setup.png"
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"Saved: {out_path}")
