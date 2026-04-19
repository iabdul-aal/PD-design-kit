# Changelog

All notable changes to PD-Design-Kit are documented here.

## [1.2.0] - 2026-04-19

### Fixed
- **CHARGE data export**: `ge_pd_device_oband.lsf` now saves all variables that the MATLAB postprocess expects (band energies, carrier densities, doping, electric field, generation rate, dark/illuminated I-V, metrics).
- **Absorption formula**: `ge_pd_fdtd_oband_optional.lsf` now uses `A = 1 - |T| - |R|` (matching the main script) instead of the incorrect `A = 1 - |T|` in Sections A, B, and D.
- **Sign convention**: Unified voltage sign handling across all CHARGE script sections.
- **Hardcoded values**: Eliminated all hardcoded physics constants and geometry from the MATLAB postprocess scripts; everything is now loaded from the MAT files.

### Added
- **SRH recombination**: CHARGE script now explicitly sets SRH recombination parameters for Ge (τ_n = τ_p = 5 ns, calibrated to I_d = 1.3 nA).
- **CHARGE mesh override**: Fine mesh (20 nm max edge) over the Ge active region.
- **`thesis_utils.m`**: Shared thesis figure styling and export utility to eliminate code duplication between postprocess scripts.
- **PAM-4 histogram**: System-level `main.m` now generates a PAM-4 matched-filter-output histogram with decision thresholds.
- **Thesis chapter expansion**: Added figure floats for band diagram, carrier density, electric field, frequency response, optical generation rate map, eye diagrams, and INTERCONNECT model. Added system-level validation section.
- **`CHANGELOG.md`**: Version history (this file).

### Changed
- Postprocess scripts now use `thesis_utils.m` instead of duplicated local functions.
- `ge_pd_oband_postprocess.m` computes `idx1V` from loaded data instead of expecting a pre-saved index.
- Transit-time bandwidth computed from loaded `iGe_H` and `v_sat_Ge` instead of hardcoded values.
- CITATION.cff updated with real ORCID.
- README.md updated with reproduction notes and acknowledgements.

## [1.1.0] - 2026-04-11

### Added
- Initial device-level FDTD and CHARGE simulation scripts.
- System-level MATLAB PAM-4 receiver model with INTERCONNECT export.
- KLayout mask layout script.
- LaTeX thesis chapter and Marp presentation.
- CITATION.cff, LICENSE (CC BY 4.0), README.md.

## [1.0.0] - 2026-04-05

### Added
- Project skeleton and initial FDTD geometry.
