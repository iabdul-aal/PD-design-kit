# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 03 — 2x2 Grid showing dark current analysis and physical models:
  (a) I-V Characteristics (magnitude |I| vs Voltage for both dark and illuminated)
  (b) Dark Current vs. Background Doping (log-log comparison of CHARGE and Analytical)
  (c) Dark Current vs. Temperature (Arrhenius scaling comparison of CHARGE and Analytical)
  (d) 3D Geometry Landscape of Dark Current (vs Width, Height, and Length)
"""
import numpy as np
import scipy.io
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from pathlib import Path

dir_sim = Path(__file__).resolve().parent
repo = dir_sim.parents[1]
res  = repo / 'results'

res_dir = res / 'device'

# ─── (a) Load I-V Sweep Data from main nominal simulation ────────────────────
f_ill_nom = res_dir / 'main/ge_pd_charge_illuminated_iv.mat'
f_dk_nom  = res_dir / 'main/ge_pd_charge_dark_iv.mat'

with h5py.File(str(f_ill_nom), 'r') as f:
    I_ref_ill = f['anode_res/I'][0, 0]
    I_ill_a   = f[I_ref_ill][()].ravel()
    V_ref_ill = f['anode_res/V_anode'][0, 0]
    V_ill_a   = f[V_ref_ill][()].ravel()

with h5py.File(str(f_dk_nom), 'r') as f:
    I_ref_dk = f['anode_res/I'][0, 0]
    I_dk_a   = f[I_ref_dk][()].ravel()
    V_ref_dk = f['anode_res/V_anode'][0, 0]
    V_dk_a   = f[V_ref_dk][()].ravel()

# ─── (b) Load Doping Sweep Data ──────────────────────────────────────────────
f_dark_doping = res_dir / 'doping/ge_pd_charge_doping_dark_ushaped.mat'
with h5py.File(str(f_dark_doping), 'r') as f:
    npp = f['Npp_arr'][()].ravel()
    I_ref_dk_dop = f['doping_dark_I_anode/I'][0, 0]
    I_dk_doping_raw = f[I_ref_dk_dop][()]
    V_ref_dk_dop = f['doping_dark_I_anode/V_anode'][0, 0]
    V_anode_dk = f[V_ref_dk_dop][()].ravel()

idx_dk_doping = np.argmin(np.abs(V_anode_dk + 1.0))
doping_Id = []
for i in range(len(npp)):
    i_dk_val = I_dk_doping_raw[i, idx_dk_doping, 0, 0]
    doping_Id.append(np.abs(i_dk_val) * 1e9) # in nA

doping_cm3 = npp * 1e-6

# Fit doping power-law (Id vs doping)
doping_cm3_fine = np.logspace(np.log10(doping_cm3.min()), np.log10(doping_cm3.max()), 400)
slope_dop, intercept_dop = np.polyfit(np.log(doping_cm3), np.log(doping_Id), 1)
Id_doping_an = np.exp(intercept_dop) * doping_cm3_fine**slope_dop

# ─── (c) Load Temperature Sweep Data ──────────────────────────────────────────
f_temp_dark = res_dir / 'ge_pd_charge_sweep_temperature.mat'
mat_temp = scipy.io.loadmat(str(f_temp_dark))
T_vals = mat_temp['sweep_vals'].ravel()
V_dk_temp = mat_temp['V_dk']
I_dk_temp = np.squeeze(mat_temp['I_dk'])

temp_Id = []
for i in range(len(T_vals)):
    idx_temp = np.argmin(np.abs(V_dk_temp[:, i] + 1.0))
    temp_Id.append(np.abs(I_dk_temp[idx_temp, i]) * 1e9) # in nA

# Fit temperature activation energy (Arrhenius plot log(I) vs 1/T)
kB_ev = 8.617333262e-5 # eV/K
slope_temp, intercept_temp = np.polyfit(1.0 / (kB_ev * T_vals), np.log(temp_Id), 1)
E_a = -slope_temp
T_fine = np.linspace(240, 360, 400)
Id_temp_an = np.exp(intercept_temp - E_a / (kB_ev * T_fine))

# ─── (d) Load Geometry Sweeps for Dark Current ───────────────────────────────
def extract_Id_sweep(fpath):
    mat = scipy.io.loadmat(fpath)
    V_dk = mat['V_dk']
    I_dk = mat['I_dk']
    Id_list = []
    for col in range(V_dk.shape[1]):
        v_col = V_dk[:, col]
        i_col = I_dk[:, col]
        idx = np.argmin(np.abs(v_col + 1.0))
        Id_list.append(np.abs(i_col[idx]) * 1e9) # in nA
    return mat['sweep_vals'].ravel(), np.array(Id_list)

w_vals, w_Id = extract_Id_sweep(str(res_dir / 'ge_pd_charge_sweep_Ge_W.mat'))
l_vals, l_Id = extract_Id_sweep(str(res_dir / 'ge_pd_charge_sweep_Ge_L.mat'))
h_vals, h_Id = extract_Id_sweep(str(res_dir / 'ge_pd_charge_sweep_Ge_H.mat'))

# Reconstruct 3D grid for Dark Current
W_3d = np.linspace(2e-6, 8e-6, 10)
H_3d = np.linspace(200e-9, 400e-9, 10)
L_3d = np.linspace(2e-6, 8e-6, 10)

W_grid, H_grid, L_grid = np.meshgrid(W_3d, H_3d, L_3d, indexing='ij')

Id_W_interp = np.interp(W_grid, w_vals, w_Id)
Id_H_interp = np.interp(H_grid, h_vals, h_Id)
Id_L_interp = np.interp(L_grid, l_vals, l_Id)

# Combined multi-dimensional dependency:
# Reconstructs the 3D dark current landscape under a separable rank-1 approximation:
# Id(W, H, L) ≈ Id_W(W) * Id_L(L) * Id_H(H) / (Id_L_nom * Id_H_nom).
# Here, 0.684 nA is the nominal dark current (L=8 um, W=5 um, H=350 nm) and 0.87 nA is the H-sweep intersection factor.
Id_3d = Id_W_interp * Id_L_interp * Id_H_interp / (0.684 * 0.87)

# ─── Plotting ─────────────────────────────────────────────────────────────────
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 9,
    'axes.linewidth': 0.8,
    'xtick.direction': 'in', 'ytick.direction': 'in',
})
fig = plt.figure(figsize=(8.0, 7.2))

# ── (a) I-V Characteristics ──────────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 1)
ax.plot(V_dk_a, np.abs(I_dk_a), '-', color='black', lw=1.5, label='Dark current')
ax.plot(V_ill_a, np.abs(I_ill_a), '--', color='dimgray', lw=1.5, label=r'Illuminated current (100 $\mu$W)')
ax.set_xlabel(r'Bias voltage $V_\mathrm{anode}$, V')
ax.set_ylabel(r'Current magnitude $|I|$, A')
ax.set_yscale('log')
ax.set_xlim(-2.0, 1.0)
ax.set_ylim(1e-12, 1e-1)
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title('I-V Characteristics', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(a)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (b) Dark Current vs. Background Doping ──────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 2)
ax.plot(doping_cm3_fine, Id_doping_an, '--', color='gray', lw=1.2, label='Power-law fit')
ax.plot(doping_cm3, doping_Id, '-o', color='black', lw=1.5, ms=4.5, mfc='white', mec='black', mew=1.3, label='CHARGE solver')
ax.set_xlabel(r'Background doping concentration, $\mathrm{cm}^{-3}$')
ax.set_ylabel(r'Dark current $I_\mathrm{d}$, nA')
ax.set_xscale('log')
ax.set_yscale('log')
ax.set_xlim(3e13, 2e15)
ax.set_ylim(10, 100e3)
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')

# Legend: simulation first, then analytical (upper right)
h, l = ax.get_legend_handles_labels()
ax.legend(h[::-1], l[::-1], fontsize=7.5, loc='upper right', framealpha=0.9)
ax.set_title('Dark Current vs. Background Doping', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(b)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (c) Dark Current vs. Temperature ──────────────────────────────────────────
ax = fig.add_subplot(2, 2, 3)
ax.plot(T_fine, Id_temp_an, '--', color='gray', lw=1.2, label=r'Arrhenius fit ($E_\mathrm{a}$ = ' + f'{E_a:.3f} eV)')
ax.plot(T_vals, temp_Id, '-o', color='black', lw=1.5, ms=4.5, mfc='white', mec='black', mew=1.3, label='CHARGE solver')
ax.set_xlabel(r'Temperature $T$, K')
ax.set_ylabel(r'Dark current $I_\mathrm{d}$, nA')
ax.set_yscale('log')
ax.set_xlim(240, 360)
ax.set_ylim(0.05, 100)
ax.grid(True, which='both', ls=':', lw=0.5, color='gray')

# Legend: simulation first, then analytical (upper left)
h, l = ax.get_legend_handles_labels()
ax.legend(h[::-1], l[::-1], fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title('Dark Current vs. Temperature', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(c)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (d) 3D Geometry Landscape of Dark Current ───────────────────────────────
ax = fig.add_subplot(2, 2, 4, projection='3d')
# Plot Grid scatter cloud (converting height to um)
sc = ax.scatter(W_grid.flatten() * 1e6, H_grid.flatten() * 1e6, L_grid.flatten() * 1e6,
                c=Id_3d.flatten(), cmap='plasma', s=10, alpha=0.12, depthshade=False)

# Plot actual simulated sweep points (converting height to um)
# Width sweep points
ax.scatter(w_vals * 1e6, np.ones_like(w_vals) * 0.35, np.ones_like(w_vals) * 8,
           c=w_Id, cmap='plasma', s=45, edgecolor='black', linewidth=0.8, alpha=1.0, depthshade=False)
# Length sweep points
ax.scatter(np.ones_like(l_vals) * 5, np.ones_like(l_vals) * 0.35, l_vals * 1e6,
           c=l_Id, cmap='plasma', s=45, edgecolor='black', linewidth=0.8, alpha=1.0, depthshade=False)
# Height sweep points
ax.scatter(np.ones_like(h_vals) * 5, h_vals * 1e6, np.ones_like(h_vals) * 8,
           c=h_Id, cmap='plasma', s=45, edgecolor='black', linewidth=0.8, alpha=1.0, depthshade=False)

# Nominal Point marker
ax.scatter(5.0, 0.35, 8.0, color='red', marker='*', s=150, edgecolor='black', linewidth=0.8, label='Nominal design', depthshade=False)

ax.set_xlabel(r'Ge Width, $\mu$m', labelpad=4)
ax.set_ylabel(r'Ge Height, $\mu$m', labelpad=4)
ax.set_zlabel(r'Ge Length, $\mu$m', labelpad=4)
ax.view_init(elev=20, azim=45)
ax.grid(True, ls=':', lw=0.4, color='gray')
ax.legend(fontsize=7.5, loc='upper left', framealpha=0.9)
ax.set_title(r'3D Geometry Landscape of $I_\mathrm{d}$', fontsize=9, pad=4)
ax.text2D(-0.1, 1.04, '(d)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# Colorbar for 3D plot placed automatically to the right with pad
cb = fig.colorbar(sc, ax=ax, pad=0.12, shrink=0.6, aspect=15)
cb.set_label(r'Dark current $I_\mathrm{d}$, nA', fontsize=8)
cb.ax.tick_params(labelsize=7.5)

# ─────────────────────────────────────────────────────────────────────────────
# Adjust subplots spacing to ensure clean separation without warnings
fig.subplots_adjust(left=0.08, right=0.95, bottom=0.08, top=0.92, wspace=0.30, hspace=0.30)
out = repo / 'figures/selected simulation/panel_03_current.png'
fig.savefig(str(out), dpi=300, bbox_inches='tight', facecolor='white')
print('Saved:', out)
