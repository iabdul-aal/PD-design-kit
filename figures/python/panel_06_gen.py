# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 06 — 2x2 Grid showing advanced electro-optic bandwidth sweeps and limits:
  (a) 3D Design Space Landscape (Height, Width, Length) showing cutoff frequency
  (b) Cutoff Frequency & Capacitance vs. Bias Voltage (Transit limit, RC limit, and Cj)
  (c) Cutoff Frequency vs. Optical Power (Space-charge screening roll-off)
  (d) Cutoff Frequency vs. Background Doping Concentration (Depletion limit)
"""
import numpy as np
import scipy.interpolate
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from pathlib import Path

dir_sim = Path(__file__).resolve().parent
repo = dir_sim.parents[1]
res  = repo / 'results'

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS & PARAMETERS
# ═══════════════════════════════════════════════════════════════════════════════
q       = 1.602176634e-19  # C
eps_0   = 8.854e-12        # F/m
eps_r   = 16.0             # Ge relative permittivity
Rload   = 50.0             # Ω
Lp_nom  = 300e-12          # H
Cp_nom  = 9.78e-15         # F
H_nom   = 350e-9           # m
L_nom   = 8e-6             # m
W_ge    = 3.665e-6         # m
v_sat   = 240000.0         # m/s (effective saturation velocity)
Vbi     = 0.6              # V

# ═══════════════════════════════════════════════════════════════════════════════
# DATA EXTRACTION HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
def get_rlc_bandwidth(Rs, Lp, Ctot, Rload=50.0):
    R_t = Rs + Rload
    a = (Lp * Ctot)**2
    b = (R_t * Ctot)**2 - 2.0 * Lp * Ctot
    c = -1.0
    if isinstance(Ctot, np.ndarray):
        disc = b**2 - 4.0 * a * c
        x = (-b + np.sqrt(disc)) / (2.0 * a)
        return np.sqrt(np.maximum(x, 0.0)) / (2.0 * np.pi)
    else:
        if a == 0:
            return 1.0 / (2.0 * np.pi * R_t * Ctot)
        disc = b**2 - 4.0 * a * c
        x = (-b + np.sqrt(disc)) / (2.0 * a)
        return np.sqrt(max(x, 0.0)) / (2.0 * np.pi)

def get_bandwidth_from_file(fpath, Cj=None):
    """Interpolate small-signal AC current and calculate the -3 dB bandwidth."""
    if Cj is None:
        Cj = eps_r * eps_0 * W_ge * L_nom / H_nom  # Nominal Cj
    freq_grid_hz = np.linspace(0.1e9, 200e9, 1000)
    with h5py.File(fpath, 'r') as fm:
        # Support both main dataset ('ac_anode') and sweep dataset ('ssac_I_anode')
        if 'ac_anode' in fm:
            freq_raw = fm[fm['ac_anode/f'][0, 0]][()].ravel()
            dI_ref   = fm['ac_anode/dI'][0, 0]
            dI_raw   = fm[dI_ref]['real'].ravel() + 1j * fm[dI_ref]['imag'].ravel()
        else:
            freq_raw = fm[fm['ssac_I_anode/f'][0, 0]][()].ravel()
            I_ref    = fm['ssac_I_anode/I'][0, 0]
            dI_raw   = fm[I_ref]['real'].ravel() + 1j * fm[I_ref]['imag'].ravel()

    # Spline interpolation to frequency grid
    spl_r = scipy.interpolate.make_interp_spline(freq_raw, np.real(dI_raw), k=3)
    spl_i = scipy.interpolate.make_interp_spline(freq_raw, np.imag(dI_raw), k=3)
    dI_fine = spl_r(freq_grid_hz) + 1j * spl_i(freq_grid_hz)

    # Apply compact-model parasitics using correct Cj
    Y_tot_fine = 1j * 2 * np.pi * freq_grid_hz * (Cj + Cp_nom)
    denom_fine = 1.0 + Y_tot_fine * (Rload + 1j * 2 * np.pi * freq_grid_hz * Lp_nom)
    resp_fine  = dI_fine / denom_fine
    resp_db    = 20 * np.log10(np.abs(resp_fine) / np.abs(resp_fine[0]))

    # Find first crossing below -3 dB
    idx = np.where(resp_db <= -3.0)[0]
    if len(idx) > 0:
        i0 = idx[0]
        f0, f1 = freq_grid_hz[i0-1], freq_grid_hz[i0]
        d0, d1 = resp_db[i0-1], resp_db[i0]
        return (f0 + (f1 - f0) * (-3.0 - d0) / (d1 - d0)) * 1e-9
    return 200.0

# ═══════════════════════════════════════════════════════════════════════════════
# (a) 3D Landscape Data & Simulated Points
# ═══════════════════════════════════════════════════════════════════════════════
# Analytical model grid
W_vals_3d = np.linspace(2e-6, 8e-6, 8)
H_vals_3d = np.linspace(200e-9, 400e-9, 8)
L_vals_3d = np.linspace(2e-6, 8e-6, 8)
W_grid, H_grid, L_grid = np.meshgrid(W_vals_3d, H_vals_3d, L_vals_3d, indexing='ij')

f_tr_grid = (0.443 * v_sat / H_grid) * 1e-9
Cj_grid = eps_r * eps_0 * W_grid * L_grid / H_grid
Ctot_grid = Cj_grid + Cp_nom
f_RLC_grid = get_rlc_bandwidth(0.0, Lp_nom, Ctot_grid, Rload) * 1e-9
bw_grid = 1.0 / np.sqrt(1.0 / f_tr_grid**2 + 1.0 / f_RLC_grid**2)

# Load real simulated sweep points
w_sim_vals = np.array([2e-6, 4e-6, 6e-6, 8e-6])
w_bw = np.array([get_bandwidth_from_file(res / f'device/GeW/ge_pd_charge_GeW_{w}um_ssac.mat', Cj=eps_r * eps_0 * (w * 1e-6) * L_nom / H_nom) for w in [2, 4, 6, 8]])

l_sim_vals = np.array([2e-6, 4e-6, 6e-6, 8e-6])
l_bw = np.array([get_bandwidth_from_file(res / f'device/GeL/ge_pd_charge_GeL_{l}um_ssac.mat', Cj=eps_r * eps_0 * W_ge * (l * 1e-6) / H_nom) for l in [2, 4, 6, 8]])

h_sim_vals = np.array([200e-9, 300e-9, 400e-9])
h_bw = np.array([get_bandwidth_from_file(res / f'device/GeH/ge_pd_charge_GeH_{h}nm_ssac.mat', Cj=eps_r * eps_0 * W_ge * L_nom / (h * 1e-9)) for h in [200, 300, 400]])

# ═══════════════════════════════════════════════════════════════════════════════
# (b) Cutoff Frequency & Capacitance vs Bias Voltage
# ═══════════════════════════════════════════════════════════════════════════════
V_sim = np.array([-0.5, -1.0, -1.5, -2.0, -2.5])
# Get simulated bandwidths for main bias points
bw_sim = np.zeros_like(V_sim)
Cj_sim = np.zeros_like(V_sim)
for idx, name in enumerate(['V1', 'V2', 'V3', 'V4', 'V5']):
    # Extract simulated capacitance from SSAC capacitance run
    fpath_cap = res / f'device/main/ge_pd_charge_capacitance_{name}.mat'
    with h5py.File(fpath_cap, 'r') as fm:
        freq_cap = fm[fm['ac_anode/f'][0, 0]][()].ravel()[0]
        dI_ref    = fm['ac_anode/dI'][0, 0]
        dI_cap    = fm[dI_ref]['real'].ravel()[0] + 1j * fm[dI_ref]['imag'].ravel()[0]
    Cj_sim[idx] = (np.imag(dI_cap * 1e3) / (2 * np.pi * freq_cap)) * 1e15 # fF
    
    fpath_ssac = res / f'device/main/ge_pd_charge_ssac_{name}.mat'
    bw_sim[idx] = get_bandwidth_from_file(fpath_ssac, Cj=Cj_sim[idx]*1e-15)

# Analytical bias models
V_fine = np.linspace(-2.5, 0.0, 100)
# C-V fit model: Cj0 = 12.8 fF, m = 0.071
Cj_an_fine = 12.80 / (1.0 - V_fine / Vbi)**0.071
f_RLC_fine = get_rlc_bandwidth(0.0, Lp_nom, Cj_an_fine * 1e-15 + Cp_nom, Rload) * 1e-9

# Transit limit model with sharp drop at 0V (diffusion limit)
f_tr_sat = (0.443 * v_sat / H_nom) * 1e-9
f_tr_fine = f_tr_sat * (1.0 - np.exp(-10.0 * (-V_fine))) + 13.0
f_comb_fine = 1.0 / np.sqrt(1.0 / f_tr_fine**2 + 1.0 / f_RLC_fine**2)

# ═══════════════════════════════════════════════════════════════════════════════
# (c) Cutoff Frequency vs Optical Power
# ═══════════════════════════════════════════════════════════════════════════════
P_dBm = np.linspace(-20.0, 15.0, 100)
P_W = 10**((P_dBm - 30.0) / 10.0)
P_crit = 5.0e-3 # 5 mW critical power (approx +7 dBm)
# Space charge screening rolls off saturation velocity
v_power = v_sat / (1.0 + (P_W / P_crit)**2)
f_tr_power = (0.443 * v_power / H_nom) * 1e-9
f_RLC_nom = get_rlc_bandwidth(0.0, Lp_nom, Cj_sim[1]*1e-15 + Cp_nom, Rload) * 1e-9
f_comb_power = 1.0 / np.sqrt(1.0 / f_tr_power**2 + 1.0 / f_RLC_nom**2)

# ═══════════════════════════════════════════════════════════════════════════════
# (d) Cutoff Frequency vs Background Doping Concentration
# ═══════════════════════════════════════════════════════════════════════════════
# Extract doping sweep simulated points
f_doping_ssac = res / 'device/doping/ge_pd_charge_doping_ssac_ushaped.mat'
doping_bw = np.zeros(4)
with h5py.File(f_doping_ssac, 'r') as fm:
    freq_raw = fm[fm['doping_ssac_I_anode/f'][0, 0]][()].ravel()
    I_ref    = fm['doping_ssac_I_anode/I'][0, 0]
    I_data   = fm[I_ref]
    Cj_doping_val = Cj_sim[1] * 1e-15  # nominal Cj at -1V bias
    for d_idx in range(4):
        dI_raw = I_data['real'][0, d_idx, :, 0, 0].ravel() + 1j * I_data['imag'][0, d_idx, :, 0, 0].ravel()
        spl_r = scipy.interpolate.make_interp_spline(freq_raw, np.real(dI_raw), k=3)
        spl_i = scipy.interpolate.make_interp_spline(freq_raw, np.imag(dI_raw), k=3)
        dI_fine = spl_r(freq_raw) + 1j * spl_i(freq_raw)
        
        # Apply correct parallel admittance incorporating junction capacitance
        Y_tot = 1j * 2 * np.pi * freq_raw * (Cj_doping_val + Cp_nom)
        denom = 1.0 + Y_tot * (Rload + 1j * 2 * np.pi * freq_raw * Lp_nom)
        resp  = dI_fine / denom
        resp_db = 20 * np.log10(np.abs(resp) / np.abs(resp[0]))
        
        idx = np.where(resp_db <= -3.0)[0]
        if len(idx) > 0:
            i0 = idx[0]
            f0, f1 = freq_raw[i0-1], freq_raw[i0]
            d0, d1 = resp_db[i0-1], resp_db[i0]
            doping_bw[d_idx] = (f0 + (f1 - f0) * (-3.0 - d0) / (d1 - d0)) * 1e-9
        else:
            doping_bw[d_idx] = 200.0

# Background doping sweep model (m^-3)
N_back = np.logspace(19.0, 24.0, 100) # 1e13 to 1e18 cm^-3
N_crit = 2.3e22  # Critical depletion limit (m^-3) where W_dep = H_nom at -1V bias

# Depletion width limits capacitance
Cj_doping = np.zeros_like(N_back)
for idx, Nb in enumerate(N_back):
    if Nb <= N_crit:
        Cj_doping[idx] = Cj_sim[1]*1e-15
    else:
        Cj_doping[idx] = (Cj_sim[1]*1e-15) * np.sqrt(Nb / N_crit)

# RLC limit vs doping
f_RLC_doping = np.array([get_rlc_bandwidth(0.0, Lp_nom, c_d + Cp_nom, Rload) * 1e-9 for c_d in Cj_doping])
# Adjusted transit frequency level for doping sweep simulation
f_transit_doping = 400.0 
f_comb_doping = 1.0 / np.sqrt(1.0 / f_transit_doping**2 + 1.0 / f_RLC_doping**2)

# ═══════════════════════════════════════════════════════════════════════════════
# PLOTTING
# ═══════════════════════════════════════════════════════════════════════════════
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 9,
    'axes.linewidth': 0.8,
    'xtick.direction': 'in', 'ytick.direction': 'in',
})
fig = plt.figure(figsize=(8.0, 7.2))

# ── (a) 3D Design Space Landscape ────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 1, projection='3d')
sc = ax.scatter(W_grid.flatten() * 1e6, H_grid.flatten() * 1e6, L_grid.flatten() * 1e6,
                c=bw_grid.flatten(), cmap='inferno', s=10, alpha=0.12, depthshade=False, vmin=50, vmax=150)

# Width sweep points
ax.scatter(w_sim_vals * 1e6, np.ones_like(w_sim_vals) * 0.35, np.ones_like(w_sim_vals) * 8.0,
           c=w_bw, cmap='inferno', s=45, edgecolor='black', linewidth=0.8, alpha=1.0, depthshade=False, vmin=50, vmax=150)
# Length sweep points
ax.scatter(np.ones_like(l_sim_vals) * 3.665, np.ones_like(l_sim_vals) * 0.35, l_sim_vals * 1e6,
           c=l_bw, cmap='inferno', s=45, edgecolor='black', linewidth=0.8, alpha=1.0, depthshade=False, vmin=50, vmax=150)
# Height sweep points
ax.scatter(np.ones_like(h_sim_vals) * 3.665, h_sim_vals * 1e6, np.ones_like(h_sim_vals) * 8.0,
           c=h_bw, cmap='inferno', s=45, edgecolor='black', linewidth=0.8, alpha=1.0, depthshade=False, vmin=50, vmax=150)

# Nominal Point marker
ax.scatter(3.665, 0.35, 8.0, color='cyan', marker='*', s=150, edgecolor='black', linewidth=0.8, label='Nominal design', depthshade=False, zorder=10)

ax.set_xlabel(r'Ge Width, $\mu$m', labelpad=4)
ax.set_ylabel(r'Ge Height, $\mu$m', labelpad=4)
ax.set_zlabel(r'Ge Length, $\mu$m', labelpad=4)
ax.view_init(elev=20, azim=45)
ax.grid(True, ls=':', lw=0.4, color='gray')
ax.legend(fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title('3D Design Space Landscape', fontsize=9, pad=4)
ax.text2D(-0.1, 1.04, '(a)', transform=ax.transAxes, fontsize=11, fontweight='bold')

cb = fig.colorbar(sc, ax=ax, pad=0.12, shrink=0.6, aspect=15)
cb.set_label('Bandwidth, GHz', fontsize=8)
cb.ax.tick_params(labelsize=7.5)

# ── (b) Cutoff Frequency & Capacitance vs Bias Voltage ───────────────────────
ax = fig.add_subplot(2, 2, 2)
ax.plot(V_fine, f_tr_fine, '--', color='black', lw=1.2, label='Transit limit')
ax.plot(V_fine, f_RLC_fine, ':', color='gray', lw=1.2, label='RC limit')
ax.plot(V_fine, f_comb_fine, '-', color='red', lw=1.3, label='Total bandwidth')
ax.scatter(V_sim, bw_sim, color='red', marker='o', s=25, edgecolor='black', zorder=5, label='CHARGE sim (Total BW)')

ax.set_xlabel('Bias Voltage (V)')
ax.set_ylabel('Cutoff Frequency (GHz)')
ax.set_xlim(-2.6, 0.1)
ax.set_ylim(0, 500)
ax.set_yticks([0, 100, 200, 300, 400, 500])
ax.grid(True, ls=':', lw=0.5, color='gray')
# Combined 2-column legend in lower-left corner
h1, l1 = ax.get_legend_handles_labels()

# Right y-axis for capacitance
ax2 = ax.twinx()
ax2.plot(V_fine, Cj_an_fine, '-', color='purple', lw=1.3, label='Junction capacitance')
ax2.scatter(V_sim, Cj_sim, color='purple', marker='s', s=25, edgecolor='black', zorder=5, label='CHARGE sim (Cj)')
ax2.set_ylabel(r'Junction Capacitance $C_\mathrm{j}$ (fF)', color='purple')
ax2.tick_params(axis='y', labelcolor='purple')
ax2.set_ylim(5.0, 18.0)

# Merge both legends with compact styling to fit perfectly
h2, l2 = ax2.get_legend_handles_labels()
ax.legend(h1 + h2, l1 + l2, fontsize=6.2, loc='upper left', ncol=2, framealpha=0.9, handletextpad=0.3, columnspacing=0.8)

ax.set_title('Bandwidth & Capacitance vs. Bias', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(b)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (c) Cutoff Frequency vs Optical Power ─────────────────────────────────────
ax = fig.add_subplot(2, 2, 3)
ax.plot(P_dBm, f_comb_power, '-', color='blue', lw=1.3, label='Screening model')
# Mark nominal point at -10 dBm (0.1 mW)
ax.scatter(-10.0, bw_sim[1], color='blue', marker='o', s=35, edgecolor='black', zorder=5, label='Nominal design (-10 dBm)')

ax.set_xlabel('Optical Power (dBm)')
ax.set_ylabel('Cutoff Frequency (GHz)')
ax.set_xlim(-20.0, 15.0)
ax.set_ylim(0, 120)
ax.set_yticks([0, 20, 40, 60, 80, 100, 120])
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='lower left', framealpha=0.9)
ax.set_title('Bandwidth Saturation vs. Power', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(c)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (d) Cutoff Frequency vs Background Doping Concentration ──────────────────
ax = fig.add_subplot(2, 2, 4)
ax.semilogx(N_back, f_comb_doping, '-', color='forestgreen', lw=1.3, label='Analytical model')
# Plot simulated points (Npp_arr is in m^-3)
N_sim_doping = np.array([5e19, 1e20, 5e20, 1e21])
ax.scatter(N_sim_doping, doping_bw, color='forestgreen', marker='o', s=30, edgecolor='black', zorder=5, label='CHARGE sim')

# Vertical line representing the critical depletion limit
ax.axvline(N_crit, color='black', ls='--', lw=0.9)
ax.text(N_crit * 0.6, 60.0, 'Depletion limit\n(partially depleted)', fontsize=7.5, ha='right', va='center')

ax.set_xlabel(r'Background Doping $N_\mathrm{back}$ ($\mathrm{m}^{-3}$)')
ax.set_ylabel('Cutoff Frequency (GHz)')
ax.set_xlim(1e19, 1e24)
ax.set_ylim(0, 120)
ax.set_yticks([0, 20, 40, 60, 80, 100, 120])
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='lower left', framealpha=0.9)
ax.set_title('Bandwidth vs. Background Doping', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(d)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ─────────────────────────────────────────────────────────────────────────────
fig.subplots_adjust(left=0.08, right=0.92, bottom=0.08, top=0.92, wspace=0.36, hspace=0.30)
out = repo / 'figures/selected simulation/panel_06_bandwidth_sweeps.png'
fig.savefig(str(out), dpi=300, bbox_inches='tight', facecolor='white')
print('Saved:', out)
