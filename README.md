# PD-Design-Kit

**Ge-on-Si photodiode design toolkit for silicon-photonic high-speed links**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19652934.svg)](https://doi.org/10.5281/zenodo.19652934)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

> Reference: Yang Shi et al., *Photonics Research* **12** (2024), DOI: [10.1364/PRJ.504759](https://doi.org/10.1364/PRJ.504759)
>
> Target benchmark: `R >= 0.95 A/W`, `I_d <= 1.3 nA`, `BW >= 103 GHz`, `D* >= 2.95 x 10^10 Jones`

This repository develops a germanium-on-silicon photodetector as a device-level and compact-model building block for a silicon-based mode-division-multiplexed photonic link.

## Repository Structure

```text
PD-Design-Kit/
|-- device-level/     Lumerical FDTD and CHARGE scripts, MATLAB postprocess, KLayout mask
|-- system-level/     MATLAB PAM-4 transfer model and INTERCONNECT export
|-- thesis/           LaTeX chapter, bibliography, figures, and presentation deck
|-- CHANGELOG.md
|-- CITATION.cff
|-- LICENSE
`-- README.md
```

## Device-Level Flow

Main O-band workflow for the vertical n-i-p Ge-on-Si photodiode:

| Step | Script | Solver | Primary output |
|------|--------|--------|----------------|
| 1 | `ge_pd_fdtd_oband.lsf` | Lumerical FDTD | `fdtd_summary_oband.mat` |
| 2 | `ge_pd_device_oband.lsf` | Lumerical CHARGE | `ge_charge_results_oband.mat` |
| 3 | `ge_pd_oband_postprocess.m` | MATLAB | Thesis-ready data plots in `thesis/figures/` |

Optional sweeps:

| Script | Solver | Output |
|--------|--------|--------|
| `ge_pd_fdtd_oband_optional.lsf` | FDTD | `ge_fdtd_optional_oband.mat` |
| `ge_pd_device_oband_optional.lsf` | CHARGE | `ge_charge_optional_oband.mat` |
| `ge_pd_oband_optional_postprocess.m` | MATLAB | Optional sweep plots in `thesis/figures/` |

GDS generation:

```text
klayout -r ge_pd_layout.rb  ->  ge_pd_layout_oband.gds
```

Nominal device stack:

| Layer | Material | Thickness | Doping |
|-------|----------|-----------|--------|
| `n++` cathode | Ge | 50 nm | `N_D = 1e19 cm^-3` |
| `i` absorber | Ge | 350 nm | `~1e13 cm^-3` |
| `p++` anode platform | Si | 220 nm | `N_A = 1e20 cm^-3` |
| BOX | SiO2 | 2 um | - |

The CHARGE export is the central handoff file. It contains the I-V curves, current components, extracted scalar metrics, geometry values, electrostatic and carrier profiles, generation-rate data, and bandwidth parameters consumed by the MATLAB postprocess and referenced by the thesis chapter.

Requirements:

- Lumerical FDTD Solutions and DEVICE CHARGE 2020 R2 or newer
- MATLAB R2020b or newer
- KLayout

Note: simulation `.mat` outputs are excluded from git. A fresh clone requires rerunning the solver chain.

## System-Level Flow

The `system-level/` directory contains a MATLAB PAM-4 receiver model calibrated to the photodetector physics and an INTERCONNECT-ready compact-model export.

Run:

```matlab
cd system-level
transfer_model
```

Key outputs written to `thesis/figures/`:

- `system_responsivity_curve`
- `system_transfer_function`
- `system_optical_eye`
- `system_photocurrent_eye`
- `system_pam4_histogram`
- `system_quantum_efficiency`
- `system_bandwidth_budget`
- `system_noise_analysis`
- `system_ber_vs_power`
- `system_interconnect_compact_model`

The `interconnect_model.m` helper also writes CSV and MAT compact-model data into `system-level/interconnect/`.

Requirements:

- MATLAB R2020b or newer
- Signal Processing Toolbox
- Communications Toolbox

## Thesis

The `thesis/` directory contains the standalone photodetector chapter plus its presentation companion.

| File | Role |
|------|------|
| `chapter_photodetector.tex` | Main chapter source |
| `references.bib` | BibTeX database |
| `build_photodetector_chapter.ps1` | Standalone PDF build helper |
| `chapter_photodetector_slides.md` | Marp presentation source |
| `chapter_photodetector_slides.html` | Rendered presentation |

The chapter mixes:

- simulation-backed figures exported by the MATLAB workflows
- literature tables and analytical derivations
- figure placeholders with detailed prompts for diagrams that are intended to be produced outside this repo

To include the chapter in a larger thesis:

```latex
\usepackage{mhchem}
\addbibresource{references.bib}
\include{chapter_photodetector}
```

To build the standalone chapter:

```powershell
powershell -ExecutionPolicy Bypass -File thesis/build_photodetector_chapter.ps1
```

To render the presentation:

```powershell
npx @marp-team/marp-cli thesis/chapter_photodetector_slides.md --html --allow-local-files -o thesis/chapter_photodetector_slides.html
```

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

## Acknowledgements

This work reproduces and extends the Ge-on-Si photodetector reported by Yang Shi et al. Physics-based system modeling follows Marek S. Wartak, *Computational Photonics: An Introduction with MATLAB*. The simulation and thesis material were developed within an Electronics and Communications Engineering thesis project at Alexandria University.

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

Copyright 2026 Islam I. Abdulaal

DOI: [10.5281/zenodo.19652934](https://doi.org/10.5281/zenodo.19652934)
