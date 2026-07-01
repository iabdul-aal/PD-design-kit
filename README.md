# PD-Design-Kit

**Ge-on-Si PIN Photodetector — Modeling, Simulation and Design for IEEE 802.3bs DR4 Link Integration**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21089184.svg)](https://doi.org/10.5281/zenodo.21089184)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

A complete, cascaded multiphysics simulation pipeline for a waveguide-integrated Ge-on-Si vertical PIN photodiode operating at O-band (1310 nm). The project spans from Maxwell's equations (FDTD optical absorption) through carrier transport (CHARGE drift-diffusion) to system-level PAM-4 receiver performance (Lumerical INTERCONNECT compact model). Solver-derived metrics flow strictly through the pipeline — nothing is injected manually at system level.

---

## Design Summary

| Parameter | Value | Source |
|---|---|---|
| Architecture | Vertical n-i-p PIN with U-shaped anode electrode | Geometry |
| Waveguide platform | 220 nm SOI, 90 nm slab | Geometry |
| Optical coupling | Adiabatic taper, 500 nm → 5 µm × 40 µm | Geometry |
| i-Ge absorber | 350 nm × 8 µm × 5 µm | Geometry |
| N++ Ge cathode | 50 nm, N_D = 1×10²⁰ cm⁻³ | Geometry |
| P++ Si anode | 220 nm, N_A = 1×10²⁰ cm⁻³ | Geometry |
| Operating wavelength | 1310 nm (O-band) | IEEE 802.3bs DR4 |
| Responsivity (CHARGE) | 0.931 A/W, EQE 88.08% | Solver |
| Dark current at −1 V | 0.684 nA | Solver |
| 3dB Bandwidth | 89.7 GHz (with inductive peaking) | Solver |
| Junction capacitance | 11.87 fF | Solver |
| Specific Detectivity D* | 3.41×10¹⁰ Jones | Computed |
| PAM-4 BER floor | 4.93×10⁻³ at +3 dBm | INTERCONNECT |
| Target standard | IEEE 802.3bs 400GBASE-DR4, 4×106.25 Gb/s PAM-4 | Specification |

---

## Data Pipeline

All performance metrics flow strictly from solvers through the cascade:

```
FDTD (.lsf)  ──►  results/fdtd/          ──►  CHARGE (.lsf)
     │                                               │
     ▼                                               ▼
 fdtd results                              charge results
     │                                               │
     └──────────────►  matlab/post_cml_bridge.m  ◄───┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
             CML .json / .mat           INTERCONNECT CSVs
                    │                   (resp / BW / Idark)
                    ▼
      lumerical/interconnect/models/
      (source JSON + LSF scripts)
```

---

## Repository Structure

```text
PD-Design-Kit/
├── lumerical/
│   ├── fdtd/
│   │   └── scripts/          FDTD simulation scripts (main + sweeps)
│   ├── device/
│   │   └── scripts/          CHARGE simulation scripts (main + sweeps)
│   └── interconnect/
│       ├── scripts/          INTERCONNECT setup script
│       └── models/           CML model source (LSF + ICP) and QA scripts
├── matlab/
│   └── post_cml_bridge.m     Reads solver results → writes CML JSON/MAT + INTERCONNECT CSVs
├── figures/
│   ├── tikz/                 TikZ source files for all conceptual diagrams (used in chapter)
│   └── selected simulation/  Python panel generators for simulation result figures
├── klayout/                  Post-design GDS validation and DRC/LVS checks (Python)
├── preprint_photodetector_solo.pdf   Solo-author chapter preprint (PDF)
├── preprint_slides_solo.pdf          Solo-author slides preprint (PDF)
├── docs slides.pdf                   Presentation: Modeling, Simulation and Design of a
│                                     Ge-on-Si PIN Photodetector — IEEE 802.3bs DR4 Link Integration
└── README.md
```

---

## Key Scripts

| Stage | Script | Main output |
|---|---|---|
| FDTD base | `lumerical/fdtd/scripts/main.lsf` | `results/fdtd/` solver MAT files |
| FDTD sweeps | `lumerical/fdtd/scripts/sweep_GeH/L/W/spectral.lsf` | sweep MAT files |
| CHARGE base | `lumerical/device/scripts/main/01_build.lsf` … `07_export_spatial.lsf` | `results/device/` solver MAT files |
| CHARGE sweeps | `lumerical/device/scripts/sweep_charge_*.lsf` | sweep MAT files |
| CML bridge | `matlab/post_cml_bridge.m` | `lumerical/interconnect/models/source/` JSON + MAT + INTERCONNECT CSVs |
| INTERCONNECT | `lumerical/interconnect/scripts/main_interconnect.lsf` | PAM-4 eye / BER data |
| CML model source | `lumerical/interconnect/models/source/ge_pd_cml_oband_ushaped/` | `.lsf` + `.icp` model + QA scripts |
| Figure generators | `figures/selected simulation/panel_*.py` | simulation result panel PNGs |
| Conceptual figures | `figures/tikz/*.tex` | TikZ PDF figures for chapter |
| Layout validation | `klayout/run_checks.py` | DRC/LVS pass/fail log |

---

## Toolchain

| Tool | Purpose |
|---|---|
| Lumerical FDTD | Optical absorption, generation rate, field profiles |
| Lumerical DEVICE/CHARGE | Drift-diffusion, I-V, carrier profiles, SSAC/transient data |
| Lumerical INTERCONNECT | CML compact model, PAM-4 eye diagram, BER |
| MATLAB | CML bridge sync/verify, INTERCONNECT CSV export |
| KLayout (built-in Python API) | Post-design GDS validation and DRC/LVS checks |
| LaTeX + TikZ | Thesis chapter figures and defense slides |

---

## Compact Model (CML) Bridge

`matlab/post_cml_bridge.m` is the sole bridge between physics solvers and the INTERCONNECT compact model. It:

1. Reads CHARGE dark I-V, illuminated I-V, SSAC, and transient results
2. Reads FDTD transmission spectra and optical generation rate
3. Computes: responsivity, dark current, junction capacitance, 3dB bandwidth, saturation power
4. Writes `lumerical/interconnect/models/source/ge_pd_cml_oband_ushaped/ge_pd_cml_oband_ushaped.json` and `.mat`
5. Exports INTERCONNECT-ready CSV tables: responsivity spectrum, bandwidth vs. bias, dark current vs. bias, and a parameter summary
6. Runs a self-consistency check — errors if any field is missing or mismatched



---

## Citation

```bibtex
@misc{ibrahim2026pdkit,
  author    = {Ibrahim, Islam},
  title     = {{PD-Design-Kit}: Ge-on-Si PIN Photodetector Modeling, Simulation and Design
               for IEEE 802.3bs DR4 Link Integration},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.21089184},
  url       = {https://doi.org/10.5281/zenodo.21089184},
  note      = {Thesis chapter simulation kit, Alexandria University}
}
```

## License

CC BY 4.0.
