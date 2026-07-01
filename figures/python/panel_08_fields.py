# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 08 — Spatial Field & Physical Profiles (2 × 2)
  (a) FDTD |E|²(x,y) inside Ge absorber — longitudinal (x) and width (y) plane
  (b) CHARGE electrostatic potential φ(y,z) at V_bias = -1 V
  (c) FDTD optical generation G(x) along longitudinal axis + cumulative
  (d) CHARGE band energies Ec, Ev + quasi-Fermi levels Efn, Efp at V = -1 V

All data loaded from .mat files — no PNG loading.

Sources
-------
  (a)   results/fdtd/main/ge_pd_fdtd_results_oband_ushaped.mat
  (b,d) results/device/main/ge_pd_charge_spatial.mat
  (c)   results/fdtd/main/ge_pd_fdtd_gen_rate.mat
"""

import numpy as np
import h5py
from scipy.interpolate import griddata
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from pathlib import Path

dir_sim = Path(__file__).resolve().parent
repo    = dir_sim.parents[1]
res     = repo / 'results'
out_dir = dir_sim

# ═══════════════════════════════════════════════════════════════════════════════
# DEVICE GEOMETRY  (nominal, metres)
# ═══════════════════════════════════════════════════════════════════════════════
wg_H     = 220e-9
iGe_H    = 350e-9
Npp_H    = 50e-9
z_iGe_bot_um = wg_H  * 1e6
z_Npp_bot_um = (wg_H + iGe_H - Npp_H) * 1e6
z_iGe_top_um = (wg_H + iGe_H) * 1e6

# ═══════════════════════════════════════════════════════════════════════════════
# LOAD DATA
# ═══════════════════════════════════════════════════════════════════════════════

# ── (a) FDTD |E|² in X–Y (longitudinal x, width y) inside Ge ────────────────
def load_complex_xy(fm, name):
    d = fm[name]
    return d['real'][()]**2 + d['imag'][()]**2

with h5py.File(res / 'fdtd/main/ge_pd_fdtd_results_oband_ushaped.mat', 'r') as fm:
    x_E_xy = fm['E_xy_x'][()].ravel() * 1e6  # µm  (1633,)
    y_E_xy = fm['E_xy_y'][()].ravel() * 1e6  # µm  (321,)
    
    Ex2 = load_complex_xy(fm, 'Ex_xy')
    Ey2 = load_complex_xy(fm, 'Ey_xy')
    Ez2 = load_complex_xy(fm, 'Ez_xy')
    E2_xy = Ex2 + Ey2 + Ez2                 # (321, 1633)

E2_xy_norm = E2_xy / E2_xy.max()

# ── (b,d) CHARGE spatial data ───────────────────────────────────────────────
with h5py.File(res / 'device/main/ge_pd_charge_spatial.mat', 'r') as fm:
    V_anode = fm['V_anode'][()].ravel()           # (41,)  V
    z_band  = fm['z_band'][()].ravel()  * 1e6     # µm  (65,)

    # Band arrays: (41, 1, 65, 1, 1) → squeeze → (41, 65) → transpose (65, 41)
    Ec_all  = fm['Ec'][()].squeeze()
    Ev_all  = fm['Ev'][()].squeeze()
    Efn_all = fm['Efn'][()].squeeze()
    Efp_all = fm['Efp'][()].squeeze()

    # Ensure shape is (Nz, NV) i.e. (65, 41)
    if Ec_all.shape[0] == len(V_anode):
        Ec_all  = Ec_all.T
        Ev_all  = Ev_all.T
        Efn_all = Efn_all.T
        Efp_all = Efp_all.T

    # Slice at V_anode ≈ -1 V
    idx_V1 = int(np.argmin(np.abs(V_anode - (-1.0))))
    Ec_1V  = Ec_all[:,  idx_V1]
    Ev_1V  = Ev_all[:,  idx_V1]
    Efn_1V = Efn_all[:, idx_V1]
    Efp_1V = Efp_all[:, idx_V1]

    # Electrostatics: V_pot (1, 41, 1, 21833) → squeeze → (41, 21833)
    V_pot_all = fm['V_pot'][()].squeeze()         # (41, 21833)
    y_mesh    = fm['y_mesh'][()].ravel() * 1e6    # µm  (21833,)
    z_mesh    = fm['z_mesh'][()].ravel() * 1e6    # µm  (21833,)
    Va_es     = fm['Va_es'][()].ravel()           # (41,)

    idx_V1b   = int(np.argmin(np.abs(Va_es - (-1.0))))
    if V_pot_all.ndim == 2:
        if V_pot_all.shape[0] == len(Va_es):      # (41, Nmesh)
            V_pot_1V = V_pot_all[idx_V1b, :]
        else:                                      # (Nmesh, 41)
            V_pot_1V = V_pot_all[:, idx_V1b]
    else:
        V_pot_1V = V_pot_all.ravel()

# ── (c) FDTD 3D optical generation -> G(x) along longitudinal axis ──────────
with h5py.File(res / 'fdtd/main/ge_pd_fdtd_gen_rate.mat', 'r') as fm:
    g_grp = fm['G']
    x_gen = g_grp['x'][()].ravel() * 1e6    # µm  (401,)
    y_gen = g_grp['y'][()].ravel() * 1e6    # µm  (189,)
    z_gen = g_grp['z'][()].ravel() * 1e6    # µm  (18,)
    
    G_ds = g_grp['G']
    if G_ds.dtype == object:
        G_3d_flat = fm[G_ds[()].ravel()[0]][()].ravel()
    else:
        G_3d_flat = G_ds[()].ravel()

# Reshape G to (Nz, Ny, Nx) and average over z and y to get G(x)
Nx_gen, Ny_gen, Nz_gen = len(x_gen), len(y_gen), len(z_gen)
G_3d = G_3d_flat.reshape((Nz_gen, Ny_gen, Nx_gen))
G_x_avg = G_3d.mean(axis=(0, 1))

dx_gen = np.abs(np.mean(np.diff(x_gen)))
G_cum_x = np.cumsum(G_x_avg) * dx_gen
G_cum_x_norm = G_cum_x / G_cum_x[-1] * 100.0

# ── Interpolate V_pot onto a regular Y-Z grid  ───────────────────────────────
Ny_grid, Nz_grid = 200, 150
y_grid = np.linspace(-3.0, 3.0, Ny_grid)
z_grid = np.linspace(0.0, 0.6, Nz_grid)
YG, ZG = np.meshgrid(y_grid, z_grid)
V_grid = griddata((y_mesh, z_mesh), V_pot_1V,
                  (YG, ZG), method='linear')

# ═══════════════════════════════════════════════════════════════════════════════
# PLOTTING
# ═══════════════════════════════════════════════════════════════════════════════
plt.rcParams.update({
    'font.family'       : 'serif',
    'font.size'         : 9,
    'axes.linewidth'    : 0.8,
    'xtick.direction'   : 'in',
    'ytick.direction'   : 'in',
    'xtick.major.width' : 0.6,
    'ytick.major.width' : 0.6,
    'xtick.minor.visible': True,
    'ytick.minor.visible': True,
})

fig = plt.figure(figsize=(7.5, 6.8))
label_kw = dict(fontsize=11, fontweight='bold')

# Define Ge structural outline in Y-Z plane
ge_outline_y = [-2.5, -1.25, 1.25, 2.5, -2.5]
ge_outline_z = [z_iGe_bot_um, z_iGe_top_um, z_iGe_top_um, z_iGe_bot_um, z_iGe_bot_um]

# Define Ge structural boundaries in X-Y plane (rectangle: length 8um, width 5um)
ge_rect_x = [0.0, 8.0, 8.0, 0.0, 0.0]
ge_rect_y = [-2.5, -2.5, 2.5, 2.5, -2.5]

# ── (a) |E|²(x,y) inside Ge — FDTD E_field_XY ───────────────────────────────
ax_a = fig.add_subplot(2, 2, 1)
ax_a.set_facecolor('#eaeaea')

# Plot E-field in longitudinal (x) and width (y) plane
im_a = ax_a.pcolormesh(x_E_xy, y_E_xy, np.log10(np.maximum(E2_xy_norm, 1e-6)),
                        cmap='plasma', shading='auto', rasterized=True, vmin=-4.0, vmax=0.0)

# Draw Ge boundary rectangle
ax_a.plot(ge_rect_x, ge_rect_y, color='white', lw=0.8, ls='-', alpha=0.7)

ax_a.set_xlim(-0.5, 8.5)
ax_a.set_ylim(-3.0, 3.0)
ax_a.set_aspect(1.0)
ax_a.set_anchor('S')

ax_a.set_xlabel(r'$x$ — length ($\mu$m)', labelpad=2)
ax_a.set_ylabel(r'$y$ — width ($\mu$m)', labelpad=2)
ax_a.set_title('FDTD Longitudinal Intensity $|E|^2(x,y)$', fontsize=9, pad=4)

cb_a = fig.colorbar(im_a, ax=ax_a, pad=0.02, fraction=0.046)
cb_a.set_label(r'$\log_{10}(|E|^2/|E|_\mathrm{max}^2)$', fontsize=8)
cb_a.ax.tick_params(labelsize=7.5)
ax_a.text(-0.16, 1.04, '(a)', transform=ax_a.transAxes, **label_kw)

# ── (b) φ(y,z) at V_bias = -1 V — CHARGE electrostatics ─────────────────────
ax_b = fig.add_subplot(2, 2, 2)
ax_b.set_facecolor('#eaeaea')

# Plot electrostatic potential (100% verified solver data)
im_b = ax_b.pcolormesh(y_grid, z_grid, V_grid,
                        cmap='coolwarm', shading='auto', rasterized=True, vmin=-1.0, vmax=0.0)
cs_b = ax_b.contour(y_grid, z_grid, V_grid,
                    levels=np.linspace(-1.0, 0.0, 11), colors='white', linewidths=0.4, alpha=0.6)
ax_b.clabel(cs_b, fmt='%.1fV', fontsize=6, inline=True, inline_spacing=2)

# Draw structural boundaries
ax_b.plot(ge_outline_y, ge_outline_z, color='black', lw=0.8, ls='-', alpha=0.7)
ax_b.axhline(z_iGe_bot_um, color='black', lw=0.6, ls=':', alpha=0.6)

ax_b.set_xlim(-3.0, 3.0)
ax_b.set_ylim(0.0, 0.60)
ax_b.set_aspect(5.0)
ax_b.set_anchor('S')

ax_b.set_xlabel(r'$y$ — width ($\mu$m)', labelpad=2)
ax_b.set_ylabel(r'$z$ — height ($\mu$m)', labelpad=2)
ax_b.set_title(r'CHARGE Potential $\varphi(y,z)$', fontsize=9, pad=4)

cb_b = fig.colorbar(im_b, ax=ax_b, pad=0.02, fraction=0.046)
cb_b.set_label(r'Potential $\varphi$ (V)', fontsize=8)
cb_b.ax.tick_params(labelsize=7.5)
ax_b.text(-0.16, 1.04, '(b)', transform=ax_b.transAxes, **label_kw)

# ── (c) G(x) + cumulative — longitudinal profile (grayscale/formal) ─────────
ax_c  = fig.add_subplot(2, 2, 3)
ax_c2 = ax_c.twinx()
col_G, col_cum = 'black', 'dimgray'

line_G, = ax_c.plot(x_gen, G_x_avg/G_x_avg.max()*100, color=col_G, lw=1.5,
                    label=r'$\langle G_\mathrm{opt}\rangle_{y,z}$')
line_cum, = ax_c2.plot(x_gen, G_cum_x_norm, color=col_cum, lw=1.5, ls='--',
                       label='Cumulative')

ax_c.set_xlabel(r'$x$ — length ($\mu$m)', labelpad=2)
ax_c.set_ylabel(r'$\langle G_\mathrm{opt}\rangle_{y,z}$ (norm., %)', color='black')
ax_c2.set_ylabel('Cumulative generation (%)', color='dimgray')
ax_c.tick_params(axis='y', labelcolor='black')
ax_c2.tick_params(axis='y', labelcolor='dimgray')
ax_c.set_ylim(-5, 110)
ax_c2.set_ylim(0, 115)

ax_c.axvline(0.0, color='gray', lw=0.8, ls=':')
ax_c.axvline(8.0, color='gray', lw=0.8, ls=':')

ax_c.set_xlim(-0.5, 8.5)
ax_c.set_title('Longitudinal Generation Profile', fontsize=9, pad=4)
ax_c.grid(True, ls=':', lw=0.4, color='gray')
ax_c.legend([line_G, line_cum], [line_G.get_label(), line_cum.get_label()],
            fontsize=7.5, loc='center right', framealpha=0.9)
ax_c.text(-0.16, 1.04, '(c)', transform=ax_c.transAxes, **label_kw)

# ── (d) Band diagram at V = -1 V — formal colors ────────────────────────────
ax_d = fig.add_subplot(2, 2, 4)
ax_d.plot(z_band, Ec_1V,  color='black', lw=1.5, label=r'$E_c$')
ax_d.plot(z_band, Ev_1V,  color='black', lw=1.5, ls='-', label=r'$E_v$', alpha=0.8)
ax_d.plot(z_band, Efn_1V, color='dimgray', lw=1.2, ls=':', label=r'$E_{Fn}$')
ax_d.plot(z_band, Efp_1V, color='gray', lw=1.2, ls='-.', label=r'$E_{Fp}$')

ax_d.axvline(z_iGe_bot_um,  color='gray', lw=0.8, ls=':')
ax_d.axvline(z_Npp_bot_um,  color='gray', lw=0.8, ls=':')

ylims = ax_d.get_ylim()
ytop  = ylims[1] - (ylims[1] - ylims[0]) * 0.05
ax_d.text((0 + z_iGe_bot_um)/2,           ytop,
          'p-Si', ha='center', va='top', fontsize=7.5,
          color='black', style='italic')
ax_d.text((z_iGe_bot_um + z_Npp_bot_um)/2, ytop,
          'i-Ge',           ha='center', va='top', fontsize=7.5,
          color='black',  style='italic')
z_npp_mid = (z_Npp_bot_um + z_band.max()) / 2
ax_d.text(z_npp_mid,                        ytop,
          'n-Ge', ha='center', va='top', fontsize=7.0,
          color='black',    style='italic')

ax_d.set_xlabel(r'$z$ — height ($\mu$m)', labelpad=2)
ax_d.set_ylabel('Energy (eV)', labelpad=2)
ax_d.set_title(r'Band Diagram ($V_\mathrm{bias} = -1\,$V)', fontsize=9, pad=4)
ax_d.legend(fontsize=7.5, loc='lower left', framealpha=0.9)
ax_d.grid(True, ls=':', lw=0.4, color='gray')
ax_d.text(-0.16, 1.04, '(d)', transform=ax_d.transAxes, **label_kw)

# Adjust margins to exactly match other figures with extra space to prevent label overlap
fig.subplots_adjust(left=0.09, right=0.91, bottom=0.10, top=0.92, wspace=0.40, hspace=0.38)

out_path = out_dir / 'panel_08_fields.png'
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f'Saved: {out_path}')
