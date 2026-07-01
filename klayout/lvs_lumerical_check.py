# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

import os
import klayout.db as pya

GDS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ge_pd_layout.gds")

rib_W          = 0.500
taper_L        = 40.0
Ge_W           = 5.0
Ge_L           = 8.0
Npp_W          = Ge_W * 0.50
ext_W          = Ge_W * 1.10
Al_cath_W_top  = Npp_W * 0.80
Al_anode_W_top = 0.500
D1             = 1.600
D2             = 2.560
y_anode_in     = Ge_W / 2 + D1
y_anode_out    = y_anode_in + Al_anode_W_top
x_back_min     = Ge_L + D2
x_back_max     = x_back_min + Al_anode_W_top

TOL = 0.005

LAYER_MAP = {
    "Ge":     (10, 0),
    "Npp":    (11, 0),
    "Ppp":    (12, 0),
    "ext":    ( 4, 0),
    "rib":    ( 2, 0),
    "slab":   ( 1, 0),
    "cath":   (20, 0),
    "anode":  (21, 0),
    "taper":  ( 3, 0),
    "PinRec": (68, 0),
}

def run():
    layout = pya.Layout()
    layout.read(GDS_PATH)
    top = layout.top_cell()
    dbu = layout.dbu
    results = []

    def region(layer_name):
        ln, dt = LAYER_MAP[layer_name]
        li = layout.find_layer(ln, dt)
        r = pya.Region()
        if li is not None:
            r.insert(top.begin_shapes_rec(li))
        return r

    def bbox(layer_name):
        r = region(layer_name)
        if r.is_empty():
            return None
        bb = r.bbox()
        return {
            "x_min":  bb.left    * dbu,
            "x_max":  bb.right   * dbu,
            "y_min":  bb.bottom  * dbu,
            "y_max":  bb.top     * dbu,
            "width":  bb.height() * dbu,
            "length": bb.width()  * dbu,
            "cx":     bb.center().x * dbu,
            "cy":     bb.center().y * dbu,
        }

    def anode_gaps():
        r = region("anode")
        y_vals = []
        for s in r.each():
            bb = s.bbox()
            y_vals.append((bb.bottom * dbu, bb.top * dbu))
        pos = [(b, t) for b, t in y_vals if b > 0]
        if not pos:
            return None, None
        return min(b for b, t in pos), max(t for b, t in pos)

    def pin_x(name):
        ln, dt = LAYER_MAP["PinRec"]
        li = layout.find_layer(ln, dt)
        if li is None:
            return None
        for shape in top.begin_shapes_rec(li):
            s = shape.shape()
            if s.is_text() and name in s.text.string:
                return s.text.trans.disp.x * dbu
        return None

    def record(name, measured, expected, tol=TOL):
        if measured is None:
            results.append({"name": name, "passed": None, "detail": "could not extract from GDS"})
            return
        delta = abs(measured - expected)
        passed = delta <= tol
        results.append({
            "name":    name,
            "passed":  passed,
            "detail":  f"GDS={measured:.4f} um  expected={expected:.4f} um  delta={delta:.4f} um  tol={tol} um",
        })

    Ge_bb    = bbox("Ge")
    Npp_bb   = bbox("Npp")
    ext_bb   = bbox("ext")
    cath_bb  = bbox("cath")
    rib_bb   = bbox("rib")
    taper_bb = bbox("taper")

    record("Ge_width",        Ge_bb["width"]    if Ge_bb    else None, Ge_W)
    record("Ge_length",       Ge_bb["length"]   if Ge_bb    else None, Ge_L)
    record("Npp_width",       Npp_bb["width"]   if Npp_bb   else None, Npp_W)
    record("Npp_length",      Npp_bb["length"]  if Npp_bb   else None, Ge_L)
    record("ext_width",       ext_bb["width"]   if ext_bb   else None, ext_W)
    record("ext_length",      ext_bb["length"]  if ext_bb   else None, Ge_L)
    record("cath_width",      cath_bb["width"]  if cath_bb  else None, Al_cath_W_top)
    record("cath_length",     cath_bb["length"] if cath_bb  else None, Ge_L)
    record("rib_width",       rib_bb["width"]   if rib_bb   else None, rib_W)
    record("taper_length",    taper_bb["length"]if taper_bb else None, taper_L)

    gap_inner, gap_outer = anode_gaps()
    record("anode_gap_inner", gap_inner, y_anode_in)
    record("anode_gap_outer", gap_outer, y_anode_out)

    record("port_in_x",       pin_x("wg_in"),  -taper_L)
    record("port_out_x",      pin_x("wg_out"),  x_back_max)

    record("Ge_centered_y",   Ge_bb["cy"]    if Ge_bb    else None, 0.0)
    record("Npp_centered_y",  Npp_bb["cy"]   if Npp_bb   else None, 0.0)
    record("ext_centered_y",  ext_bb["cy"]   if ext_bb   else None, 0.0)
    record("cath_centered_y", cath_bb["cy"]  if cath_bb  else None, 0.0)
    record("Ge_x_start",      Ge_bb["x_min"] if Ge_bb    else None, 0.0)
    record("ext_x_start",     ext_bb["x_min"]if ext_bb   else None, 0.0)

    return results
