# PD-Design-Kit

**Vertical PIN Taper-Coupled U-Shaped Electrode Ge-on-Si Photodetector for IEEE 802.3 400GBASE-DR4 Intra-Datacenter High-Speed Links**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19652934.svg)](https://doi.org/10.5281/zenodo.19652934)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

> **Reference:** Yang Shi _et al._, "103 GHz germanium-on-silicon photodiode enabled by an optimized U-shaped electrode," _Photonics Research_ **12**(1), 1–6 (2024). DOI: [10.1364/PRJ.495958](https://doi.org/10.1364/PRJ.495958)

A complete, cascaded multiphysics simulation pipeline for a waveguide-integrated Ge-on-Si vertical n-i-p photodiode operating at O-band (1310 nm). The project spans from Maxwell's equations (FDTD optical absorption) through carrier transport (CHARGE drift-diffusion) to system-level PAM-4 receiver performance (MATLAB DSP + Lumerical INTERCONNECT compact model), producing a self-contained thesis chapter with all figures generated directly from solver outputs — **zero hardcoded paper values in the pipeline**.

---

## Design Summary

| Parameter | Value | Source |
|---|---|---|
| Architecture | Vertical n-i-p PIN with U-shaped anode electrode | Geometry |
| Waveguide platform | 220 nm SOI, 90 nm slab | Geometry |
| Optical coupling | Adiabatic taper, 500 nm → 5 µm × 40 µm | Geometry |
| i-Ge absorber | 350 nm × 8 µm × 5 µm | Geometry |
| N++ Ge cathode | 50 nm, Nᴅ = 1×10¹⁹ cm⁻³ | Geometry |
| P++ Si anode | 220 nm, Nᴬ = 1×10²⁰ cm⁻³ | Geometry |
| Operating wavelength | 1310 nm (O-band) | IEEE 802.3 DR4 |
| Responsivity | Extracted from FDTD absorption + CHARGE I-V | Solver |
| Dark current | Extracted from CHARGE steady-state | Solver |
| Bandwidth (f₃dB) | Transit-time × RC model, all parasitics from geometry | Computed |
| Cⱼ (junction) | Parallel-plate: ε_Ge·A/d | Computed |
| Rₛ (series) | Sheet-resistance model + 36% U-shape reduction | Computed |
| Lₚ (on-electrode) | Microstrip inductance from electrode layout | Computed |
| Target standard | IEEE 802.3bs 400GBASE-DR4, 4×106.25 Gb/s PAM-4 | Specification |

---

## Data Pipeline

All performance metrics flow strictly from solvers through the cascade — nothing is injected manually at system level:

```
FDTD (.lsf)  ──►  fdtd_gen.mat (optical generation rate)  ──►  CHARGE (.lsf)
     │                                                               │
     ▼                                                               ▼
fdtd_results.mat                                           charge_results.mat
     │                                                               │
     └──────────────────►  postprocess.m  ◄──────────────────────────┘
                                │
                                ▼
                         CML .mat / .json  ──►  system-level scripts
                                │                (DSP model, INTERCONNECT,
                                ▼                 postprocess, layout)
                        thesis/figures/
```


---

## Repository Structure

```
PD-Design-Kit/
├── device-level/
│   ├── ge_pd_fdtd_oband_ushaped.lsf            FDTD: optical absorption + generation rate
│   ├── ge_pd_charge_oband_ushaped.lsf           CHARGE: carrier transport, I-V, profiles
│   ├── ge_pd_fdtd_oband_ushaped_sweeps.lsf      FDTD sweeps: Ge length, polarisation, taper
│   ├── ge_pd_charge_oband_ushaped_sweeps.lsf     CHARGE sweeps: i-Ge thickness, T, SRV, τ, electrode
│   ├── ge_pd_oband_ushaped_postprocess.m         Base postprocess → 26 figures + CML dataset
│   └── ge_pd_oband_ushaped_sweeps_postprocess.m  Sweep postprocess → 20 figures: trade-offs, octagon, contours
├── system-level/
│   ├── ge_pd_dsp_model.m                         PAM-4 Wartak-based receiver transfer model
│   ├── ge_pd_interconnect_model.m                INTERCONNECT CML compact model generator
│   ├── ge_pd_interconnect_setup.lsf              INTERCONNECT test bench builder
│   ├── ge_pd_interconnect_postprocess.m          System-level figure generation
│   └── ge_pd_layout.py                           KLayout GDSII mask generation
├── thesis/
│   ├── chapter_photodetector_combine.tex         Standalone document (title page, ToC, chapter, bibliography)
│   ├── chapter_photodetector.tex                 Thesis inclusion driver (pulls from sections/)
│   ├── chapter_photodetector_slides.tex          Beamer presentation deck
│   ├── build_photodetector_chapter.ps1           PowerShell script to compile chapter PDF
│   ├── build_photodetector_slides.ps1            PowerShell script to compile slides PDF
│   ├── references.bib                            BibTeX bibliography
│   ├── sections/                                 Modularized "Zero to Hero" chapter content
│   │   ├── sec_introduction.tex                  Introduction and chapter scope
│   │   ├── sec_fundamentals.tex                  Fundamentals of photodetection (Maxwell → SRH)
│   │   ├── sec_metrics.tex                       Performance metrics and design trade-offs
│   │   ├── sec_architectures.tex                 Photodetector architectures and selection rationale
│   │   ├── sec_material.tex                      Material platform: Ge-on-Si
│   │   ├── sec_literature.tex                    Literature review and state of the art
│   │   ├── sec_design.tex                        Proposed device architecture and design rationale
│   │   ├── sec_simulation.tex                    Multiphysics simulation methodology
│   │   ├── sec_results.tex                       Results, discussion, and sensitivity analysis
│   │   └── sec_summary.tex                       Chapter summary and transition
│   └── figures/                                  All exported figures (300 DPI PNG)
├── CITATION.cff
├── LICENSE
└── README.md
```

---

## Execution Order

### Device Level

| Step | Script | Solver | Output |
|:----:|--------|--------|--------|
| 1 | `ge_pd_fdtd_oband_ushaped.lsf` | Lumerical FDTD | `ge_pd_fdtd_results_oband_ushaped.mat` |
| 2 | `ge_pd_charge_oband_ushaped.lsf` | Lumerical CHARGE | `ge_pd_charge_results_oband_ushaped.mat` |
| 3 | `ge_pd_oband_ushaped_postprocess.m` | MATLAB | 26 thesis figures + `ge_pd_cml_oband_ushaped.mat` |
| 4 | `ge_pd_fdtd_oband_ushaped_sweeps.lsf` | Lumerical FDTD | `ge_pd_fdtd_sweeps_oband_ushaped.mat` |
| 5 | `ge_pd_charge_oband_ushaped_sweeps.lsf` | Lumerical CHARGE | `ge_pd_charge_sweeps_oband_ushaped.mat` |
| 6 | `ge_pd_oband_ushaped_sweeps_postprocess.m` | MATLAB | Design octagon, contours, tornado, literature table |

### System Level (reads CML .mat from Step 3)

| Step | Script | Output |
|:----:|--------|--------|
| 7 | `ge_pd_dsp_model.m` | PAM-4 eye, BER, histogram, noise, bandwidth budget |
| 8 | `ge_pd_interconnect_setup.lsf` | INTERCONNECT `.icp` test bench |
| 9 | `ge_pd_interconnect_postprocess.m` | Link-budget and receiver figures |
| 10 | `ge_pd_layout.py` | `ge_pd_layout.gds` |

---

## Key Figures Generated

### Device-Level Base (26 figures)
- Dark/illuminated I-V curves, photocurrent components
- Optical generation rate map, absorption spectrum
- Band diagram, carrier density, electric field profiles (at V = −1 V)
- Responsivity, EQE, IQE vs bias
- Frequency response model (transit-time + RC)
- Transit-time vs RC trade-off (parametric)
- Summary metrics table
- **Doping profile** — net doping (Nᴅ−Nᴀ) vs z, vertical cut
- **C-V characteristic** — junction capacitance vs reverse bias
- **Optical impulse response** — time-domain from FDTD
- **Waveguide input mode profile** — |E|² at Si WG input
- **Taper output mode profile** — |E|² at Ge entrance
- **XY power heatmap** — full device from taper to Ge end
- **Resistance vs bias** — dV/dI from dark I-V

### Sweep Analysis (20 figures)
- **PD Design Octagon** — Razavi-equivalent radar chart: R, BW, D*, EQE, 1/Iᵈ, R×BW, NEP⁻¹, LDR across 5 published designs
- **2D Design-Space Contour Maps** — iGe_H × Ge_L: bandwidth, responsivity, R×BW product with 100 GHz isoline
- **Sensitivity Tornado Chart** — ±20% perturbation ranking of 7 design parameters on bandwidth
- **Literature Benchmarking Table** — state-of-the-art comparison (8 devices, 2012–2024)
- **Resistance vs Ge length** — R_s for parallel vs U-shaped electrodes
- Dark current vs i-Ge thickness, temperature (Arrhenius), SRV, carrier lifetime
- U-shaped vs parallel electrode comparison
- Absorption vs Ge length, spectral responsivity, PDL

### System-Level (10 figures)
- Responsivity curve (wavelength-dependent)
- Optical-to-electrical transfer function
- PAM-4 photocurrent eye diagram at 53.125 GBd
- PAM-4 symbol histogram with decision thresholds
- Quantum efficiency (Wartak model)
- Bandwidth budget breakdown
- Noise analysis (shot + thermal + total)
- BER vs received optical power
- INTERCONNECT compact model E/O response

---

## Design Methodology

This project implements a **photodetector design octagon** — the optoelectronic analogue of Razavi's analog design octagon — providing a structured framework for multi-dimensional trade-off analysis:

1. **Responsivity (R)** — optical absorption efficiency, Ge length dependent
2. **Bandwidth (f₃dB)** — transit-time × RC limit, i-Ge thickness dependent
3. **Dark current (Iᵈ)** — SRH recombination, Ge/SiO₂ interface quality
4. **Detectivity (D\*)** — combined R and Iᵈ sensitivity metric
5. **Quantum efficiency (η)** — photon-to-carrier conversion
6. **R × BW product** — composite speed-efficiency FoM
7. **NEP** — minimum detectable power
8. **Dynamic range** — saturation power vs noise floor

The 2D contour maps and tornado charts enable rapid identification of optimal design points and critical sensitivities, following the systematic methodology of Binkley's _Tradeoffs and Optimization in Analog CMOS Design_ applied to photonic devices.

---

## Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| Lumerical FDTD Solutions | 2020 R2+ | Optical simulation |
| Lumerical DEVICE CHARGE | 2020 R2+ | Electrical simulation |
| MATLAB | R2020b+ | Post-processing, DSP model |
| Signal Processing Toolbox | — | Filter design, spectral analysis |
| Communications Toolbox | — | PAM-4 modulation/detection |
| KLayout + klayout.db (Python) | 0.28+ | GDSII layout generation |
| LaTeX (pdflatex + biber) | TeX Live 2022+ | Thesis chapter compilation |

Simulation `.mat` outputs are excluded from git (see `.gitignore`). A fresh clone requires rerunning the solver chain from Step 1.

---

## Citation

```bibtex
@misc{abdulaal2026pdkit,
  author    = {Abdulaal, Islam I.},
  title     = {{PD-Design-Kit}: Ge-on-Si Vertical PIN Photodetector Design Toolkit
               for 400GBASE-DR4 High-Speed Links},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.19652934},
  url       = {https://doi.org/10.5281/zenodo.19652934}
}
```

## Acknowledgements

This work reproduces and extends the Ge-on-Si vertical photodetector reported by Yang Shi _et al._, _Photonics Research_ **12**(1), 2024. Physics-based receiver modeling follows Marek S. Wartak, _Computational Photonics: An Introduction with MATLAB_. The Lumerical VPD reference example (Ansys Application Gallery) provided the foundational FDTD/CHARGE workflow. The simulation pipeline and thesis material were developed as part of an Electronics and Communications Engineering thesis at Alexandria University.

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — Copyright 2026 Islam I. Abdulaal

DOI: [10.5281/zenodo.19652934](https://doi.org/10.5281/zenodo.19652934)
