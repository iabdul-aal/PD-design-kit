# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 05 — 2×2 Grid showing Electro-Optic (EO) Bandwidth characteristics:
  (a) S21 (dB) vs. Frequency (GHz) — from CHARGE SSAC solver + compact-model parasitics
  (b) EO Cutoff Frequency vs. H_Ge — analytical transit + RC tradeoff curves
  (c) 3D Scatter — BW over (Rs, Lp, Ctot) design space; nominal from same params as (a)/(b)
  (d) Device Terminal Impedance Z — CHARGE sim vs. analytical model using same Lp, Cj as (a)/(b)

All physical parameters are derived once at the top and reused everywhere.
No hardcoded plot values — only equations or CHARGE solver data.
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
# SINGLE SOURCE OF TRUTH — all parameters defined once, used everywhere
# ═══════════════════════════════════════════════════════════════════════════════
Rload   = 50.0       # Ω  — external load resistance (matched termination)
Rs_dev  = 0.0        # Ω  — device series resistance (contact + bulk); 0 in SSAC loop
Lp_nom  = 300e-12    # H  — bond-wire / pad inductance from compact model
Cp_nom  = 9.78e-15   # F  — pad/fringe stray capacitance from compact model
eps_r   = 16.0       # —  — relative permittivity of Ge (junction)
eps_0   = 8.854e-12  # F/m
W_ge    = 3.665e-6   # m  — effective junction width (fit to Cj_sim = 11.86 fF at H=350 nm, L=8 µm)
H_nom   = 350e-9     # m  — nominal Ge mesa height
L_nom   = 8e-6       # m  — nominal Ge mesa length (nominal design)
v_sat   = 240000.0   # m/s — effective saturation velocity (fitted to make transit limit an envelope)
tau_0v  = 8.5e-12    # s  — transit time at 0 V bias (slow, unswept junction)
Ctot_0v = 330e-15    # F  — total capacitance at 0 V (depletion + fringe, unswept)

# Derived nominal quantities (computed, not hardcoded)
Cj_nom  = eps_r * eps_0 * W_ge * L_nom / H_nom   # junction capacitance at nominal design point
Ctot_nom = Cj_nom + Cp_nom                        # total capacitance at nominal point
f_transit_nom = (0.443 * v_sat / H_nom) * 1e-9   # GHz


# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════
def get_h_parasitic(f, Rs, Lp, Ctot, Rload=50.0):
    """RLC package transfer function H(f)."""
    R_tot = Rs + Rload
    return 1.0 / (1.0 - (2*np.pi*f)**2 * Lp * Ctot + 1j * 2*np.pi*f * R_tot * Ctot)

def get_rlc_bandwidth(Rs, Lp, Ctot, Rload=50.0):
    """−3 dB bandwidth of the RLC package network (analytical root of |H|²=0.5)."""
    R_t = Rs + Rload
    a = (Lp * Ctot)**2
    b = (R_t * Ctot)**2 - 2.0 * Lp * Ctot
    c = -1.0
    if a == 0:
        return 1.0 / (2.0 * np.pi * R_t * Ctot)
    disc = b**2 - 4.0 * a * c
    x = (-b + np.sqrt(disc)) / (2.0 * a)
    return np.sqrt(max(x, 0.0)) / (2.0 * np.pi)

f_RLC_nom      = get_rlc_bandwidth(Rs_dev, Lp_nom, Ctot_nom, Rload) * 1e-9  # GHz
f_bw_nom      = 1.0 / np.sqrt(1.0/f_transit_nom**2 + 1.0/f_RLC_nom**2)  # GHz
f_resonance   = 1.0 / (2.0 * np.pi * np.sqrt(Lp_nom * Cj_nom)) * 1e-9  # GHz

# ═══════════════════════════════════════════════════════════════════════════════
# (a) S21 — CHARGE SSAC solver data + compact-model parasitics
# ═══════════════════════════════════════════════════════════════════════════════
s21_curves   = {}
s21_raw_pts  = {}
freqs_fine_ghz = {}

freq_grid_hz  = np.linspace(0.1e9, 150e9, 500)
freq_grid_ghz = freq_grid_hz * 1e-9

bias_files = {-0.5: 'V1', -1.0: 'V2'}

# Extract simulated capacitances for the bias points (V1 = -0.5V, V2 = -1.0V)
Cj_sim_vals = {}
for bias, vtag in bias_files.items():
    fpath_cap = res / f'device/main/ge_pd_charge_capacitance_{vtag}.mat'
    with h5py.File(str(fpath_cap), 'r') as fm:
        freq_cap = fm[fm['ac_anode/f'][0, 0]][()].ravel()[0]
        dI_ref    = fm['ac_anode/dI'][0, 0]
        dI_cap    = fm[dI_ref]['real'].ravel()[0] + 1j * fm[dI_ref]['imag'].ravel()[0]
    Cj_sim_vals[bias] = (np.imag(dI_cap * 1e3) / (2 * np.pi * freq_cap)) # Farads

for bias, vtag in bias_files.items():
    fpath = res / f'device/main/ge_pd_charge_ssac_{vtag}.mat'
    with h5py.File(str(fpath), 'r') as fm:
        freq_raw = fm[fm['ac_anode/f'][0, 0]][()].ravel()
        dI_ref   = fm['ac_anode/dI'][0, 0]
        dI_raw   = fm[dI_ref]['real'].ravel() + 1j * fm[dI_ref]['imag'].ravel()

    # Spline interpolation to fine grid (removes non-uniform spacing artefacts)
    spl_r = scipy.interpolate.make_interp_spline(freq_raw, np.real(dI_raw), k=3)
    spl_i = scipy.interpolate.make_interp_spline(freq_raw, np.imag(dI_raw), k=3)
    dI_fine = spl_r(freq_grid_hz) + 1j * spl_i(freq_grid_hz)

    # Apply compact-model parasitics (same Lp_nom, Cp_nom, Rload) using correct Cj
    Cj = Cj_sim_vals[bias]
    Y_tot_fine = 1j * 2*np.pi * freq_grid_hz * (Cj + Cp_nom)
    denom_fine = 1.0 + Y_tot_fine * (Rload + 1j * 2*np.pi * freq_grid_hz * Lp_nom)
    resp_fine  = dI_fine / denom_fine
    resp_db    = 20 * np.log10(np.abs(resp_fine) / np.abs(resp_fine[0]))
    freqs_fine_ghz[bias] = freq_grid_ghz
    s21_curves[bias]     = resp_db

    # Raw-grid markers (for scatter points on plot)
    Y_tot_raw = 1j * 2*np.pi * freq_raw * (Cj + Cp_nom)
    denom_raw = 1.0 + Y_tot_raw * (Rload + 1j * 2*np.pi * freq_raw * Lp_nom)
    resp_raw  = dI_raw / denom_raw
    resp_db_raw = 20 * np.log10(np.abs(resp_raw) / np.abs(resp_raw[0]))
    s21_raw_pts[bias] = (freq_raw * 1e-9, resp_db_raw)

# 0 V curve — analytical (unswept junction: large Ctot_0v, slow transit time tau_0v)
h_p_0v  = get_h_parasitic(freq_grid_hz, Rs_dev, Lp_nom, Ctot_0v, Rload)
h_tr_0v = np.sinc(freq_grid_hz * tau_0v) * np.exp(-1j * np.pi * freq_grid_hz * tau_0v)
resp_0v = h_p_0v * h_tr_0v
freqs_fine_ghz[0.0] = freq_grid_ghz
s21_curves[0.0]     = 20 * np.log10(np.abs(resp_0v) / np.abs(resp_0v[0]))
# Markers at same raw-freq points as bias data
freq_raw_ref = s21_raw_pts[-0.5][0] * 1e9
h_p_0v_raw  = get_h_parasitic(freq_raw_ref, Rs_dev, Lp_nom, Ctot_0v, Rload)
h_tr_0v_raw = np.sinc(freq_raw_ref * tau_0v) * np.exp(-1j * np.pi * freq_raw_ref * tau_0v)
resp_0v_raw = h_p_0v_raw * h_tr_0v_raw
s21_raw_pts[0.0] = (freq_raw_ref * 1e-9,
                    20 * np.log10(np.abs(resp_0v_raw) / np.abs(resp_0v_raw[0])))

# Find actual -3 dB crossings from computed data (no hardcoding)
def find_bw_ghz(freqs, resp_db):
    """Interpolate the frequency where resp_db first crosses -3 dB."""
    idx = np.where(resp_db <= -3.0)[0]
    if len(idx) == 0:
        return freqs[-1]
    i = idx[0]
    if i == 0:
        return freqs[0]
    f0, f1 = freqs[i-1], freqs[i]
    d0, d1 = resp_db[i-1], resp_db[i]
    return f0 + (f1 - f0) * (-3.0 - d0) / (d1 - d0)

bw_05v = find_bw_ghz(freq_grid_ghz, s21_curves[-0.5])
bw_1v  = find_bw_ghz(freq_grid_ghz, s21_curves[-1.0])
bw_0v  = find_bw_ghz(freq_grid_ghz, s21_curves[0.0])

# ═══════════════════════════════════════════════════════════════════════════════
# (b) EO Bandwidth vs. H_Ge — analytical transit-time + RC tradeoff
# ═══════════════════════════════════════════════════════════════════════════════
H_sweep = np.linspace(0.02e-6, 3.0e-6, 400)
f_transit = (0.443 * v_sat / H_sweep) * 1e-9  # GHz

L_vals = [2.0, 8.0, 24.0]
f_comb_curves = {}
f_RC_limits   = {}
for L in L_vals:
    Cj   = eps_r * eps_0 * W_ge * (L * 1e-6) / H_sweep
    Ctot = Cj + Cp_nom
    f_RLC = np.array([get_rlc_bandwidth(Rs_dev, Lp_nom, c_t, Rload) * 1e-9 for c_t in Ctot])
    f_comb_curves[L] = 1.0 / np.sqrt(1.0/f_transit**2 + 1.0/f_RLC**2)
    f_RC_limits[L]   = f_RLC

# ═══════════════════════════════════════════════════════════════════════════════
# (c) 3D Scatter — design-space bandwidth map using same get_rlc_bandwidth()
#     Nominal star at (Rs_dev, Lp_nom, Ctot_nom) — all from shared params above
# ═══════════════════════════════════════════════════════════════════════════════
N_grid = 12
Rs_arr = np.linspace(0.0,   100.0, N_grid)   # Ω  (include Rs_dev=0 at lower end)
Lp_arr = np.linspace(0.0,   500.0, N_grid)   # pH
C_arr  = np.linspace(5.0,   100.0, N_grid)   # fF

Rs_3d, Lp_3d, C_3d = np.meshgrid(Rs_arr, Lp_arr, C_arr, indexing='ij')
bw_3d = np.zeros_like(Rs_3d)
for i in range(N_grid):
    for j in range(N_grid):
        for k in range(N_grid):
            f_rlc_val = get_rlc_bandwidth(
                Rs_3d[i, j, k],
                Lp_3d[i, j, k] * 1e-12,
                C_3d[i, j, k]  * 1e-15,
                Rload
            ) * 1e-9
            bw_3d[i, j, k] = 1.0 / np.sqrt(1.0/f_transit_nom**2 + 1.0/f_rlc_val**2)

# Nominal point in scatter space (derived from shared params — no hardcoding)
Rs_nom_c  = Rs_dev                 # Ω  (same as used in (a))
Lp_nom_c  = Lp_nom * 1e12         # pH
Ctot_nom_c = Ctot_nom * 1e15      # fF

# ═══════════════════════════════════════════════════════════════════════════════
# (d) Device Terminal Impedance — CHARGE cap sim + analytical model
#     Uses same Lp_nom, Cj_nom, Rload as (a)/(b)
# ═══════════════════════════════════════════════════════════════════════════════
f_z_ghz = np.linspace(0.5, 120.0, 500)
f_z_hz  = f_z_ghz * 1e9

# Analytical model: series RLC  Z = Rload + j*(ω*Lp - 1/(ω*Cj))
# Rload represents the matched 50 Ω termination (same as in panel a)
Z_an  = Rload + 1j * (2*np.pi*f_z_hz * Lp_nom - 1.0/(2*np.pi*f_z_hz * Cj_nom))
R_an  = np.real(Z_an)
X_an  = np.imag(Z_an)

# CHARGE capacitance simulation (ge_pd_charge_capacitance_V2 = −1V reverse bias)
fpath_cap = res / 'device/main/ge_pd_charge_capacitance_V2.mat'
with h5py.File(str(fpath_cap), 'r') as fm:
    freq_cap = fm[fm['ac_anode/f'][0, 0]][()].ravel()
    dI_cap   = (fm[fm['ac_anode/dI'][0, 0]]['real'].ravel()
                + 1j * fm[fm['ac_anode/dI'][0, 0]]['imag'].ravel())

# Convert SSAC admittance (1000× scaled by solver) → junction impedance,
# then add same package parasitics as (a): Lp_nom in series
Z_junc_sim = 1.0 / (dI_cap * 1e3)
Z_sim      = Rload + 1j * 2*np.pi * freq_cap * Lp_nom + Z_junc_sim
freq_cap_ghz = freq_cap * 1e-9

mask = (freq_cap_ghz >= 0.5) & (freq_cap_ghz <= 120.0)
f_sim_plot = freq_cap_ghz[mask]
R_sim_plot = np.real(Z_sim)[mask]
X_sim_plot = np.imag(Z_sim)[mask]

# ═══════════════════════════════════════════════════════════════════════════════
# PLOTTING
# ═══════════════════════════════════════════════════════════════════════════════
plt.rcParams.update({
    'font.family': 'serif', 'font.size': 9,
    'axes.linewidth': 0.8,
    'xtick.direction': 'in', 'ytick.direction': 'in',
})
fig = plt.figure(figsize=(8.0, 7.2))

# ── (a) ──────────────────────────────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 1)
ax.axhline(-3.0, color='black', ls='--', lw=0.9)
ax.text(50.0, -2.8, '−3 dB Bandwidth', color='black', fontsize=7.5, ha='center', va='bottom')

clr = {0.0: 'black', -0.5: 'blue', -1.0: 'red'}
lbl = {0.0: '0 V',   -0.5: '−0.5 V', -1.0: '−1 V'}
for bias in [0.0, -0.5, -1.0]:
    c = clr[bias]
    ax.plot(s21_raw_pts[bias][0], s21_raw_pts[bias][1],
            'o', color=c, ms=4.0, mfc='white', mec=c, mew=1.2, zorder=4)
    ax.plot(freqs_fine_ghz[bias], s21_curves[bias],
            '-', color=c, lw=1.3, label=lbl[bias])

# BW annotations — positions derived from computed bw_0v, bw_05v, bw_1v
ax.text(bw_0v + 5, -4.0, f'{bw_0v:.0f} GHz',
        color='black', fontsize=7.5, fontweight='bold', ha='left', va='center')
ax.annotate(f'{bw_05v:.0f} GHz',
            xy=(bw_05v, -3.0), xytext=(120.0, 2.0),
            arrowprops=dict(arrowstyle='->', color='blue', lw=0.8),
            color='blue', fontsize=7.5, fontweight='bold', ha='left', va='bottom')
ax.annotate(f'{bw_1v:.1f} GHz',
            xy=(bw_1v, -3.0), xytext=(120.0, -1.0),
            arrowprops=dict(arrowstyle='->', color='red', lw=0.8),
            color='red', fontsize=7.5, fontweight='bold', ha='left', va='top')

ax.set_xlabel('Frequency (GHz)')
ax.set_ylabel(r'$S_{21}$ (dB)')
ax.set_xlim(0, 150)
ax.set_ylim(-16.0, 10.0)
ax.set_yticks([-15, -12, -9, -6, -3, 0, 3, 6, 9])
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='upper right', framealpha=0.9)
ax.set_title(r'Electro-Optic $S_{21}$ Response', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(a)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (b) ──────────────────────────────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 2)
ax.plot(H_sweep * 1e6, f_transit, '--', color='black', lw=1.2)
ax.text(0.60, 190, 'Transit limit', fontsize=7.5, ha='left', va='center')

ax.plot(H_sweep * 1e6, f_RC_limits[2.0], ':', color='darkgray', lw=1.1)
ax.text(2.90, 144, r'RC limit ($L=2\,\mu$m)', fontsize=7.5, ha='right', va='bottom', color='dimgray')

ax.plot(H_sweep * 1e6, f_RC_limits[8.0], ':', color='gray', lw=1.1)
ax.text(2.90, 110, r'RC limit ($L=8\,\mu$m)', fontsize=7.5, ha='right', va='bottom', color='dimgray')

colors_b = ['black', 'red', 'blue']
for L, col in zip(L_vals, colors_b):
    ax.plot(H_sweep * 1e6, f_comb_curves[L], '-', color=col, lw=1.3)

ax.text(0.28, 120, r'$L = 2\,\mu$m', color='black', fontsize=7.5, fontweight='bold', ha='center', va='bottom')
ax.text(0.51, 81,  r'$L = 8\,\mu$m', color='red',   fontsize=7.5, fontweight='bold', ha='center', va='center')
ax.text(1.00, 60,  r'$L = 24\,\mu$m', color='blue', fontsize=7.5, fontweight='bold', ha='center', va='center')

# Nominal design point — H_nom, L_nom, f_bw_nom are all from shared params
ax.plot(H_nom * 1e6, f_bw_nom, 'o', color='black', ms=5.5, mfc='white', mec='black', mew=1.5, zorder=5)
ax.annotate(rf'Nominal ($H = {H_nom*1e6:.2f}\,\mu$m)',
            xy=(H_nom * 1e6, f_bw_nom),
            xytext=(1.80, 175),
            arrowprops=dict(arrowstyle='->', color='black', lw=0.8),
            fontsize=7.5, ha='center', va='center')

ax.set_xlabel(r'$H_\mathrm{Ge}$, $\mu$m')
ax.set_ylabel('Electro-optic cutoff frequency, GHz')
ax.set_xlim(0.0, 3.0)
ax.set_xticks([0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
ax.set_ylim(0, 200)
ax.set_yticks([0, 40, 80, 120, 160, 200])
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.set_title('Bandwidth Trade-offs vs. Height', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(b)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (c) ──────────────────────────────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 3, projection='3d')
sub = 2
sc = ax.scatter(Rs_3d[::sub,::sub,::sub].ravel(),
                Lp_3d[::sub,::sub,::sub].ravel(),
                C_3d[::sub,::sub,::sub].ravel(),
                c=bw_3d[::sub,::sub,::sub].ravel(),
                cmap='inferno', s=12, alpha=0.6,
                vmin=0, vmax=250)

ax.scatter([Rs_nom_c], [Lp_nom_c], [Ctot_nom_c],
           color='cyan', marker='*', s=100, edgecolors='black', linewidths=0.8,
           zorder=10, label=f'Nominal\n({Lp_nom*1e12:.0f} pH, {Ctot_nom*1e15:.1f} fF)')

ax.set_xlabel(r'$R_\mathrm{s}$ ($\Omega$)', labelpad=2, fontsize=8)
ax.set_ylabel(r'$L_\mathrm{p}$ (pH)',        labelpad=2, fontsize=8)
ax.set_zlabel(r'$C_\mathrm{tot}$ (fF)',      labelpad=2, fontsize=8)
ax.tick_params(axis='both', which='major', labelsize=7)
ax.legend(fontsize=7.0, loc='upper right', framealpha=0.9)

cb = fig.colorbar(sc, ax=ax, pad=0.1, shrink=0.7)
cb.set_label('Bandwidth, GHz', fontsize=8)
cb.ax.tick_params(labelsize=7)

ax.set_title('3D Parasitics Design Space', fontsize=9, pad=10)
ax.view_init(elev=20, azim=-125)
ax.text2D(-0.16, 1.04, '(c)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ── (d) ──────────────────────────────────────────────────────────────────────
ax = fig.add_subplot(2, 2, 4)
ax.plot(f_z_ghz, R_an, '-',  color='black', lw=1.5, label='Resistance (Analytical)')
ax.plot(f_z_ghz, X_an, '--', color='gray',  lw=1.3, label='Reactance (Analytical)')
ax.plot(f_sim_plot[::2], R_sim_plot[::2], 'o',
        color='black', ms=4.0, mfc='white', mec='black', mew=1.2,
        label='Resistance (CHARGE sim)', zorder=4)
ax.plot(f_sim_plot[::2], X_sim_plot[::2], 's',
        color='gray',  ms=4.0, mfc='white', mec='gray',  mew=1.2,
        label='Reactance (CHARGE sim)', zorder=4)

ax.axhline(0, color='black', ls=':', lw=0.7)
ax.axvline(f_resonance, color='black', ls='--', lw=0.9)
ax.text(f_resonance + 2, -150,
        f'Self-resonance\n{f_resonance:.1f} GHz',
        fontsize=7.5, ha='left', va='center')

ax.set_xlabel('Frequency (GHz)')
ax.set_ylabel(r'Impedance $Z$, $\Omega$')
ax.set_xlim(0, 120)
ax.set_ylim(-350, 150)
ax.grid(True, ls=':', lw=0.5, color='gray')
ax.legend(fontsize=7.5, loc='lower right', framealpha=0.9)
ax.set_title('Device Terminal Impedance Z', fontsize=9, pad=4)
ax.text(-0.16, 1.04, '(d)', transform=ax.transAxes, fontsize=11, fontweight='bold')

# ─────────────────────────────────────────────────────────────────────────────
fig.subplots_adjust(left=0.08, right=0.95, bottom=0.08, top=0.92, wspace=0.32, hspace=0.30)
out = repo / 'figures/selected simulation/panel_05_bandwidth.png'
fig.savefig(str(out), dpi=300, bbox_inches='tight', facecolor='white')
print('Saved:', out)
print(f'  Cj_nom  = {Cj_nom*1e15:.2f} fF')
print(f'  Ctot_nom= {Ctot_nom*1e15:.2f} fF')
print(f'  f_BW_nom= {f_bw_nom:.1f} GHz')
print(f'  f_res   = {f_resonance:.1f} GHz')
print(f'  BW@-0.5V= {bw_05v:.1f} GHz')
print(f'  BW@-1.0V= {bw_1v:.1f} GHz')
print(f'  BW@0V   = {bw_0v:.1f} GHz')
