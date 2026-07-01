# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

import os
import klayout.db as pya

GDS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ge_pd_layout.gds")

EXPECTED_PORTS = [
    {"name": "wg_in",  "x": -40.0, "y": 0.0, "width": 0.500},
    {"name": "wg_out", "x":  10.56, "y": 0.0, "width": 0.500},
]

TOL_POS   = 0.005
TOL_WIDTH = 0.005

def run():
    layout = pya.Layout()
    layout.read(GDS_PATH)
    top = layout.top_cell()
    dbu = layout.dbu
    results = []

    pinrec_li = layout.find_layer(68, 0)

    def record(name, passed, detail=""):
        results.append({"name": name, "passed": passed, "detail": detail})

    extracted = {}
    if pinrec_li is not None:
        for shape in top.begin_shapes_rec(pinrec_li):
            s = shape.shape()
            if not s.is_text():
                continue
            txt = s.text.string
            for p in EXPECTED_PORTS:
                tag = "INTC_IO_" + p["name"]
                if tag in txt:
                    tx = s.text.trans.disp.x * dbu
                    ty = s.text.trans.disp.y * dbu
                    extracted[p["name"]] = {"x": tx, "y": ty}

        for shape in top.begin_shapes_rec(pinrec_li):
            s = shape.shape()
            if not s.is_box():
                continue
            bb = s.box
            cx = (bb.left + bb.right) / 2 * dbu
            cy = (bb.bottom + bb.top)  / 2 * dbu
            w  = (bb.top - bb.bottom)  * dbu
            for p in EXPECTED_PORTS:
                if p["name"] in extracted:
                    px = extracted[p["name"]]["x"]
                    if abs(cx - px) < TOL_POS:
                        extracted[p["name"]]["width"] = w

    for p in EXPECTED_PORTS:
        name = p["name"]
        if name not in extracted:
            record(f"{name}_found", False, "pin marker not found in PinRec layer")
            continue

        e = extracted[name]

        dx = abs(e["x"] - p["x"])
        record(
            f"{name}_x_position",
            dx <= TOL_POS,
            f"GDS={e['x']:.4f} um  expected={p['x']:.4f} um  delta={dx:.4f} um",
        )

        dy = abs(e["y"] - p["y"])
        record(
            f"{name}_y_position",
            dy <= TOL_POS,
            f"GDS={e['y']:.4f} um  expected={p['y']:.4f} um  delta={dy:.4f} um",
        )

        if "width" in e:
            dw = abs(e["width"] - p["width"])
            record(
                f"{name}_width",
                dw <= TOL_WIDTH,
                f"GDS={e['width']:.4f} um  expected={p['width']:.4f} um  delta={dw:.4f} um",
            )
        else:
            record(f"{name}_width", None, "could not extract width from pin box")

    port_names = [p["name"] for p in EXPECTED_PORTS if p["name"] in extracted]
    if len(port_names) == 2:
        y0 = extracted[port_names[0]]["y"]
        y1 = extracted[port_names[1]]["y"]
        dy = abs(y0 - y1)
        record(
            "ports_colinear_y",
            dy <= TOL_POS,
            f"y_in={y0:.4f} um  y_out={y1:.4f} um  delta={dy:.4f} um",
        )

        x_in  = extracted["wg_in"]["x"]  if "wg_in"  in extracted else None
        x_out = extracted["wg_out"]["x"] if "wg_out" in extracted else None
        if x_in is not None and x_out is not None:
            record(
                "ports_opposing_direction",
                x_in < x_out,
                f"wg_in x={x_in:.4f} um  wg_out x={x_out:.4f} um",
            )

        if "wg_in" in extracted and "wg_out" in extracted:
            w_in  = extracted["wg_in"].get("width")
            w_out = extracted["wg_out"].get("width")
            if w_in is not None and w_out is not None:
                dw = abs(w_in - w_out)
                record(
                    "ports_width_match",
                    dw <= TOL_WIDTH,
                    f"wg_in={w_in:.4f} um  wg_out={w_out:.4f} um  delta={dw:.4f} um",
                )

    return results
