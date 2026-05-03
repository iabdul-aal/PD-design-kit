import os
import pya

rib_W          = 0.500
wg_H           = 0.220
slab_H         = 0.090
taper_L        = 40.0
Ge_W           = 5.0
Ge_L           = 8.0
iGe_H          = 0.350
Npp_H          = 0.050
ext_W          = Ge_W * 1.10
iGe_W_bot      = Ge_W
iGe_W_top      = Ge_W * 0.50
Npp_W          = iGe_W_top
Al_cath_W_bot  = Npp_W * 0.60
Al_cath_W_top  = Npp_W * 0.80
Al_anode_W_bot = 0.200
Al_anode_W_top = 0.500
D1             = 1.600
D2             = 2.560
y_anode_in     = Ge_W / 2 + D1
y_anode_out    = y_anode_in + Al_anode_W_top
x_back_min     = Ge_L + D2
x_back_max     = x_back_min + Al_anode_W_top
slab_margin    = 2.0
slab_x_min     = -(taper_L + slab_margin)
slab_x_max     = x_back_max + slab_margin
slab_half_y    = y_anode_out + slab_margin
ppp_y_inner    = ext_W / 2
ppp_y_outer    = y_anode_in


def nm(x):
    return int(round(x * 1000))

def box(layer, x0, x1, y0, y1, cell):
    cell.shapes(layer).insert(pya.Box(nm(x0), nm(y0), nm(x1), nm(y1)))

def polygon(layer, pts_um, cell):
    pts = [pya.Point(nm(x), nm(y)) for x, y in pts_um]
    cell.shapes(layer).insert(pya.Polygon(pts))

def text_label(layer, txt, x, y, cell):
    cell.shapes(layer).insert(pya.Text(txt, pya.Trans(nm(x), nm(y))))


layout     = pya.Layout()
layout.dbu = 0.001

L_slab  = layout.layer(1,  0)
L_rib   = layout.layer(2,  0)
L_taper = layout.layer(3,  0)
L_ext   = layout.layer(4,  0)
L_Ge    = layout.layer(10, 0)
L_Npp   = layout.layer(11, 0)
L_Ppp   = layout.layer(12, 0)
L_cath  = layout.layer(20, 0)
L_anode = layout.layer(21, 0)
L_text  = layout.layer(99, 0)

top      = layout.create_cell("GE_PD_USHAPED_OBAND")
die_cell = layout.create_cell("DIE_BOUNDARY")
L_die    = layout.layer(0, 0)
box(L_die, slab_x_min, slab_x_max, -slab_half_y, slab_half_y, die_cell)
top.insert(pya.CellInstArray(die_cell.cell_index(), pya.Trans()))

box(L_slab, slab_x_min, slab_x_max, -slab_half_y, slab_half_y, top)

box(L_rib, slab_x_min, -taper_L, -rib_W / 2, rib_W / 2, top)

polygon(L_taper, [
    (-taper_L, -rib_W / 2),
    (-taper_L,  rib_W / 2),
    (0,         ext_W / 2),
    (0,        -ext_W / 2),
], top)

box(L_ext, 0, Ge_L, -ext_W / 2, ext_W / 2, top)

box(L_Ge, 0, Ge_L, -Ge_W / 2, Ge_W / 2, top)

box(L_Npp, 0, Ge_L, -Npp_W / 2, Npp_W / 2, top)

box(L_Ppp, 0, x_back_min, -ppp_y_outer, -ppp_y_inner, top)
box(L_Ppp, 0, x_back_min,  ppp_y_inner,  ppp_y_outer, top)

box(L_cath, 0, Ge_L, -Al_cath_W_top / 2, Al_cath_W_top / 2, top)

box(L_anode, 0, x_back_min, -y_anode_out, -y_anode_in, top)
box(L_anode, 0, x_back_min,  y_anode_in,   y_anode_out, top)
box(L_anode, x_back_min, x_back_max, -y_anode_out, y_anode_out, top)

labels = [
    ("Si_rib",         -(taper_L * 0.75),             0.0),
    ("Si_taper",       -(taper_L * 0.30),              rib_W + 0.4),
    ("Si_ext",          Ge_L / 2,                      ext_W / 2 + 0.4),
    ("Ge",              Ge_L / 2,                      0.3),
    ("N++_Ge",          Ge_L / 2,                     -0.4),
    ("P++_Si (left)",   x_back_min / 2,               -(ppp_y_inner + ppp_y_outer) / 2),
    ("P++_Si (right)",  x_back_min / 2,                (ppp_y_inner + ppp_y_outer) / 2),
    ("Al_cathode",      Ge_L / 2,                      Al_cath_W_top / 2 + 0.3),
    ("Al_anode_arm_L",  x_back_min / 3,               -(y_anode_in + y_anode_out) / 2),
    ("Al_anode_arm_R",  x_back_min / 3,                (y_anode_in + y_anode_out) / 2),
    ("Al_anode_back",  (x_back_min + x_back_max) / 2,  0.0),
]
for lbl, x, y in labels:
    text_label(L_text, lbl, x, y, top)

tick = 0.2

def tick_x(layer, x, y_ctr, cell, half=tick):
    box(layer, x - 0.02, x + 0.02, y_ctr - half, y_ctr + half, cell)

def tick_y(layer, y, x_ctr, cell, half=tick):
    box(layer, x_ctr - half, x_ctr + half, y - 0.02, y + 0.02, cell)

tick_x(L_text, 0,    -Ge_W / 2 - 0.6, top)
tick_x(L_text, Ge_L, -Ge_W / 2 - 0.6, top)
tick_y(L_text, Ge_W / 2,   x_back_min / 2, top)
tick_y(L_text, y_anode_in, x_back_min / 2, top)


outdir = os.path.dirname(os.path.abspath(__file__))
layout.write(os.path.join(outdir, "ge_pd_layout.gds"))
