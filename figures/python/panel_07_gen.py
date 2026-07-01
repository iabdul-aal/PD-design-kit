# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 07 — 2x2 Grid showing photodetector design trade-offs:
  (a) 3D Design Space Landscape (Height, Width, Length) showing Figure of Merit
      FOM = D* × f_3dB  [Jones·GHz]  (specific detectivity × 3dB bandwidth)
  (b) Bandwidth vs. Responsivity (Pareto trade-off)
  (c) Responsivity vs. Dark Current (leakage vs. absorption trade-off)
  (d) Dark Current vs. Bandwidth (leakage vs. speed trade-off)
"""
import numpy as np
import scipy.interpolate
import scipy.io
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
    if Cj is None:
        Cj = eps_r * eps_0 * W_ge * L_nom / H_nom
    freq_grid_hz = np.linspace(0.1e9, 200e9, 1000)
    with h5py.File(fpath, 'r') as fm:
        if 'ac_anode' in fm:
            freq_raw = fm[fm['ac_anode/f'][0, 0]][()].ravel()
            dI_ref   = fm['ac_anode/dI'][0, 0]
            dI_raw   = fm[dI_ref]['real'].ravel() + 1j * fm[dI_ref]['imag'].ravel()
        else:
            freq_raw = fm[fm['ssac_I_anode/f'][0, 0]][()].ravel()
            I_ref    = fm['ssac_I_anode/I'][0, 0]
            dI_raw   = fm[I_ref]['real'].ravel() + 1j * fm[I_ref]['imag'].ravel()

    spl_r = scipy.interpolate.make_interp_spline(freq_raw, np.real(dI_raw), k=3)
    spl_i = scipy.interpolate.make_interp_spline(freq_raw, np.imag(dI_raw), k=3)
    dI_fine = spl_r(freq_grid_hz) + 1j * spl_i(freq_grid_hz)

    Y_tot_fine = 1j * 2 * np.pi * freq_grid_hz * (Cj + Cp_nom)
    denom_fine = 1.0 + Y_tot_fine * (Rload + 1j * 2 * np.pi * freq_grid_hz * Lp_nom)
    resp_fine  = dI_fine / denom_fine
    resp_db    = 20 * np.log10(np.abs(resp_fine) / np.abs(resp_fine[0]))

    idx = np.where(resp_db <= -3.0)[0]
    if len(idx) > 0:
        i0 = idx[0]
        f0, f1 = freq_grid_hz[i0-1], freq_grid_hz[i0]
        d0, d1 = resp_db[i0-1], resp_db[i0]
        return (f0 + (f1 - f0) * (-3.0 - d0) / (d1 - d0)) * 1e-9
    return 200.0

# ═══════════════════════════════════════════════════════════════════════════════
# LOAD SIMULATION SWEEP DATA
# ═══════════════════════════════════════════════════════════════════════════════
# Sweep param definitions
W_vals = np.array([2e-6, 4e-6, 6e-6, 8e-6])
H_vals = np.array([200e-9, 300e-9, 400e-9])
L_vals = np.array([2e-6, 4e-6, 6e-6, 8e-6])

# 1. Width Sweep
data_W = scipy.io.loadmat(res / 'device/ge_pd_charge_sweep_Ge_W.mat')
P_opt_W = data_W['P_opt'].ravel()[0]
Id_W = np.abs(data_W['I_dk'][15, :])  # at -1.0V (index 15)
R_W = (np.abs(data_W['I_ill'][15, :]) - Id_W) / P_opt_W
bw_W = np.array([get_bandwidth_from_file(res / f'device/GeW/ge_pd_charge_GeW_{int(w*1e6)}um_ssac.mat', Cj=eps_r * eps_0 * w * L_nom / H_nom) for w in W_vals])
A_W_cm2  = W_vals * L_nom * 1e4      # area per W-sweep point in cm²
Dstar_W = R_W * np.sqrt(A_W_cm2) / np.sqrt(2 * q * Id_W)
fom_W = Dstar_W * bw_W                # FOM = D* × f_3dB  [Jones·GHz]

# 2. Height Sweep
data_H = scipy.io.loadmat(res / 'device/ge_pd_charge_sweep_Ge_H.mat')
P_opt_H = data_H['P_opt'].ravel()[0]
Id_H = np.abs(data_H['I_dk'][15, :])
R_H = (np.abs(data_H['I_ill'][15, :]) - Id_H) / P_opt_H
bw_H = np.array([get_bandwidth_from_file(res / f'device/GeH/ge_pd_charge_GeH_{int(h*1e9)}nm_ssac.mat', Cj=eps_r * eps_0 * W_ge * L_nom / h) for h in H_vals])
A_H_cm2  = W_ge * L_nom * 1e4       # area for H-sweep (fixed W,L)
Dstar_H = R_H * np.sqrt(A_H_cm2) / np.sqrt(2 * q * Id_H)
fom_H = Dstar_H * bw_H                # FOM = D* × f_3dB  [Jones·GHz]

# 3. Length Sweep
data_L = scipy.io.loadmat(res / 'device/ge_pd_charge_sweep_Ge_L.mat')
P_opt_L = data_L['P_opt'].ravel()[0]
Id_L = np.abs(data_L['I_dk'][15, :])
R_L = (np.abs(data_L['I_ill'][15, :]) - Id_L) / P_opt_L
bw_L = np.array([get_bandwidth_from_file(res / f'device/GeL/ge_pd_charge_GeL_{int(l*1e6)}um_ssac.mat', Cj=eps_r * eps_0 * W_ge * l / H_nom) for l in L_vals])
A_L_cm2  = W_ge * L_vals * 1e4      # area per L-sweep point in cm²
Dstar_L = R_L * np.sqrt(A_L_cm2) / np.sqrt(2 * q * Id_L)
fom_L = Dstar_L * bw_L                # FOM = D* × f_3dB  [Jones·GHz]

# Nominal design point values from simulation
Id_nom = Id_L[3]  # 4th point in L-sweep is L=8um, W=3.665um, H=350nm
R_nom = R_L[3]
bw_nom = bw_L[3]
A_nom_cm2 = W_ge * L_nom * 1e4      # nominal area in cm²
Dstar_nom = R_nom * np.sqrt(A_nom_cm2) / np.sqrt(2 * q * Id_nom)
fom_nom = Dstar_nom * bw_nom          # FOM = D* × f_3dB  [Jones·GHz]

# ═══════════════════════════════════════════════════════════════════════════════
# ANALYTICAL 3D GRID MODEL FOR THE ENTIRE DESIGN SPACE
# ═══════════════════════════════════════════════════════════════════════════════
# Multiplicative scaling model interpolators
f_R_W = scipy.interpolate.interp1d(W_vals, R_W / np.interp(W_ge, W_vals, R_W), kind='linear', fill_value='extrapolate')
f_R_H = scipy.interpolate.interp1d(H_vals, R_H / np.interp(H_nom, H_vals, R_H), kind='linear', fill_value='extrapolate')
f_R_L = scipy.interpolate.interp1d(L_vals, R_L / np.interp(L_nom, L_vals, R_L), kind='linear', fill_value='extrapolate')

f_Id_W = scipy.interpolate.interp1d(W_vals, Id_W / np.interp(W_ge, W_vals, Id_W), kind='linear', fill_value='extrapolate')
f_Id_H = scipy.interpolate.interp1d(H_vals, Id_H / np.interp(H_nom, H_vals, Id_H), kind='linear', fill_value='extrapolate')
f_Id_L = scipy.interpolate.interp1d(L_vals, Id_L / np.interp(L_nom, L_vals, Id_L), kind='linear', fill_value='extrapolate')

# Generate a fine 3D grid
N_grid = 12
W_grid_vals = np.linspace(2e-6, 8e-6, N_grid)
H_grid_vals = np.linspace(200e-9, 400e-9, N_grid)
L_grid_vals = np.linspace(2e-6, 8e-6, N_grid)
W_g, H_g, L_g = np.meshgrid(W_grid_vals, H_grid_vals, L_grid_vals, indexing='ij')

# Evaluate models on the grid
R_grid = R_nom * f_R_W(W_g) * f_R_H(H_g) * f_R_L(L_g)
Id_grid = Id_nom * f_Id_W(W_g) * f_Id_H(H_g) * f_Id_L(L_g)

# Bandwidth on the grid
f_tr_grid = (0.443 * v_sat / H_g) * 1e-9
Cj_grid = eps_r * eps_0 * W_g * L_g / H_g
Ctot_grid = Cj_grid + Cp_nom
f_RLC_grid = get_rlc_bandwidth(0.0, Lp_nom, Ctot_grid, Rload) * 1e-9
bw_grid = 1.0 / np.sqrt(1.0 / f_tr_grid**2 + 1.0 / f_RLC_grid**2)

# Figure of Merit on the grid: FOM = D* × f_3dB
A_grid_cm2 = W_g * L_g * 1e4        # 3D grid area in cm²
Dstar_grid = R_grid * np.sqrt(A_grid_cm2) / np.sqrt(2 * q * Id_grid)
fom_grid = Dstar_grid * bw_grid      # FOM = D* × f_3dB  [Jones·GHz]

# Fine 1D sweeps for continuous analytical lines
W_fine = np.linspace(2e-6, 8e-6, 100)
H_fine = np.linspace(200e-9, 400e-9, 100)
L_fine = np.linspace(2e-6, 8e-6, 100)

# 1. Width sweep curves
R_W_an = R_nom * f_R_W(W_fine)
Id_W_an = Id_nom * f_Id_W(W_fine)
f_tr_W_an = (0.443 * v_sat / H_nom) * 1e-9
Cj_W_an = eps_r * eps_0 * W_fine * L_nom / H_nom
bw_W_an = 1.0 / np.sqrt(1.0 / f_tr_W_an**2 + 1.0 / (get_rlc_bandwidth(0.0, Lp_nom, Cj_W_an + Cp_nom, Rload)*1e-9)**2)

# 2. Length sweep curves
R_L_an = R_nom * f_R_L(L_fine)
Id_L_an = Id_nom * f_Id_L(L_fine)
f_tr_L_an = (0.443 * v_sat / H_nom) * 1e-9
Cj_L_an = eps_r * eps_0 * W_ge * L_fine / H_nom
bw_L_an = 1.0 / np.sqrt(1.0 / f_tr_L_an**2 + 1.0 / (get_rlc_bandwidth(0.0, Lp_nom, Cj_L_an + Cp_nom, Rload)*1e-9)**2)

# 3. Height sweep curves
R_H_an = R_nom * f_R_H(H_fine)
Id_H_an = Id_nom * f_Id_H(H_fine)
f_tr_H_an = (0.443 * v_sat / H_fine) * 1e-9
Cj_H_an = eps_r * eps_0 * W_ge * L_nom / H_fine
bw_H_an = 1.0 / np.sqrt(1.0 / f_tr_H_an**2 + 1.0 / (get_rlc_bandwidth(0.0, Lp_nom, Cj_H_an + Cp_nom, Rload)*1e-9)**2)

# ═══════════════════════════════════════════════════════════════════════════════
# PLOTTING
# ═══════════════════════════════════════════════════════════════════════════════
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 9,
    'axes.linewidth': 0.8,
    'xtick.direction': 'in', 'ytick.direction': 'in',
})
fig = plt.figure(figsize=(9.0, 7.8))

# ── (a) 3D Design Space Landscape (FOM) ──────────────────────────────────────
ax = fig.add_subplot(2, 2, 1, projection='3d')
sc = ax.scatter(W_g.flatten() * 1e6, H_g.flatten() * 1e6, L_g.flatten() * 1e6,
                c=fom_grid.flatten(), cmap='viridis', s=8, alpha=0.10, depthshade=False)

# Overlay sweep points
ax.scatter(W_vals * 1e6, np.ones_like(W_vals) * 0.35, np.ones_like(W_vals) * 8.0,
           c=fom_W, cmap='viridis', s=40, edgecolor='black', linewidth=0.7, alpha=0.9, depthshade=False)
ax.scatter(np.ones_like(L_vals) * 3.665, np.ones_like(L_vals) * 0.35, L_vals * 1e6,
           c=fom_L, cmap='viridis', s=40, edgecolor='black', linewidth=0.7, alpha=0.9, depthshade=False)
ax.scatter(np.ones_like(H_vals) * 3.665, H_vals * 1e6, np.ones_like(H_vals) * 8.0,
           c=fom_H, cmap='viridis', s=40, edgecolor='black', linewidth=0.7, alpha=0.9, depthshade=False)

# Nominal Point marker
ax.scatter(3.665, 0.35, 8.0, color='red', marker='*', s=120, edgecolor='black', linewidth=0.7, label='Nominal design', depthshade=False, zorder=10)

ax.set_xlabel(r'Ge Width, $\mu$m', labelpad=4)
ax.set_ylabel(r'Ge Height, $\mu$m', labelpad=4)
ax.set_zlabel(r'Ge Length, $\mu$m', labelpad=4)
ax.view_init(elev=20, azim=45)
ax.grid(True, ls=':', lw=0.4, color='gray')
ax.legend(fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title(r'3D Design Space ($D^*\!\times\!f_{\rm 3dB}$ FOM)', fontsize=9, pad=4)
ax.text2D(-0.1, 1.04, '(a)', transform=ax.transAxes, fontsize=11, fontweight='bold')

cb = fig.colorbar(sc, ax=ax, pad=0.12, shrink=0.6, aspect=15)
cb.set_label(r'$D^*\!\times\!f_{\rm 3dB}$ (Jones$\cdot$GHz)', fontsize=8)
cb.ax.tick_params(labelsize=7.5)

# ── (b) Bandwidth vs. Responsivity ────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 2)
sc2 = ax.scatter(R_grid.flatten(), bw_grid.flatten(), c=(W_g * L_g).flatten() * 1e12, cmap='coolwarm', s=4, alpha=0.25)
# Analytical curves (continuous lines)
ax.plot(R_W_an, bw_W_an, 'k-', lw=1.2, label='Width Sweep (Analyt.)')
ax.plot(R_L_an, bw_L_an, color='purple', ls='--', lw=1.2, label='Length Sweep (Analyt.)')
ax.plot(R_H_an, bw_H_an, color='darkorange', ls='-.', lw=1.2, label='Height Sweep (Analyt.)')
# Simulated points (markers)
ax.scatter(R_W, bw_W, color='black', marker='o', s=25, edgecolor='black', zorder=4, label='Width Sweep (Sim.)')
ax.scatter(R_L, bw_L, color='purple', marker='s', s=25, edgecolor='black', zorder=4, label='Length Sweep (Sim.)')
ax.scatter(R_H, bw_H, color='darkorange', marker='^', s=30, edgecolor='black', zorder=4, label='Height Sweep (Sim.)')

ax.scatter(R_nom, bw_nom, color='red', marker='*', s=120, edgecolor='black', zorder=5, label='Nominal design')

ax.set_xlabel('Responsivity (A/W)')
ax.set_ylabel('Bandwidth (GHz)')
ax.set_xlim(0.45, 1.05)
ax.set_ylim(20, 150)
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='lower left', framealpha=0.9)
ax.set_title('Bandwidth vs. Responsivity', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(b)', transform=ax.transAxes, fontsize=11, fontweight='bold')

cb2 = fig.colorbar(sc2, ax=ax, pad=0.02, shrink=0.8, aspect=20)
cb2.set_label(r'Ge Area $W\times L$ ($\mu$m²)', fontsize=8)
cb2.ax.tick_params(labelsize=7.5)

# ── (c) Responsivity vs. Dark Current ─────────────────────────────────────────
ax = fig.add_subplot(2, 2, 3)
sc3 = ax.scatter(Id_grid.flatten() * 1e9, R_grid.flatten(), c=(W_g * L_g).flatten() * 1e12, cmap='coolwarm', s=4, alpha=0.25)
# Analytical curves (continuous lines)
ax.plot(Id_W_an * 1e9, R_W_an, 'k-', lw=1.2, label='Width Sweep (Analyt.)')
ax.plot(Id_L_an * 1e9, R_L_an, color='purple', ls='--', lw=1.2, label='Length Sweep (Analyt.)')
ax.plot(Id_H_an * 1e9, R_H_an, color='darkorange', ls='-.', lw=1.2, label='Height Sweep (Analyt.)')
# Simulated points (markers)
ax.scatter(Id_W * 1e9, R_W, color='black', marker='o', s=25, edgecolor='black', zorder=4, label='Width Sweep (Sim.)')
ax.scatter(Id_L * 1e9, R_L, color='purple', marker='s', s=25, edgecolor='black', zorder=4, label='Length Sweep (Sim.)')
ax.scatter(Id_H * 1e9, R_H, color='darkorange', marker='^', s=30, edgecolor='black', zorder=4, label='Height Sweep (Sim.)')

ax.scatter(Id_nom * 1e9, R_nom, color='red', marker='*', s=120, edgecolor='black', zorder=5, label='Nominal design')

ax.set_xlabel('Dark Current (nA)')
ax.set_ylabel('Responsivity (A/W)')
ax.set_xlim(0.0, 2.2)
ax.set_ylim(0.45, 1.05)
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='lower right', framealpha=0.9)
ax.set_title('Responsivity vs. Dark Current', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(c)', transform=ax.transAxes, fontsize=11, fontweight='bold')

cb3 = fig.colorbar(sc3, ax=ax, pad=0.02, shrink=0.8, aspect=20)
cb3.set_label(r'Ge Area $W\times L$ ($\mu$m²)', fontsize=8)
cb3.ax.tick_params(labelsize=7.5)

# ── (d) Dark Current vs. Bandwidth ────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 4)
sc4 = ax.scatter(bw_grid.flatten(), Id_grid.flatten() * 1e9, c=(W_g * L_g).flatten() * 1e12, cmap='coolwarm', s=4, alpha=0.25)
# Analytical curves (continuous lines)
ax.plot(bw_W_an, Id_W_an * 1e9, 'k-', lw=1.2, label='Width Sweep (Analyt.)')
ax.plot(bw_L_an, Id_L_an * 1e9, color='purple', ls='--', lw=1.2, label='Length Sweep (Analyt.)')
ax.plot(bw_H_an, Id_H_an * 1e9, color='darkorange', ls='-.', lw=1.2, label='Height Sweep (Analyt.)')
# Simulated points (markers)
ax.scatter(bw_W, Id_W * 1e9, color='black', marker='o', s=25, edgecolor='black', zorder=4, label='Width Sweep (Sim.)')
ax.scatter(bw_L, Id_L * 1e9, color='purple', marker='s', s=25, edgecolor='black', zorder=4, label='Length Sweep (Sim.)')
ax.scatter(bw_H, Id_H * 1e9, color='darkorange', marker='^', s=30, edgecolor='black', zorder=4, label='Height Sweep (Sim.)')

ax.scatter(bw_nom, Id_nom * 1e9, color='red', marker='*', s=120, edgecolor='black', zorder=5, label='Nominal design')

ax.set_xlabel('Bandwidth (GHz)')
ax.set_ylabel('Dark Current (nA)')
ax.set_xlim(20, 150)
ax.set_ylim(0.0, 2.2)
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='upper right', framealpha=0.9)
ax.set_title('Dark Current vs. Bandwidth', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(d)', transform=ax.transAxes, fontsize=11, fontweight='bold')

cb4 = fig.colorbar(sc4, ax=ax, pad=0.02, shrink=0.8, aspect=20)
cb4.set_label(r'Ge Area $W\times L$ ($\mu$m²)', fontsize=8)
cb4.ax.tick_params(labelsize=7.5)

plt.tight_layout()
out_path = dir_sim / 'panel_07_tradeoffs.png'
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"Saved: {out_path}")
