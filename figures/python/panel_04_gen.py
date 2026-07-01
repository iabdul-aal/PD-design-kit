# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 04 — 2x2 Grid showing dark current noise and recombination limits:
  (a) Shot Noise vs. Dark Current with Poisson distribution inset (smooth curve)
  (b) Thermal Noise vs. Resistance with Gaussian distribution inset
  (c) Dark Current Density vs. Sidewall Perimeter-to-Area Ratio (Perimeter scaling)
  (d) Recombination Current Densities vs. Excess Carrier Concentration (legend at top left)
"""
import numpy as np
import scipy.io
import scipy.special
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from pathlib import Path

dir_sim = Path(__file__).resolve().parent
repo = dir_sim.parents[1]
res  = repo / 'results'

q   = 1.602176634e-19   # C
kB  = 1.380649e-23      # J/K
hh  = 6.62607015e-34    # J·s
c0  = 2.99792458e8      # m/s
kB_ev = 8.617333262e-5  # eV/K
T0  = 300.0             # K
R_nom = 70.0            # Ohm (load 50 + series 20)

res_dir = res / 'device'

# ─── (a) Load I-V Sweep Data and calculate shot noise vs Id ──────────────────
f_dk_nom = res_dir / 'main/ge_pd_charge_dark_iv.mat'
with h5py.File(str(f_dk_nom), 'r') as f:
    I_ref_dk = f['anode_res/I'][0, 0]
    I_dk_a   = np.abs(f[I_ref_dk][()].ravel())

I_dk_fine = np.logspace(-12, -2, 400)
i_n_shot_an = np.sqrt(2 * q * I_dk_fine) * 1e12 # pA/sqrt(Hz)
i_n_shot_sim = np.sqrt(2 * q * I_dk_a) * 1e12

# ─── (b) Thermal Noise vs. Resistance ────────────────────────────────────────
R_fine = np.logspace(1, 3, 400)
i_n_thermal_an = np.sqrt(4 * kB * T0 / R_fine) * 1e12 # pA/sqrt(Hz)
i_n_thermal_nom = np.sqrt(4 * kB * T0 / R_nom) * 1e12

# ─── (c) Dark Current Density vs. Sidewall Perimeter-to-Area Ratio ───────────
# Width Sweep Data (L = 8 um, W = 2, 4, 6, 8 um)
W_vals = np.array([2.0, 4.0, 6.0, 8.0]) # um
Id_W = np.array([0.3044, 0.5637, 0.8018, 1.0302]) # nA
Area_W = W_vals * 8.0 # um^2
Jd_W = (Id_W / Area_W) * 100.0 # mA/cm^2
Perim_ratio_W = 2.0 / W_vals # um^-1 (2*L / W*L = 2/W lateral sidewall ratio)

# Length Sweep Data (W = 5 um, L = 2, 4, 6, 8 um)
L_vals = np.array([2.0, 4.0, 6.0, 8.0]) # um
Id_L = np.array([0.1710, 0.3422, 0.5133, 0.6842]) # nA
Area_L = L_vals * 5.0 # um^2
Jd_L = (Id_L / Area_L) * 100.0 # mA/cm^2
Perim_ratio_L = np.full_like(L_vals, 2.0 / 5.0) # um^-1 (constant at 0.4)

# Linear regression on Width Sweep points
slope, intercept = np.polyfit(Perim_ratio_W, Jd_W, 1)
x_fit = np.linspace(0.0, 1.2, 200)
y_fit = intercept + slope * x_fit

# ─── (d) Recombination Current Densities vs. Excess Carrier Concentration ────
dn_cm3 = np.logspace(11, 19, 200)    # excess carriers (cm^-3)
V_Ge = 5.0e-4 * 0.35e-4 * 8.0e-4     # Active Ge volume (cm^3)
Area_Ge = 5.0e-4 * 8.0e-4            # Active Ge area W * L (cm^2)
tau_srh = 10e-9                      # SRH lifetime (s)
B_rad = 1e-13                        # Radiative coefficient (cm^3/s)
C_aug = 2e-31                        # Auger coefficient (cm^6/s)

# Recombination current densities in A/cm^2: J = q * d * U
# d = 0.35e-4 cm (active height)
# J_srh = q * d_Ge * (dn / tau_srh)
d_Ge = 0.35e-4
J_srh_Acm2 = q * d_Ge * (dn_cm3 / tau_srh)
J_rad_Acm2 = q * d_Ge * (B_rad * dn_cm3**2)
J_aug_Acm2 = q * d_Ge * (C_aug * dn_cm3**3)
J_total_Acm2 = J_srh_Acm2 + J_rad_Acm2 + J_aug_Acm2

# Nominal point from CHARGE solver (0.224 uA at dn ~ 1e15 cm^-3)
# J = I / Area = 0.224e-6 A / (4e-7 cm^2) = 0.56 A/cm^2
J_sim_nom = 0.224e-6 / Area_Ge

# ─── Plotting ─────────────────────────────────────────────────────────────────
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 9,
    'axes.linewidth': 0.8,
    'xtick.direction': 'in', 'ytick.direction': 'in',
})
fig = plt.figure(figsize=(8.0, 7.2))

# ── (a) Shot Noise vs. Dark Current ──────────────────────────────────────────
ax = fig.add_subplot(2, 2, 1)
# Plot analytical fit as a dashed line first
ax.loglog(I_dk_fine, i_n_shot_an, '--', color='gray', lw=1.2, label='Analytical fit')
# Plot simulation points as markers only (no line) so the dashed line remains visible
ax.loglog(I_dk_a, i_n_shot_sim, 'o', color='black', ms=4.5, mfc='white', mec='black', mew=1.3, label='CHARGE solver')
ax.set_xlabel(r'Dark current $I_\mathrm{d}$, A')
ax.set_ylabel(r'Shot noise NSD, $\mathrm{pA}/\sqrt{\mathrm{Hz}}$')
ax.set_xlim(1e-12, 1e-2)
ax.set_ylim(1e-3, 1e4)
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')

h, l = ax.get_legend_handles_labels()
ax.legend(h[::-1], l[::-1], fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title('Shot Noise vs. Dark Current', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(a)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# Add Poisson distribution inset (smooth curve style like Gaussian, placed in top-left below legend, centered near y = 10^1)
ax_ins_a = ax.inset_axes([0.15, 0.42, 0.35, 0.32])
x_p = np.linspace(0.1, 12, 200)
mu_poisson = 4.0
pdf_p = (mu_poisson**x_p * np.exp(-mu_poisson)) / scipy.special.gamma(x_p + 1.0)
ax_ins_a.plot(x_p, pdf_p, color='black', lw=0.9)
ax_ins_a.fill_between(x_p, pdf_p, color='gray', alpha=0.3)
ax_ins_a.set_title('Poisson distro', fontsize=7, pad=2)
ax_ins_a.tick_params(axis='both', which='both', labelsize=6, pad=1)
ax_ins_a.set_xlim(0, 12)
ax_ins_a.set_ylim(0, 0.22)
ax_ins_a.set_xticks([0, 4, 8, 12])
ax_ins_a.set_yticks([0, 0.1, 0.2])

# ── (b) Thermal Noise vs. Resistance ─────────────────────────────────────────
ax = fig.add_subplot(2, 2, 2)
ax.loglog(R_fine, i_n_thermal_an, '--', color='gray', lw=1.2, label='Analytical fit')
ax.plot(R_nom, i_n_thermal_nom, 'o', color='black', ms=5.0, mfc='white', mec='black', mew=1.5, label='Nominal design')
ax.set_xlabel(r'Equivalent resistance $R_\mathrm{eq}$, $\Omega$')
ax.set_ylabel(r'Thermal noise NSD, $\mathrm{pA}/\sqrt{\mathrm{Hz}}$')
ax.set_xlim(10, 1000)
ax.set_ylim(1.0, 50.0)
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')

h, l = ax.get_legend_handles_labels()
ax.legend(h[::-1], l[::-1], fontsize=7.5, loc='upper right', framealpha=0.9)
ax.set_title('Thermal Noise vs. Resistance', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(b)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# Add Gaussian distribution inset (bottom-left)
ax_ins_b = ax.inset_axes([0.12, 0.12, 0.38, 0.35])
x_g = np.linspace(-3, 3, 200)
pdf_g = np.exp(-x_g**2 / 2.0) / np.sqrt(2 * np.pi)
ax_ins_b.plot(x_g, pdf_g, color='black', lw=0.9)
ax_ins_b.fill_between(x_g, pdf_g, color='gray', alpha=0.3)
ax_ins_b.set_title('Gaussian distro', fontsize=7, pad=2)
ax_ins_b.tick_params(axis='both', which='both', labelsize=6, pad=1)
ax_ins_b.set_xticks([-3, 0, 3])
ax_ins_b.set_yticks([0, 0.2, 0.4])

# ── (c) Dark Current Density vs. Sidewall Perimeter-to-Area Ratio ────────────
ax = fig.add_subplot(2, 2, 3)
ax.plot(x_fit, y_fit, '--', color='gray', lw=1.2, label='Linear fit')
ax.plot(Perim_ratio_W, Jd_W, 'o', color='black', ms=4.5, mfc='white', mec='black', mew=1.3, label='Width sweep')
ax.plot(Perim_ratio_L, Jd_L, 's', color='dimgray', ms=4.5, mfc='white', mec='dimgray', mew=1.3, label='Length sweep')

# Labels and layout
ax.set_xlabel(r'Sidewall perimeter-to-area ratio $P_\mathrm{side}/A$, $\mu\mathrm{m}^{-1}$')
ax.set_ylabel(r'Dark current density $J_\mathrm{d}$, $\mathrm{mA/cm}^2$')
ax.set_xlim(0.0, 1.25)
ax.set_ylim(1.4, 2.0)
ax.grid(True, ls=':', lw=0.5, color='gray')

# Extrapolate to intercept (y-intercept is pure bulk leakage).
ax.axhline(intercept, color='black', ls=':', lw=0.9)
ax.text(0.10, intercept - 0.02, r'$J_\mathrm{bulk} = $' + f'{intercept:.2f} ' + r'$\mathrm{mA/cm}^2$',
        fontsize=8.0, ha='left', va='top', color='black')

# Convert slope from (mA/cm^2)*um to nA/cm: slope_nA_cm = slope * 100
J_surf_val = slope * 100.0
ax.text(0.10, intercept - 0.07, r'$J_\mathrm{surface} = $' + f'{J_surf_val:.1f} ' + r'$\mathrm{nA/cm}$',
        fontsize=8.0, ha='left', va='top', color='black')

ax.legend(fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title('Bulk vs. Surface Current Scaling', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(c)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (d) Recombination Current Densities vs. Excess Carrier Concentration ────
ax = fig.add_subplot(2, 2, 4)
ax.plot(dn_cm3, J_rad_Acm2, '-.', color='gray', lw=1.2, label=r'Radiative ($J_\mathrm{rad}$)')
ax.plot(dn_cm3, J_aug_Acm2, ':', color='lightgray', lw=1.2, label=r'Auger ($J_\mathrm{aug}$)')
# Plot Combined first, and then SRH on top using zorder to ensure it is visible
ax.plot(dn_cm3, J_total_Acm2, '-', color='black', lw=1.8, label=r'Combined ($J_\mathrm{combined}$)')
ax.plot(dn_cm3, J_srh_Acm2, '--', color='dimgray', lw=1.2, label=r'SRH ($J_\mathrm{SRH}$)', zorder=4)

# Add nominal CHARGE solver point
ax.plot(1e15, J_sim_nom, 'o', color='black', ms=5.0, mfc='white', mec='black', mew=1.5, label='CHARGE solver', zorder=5)

ax.set_xlabel(r'Excess carrier concentration $\Delta n$, $\mathrm{cm}^{-3}$')
ax.set_ylabel(r'Recombination density $J_{\mathrm{recomb}}$, $\mathrm{A/cm}^2$')
ax.set_xscale('log')
ax.set_yscale('log')
ax.set_xlim(1e11, 1e19)
ax.set_ylim(1e-6, 1e8)
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')

h_d, l_d = ax.get_legend_handles_labels()
# Rearrange legend handles to show: CHARGE solver, SRH, Radiative, Auger, Combined
h_d_ordered = [h_d[4], h_d[3], h_d[0], h_d[1], h_d[2]]
l_d_ordered = [l_d[4], l_d[3], l_d[0], l_d[1], l_d[2]]
ax.legend(h_d_ordered, l_d_ordered, fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title('Recombination Current Densities', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(d)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ─────────────────────────────────────────────────────────────────────────────
fig.subplots_adjust(left=0.08, right=0.95, bottom=0.08, top=0.92, wspace=0.30, hspace=0.30)
out = repo / 'figures/selected simulation/panel_04_noise.png'
fig.savefig(str(out), dpi=300, bbox_inches='tight', facecolor='white')
print('Saved:', out)
