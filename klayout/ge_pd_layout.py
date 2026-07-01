# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

import os
import shutil
from pathlib import Path

try:
    import pya
    _app = pya.Application.instance()
    IN_KLAYOUT = _app is not None
    HAVE_KLAYOUT = True
except Exception:
    try:
        import klayout.db as pya
        import klayout.lay as _lay
        IN_KLAYOUT = False
        HAVE_KLAYOUT = True
    except Exception:
        pya = None
        _lay = None
        IN_KLAYOUT = False
        HAVE_KLAYOUT = False

rib_W = 0.500
taper_L = 40.0
Ge_W = 5.0
Ge_L = 8.0
Npp_W = Ge_W * 0.50
ext_W = Ge_W * 1.10
Al_cath_W_top = Npp_W * 0.80
Al_anode_W_top = 0.500
D1 = 1.600
D2 = 2.560
y_anode_in = Ge_W / 2 + D1
y_anode_out = y_anode_in + Al_anode_W_top
x_back_min = Ge_L + D2
x_back_max = x_back_min + Al_anode_W_top
slab_margin = 2.0
slab_x_min = -(taper_L + slab_margin)
slab_x_max = x_back_max + slab_margin
slab_half_y = y_anode_out + slab_margin
ppp_y_inner = ext_W / 2
ppp_y_outer = y_anode_in

LAYER_STYLE = {
    (0, 0): (0x222222, False, "die"),
    (1, 0): (0x4080FF, True, "slab"),
    (2, 0): (0x0040C0, True, "rib"),
    (3, 0): (0x00C0FF, True, "taper"),
    (4, 0): (0x00FF80, True, "ext"),
    (10, 0): (0xFF4040, True, "Ge"),
    (11, 0): (0xFF8000, True, "Npp"),
    (12, 0): (0xC000C0, True, "Ppp"),
    (20, 0): (0xFFFF00, True, "cath"),
    (21, 0): (0xFFD700, True, "anode"),
    (68, 0): (0xFFFFFF, False, "PinRec"),
}

PORTS = [
    {"name": "wg_in", "x": -taper_L, "y": 0.0, "width": rib_W},
    {"name": "wg_out", "x": x_back_max, "y": 0.0, "width": rib_W},
]

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
FIG_DIR = REPO_ROOT / "figures"
SETUP_DIR = FIG_DIR / "Setup"
LEGACY_LAYOUT_DIR = FIG_DIR / "layout"
FIG_DIR.mkdir(exist_ok=True)
SETUP_DIR.mkdir(exist_ok=True)

GDS_PATH = SCRIPT_DIR / "ge_pd_layout.gds"
LYP_PATH = SCRIPT_DIR / "ge_pd.lyp"

GEOM_DIR = FIG_DIR / "Geometry"
GEOM_DIR.mkdir(exist_ok=True)

MASK_PNG = FIG_DIR / "layout_mask_view.png"
DETAIL_PNG = FIG_DIR / "layout_pd_detail.png"
SETUP_TOP_PNG = SETUP_DIR / "klayout_top.png"
SETUP_DETAIL_PNG = SETUP_DIR / "klayout_pd_detail.png"
GEOM_PNG = GEOM_DIR / "geom_vpin_layout_klayout.png"

def nm(x):
    return int(round(x * 1000))

def build_shape_specs():
    return [
        ("slab", "rect", (slab_x_min, slab_x_max, -slab_half_y, slab_half_y)),
        ("rib", "rect", (slab_x_min, -taper_L, -rib_W / 2, rib_W / 2)),
        ("taper", "poly", [
            (-taper_L, -rib_W / 2),
            (-taper_L, rib_W / 2),
            (0, ext_W / 2),
            (0, -ext_W / 2),
        ]),
        ("ext", "rect", (0, Ge_L, -ext_W / 2, ext_W / 2)),
        ("Ge", "rect", (0, Ge_L, -Ge_W / 2, Ge_W / 2)),
        ("Npp", "rect", (0, Ge_L, -Npp_W / 2, Npp_W / 2)),
        ("Ppp", "rect", (0, x_back_min, -ppp_y_outer, -ppp_y_inner)),
        ("Ppp", "rect", (0, x_back_min, ppp_y_inner, ppp_y_outer)),
        ("cath", "rect", (0, Ge_L, -Al_cath_W_top / 2, Al_cath_W_top / 2)),
        ("anode", "rect", (0, x_back_min, -y_anode_out, -y_anode_in)),
        ("anode", "rect", (0, x_back_min, y_anode_in, y_anode_out)),
        ("anode", "rect", (x_back_min, x_back_max, -y_anode_out, y_anode_out)),
    ]

def layer_lookup(layout):
    return {
        name: layout.layer(ln, dt)
        for (ln, dt), (_, _, name) in LAYER_STYLE.items()
    }

def box(layer, x0, x1, y0, y1, cell):
    cell.shapes(layer).insert(pya.Box(nm(x0), nm(y0), nm(x1), nm(y1)))

def polygon(layer, pts, cell):
    cell.shapes(layer).insert(
        pya.Polygon([pya.Point(nm(x), nm(y)) for x, y in pts])
    )

def pin(layer, name, x, y, width, cell):
    half = width / 2
    cell.shapes(layer).insert(
        pya.Box(nm(x) - 10, nm(y - half), nm(x) + 10, nm(y + half))
    )
    cell.shapes(layer).insert(pya.Text(name, pya.Trans(nm(x), nm(y))))

def label(layer, txt, x, y, cell):
    cell.shapes(layer).insert(pya.Text(txt, pya.Trans(nm(x), nm(y))))

def write_lyp():
    rows = ['<?xml version="1.0" encoding="utf-8"?>', "<layer-properties>"]
    for (ln, dt), (color, fill, name) in LAYER_STYLE.items():
        fc = "%06x" % color
        rows += [
            " <properties>",
            f"  <frame-color>
            f"  <fill-color>
            f"  <fill-brightness>{'0' if fill else '-255'}</fill-brightness>",
            f"  <dither-pattern>{'I5' if fill else 'I0'}</dither-pattern>",
            f"  <source>{ln}/{dt}@1</source>",
            f"  <name>{name}</name>",
            "  <visible>true</visible>",
            "  <transparent>false</transparent>",
            f"  <width>{'0' if fill else '1'}</width>",
            " </properties>",
        ]
    rows.append("</layer-properties>")
    LYP_PATH.write_text("\n".join(rows), encoding="utf-8")

def write_gds_if_available():
    if not HAVE_KLAYOUT:
        write_lyp()
        return False
    layout = pya.Layout()
    layout.dbu = 0.001
    layers = layer_lookup(layout)
    top = layout.create_cell("GE_PD_USHAPED_OBAND")
    die_cell = layout.create_cell("DIE_BOUNDARY")
    box(layers["die"], slab_x_min, slab_x_max, -slab_half_y, slab_half_y, die_cell)
    top.insert(pya.CellInstArray(die_cell.cell_index(), pya.Trans()))
    for layer_name, kind, payload in build_shape_specs():
        if kind == "rect":
            box(layers[layer_name], *payload, top)
        else:
            polygon(layers[layer_name], payload, top)
    for port in PORTS:
        pin(layers["PinRec"], "INTC_IO_" + port["name"], port["x"], port["y"], port["width"], top)
    for text, x, y in [
        ("Si rib", -(taper_L * 0.75), 0.0),
        ("Si taper", -(taper_L * 0.30), rib_W + 0.4),
        ("Si ext", Ge_L / 2, ext_W / 2 + 0.4),
        ("Ge L=8.0um W=5.0um", Ge_L / 2, 0.3),
        ("N++ Ge", Ge_L / 2, -0.4),
        ("P++ Si", x_back_min / 2, -(ppp_y_inner + ppp_y_outer) / 2),
        ("Al cathode", Ge_L / 2, Al_cath_W_top / 2 + 0.3),
        ("Al anode", (x_back_min + x_back_max) / 2, 0.0),
        ("electrode gap=1.6um", Ge_L + 0.5, y_anode_in),
    ]:
        label(layers["PinRec"], text, x, y, top)
    layout.write(str(GDS_PATH))
    write_lyp()
    return True

def color_tuple(hex_color, alpha=1.0):
    return (
        ((hex_color >> 16) & 255) / 255,
        ((hex_color >> 8) & 255) / 255,
        (hex_color & 255) / 255,
        alpha,
    )

def render_with_matplotlib(path, detail=False):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon, Rectangle

    fig, ax = plt.subplots(figsize=(14, 7), facecolor="white")
    ax.set_facecolor("
    name_to_style = {v[2]: v for v in LAYER_STYLE.values()}
    for layer_name, kind, payload in build_shape_specs():
        color, fill, _ = name_to_style[layer_name]
        rgba = color_tuple(color, 0.60 if fill else 1.0)
        if kind == "rect":
            x0, x1, y0, y1 = payload
            ax.add_patch(Rectangle((x0, y0), x1-x0, y1-y0, facecolor=rgba, edgecolor=color_tuple(color), linewidth=1.0))
        else:
            ax.add_patch(Polygon(payload, closed=True, facecolor=rgba, edgecolor=color_tuple(color), linewidth=1.0))

    ax.annotate("", xy=(0, -Ge_W/2 - 0.7), xytext=(Ge_L, -Ge_W/2 - 0.7), arrowprops=dict(arrowstyle="<->", color="black", lw=1.2))
    ax.text(Ge_L/2, -Ge_W/2 - 1.0, "L_Ge = 8.0 um", ha="center", va="top", fontsize=9)
    ax.annotate("", xy=(Ge_L + 0.45, -Ge_W/2), xytext=(Ge_L + 0.45, Ge_W/2), arrowprops=dict(arrowstyle="<->", color="black", lw=1.2))
    ax.text(Ge_L + 0.65, 0, "W_Ge = 5.0 um", ha="left", va="center", fontsize=9, rotation=90)
    ax.annotate("", xy=(Ge_L + 1.1, y_anode_in), xytext=(Ge_L + 1.1, ppp_y_inner), arrowprops=dict(arrowstyle="<->", color="black", lw=1.0))
    ax.text(Ge_L + 1.3, (y_anode_in+ppp_y_inner)/2, "gap 1.6 um", ha="left", va="center", fontsize=8, rotation=90)

    scale_x = slab_x_min + 2.0 if not detail else -0.5
    scale_y = -slab_half_y + 0.6 if not detail else -y_anode_out - 0.4
    ax.plot([scale_x, scale_x + 5], [scale_y, scale_y], color="black", lw=3)
    ax.text(scale_x + 2.5, scale_y + 0.25, "5 um", ha="center", va="bottom", fontsize=9)

    for text, x, y in [
        ("Ge absorber", Ge_L/2, 0.45),
        ("N++ cathode", Ge_L/2, -0.6),
        ("P++ anodes", x_back_min/2, y_anode_out + 0.35),
        ("input", -taper_L, 0.45),
        ("output", x_back_max, 0.45),
    ]:
        if not detail or x > -2:
            ax.text(x, y, text, ha="center", va="center", fontsize=8, color="black")

    legend_layers = ["slab", "rib", "taper", "ext", "Ge", "Npp", "Ppp", "cath", "anode"]
    handles = []
    for name in legend_layers:
        color = name_to_style[name][0]
        handles.append(Rectangle((0, 0), 1, 1, facecolor=color_tuple(color, 0.60), edgecolor=color_tuple(color), label=name))
    ax.legend(handles=handles, loc="upper right", frameon=True, title="GDS layers", fontsize=8, title_fontsize=9)

    if detail:
        ax.set_xlim(-1.5, x_back_max + 1.2)
        ax.set_ylim(-y_anode_out - 1.0, y_anode_out + 1.0)
    else:
        ax.set_xlim(slab_x_min - 1.0, x_back_max + 2.0)
        ax.set_ylim(-slab_half_y - 1.0, slab_half_y + 1.0)
    ax.set_aspect("equal", adjustable="box")
    ax.set_xlabel("x (um)")
    ax.set_ylabel("y (um)")
    ax.grid(True, color="
    fig.tight_layout()
    fig.savefig(path, dpi=300)
    plt.close(fig)

def render_with_klayout_view(path, detail=False):
    if not HAVE_KLAYOUT or not GDS_PATH.exists():
        return False
    if IN_KLAYOUT:
        mw = _app.main_window()
        mw.load_layout(str(GDS_PATH), 0)
        view = mw.current_view()
    else:
        view = _lay.LayoutView()
        view.load_layout(str(GDS_PATH), True)
    view.load_layer_props(str(LYP_PATH))
    view.max_hier()
    if detail:
        box_view = pya.DBox(-1.5, -y_anode_out - 1.0, x_back_max + 1.2, y_anode_out + 1.0)
    else:
        box_view = pya.DBox(slab_x_min - 1.0, -slab_half_y - 1.0, x_back_max + 2.0, slab_half_y + 1.0)
    try:
        view.save_image_with_options(str(path), 3600, 2000, 0, 2, 0, box_view, False)
    except Exception:
        view.zoom_box(box_view)
        view.save_image(str(path), 3600, 2000)
    return True

def render_figures():
    try:
        render_with_matplotlib(MASK_PNG, detail=False)
        render_with_matplotlib(DETAIL_PNG, detail=True)
    except Exception:
        render_with_klayout_view(MASK_PNG, detail=False)
        render_with_klayout_view(DETAIL_PNG, detail=True)
    shutil.copyfile(MASK_PNG, SETUP_TOP_PNG)
    shutil.copyfile(DETAIL_PNG, SETUP_DETAIL_PNG)
    shutil.copyfile(DETAIL_PNG, GEOM_PNG)
    if LEGACY_LAYOUT_DIR.exists():
        for legacy in ("layout_mask_view.png", "layout_pd_detail.png"):
            legacy_path = LEGACY_LAYOUT_DIR / legacy
            if legacy_path.exists():
                legacy_path.unlink()

write_gds_if_available()
render_figures()
