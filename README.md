# PD-Design-Kit

**Ge-on-Si Photodiode Design Toolkit for Silicon-Based MDM Photonic 400 Gb/s IEEE 802.3 High-Speed Links**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19652934.svg)](https://doi.org/10.5281/zenodo.19652934)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

> **Reference:** Yang Shi et al., *Photonics Research* **12**, 1 (2024) — [DOI: 10.1364/PRJ.504759](https://doi.org/10.1364/PRJ.504759)
> **Targets:** R >= 0.95 A/W · I_d <= 1.3 nA · BW >= 103 GHz · D* >= 2.95 x 10^10 cm·Hz^0.5·W^-1

This repository develops the Ge-on-Si photodetector as a device-level and compact-model building block for a silicon-based mode-division-multiplexed (MDM) photonic 400 Gb/s IEEE 802.3 high-speed link.

---

## Repository Structure

```text
PD-Design-Kit/
|-- device-level/     Lumerical FDTD + CHARGE scripts, MATLAB postprocess, KLayout mask
|-- system-level/     MATLAB PAM-4 transfer model with Wartak computational photonics
|-- thesis/           LaTeX chapter, Marp presentation, figures
|-- CHANGELOG.md      Version history
|-- CITATION.cff      Machine-readable citation
|-- LICENSE           CC BY 4.0
`-- README.md
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
```text
klayout -r ge_pd_layout.rb    ->    ge_pd_layout_oband.gds
```

**Device stack:**

| Layer | Material | Thickness | Doping |
|-------|----------|-----------|--------|
| N++ cathode | Ge | 50 nm | N_D = 10^19 cm^-3 |
| i absorber | Ge | 350 nm | N_D = 10^13 cm^-3 |
| P++ anode | Si | 220 nm | N_A = 10^20 cm^-3 |
| BOX | SiO2 | 2 um | - |

**Data pipeline contract:**

The CHARGE script (`ge_pd_device_oband.lsf`) exports a comprehensive `.mat` file containing:
- Dark and illuminated I-V curves (`V_dk`, `I_dk`, `V_ill`, `I_ill`)
- Electron/hole current components (`In_ill`, `Ip_ill`)
- Scalar metrics (`idx1V`, `Id_1V`, `I_ph`, `R_AW`, `D_star`)
- Geometry parameters (`Ge_L`, `Ge_W`, `iGe_H`, `Npp_H`, `wg_H`)
- Spatial data for band diagrams, carrier densities, doping, electric field, generation rate
- Bandwidth parameters (`RS_paper`, `Cj_paper`, `fBW_U_paper`, `f_t_paper`)

The MATLAB postprocess reads these variables directly — no hardcoded values.

**Requirements:** Lumerical FDTD + DEVICE CHARGE 2020 R2+, MATLAB R2020b+, KLayout

> **Note:** Simulation output `.mat` files (>300 MB) are excluded from git via `.gitignore`. A fresh clone requires running the Lumerical scripts first.

---

## System-Level

End-to-end MATLAB PAM-4 link simulation with physics-based photodetector models from Wartak's *Computational Photonics* (Cambridge, 2013, Ch. 10 & 14), calibrated with device-level results.

```matlab
cd system-level
transfer_model
```

**Physics models (Wartak Ch. 10):**

| Model | Equation | Config Parameter |
|-------|----------|-----------------|
| Quantum efficiency | η(λ) = (1-Rf)(1-exp(-Γα(λ)L)) | `alpha_abs`, `L_absorber`, `Gamma_conf` |
| Transit-time BW | f_tr = 0.45·v_sat/d | `d_depletion`, `v_sat_e`, `v_sat_h` |
| RC bandwidth | f_RC = 1/(2π(Rs+RL)Ctot) | `Rs`, `Cj`, `Cp`, `R_load` |
| Combined BW | 1/f² = 1/f_tr² + 1/f_RC² | — |
| Analytical SNR | SNR = (RP)²/[2q(RP+Id)B + 4kTB/RL] | — |
| Q-factor (PAM-4) | Q = (I₁-I₀)/[(M-1)(σ₁+σ₀)] | — |
| BER | BER = (3/2log₂M)·½·erfc(Q/√2) | — |
| NEP | NEP = √(2qId + 4kT/RL) / R | — |
| Detectivity | D* = R√A / √(2qId + 4kT/RL) | `A_detector` |
| Saturation | hard, smooth I/(1+I/Isat), tanh | `saturation_model` |

**Outputs (9 thesis-ready figures):**

| Figure | Description |
|--------|-------------|
| `system_responsivity_curve` | Spectral responsivity — empirical + Wartak physical model |
| `system_transfer_function` | Transfer function with three saturation models |
| `system_optical_eye` | Optical power eye diagram |
| `system_photocurrent_eye` | Photocurrent eye diagram |
| `system_pam4_histogram` | PAM-4 level histogram with decision thresholds |
| `system_quantum_efficiency` | Ge absorption coefficient + QE vs wavelength |
| `system_bandwidth_budget` | f_tr/f_RC/f_3dB decomposition + QE–length trade-off |
| `system_noise_analysis` | Shot/thermal noise histograms + NEP/D* vs bandwidth |
| `system_ber_vs_power` | BER waterfall (analytical + Monte Carlo) + Q-factor |

**INTERCONNECT export:** The `interconnect_model.m` helper writes a Lumerical INTERCONNECT-ready compact PD model to `system-level/interconnect/`.

**Requirements:** MATLAB R2020b+, Signal Processing Toolbox, Communications Toolbox

---

## Thesis

LaTeX source for the Ge-on-Si photodetector chapter of the MSc group thesis.

| File | Description |
|------|-------------|
| `chapter_photodetector.tex` | Full chapter: architecture, FDTD, CHARGE, system-level, results |
| `chapter_photodetector_slides.md` | Marp presentation companion for the chapter |
| `chapter_photodetector_slides.html` | Rendered HTML presentation generated from the Marp deck |
| `references.bib` | BibTeX entries (Shi 2024, Zenodo, Bogaerts 2012) |

Include in the main thesis document:

```latex
\usepackage{mhchem}          % for \ce{SiO2}
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

## Acknowledgements

This work reproduces and extends the photodetector design presented by Yang Shi et al. in *Photonics Research* Vol. 12, No. 1 (2024). Physics models follow Marek S. Wartak, *Computational Photonics: An Introduction with MATLAB* (Cambridge, 2013). The Lumerical simulation framework was developed as part of a thesis project in Electronics and Communications Engineering at Alexandria University.

---

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) Copyright 2026 Islam I. Abdulaal
DOI: [10.5281/zenodo.19652934](https://doi.org/10.5281/zenodo.19652934)
