# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

import os
import klayout.db as pya

GDS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ge_pd_layout.gds")

WIDTH_RULES = [
    ("Ge_min_width",    10, 0, 1.000),
    ("Npp_min_width",   11, 0, 0.300),
    ("Ppp_min_width",   12, 0, 0.300),
    ("ext_min_width",    4, 0, 0.500),
    ("rib_min_width",    2, 0, 0.300),
    ("slab_min_width",   1, 0, 1.000),
    ("cath_min_width",  20, 0, 0.200),
    ("anode_min_width", 21, 0, 0.400),
]

SPACE_RULES = [
    ("Ge_min_space",   10, 0, 1.000),
    ("Npp_min_space",  11, 0, 0.300),
    ("cath_min_space", 20, 0, 0.300),
]

ENCLOSURE_RULES = [
    ("Npp_in_Ge",    10, 0, 11, 0, 0.100),
    ("Ge_in_ext",     4, 0, 10, 0, 0.100),
    ("cath_in_Npp",  11, 0, 20, 0, 0.100),
    ("anode_clr_Ge", 10, 0, 21, 0, 0.500),
]

OVERLAP_RULES = [
    ("Ppp_no_Ge",     12, 0, 10, 0),
    ("Ppp_no_Npp",    12, 0, 11, 0),
    ("cath_no_anode", 20, 0, 21, 0),
]

def run():
    layout = pya.Layout()
    layout.read(GDS_PATH)
    top = layout.top_cell()
    dbu = layout.dbu
    results = []

    def region(ln, dt):
        r = pya.Region()
        li = layout.find_layer(ln, dt)
        if li is not None:
            r.insert(top.begin_shapes_rec(li))
        return r

    def to_dbu(v):
        return int(round(v / dbu))

    def record(name, passed, detail=""):
        results.append({"name": name, "passed": passed, "detail": detail})

    for name, ln, dt, val in WIDTH_RULES:
        v = region(ln, dt).width_check(to_dbu(val))
        record(name, v.is_empty(), f"min_width={val} um" + (f"  violations={v.count()}" if not v.is_empty() else ""))

    for name, ln, dt, val in SPACE_RULES:
        v = region(ln, dt).space_check(to_dbu(val))
        record(name, v.is_empty(), f"min_space={val} um" + (f"  violations={v.count()}" if not v.is_empty() else ""))

    for name, ln_out, dt_out, ln_in, dt_in, enc in ENCLOSURE_RULES:
        outer = region(ln_out, dt_out)
        inner = region(ln_in, dt_in)
        violation = inner.sized(to_dbu(enc)) - outer
        record(name, violation.is_empty(), f"enclosure={enc} um")

    for name, ln_a, dt_a, ln_b, dt_b in OVERLAP_RULES:
        overlap = region(ln_a, dt_a) & region(ln_b, dt_b)
        record(name, overlap.is_empty(), "no overlap required")

    return results
