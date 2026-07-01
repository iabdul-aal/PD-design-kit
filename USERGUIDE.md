# User Guide

This project is scoped to Ge-on-Si PIN photodetector device design and characterization for 400 Gb/s intra-data-center optical-link requirements. TIA design, DSP implementation, and link-budget closure are outside the deliverable boundary.

## Environment

The pipeline uses **MATLAB**, **Lumerical** (FDTD / DEVICE / INTERCONNECT), and **KLayout**. No standalone Python installation is required. KLayout's own bundled Python interpreter is used internally by the layout scripts.

Minimum requirements:
- **MATLAB** R2022a or later (with `jsonencode`/`jsondecode` and Java available)
- **Lumerical** 2023 R1 or later (FDTD Solutions, DEVICE, INTERCONNECT)
- **KLayout** 0.28 or later (for post-design GDS validation and DRC/LVS checks)
- **PowerShell** 5.1 or later (ships with Windows 10/11; or PowerShell 7)

## Regenerating Figures

From the repository root in PowerShell:

```powershell
.\ge_pd_autorun.ps1 -Stage figures-only
```

This reads existing `.mat` results and writes:

```text
figures/*/*.png
matlab/cml-bridge/ge_pd_cml_oband_ushaped.mat
matlab/cml-bridge/ge_pd_cml_oband_ushaped.json
```

## Running Solver Stages

Solver stages are available individually:

```powershell
.\ge_pd_autorun.ps1 -Stage fdtd
.\ge_pd_autorun.ps1 -Stage device
.\ge_pd_autorun.ps1 -Stage fdtd-sweeps
.\ge_pd_autorun.ps1 -Stage device-sweeps
.\ge_pd_autorun.ps1 -Stage cml-only
.\ge_pd_autorun.ps1 -Stage interconnect
```

The runner executes each `.lsf` from its own directory so relative output paths resolve into `results/`. The `cml-only` stage synchronizes and verifies the checked-in compiled CML artefacts (via MATLAB), then runs INTERCONNECT. Use `-Stage cml-build` only on a machine with the separate Lumerical CML Compiler entitlement.

## CML Bridge Stages (MATLAB)

The CML bridge scripts are plain MATLAB `.m` files and can be run independently:

```matlab
run('matlab/cml-bridge/sync_cml_bridge.m')   % patches source JSON/MAT from bridge data
run('matlab/cml-bridge/verify_cml_bridge.m') % validates sync; throws on mismatch
```

## Output Locations

| Output | Directory |
|---|---|
| FDTD `.mat` data | `results/fdtd/` |
| DEVICE `.mat` data | `results/device/` |
| Compact-model side data | `results/interconnect/` |
| CML bridge `.mat/.json` | `matlab/cml-bridge/` |
| Figures | `figures/` |
| Optical figures | `figures/Optical/` |
| Electrical figures | `figures/Electrical/` |
| Thermal figures | `figures/Thermal/` |
| Noise figures | `figures/Noise/` |
| Setup views | `figures/Setup/` |
| Combined figures | `figures/Combined/` |
| Layout validation | `klayout/` |

## Unit Conventions

The DEVICE optical-generation import scale factor is `1e6`; keep `set("scale factor", 1e6);` unchanged unless a fresh FDTD-to-CHARGE unit audit proves a different convention.

## Safe Parameter Changes

Change geometry or material parameters in the solver scripts first, rerun the affected solver stage, then rerun `postprocess-only`. Do not edit thesis numbers manually; regenerate them from solver outputs and update the canonical unit table when a unit boundary changes.
