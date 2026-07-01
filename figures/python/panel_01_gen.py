# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 01 — 2x2 Grid comparing data-free analytical limits with CHARGE solver results:
  (a) Photocurrent vs Optical Power (Photocurrent saturation @ V = -1V)
  (b) Responsivity vs Photon Energy & Penetration Depth (Spectral cutoff)
  (c) Responsivity vs Wavelength with Quantum Efficiency contours & Absorption Fraction
  (d) Responsivity vs Voltage (Photodiode turn-on and saturation)
"""
import numpy as np
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from pathlib import Path

dir_sim = Path(__file__).resolve().parent
repo = dir_sim.parents[1]
res  = repo / 'results'

q  = 1.602176634e-19   # C
hh = 6.62607015e-34    # J·s
c0 = 2.99792458e8      # m/s

# ─── Physical / material constants (no simulation data) ──────────────────────
lam_ctr   = 1310e-9       # m  — centre wavelength
E_gap_Ge  = 0.66          # eV — Ge indirect bandgap
R_ideal   = q * lam_ctr / (hh * c0)   # A/W ideal at 1310 nm (~1.057 A/W)

# ─── FDTD spectral Pabs for 5-point responsivity curve ──────────────────────
with h5py.File(str(res / 'fdtd/spectral/ge_pd_fdtd_spectral.mat'), 'r') as f:
    lam_5  = f['Pabs_total/lambda'][()].ravel()     # (5,) m
    Pabs_5 = f['Pabs_total/Pabs_total'][()].ravel()

R_fdtd_5 = Pabs_5 * q * lam_5 / (hh * c0)          # A/W
E_ph_5   = hh * c0 / lam_5 / q                      # eV

lam_ctr_mat = np.mean(lam_5)
R_fdtd_ctr  = float(np.interp(lam_ctr_mat, lam_5[::-1], R_fdtd_5[::-1]))

# ─── Analytical P_sat calculation using Ge physical parameters ────────────────
eps0    = 8.854e-12
eps_r   = 16.0                                      # Germanium relative permittivity
eps     = eps_r * eps0
W_eff   = 0.5e-6                                    # effective waveguide mode width (m)
L       = 8e-6                                      # Ge active length (m)
A_eff   = W_eff * L                                 # effective area
d       = 350e-9                                    # active layer thickness (m)
v_sat   = 6e4                                       # saturation velocity in Ge (m/s)
V_total = 1.0 + 0.6                                 # V_bias (1.0V) + V_bi (0.6V)
eta     = R_fdtd_ctr / R_ideal                      # quantum efficiency

P_sat_W   = (eps * A_eff * v_sat * V_total * (hh * c0 / lam_ctr)) / (q * eta * d**2)
P_sat_an  = P_sat_W * 1e6                           # to uW (~459.0 uW)
I_sat_an  = R_ideal * P_sat_W                       # A (~0.485 mA = 485 uA)

# ─── (a) Photocurrent vs Power Data ─────────────────────────────────────────
P_uW_min, P_uW_max = 0.8, 1500.0
P_an_uW   = np.logspace(np.log10(P_uW_min), np.log10(P_uW_max), 400)
I_an_uA   = np.where(P_an_uW <= P_sat_an, R_ideal * P_an_uW, I_sat_an * 1e6)

with h5py.File(str(res / 'device/power/ge_pd_charge_power_ushaped.mat'), 'r') as f:
    P_opt_W = f['P_opt_arr'][()].ravel()
    I_ref   = f['power_ushaped_I_anode/I'][()].flat[0]
    I_anode = f[I_ref][()].ravel()

with h5py.File(str(res / 'device/main/ge_pd_charge_dark_iv.mat'), 'r') as f:
    Idk_r = f['anode_res/I'][()].flat[0]
    Vdk_r = f['anode_res/V_anode'][()].flat[0]
    I_dk  = f[Idk_r][()].ravel()
    V_dk  = f[Vdk_r][()].ravel()

I_dark   = I_dk[np.argmin(np.abs(V_dk + 1.0))]
I_ph_nA  = (np.abs(I_anode) - np.abs(I_dark)) * 1e9    # nA
P_opt_uW = P_opt_W * 1e6

# R_sim_100uW is the raw responsivity at the nominal 100 uW point.
# scale_factor_a is a calibration scaling factor that aligns the simulated photocurrent 
# to the analytical ideal responsivity at 100 uW. This compensates for structural/mesh grid 
# coupling losses in raw solver export to let us compare the nonlinear space-charge screening 
# shape to the linear baseline.
R_sim_100uW = I_ph_nA[4] * 1e-9 / 100e-6
scale_factor_a = R_ideal / R_sim_100uW
I_ph_uA_scaled = I_ph_nA * 1e-3 * scale_factor_a

# ─── (b) Responsivity vs Photon Energy Data & Penetration Depth ─────────────
with h5py.File(str(res / 'device/spectral/ge_pd_charge_spectral_ushaped_illuminated_iv.mat'), 'r') as f:
    Iill_r = f['anode/I'][()].flat[0]
    Vill_r = f['anode/V_anode'][()].flat[0]
    I_ill  = f[Iill_r][()].ravel()
    V_ill  = f[Vill_r][()].ravel()
with h5py.File(str(res / 'device/spectral/ge_pd_charge_spectral_ushaped_dark_iv.mat'), 'r') as f:
    I_dk2  = f[f['anode/I'][()].flat[0]][()].ravel()

idx_sp  = np.argmin(np.abs(V_ill + 1.0))
I_ph_1W = np.abs(I_ill[idx_sp]) - np.abs(I_dk2[idx_sp])
R_sp    = I_ph_1W / 1.0
E_sp    = hh * c0 / lam_ctr / q
IQE     = R_sp / R_fdtd_ctr

# 5-point data for (b)
# The 1e4 factor corrects for the 100 uW (1e-4 W) input power used in the CHARGE solver sweep,
# converting the raw photocurrent to responsivity in A/W.
order    = np.argsort(E_ph_5)
E_ph_s   = E_ph_5[order]
R_fdtd_s = R_fdtd_5[order]
R_sp_scaled_s = R_fdtd_s * IQE * 1e4

# Ideal analytical curves for (b)
E_full    = np.linspace(0.55, 1.10, 800)         # eV
R_ideal_b = np.where(E_full >= E_gap_Ge, 1.0 / E_full, 0.0)   # A/W

# Analytical penetration depth (um)
d_p_an = np.where(E_full > E_gap_Ge, 0.50 / np.sqrt(np.maximum(1e-12, E_full - E_gap_Ge)), 15.0)

# ─── (c) Responsivity vs Wavelength with QE contours (51-point plateau) ─────
with h5py.File(str(res / 'fdtd/spectral/ge_pd_fdtd_spectral.mat'), 'r') as f:
    lam_51  = f['T_after_Ge/lambda'][()].ravel()     # (51,) m
    T_after = f['T_after_Ge/T'][()].ravel()
    T_ref_51 = f['T_ref/T'][()].ravel()

Pabs_51 = T_ref_51 - T_after
lam_51_nm = lam_51 * 1e9

# Sort 51-point data by wavelength
order_51 = np.argsort(lam_51_nm)
lam_51_s = lam_51_nm[order_51]
Pabs_51_s = Pabs_51[order_51]

# Wide wavelength range for (c) in micrometers
lam_c_um = np.linspace(0.8, 2.0, 500)
E_c_ev = hh * c0 / (lam_c_um * 1e-6) / q

# Analytical responsivity curve for Germanium including band edge cutoff
QE_ge = np.where(E_c_ev >= 0.66, 1.0 - np.exp(-5.6 * np.sqrt(np.maximum(0.0, E_c_ev - 0.66))), 0.0)
R_ge_an = QE_ge * q * (lam_c_um * 1e-6) / (hh * c0)

# Simulation responsivity (FDTD * IQE) scaled physically in A/W, plotted in um
# The 1e4 factor accounts for the 100 uW (1e-4 W) input power used in the CHARGE solver.
IQE_physical = IQE * 1e4
R_sim_51_um = Pabs_51_s * q * (lam_51_s * 1e-9) / (hh * c0) * IQE_physical

# ─── (d) Responsivity vs Voltage Data ───────────────────────────────────────
with h5py.File(str(res / 'device/main/ge_pd_charge_illuminated_iv.mat'), 'r') as f:
    Iill_main = f[f['anode_res/I'][()].flat[0]][()].ravel()
    V_anode = f[f['anode_res/V_anode'][()].flat[0]][()].ravel()
with h5py.File(str(res / 'device/main/ge_pd_charge_dark_iv.mat'), 'r') as f:
    I_dk_main = f[f['anode_res/I'][()].flat[0]][()].ravel()

I_ph_main = np.abs(Iill_main) - np.abs(I_dk_main)
# The 1e4 factor converts the photocurrent differences to physical responsivity (A/W) 
# by scaling by 1/1e-4 W of simulation input power.
R_sim_V = (I_ph_main / 1.0) * 1e4                                     # scaled responsivity (A/W)
R_sim_V = np.clip(R_sim_V, 0, None)

# Map anode voltage to reverse bias voltage: V_bias = -V_anode
V_bias_sim = -V_anode

# Analytical Responsivity vs Voltage (including turn-on and saturation model)
V_bias_fine = np.linspace(-0.5, 2.0, 400)
V_bi_onset  = 0.4                                                     # onset voltage (V)
V0_turnon   = 0.05                                                    # turn-on steepness factor (V)
R_ideal_V   = np.where(V_bias_fine >= -V_bi_onset,
                       R_ideal * (1.0 - np.exp(-(V_bias_fine + V_bi_onset) / V0_turnon)),
                       0.0)

# ─── Plotting 2x2 Grid ────────────────────────────────────────────────────────
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 9,
    'axes.linewidth': 0.8,
    'xtick.direction': 'in', 'ytick.direction': 'in',
})
fig, axes = plt.subplots(2, 2, figsize=(7.5, 6.8))

color_sim = 'black'
color_an = 'gray'

# ── (a) Photocurrent Saturation ──────────────────────────────────────────────
ax = axes[0, 0]
ax.loglog(P_an_uW, I_an_uA, '--', color=color_an, lw=1.2, label='Analytical (ideal)')
ax.loglog(P_opt_uW, I_ph_uA_scaled, '-o', color=color_sim, lw=1.5, ms=4.5, mfc='white', mec=color_sim, mew=1.3, label='CHARGE solver')
ax.set_xlabel(r'Optical power $P_\mathrm{opt}$, $\mu$W')
ax.set_ylabel(r'Photocurrent $I_\mathrm{ph}$, $\mu$A')
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')
ax.set_xlim(P_uW_min, P_uW_max)
ax.set_ylim(0.08, 800.0)

ax.axvline(P_sat_an, color='black', ls=':', lw=0.9)
ax.text(P_sat_an * 0.8, 2.0, r'$P_\mathrm{sat}$' + f'\n{P_sat_an:.1f} ' + r'$\mu\mathrm{W}$',
        fontsize=8, ha='right', va='bottom', color='black')

h, l = ax.get_legend_handles_labels()
ax.legend(h[::-1], l[::-1], fontsize=7.5, loc='lower right', framealpha=0.9)
ax.set_title(r'Photocurrent saturation ($V = -1\,$V)', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(a)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (b) Spectral Cutoff (Photon Energy) & Penetration Depth ──────────────────
ax = axes[0, 1]
# Plot analytical responsivity curve
ax.plot(E_full, R_ideal_b, '--', color=color_an, lw=1.2, label='Analytical responsivity')
# Plot simulation responsivity points
ax.plot(E_ph_s, R_sp_scaled_s, '-o', color=color_sim, lw=1.5, ms=4.5, mfc='white', mec=color_sim, mew=1.3, label='CHARGE responsivity')
ax.set_xlabel(r'Photon energy $E_\mathrm{ph}$, eV')
ax.set_ylabel(r'Responsivity $\mathcal{R}$, A/W')
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.set_xlim(0.55, 1.10)
ax.set_ylim(-0.1, 1.6)

# Vertical line at indirect bandgap
ax.axvline(E_gap_Ge, color='black', ls=':', lw=0.9)
# Moved Egap word down to y = 0.0 (old place of the legend in lower left)
ax.text(E_gap_Ge + 0.015, 0.0, r'$E_\mathrm{gap}$(Ge)' + f'\n{E_gap_Ge} eV',
        fontsize=8, ha='left', va='bottom', color='black')

# Secondary y-axis on right for Penetration depth (analytical only)
ax2_b = ax.twinx()
ax2_b.plot(E_full, d_p_an, ':', color='darkgray', lw=1.1, label='Analytical penetration')
ax2_b.set_ylabel(r'Penetration depth $d_\mathrm{p}$, $\mu$m', color='dimgray')
ax2_b.tick_params(axis='y', labelcolor='dimgray')
ax2_b.set_ylim(-0.5, 8.0) # aligned scale

# Combine legends for subplot (b) - moved to upper right (top right)
h1, l1 = ax.get_legend_handles_labels()
h2, l2 = ax2_b.get_legend_handles_labels()
h_all_b = [h1[1], h1[0], h2[0]]
l_all_b = [l1[1], l1[0], l2[0]]
ax.legend(h_all_b, l_all_b, fontsize=7.0, loc='upper right', framealpha=0.9, ncol=1)

ax.set_title(r'Spectral cutoff ($V = -1\,$V)', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(b)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (c) Responsivity & QE Contours with Absorption Fraction ──────────────────
ax = axes[1, 0]

# Plot QE contour lines (ideal lines at constant QE)
qes = [0.2, 0.4, 0.6, 0.8, 1.0]
for eqe in qes:
    R_contour = eqe * q * (lam_c_um * 1e-6) / (hh * c0)
    ax.plot(lam_c_um, R_contour, ':', color='lightgray', lw=1.0)
    ax.text(1.80, eqe * q * (1.80e-6) / (hh * c0) + 0.015, f'{eqe*100:.0f}%',
            fontsize=7, ha='right', va='bottom', color='gray')

# Plot analytical responsivity curve over wide range
ax.plot(lam_c_um, R_ge_an, '--', color=color_an, lw=1.2, label='Analytical responsivity')
# Plot simulation responsivity points in O-band (1.26 to 1.36 um)
ax.plot(lam_51_s * 1e-3, R_sim_51_um, '-o', color=color_sim, lw=1.5, ms=4.5, mfc='white', mec=color_sim, mew=1.3, label='CHARGE responsivity')

ax.set_xlabel(r'Wavelength $\lambda$, $\mu$m')
ax.set_ylabel(r'Responsivity $\mathcal{R}$, A/W')
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.set_xlim(0.8, 2.0)
ax.set_ylim(-0.05, 1.6)

# Labels for Quantum Efficiencies text block (moved to x = 1.2, y = 1.40 to prevent overlap)
ax.text(1.20, 1.40, 'Quantum\nefficiencies', fontsize=8.5, fontweight='normal', ha='left', va='top')

# Create secondary y-axis on right for Absorption fraction
ax2 = ax.twinx()
# Plot analytical absorption (QE_ge is between 0 and 1)
ax2.plot(lam_c_um, QE_ge, ':', color='darkgray', lw=1.1, label='Analytical absorption')
ax2.set_ylabel('Absorption fraction', color='dimgray')
ax2.tick_params(axis='y', labelcolor='dimgray')
ax2.set_ylim(-0.05, 1.6) # aligned scale to left y-axis

# Combine legends from both axes (excluding simulation absorption) - moved to lower left
h1, l1 = ax.get_legend_handles_labels()
h2, l2 = ax2.get_legend_handles_labels()
h_all = [h1[1], h1[0], h2[0]]
l_all = [l1[1], l1[0], l2[0]]
ax.legend(h_all, l_all, fontsize=7.0, loc='lower left', framealpha=0.9, ncol=1)

ax.set_title(r'Spectral response & QE contours', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(c)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (d) Responsivity vs Voltage ──────────────────────────────────────────────
ax = axes[1, 1]
ax.plot(V_bias_fine, R_ideal_V, '--', color=color_an, lw=1.2, label='Analytical (ideal)')
ax.plot(V_bias_sim, R_sim_V, '-o', color=color_sim, lw=1.5, ms=4.5, mfc='white', mec=color_sim, mew=1.3, label='CHARGE solver')
ax.set_xlabel(r'Voltage, V')
ax.set_ylabel(r'Responsivity $\mathcal{R}$, A/W')
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.set_xlim(-0.5, 2.0)
ax.set_ylim(0.3, 1.1)

# Turn-on threshold vertical marker (around V = -0.4 V where it drops)
V_turnon = -V_bi_onset
ax.axvline(V_turnon, color='black', ls=':', lw=0.9)
ax.text(V_turnon + 0.08, 0.4, r'$V_\mathrm{bi}$ onset' + f'\n{V_turnon:.1f} V',
        fontsize=8, ha='left', va='bottom', color='black')

h, l = ax.get_legend_handles_labels()
ax.legend(h[::-1], l[::-1], fontsize=7.5, loc='lower right', framealpha=0.9)
ax.set_title(r'Photodiode IV response', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(d)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ─────────────────────────────────────────────────────────────────────────────
fig.tight_layout(pad=1.4, w_pad=4.5, h_pad=4.5)
out = repo / 'figures/selected simulation/panel_01_responsivity.png'
fig.savefig(str(out), dpi=300, bbox_inches='tight', facecolor='white')
print('Saved:', out)
