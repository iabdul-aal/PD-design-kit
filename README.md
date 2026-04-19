# PD-Design-Kit

**Ge-on-Si Photodiode Design Toolkit — O-band PAM-4 Optical Receivers**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19652934.svg)](https://doi.org/10.5281/zenodo.19652934)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

> **Reference:** Yang Shi et al., *Photonics Research* **12**, 1 (2024)  
> **Targets:** R ≥ 0.95 A/W · I_d ≤ 1.3 nA · BW ≥ 103 GHz · D\* ≥ 2.95 × 10¹⁰ cm·Hz^0.5·W⁻¹

---

## Repository Structure

```
PD-Design-Kit/
├── device-level/     Lumerical FDTD + CHARGE scripts and MATLAB postprocess
├── system-level/     MATLAB PAM-4 system-level model (IEEE 802.3bs 400G-DR4)
├── thesis/           LaTeX chapter on the PD design
├── CITATION.cff      Machine-readable citation
├── LICENSE           CC BY 4.0
└── README.md
```

---

## Device-Level

Complete simulation chain for a vertical n-i-p Ge-on-Si photodiode at 1310 nm.

**Run order:**

| Step | Script | Solver | Output |
|------|--------|--------|--------|
| 1 | `ge_pd_fdtd_oband.lsf` | Lumerical FDTD | `ge_gen_oband.mat`, `fdtd_summary_oband.mat` |
| 2 | `ge_pd_device_oband.lsf` | Lumerical CHARGE | `ge_charge_results_oband.mat` |
| 3 | `ge_pd_oband_postprocess.m` | MATLAB | Figures 1–9 |

**Optional parametric sweeps** (run after the main flow):

| Script | Solver | Output |
|--------|--------|--------|
| `ge_pd_fdtd_oband_optional.lsf` | FDTD | `ge_fdtd_optional_oband.mat` |
| `ge_pd_device_oband_optional.lsf` | CHARGE | `ge_charge_optional_oband.mat` |
| `ge_pd_oband_optional_postprocess.m` | MATLAB | Figures 10–16 |

**GDS layout:**
```
klayout -r ge_pd_layout.rb    →    ge_pd_layout_oband.gds
```

**Device stack:**

| Layer | Material | Thickness | Doping |
|-------|----------|-----------|--------|
| N++ cathode | Ge | 50 nm | N_D = 10¹⁹ cm⁻³ |
| i absorber | Ge | 350 nm | N_D = 10¹³ cm⁻³ |
| P++ anode | Si | 220 nm | N_A = 10²⁰ cm⁻³ |
| BOX | SiO₂ | 2 µm | — |

**Requirements:** Lumerical FDTD + DEVICE CHARGE 2020 R2+, MATLAB R2020b+, KLayout

---

## System-Level

End-to-end MATLAB PAM-4 link simulation calibrated with device-level results.
The `system-level` folder is intentionally consolidated into a single `main.m`
entry point plus an `INTERCONNECT` export helper for circuit-ready compact-model data.

```matlab
cd system-level
main       % runs the PAM-4 chain, exports thesis figures, and writes INTERCONNECT-ready PD data
```

**Outputs:** BER, SER, SNR, optical and photocurrent eye diagrams,
responsivity curve, transfer function, thesis-ready figures in `thesis/figures/`,
and a Lumerical `INTERCONNECT` photodetector source-data package in `system-level/interconnect/`.

**Requirements:** MATLAB R2020b+, Signal Processing Toolbox, Communications Toolbox

---

## Thesis

LaTeX source for the Ge-on-Si photodetector chapter of the MSc group thesis.

| File | Description |
|------|-------------|
| `chapter_photodetector.tex` | Full chapter: architecture, FDTD, CHARGE, results |
| `chapter_photodetector_slides.md` | Marp presentation companion for the chapter |
| `chapter_photodetector_slides.html` | Rendered HTML presentation generated from the Marp deck |
| `references.bib` | BibTeX entries (Shi 2024, Zenodo, Bogaerts 2012) |

Include in the main thesis document:
```latex
\addbibresource{references.bib}
\include{chapter_photodetector}
```

Render the presentation with Marp:
```powershell
npx @marp-team/marp-cli thesis/chapter_photodetector_slides.md --html --allow-local-files -o thesis/chapter_photodetector_slides.html
```

---

## Citation

```bibtex
@misc{ibrahim2026pdkit,
  author    = {Abdulaal, Islam I.},
  title     = {{PD-Design-Kit}: Ge-on-Si Photodiode Design Toolkit},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.19652934},
  url       = {https://doi.org/10.5281/zenodo.19652934}
}
```

---

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) © 2026 Islam I. Abdulaal  
DOI: [10.5281/zenodo.19652934](https://doi.org/10.5281/zenodo.19652934)
