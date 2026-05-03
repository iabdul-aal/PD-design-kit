# Final Alignment Report

## Ground Truth Technical Summary

- `device-level/ge_pd_fdtd_oband_ushaped.lsf` builds the nominal 3D FDTD optical model for a taper-coupled Ge-on-Si vertical n-i-p photodetector at 1310 nm. The implemented nominal geometry is an 8 um x 5 um Ge absorber with 350 nm intrinsic Ge, a 50 nm N++ Ge cap, a 40 um Si taper, and an eight-layer PML boundary setting.
- `device-level/ge_pd_charge_oband_ushaped.lsf` builds the electrical CHARGE model with a 2D X-normal drift-diffusion region normalized over the 8 um absorber length. It runs dark, illuminated, and SSAC analyses from the imported FDTD generation file. The implemented Ge trap-assisted lifetimes are 1 ns for electrons and holes.
- `device-level/*_sweeps.*` implement FDTD length/polarization/taper sweeps and CHARGE sweeps over intrinsic Ge thickness, temperature, and U-shaped versus parallel electrode geometry. The current CHARGE sweep script does not implement SRV or lifetime sweeps.
- `device-level/ge_pd_oband_ushaped_postprocess.m` and `device-level/ge_pd_oband_ushaped_sweeps_postprocess.m` reduce solver `.mat` files into thesis figures and a compact-model dataset for the system-level scripts.
- `system-level/` contains MATLAB DSP and INTERCONNECT compact-model generation plus a KLayout GDS generator. The MATLAB response model uses an auxiliary absorption coefficient of 7e3 cm^-1 at 1310 nm and consumes the generated CML `.mat`.

## Thesis Alignment Changes

- Removed unsupported PINN-as-implemented claims and reframed neural/surrogate design exploration as future work.
- Corrected the CHARGE methodology from a 3D electrical simulation claim to the implemented 2D X-normal drift-diffusion setup.
- Aligned lifetime, absorption, PML, absorber length, capacitance, resistance, and bandwidth statements with the scripts.
- Replaced hard-coded "simulated" result wording with solver-output language where the required `.mat` files are not present in git.
- Fixed the slide deck figure reference from `figures/dark_iv.png` to the generated `figures/elec_dark_iv.png`.
- Updated the README to remove unsupported SRV/lifetime sweep claims and exact figure-count claims.

## Validation Performed In This Checkout

- MATLAB `checkcode` passed cleanly on the repaired post-processing and system-level MATLAB scripts.
- Static repository scan found no generated `.mat`, `.json`, `.csv`, or `thesis/figures` outputs in this checkout.
- `powershell -ExecutionPolicy Bypass -File thesis/build_photodetector_chapter.ps1` completed successfully and regenerated `thesis/photodetector_chapter.pdf`.
- `powershell -ExecutionPolicy Bypass -File thesis/build_photodetector_slides.ps1` completed successfully and regenerated `thesis/photodetector_slides.pdf`; absent figure PNGs are represented by slide-safe placeholders until solver figures are copied in.

## Remaining Risks

- Final numerical thesis results cannot be independently verified in this checkout until the solver-generated `.mat` files are available.
- Lumerical FDTD, CHARGE, INTERCONNECT, and KLayout execution were not performed here.
- The thesis chapter still uses `\missingfigure` placeholders where exported PNGs are absent; these should be replaced by the generated figure files before final submission.
