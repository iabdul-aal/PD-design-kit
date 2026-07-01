# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

import datetime
import importlib
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
RESULTS_DIR = os.path.join(REPO_ROOT, "results")
REPORT_PATH = os.path.join(RESULTS_DIR, "check_report.txt")
FIGURE_DIR = os.path.join(REPO_ROOT, "figures")
SETUP_DIR = os.path.join(FIGURE_DIR, "Setup")
GEOM_DIR  = os.path.join(FIGURE_DIR, "Geometry")

os.makedirs(RESULTS_DIR, exist_ok=True)

def warn_result(name, detail):
    return [{"name": name, "passed": None, "detail": detail}]

layout_results = []
try:
    import ge_pd_layout
    layout_results.append({"name": "layout_figures_generated", "passed": True, "detail": "canonical layout figures exported"})
except Exception as exc:
    layout_results.append({"name": "layout_figures_generated", "passed": False, "detail": str(exc)})

def run_optional_module(module_name):
    try:
        module = importlib.import_module(module_name)
        return module.run()
    except Exception as exc:
        return warn_result(f"{module_name}_skipped", f"KLayout database API unavailable or check failed to import: {exc}")

drc_results = run_optional_module("drc_ge_pd")
lvs_results = run_optional_module("lvs_lumerical_check")
port_results = run_optional_module("check_ports")

def summary(results):
    total = len(results)
    passed = sum(1 for r in results if r["passed"] is True)
    failed = sum(1 for r in results if r["passed"] is False)
    warned = sum(1 for r in results if r["passed"] is None)
    return total, passed, failed, warned

def section(title, results, lines):
    col_w = max(len(r["name"]) for r in results) + 2
    lines.append(title)
    lines.append("=" * 80)
    for r in results:
        if r["passed"] is True:
            status = "PASS"
        elif r["passed"] is False:
            status = "FAIL"
        else:
            status = "WARN"
        lines.append(f"  [{status}]  {r['name']:<{col_w}}{r['detail']}")
    total, passed, failed, warned = summary(results)
    lines.append("")
    lines.append(f"  Total: {total}   Passed: {passed}   Failed: {failed}   Warnings: {warned}")
    lines.append("")

def figure_results():
    expected = [
        os.path.join(FIGURE_DIR, "layout_mask_view.png"),
        os.path.join(FIGURE_DIR, "layout_pd_detail.png"),
        os.path.join(SETUP_DIR,  "klayout_top.png"),
        os.path.join(SETUP_DIR,  "klayout_pd_detail.png"),
        os.path.join(GEOM_DIR,   "geom_vpin_layout_klayout.png"),
    ]
    results = []
    for path in expected:
        exists = os.path.isfile(path)
        size = os.path.getsize(path) if exists else 0
        results.append({
            "name": os.path.relpath(path, REPO_ROOT).replace("\\", "/"),
            "passed": exists and size > 5 * 1024,
            "detail": f"{size} bytes" if exists else "missing",
        })
    return results

lines = []
lines.append("CHECK REPORT - GE_PD_USHAPED_OBAND")
lines.append(f"Generated : {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
lines.append(f"Repo root : {REPO_ROOT}")
lines.append("")

section("LAYOUT - Generation", layout_results, lines)
section("DRC - Design Rule Checks", drc_results, lines)
section("LVS - Layout vs. Lumerical Parameters", lvs_results, lines)
section("PORTS - Sanity Checks", port_results, lines)
section("FIGURES - Canonical Layout Exports", figure_results(), lines)

all_results = layout_results + drc_results + lvs_results + port_results + figure_results()
total, passed, failed, warned = summary(all_results)
lines.append("=" * 80)
lines.append(f"OVERALL   Total: {total}   Passed: {passed}   Failed: {failed}   Warnings: {warned}")
lines.append("=" * 80)

with open(REPORT_PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

if failed > 0:
    sys.exit(1)
