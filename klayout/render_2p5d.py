# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import klayout.db as pya

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GDS_PATH   = os.path.join(SCRIPT_DIR, "ge_pd_layout.gds")
FIG_DIR    = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "figures", "layout"))
os.makedirs(FIG_DIR, exist_ok=True)

PNG_PATH = os.path.join(FIG_DIR, "device_2p5d.png")
PDF_PATH = os.path.join(FIG_DIR, "device_2p5d.pdf")

LAYER_MAP = {
    "slab":  ( 1, 0),
    "rib":   ( 2, 0),
    "taper": ( 3, 0),
    "ext":   ( 4, 0),
    "Ge":    (10, 0),
    "Npp":   (11, 0),
    "Ppp":   (12, 0),
    "cath":  (20, 0),
    "anode": (21, 0),
}

LAYER_Z = {
    "slab":  (0.000, 0.090),
    "rib":   (0.000, 0.220),
    "taper": (0.000, 0.220),
    "ext":   (0.000, 0.220),
    "Ppp":   (0.000, 0.090),
    "Ge":    (0.220, 0.720),
    "Npp":   (0.220, 0.700),
    "cath":  (0.720, 1.220),
    "anode": (0.090, 0.590),
}

LAYER_RGBA = {
    "slab":  (0.25, 0.50, 1.00, 0.18),
    "rib":   (0.00, 0.25, 0.75, 0.70),
    "taper": (0.00, 0.75, 1.00, 0.70),
    "ext":   (0.00, 1.00, 0.50, 0.70),
    "Ppp":   (0.75, 0.00, 0.75, 0.55),
    "Ge":    (1.00, 0.25, 0.25, 0.88),
    "Npp":   (1.00, 0.55, 0.00, 0.80),
    "cath":  (1.00, 1.00, 0.00, 0.90),
    "anode": (1.00, 0.84, 0.00, 0.90),
}

LAYER_ORDER = ["slab", "rib", "taper", "ext", "Ppp", "Ge", "Npp", "cath", "anode"]

CLIP = (-42.0, 13.5, -7.5, 7.5)

layout = pya.Layout()
layout.read(GDS_PATH)
top    = layout.top_cell()
dbu    = layout.dbu

def clip_region(x0, x1, y0, y1):
    return pya.Region(pya.Box(
        int(round(x0 / dbu)), int(round(y0 / dbu)),
        int(round(x1 / dbu)), int(round(y1 / dbu)),
    ))

def get_polygons(layer_name):
    ln, dt = LAYER_MAP[layer_name]
    li = layout.find_layer(ln, dt)
    if li is None:
        return []
    r = pya.Region()
    r.insert(top.begin_shapes_rec(li))
    r = r & clip_region(*CLIP)
    polys = []
    for shape in r.each():
        pts = [(pt.x * dbu, pt.y * dbu) for pt in shape.each_point_hull()]
        if len(pts) >= 3:
            polys.append(np.array(pts))
    return polys

def extrude(verts_2d, z_bot, z_top):
    faces = []
    n = len(verts_2d)
    top_face    = [(x, y, z_top) for x, y in verts_2d]
    bottom_face = [(x, y, z_bot) for x, y in reversed(verts_2d)]
    faces.append(top_face)
    faces.append(bottom_face)
    for i in range(n):
        x0, y0 = verts_2d[i]
        x1, y1 = verts_2d[(i + 1) % n]
        faces.append([
            (x0, y0, z_bot), (x1, y1, z_bot),
            (x1, y1, z_top), (x0, y0, z_top),
        ])
    return faces

fig = plt.figure(figsize=(20, 10), facecolor="
ax  = fig.add_subplot(111, projection="3d", facecolor="

for layer_name in LAYER_ORDER:
    z_bot, z_top = LAYER_Z[layer_name]
    rgba = LAYER_RGBA[layer_name]
    face_color = rgba[:3] + (rgba[3],)
    edge_color = tuple(min(c * 1.4, 1.0) for c in rgba[:3]) + (rgba[3] * 0.6,)
    all_faces = []
    for poly in get_polygons(layer_name):
        all_faces.extend(extrude(poly.tolist(), z_bot, z_top))
    if all_faces:
        col = Poly3DCollection(
            all_faces,
            facecolor=face_color,
            edgecolor=edge_color,
            linewidth=0.15,
        )
        ax.add_collection3d(col)

ax.set_xlim(CLIP[0], CLIP[1])
ax.set_ylim(CLIP[2], CLIP[3])
ax.set_zlim(0.0, 1.4)

ax.set_xlabel("x  (µm)", color="
ax.set_ylabel("y  (µm)", color="
ax.set_zlabel("z  (µm)", color="

ax.tick_params(colors="
for spine in ax.spines.values():
    spine.set_color("
ax.xaxis.pane.fill = False
ax.yaxis.pane.fill = False
ax.zaxis.pane.fill = False
ax.xaxis.pane.set_edgecolor("
ax.yaxis.pane.set_edgecolor("
ax.zaxis.pane.set_edgecolor("
ax.grid(True, color="

ax.view_init(elev=28, azim=-52)

legend_handles = []
for name in LAYER_ORDER:
    rgba = LAYER_RGBA[name]
    patch = plt.Rectangle((0, 0), 1, 1, fc=rgba[:3], alpha=rgba[3], label=name)
    legend_handles.append(patch)

legend = ax.legend(
    handles=legend_handles,
    loc="upper left",
    fontsize=7.5,
    framealpha=0.25,
    facecolor="
    edgecolor="
    labelcolor="
    ncol=1,
    title="layers",
    title_fontsize=8,
)
legend.get_title().set_color("

ax.set_title("GE_PD_USHAPED_OBAND — 2.5D Device View", color="

fig.savefig(PNG_PATH, dpi=300, bbox_inches="tight", facecolor=fig.get_facecolor())
fig.savefig(PDF_PATH, bbox_inches="tight",           facecolor=fig.get_facecolor())
plt.close(fig)
