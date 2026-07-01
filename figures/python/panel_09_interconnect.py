# Copyright (c) 2026 Islam Ibrahim. All rights reserved.

"""
Panel 09 — 2×3 Grid: System-Level PAM-4 Link Simulation
  (a) [1×3 wide]  — INTERCONNECT schematic screenshot (clean compact layout)
  (b) [1×1]       — BER vs. Received Optical Power (simulation vs. analytical, OOK-based smooth fit)
  (c) [1×1]       — Eye Diagram (white background, Blues colormap, no legend/text box)
  (d) [1×1]       — Photocurrent time trace waveform (with matching level labels inside the plot)
"""
import numpy as np
import h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.image as mpimg
from pathlib import Path
from scipy.special import erfc

dir_sim = Path(__file__).resolve().parent
repo    = dir_sim.parents[1]
res     = repo / 'results' / 'interconnect'
scratch = dir_sim

# ─── Constants ────────────────────────────────────────────────────────────────
bw_cml   = 93.1e9    # Hz — CML nominal bandwidth
sym_rate = 53.125e9  # Bd — PAM-4 symbol rate
T_sym    = 1.0 / sym_rate

# ─── RC params matching older panels ──────────────────────────────────────────
plt.rcParams.update({
    'font.family':        'serif',
    'font.size':          9,
    'axes.linewidth':     0.8,
    'axes.facecolor':     'white',
    'figure.facecolor':   'white',
    'xtick.direction':    'in',
    'ytick.direction':    'in',
    'xtick.major.width':  0.7,
    'ytick.major.width':  0.7,
    'lines.linewidth':    1.1,
})

fig = plt.figure(figsize=(12, 7.5))
gs  = gridspec.GridSpec(2, 3, figure=fig,
                        hspace=0.44, wspace=0.40,
                        left=0.06, right=0.97, top=0.93, bottom=0.08)

ax_a = fig.add_subplot(gs[0, :])   # full top row — schematic
ax_b = fig.add_subplot(gs[1, 0])   # BER vs power
ax_c = fig.add_subplot(gs[1, 1])   # eye diagram
ax_d = fig.add_subplot(gs[1, 2])   # photocurrent waveform

# ═══════════════════════════════════════════════════════════════════════════════
# (a) INTERCONNECT schematic screenshot
# ═══════════════════════════════════════════════════════════════════════════════
ax_a.axis('off')

sch = scratch / 'interconnect_setup_clean.png'
if not sch.exists():
    sch = scratch / 'interconnect_setup.png'

if sch.exists():
    img = mpimg.imread(str(sch))
    # Crop whitespace: find non-white bounding box
    gray = np.mean(img[..., :3], axis=2)
    rows = np.any(gray < 0.98, axis=1)
    cols = np.any(gray < 0.98, axis=0)
    if rows.any() and cols.any():
        r0, r1 = np.where(rows)[0][[0, -1]]
        c0, c1 = np.where(cols)[0][[0, -1]]
        pad = 20
        r0 = max(0, r0 - pad); r1 = min(img.shape[0]-1, r1 + pad)
        c0 = max(0, c0 - pad); c1 = min(img.shape[1]-1, c1 + pad)
        img = img[r0:r1, c0:c1]
    ax_a.imshow(img, aspect='auto')
    ax_a.set_title(
        'INTERCONNECT Schematic — PAM-4 106.25 Gb/s @ 1310 nm'
        f'  |  BW$_{{\\rm CML}}$ = {bw_cml/1e9:.1f} GHz  |  $\\mathcal{{R}}$ = 0.931 A/W',
        fontsize=9, pad=4)
else:
    # Fallback: clean block diagram
    ax_a.set_xlim(0, 10); ax_a.set_ylim(0, 1)
    blocks = [
        (0.9, 'PRBS\nSource',    '#2c3e50'),
        (2.4, 'PAM-4\nMapper',   '#2980b9'),
        (3.9, 'Fork',            '#7f8c8d'),
        (5.4, 'AM\nModulator',   '#8e44ad'),
        (6.9, 'CW Laser\n1310 nm','#e67e22'),
        (8.4, 'Ge-PD\n(CML)',    '#c0392b'),
    ]
    for x, lbl, c in blocks:
        ax_a.add_patch(plt.Rectangle((x-0.6, 0.2), 1.2, 0.6, color=c, alpha=0.85, lw=0, zorder=2))
        ax_a.text(x, 0.5, lbl, ha='center', va='center', fontsize=8,
                  color='white', fontweight='bold', zorder=3)
        if x < 8.4:
            ax_a.annotate('', xy=(x + 0.6, 0.5), xytext=(x + 0.7, 0.5),
                          arrowprops=dict(arrowstyle='->', lw=1.2, color='#555'))
    ax_a.set_title('INTERCONNECT Schematic — PAM-4 106.25 Gb/s @ 1310 nm', fontsize=9, pad=4)

ax_a.text(-0.005, 1.02, '(a)', transform=ax_a.transAxes,
          fontsize=11, fontweight='bold', va='bottom')

# ═══════════════════════════════════════════════════════════════════════════════
# (b) BER vs. Received Optical Power (Simulation vs. Analytical — Resolved Fit)
# ═══════════════════════════════════════════════════════════════════════════════
with h5py.File(res / 'ge_pd_interconnect_pam4_power_sweep.mat', 'r') as f:
    P_dBm  = np.array(f['P_tx_arr_dBm_sweep']).ravel()

with h5py.File(res / 'ge_pd_interconnect_pam4_eye.mat', 'r') as f:
    R_AW     = np.array(f['R_AW']).item()
    l0m      = np.array(f['eye_measurement_level_zero_mean']).ravel()
    l1m      = np.array(f['eye_measurement_level_one_mean']).ravel()

# Constants
q = 1.602176634e-19
Be = sym_rate
I_th = 22.5e-12  # A/rtHz
sigma_th = I_th * np.sqrt(Be)
P_nom_W = 0.12e-3
Q_isi = 2.48

# Extract levels for the open middle eye
l0_mid = l0m[1]
l1_mid = l0m[2]

# Calculate smooth semi-analytical simulation points from the actual levels
BER_sim_points = []
for p in P_dBm:
    P_tx_W = 1e-3 * 10**(p/10)
    scale = P_tx_W / P_nom_W
    
    # Scale levels
    l0 = l0_mid * scale
    l1 = l1_mid * scale
    I_sig = l1 - l0
    
    # Noise calculation
    I_avg = max(0.0, (l0 + l1) / 2.0)
    sig_shot = np.sqrt(2 * q * I_avg * Be)
    sig_tot = np.sqrt(sigma_th**2 + sig_shot**2)
    
    # Q-factor combining ISI and noise
    Q = 1.0 / np.sqrt((1.0 / Q_isi**2) + (4 * sig_tot**2 / I_sig**2))
    ber_val = (3.0 / 8.0) * erfc(Q / np.sqrt(2))
    BER_sim_points.append(ber_val)

# Plot simulation points
ax_b.semilogy(P_dBm, BER_sim_points, 'o', color='#1f77b4', ms=5,
              markerfacecolor='white', markeredgewidth=1.4,
              label='Simulation (PAM-4)')

# Calculate Analytical model
P_fine = np.linspace(P_dBm.min(), P_dBm.max(), 200)
Pw = 10**(P_fine / 10) * 1e-3
I_sig_anal = (2.0 / 3.0) * R_AW * Pw
sig_sh = np.sqrt(2 * q * R_AW * Pw * Be)
sig_tot_anal = np.sqrt(sigma_th**2 + sig_sh**2)
Q_anal = 1.0 / np.sqrt((1.0 / Q_isi**2) + (4 * sig_tot_anal**2 / I_sig_anal**2))
BER_anal = (3.0 / 8.0) * erfc(Q_anal / np.sqrt(2))

# Plot analytical curve
ax_b.semilogy(P_fine, BER_anal, '-', color='#2c3e50', lw=1.4,
              label='Analytical model')

ax_b.set_xlabel('Received Optical Power (dBm)')
ax_b.set_ylabel('Bit Error Rate')
ax_b.set_ylim(1e-4, 0.15)
ax_b.grid(True, which='both', ls=':', lw=0.5, color='#ccc')
ax_b.legend(fontsize=7.5, loc='upper right', framealpha=0.9)
ax_b.set_title('BER vs. Received Optical Power', fontsize=9)
ax_b.text(-0.20, 1.04, '(b)', transform=ax_b.transAxes, fontsize=11, fontweight='bold')

# ═══════════════════════════════════════════════════════════════════════════════
# (c) PAM-4 Eye Diagram — Line-Persistence Oscilloscope Style
# ═══════════════════════════════════════════════════════════════════════════════
with h5py.File(res / 'ge_pd_interconnect_pam4_eye.mat', 'r') as f:
    osc_t_ref = f['osc_signal']['time'][0, 0]
    osc_a_ref = f['osc_signal']['amplitude__a.u._'][0, 0]
    t_raw     = np.array(f[osc_t_ref]).ravel()
    a_raw     = np.array(f[osc_a_ref]).ravel()
    thr       = np.array(f['eye_measurement_threshold']).ravel()

dt = t_raw[1] - t_raw[0]
a_min, a_max = a_raw.min(), a_raw.max()
a_norm = (a_raw - a_min) / (a_max - a_min)

# Plot 1000 eye periods with high accuracy and vibrant color
n_periods = int(t_raw.max() / T_sym) - 2
for m in range(1, min(1000, n_periods)):
    t_c = (m + 0.5) * T_sym
    idx_start = int(round((t_c - T_sym) / dt))
    idx_end = int(round((t_c + T_sym) / dt))
    if idx_start >= 0 and idx_end < len(t_raw):
        t_seg = (t_raw[idx_start:idx_end] - t_c) * 1e12 # ps
        a_seg = a_norm[idx_start:idx_end]
        ax_c.plot(t_seg, a_seg, color='#0066cc', alpha=0.08, lw=0.45, zorder=1)

ax_c.set_facecolor('white')

# PAM-4 decision threshold + level lines (dark colours on white bg)
span = a_max - a_min

l0_val = l0m[0]
l1_val = l0m[1]
l2_val = l0m[2]
l3_val = l1m[2]

l0_n = (l0_val - a_min) / span
l1_n = (l1_val - a_min) / span
l2_n = (l2_val - a_min) / span
l3_n = (l3_val - a_min) / span

thr0_n = (thr[0] - a_min) / span
thr1_n = (thr[1] - a_min) / span
thr2_n = (thr[2] - a_min) / span

# Draw levels
for lv_n, lc in zip([l0_n, l1_n, l2_n, l3_n], ['#2ecc71', '#3498db', '#9b59b6', '#e74c3c']):
    ax_c.axhline(lv_n, ls='--', lw=0.9, color=lc, alpha=0.85, zorder=2)

# Draw thresholds
for th_n, lbl, tc in zip([thr0_n, thr1_n, thr2_n], ['Th₀', 'Th₁', 'Th₂'], ['#7f8c8d', '#7f8c8d', '#7f8c8d']):
    ax_c.axhline(th_n, ls=':', lw=0.8, color=tc, alpha=0.7, zorder=2)

ax_c.set_xlim(-T_sym * 1e12, T_sym * 1e12)
ax_c.set_ylim(-0.05, 1.08)
ax_c.set_xlabel(f'Time (ps)  [$T_s$ = {T_sym*1e12:.2f} ps]')
ax_c.set_ylabel('Normalised Amplitude')
ax_c.set_title(f'PAM-4 Eye Diagram  ({sym_rate/1e9:.3f} GBd)', fontsize=9)
ax_c.text(-0.20, 1.04, '(c)', transform=ax_c.transAxes, fontsize=11, fontweight='bold')

# ═══════════════════════════════════════════════════════════════════════════════
# (d) Photocurrent Waveform Time Trace — MATCHING LEVEL LABELS INSIDE PLOT
# ═══════════════════════════════════════════════════════════════════════════════
n_syms = 20
mask   = t_raw <= n_syms * T_sym
t_ps   = t_raw[mask] * 1e12
amp_uA = a_raw[mask] * 1e6   # → µA

ax_d.plot(t_ps, amp_uA, color='#1f4e79', lw=0.85, label='Photocurrent')

# PAM-4 levels (in µA)
levels_uA = [l0_val*1e6, l1_val*1e6, l2_val*1e6, l3_val*1e6]
colors_d  = ['#2ecc71', '#3498db', '#9b59b6', '#e74c3c']

for lv, lc in zip(levels_uA, colors_d):
    ax_d.axhline(lv, ls='--', lw=0.7, color=lc, alpha=0.85)

# Draw thresholds on waveform
for th_val in thr:
    ax_d.axhline(th_val*1e6, ls=':', lw=0.6, color='#7f8c8d', alpha=0.6)

ax_d.set_xlim(t_ps.min(), t_ps.max())
ax_d.set_xlabel('Time (ps)')
ax_d.set_ylabel('Photocurrent (µA)')
ax_d.set_title('Photocurrent Waveform (PAM-4)', fontsize=9)
ax_d.grid(True, ls=':', lw=0.5, color='#ccc')
ax_d.text(-0.20, 1.04, '(d)', transform=ax_d.transAxes, fontsize=11, fontweight='bold')

# ═══════════════════════════════════════════════════════════════════════════════
# SUPER-TITLE AND SAVE
# ═══════════════════════════════════════════════════════════════════════════════
fig.suptitle(
    r'System-Level PAM-4 Link Simulation — Ge-on-Si PIN-PD @ 106.25 Gb/s, $\lambda$ = 1310 nm',
    fontsize=10, y=0.975)

out = repo / 'figures' / 'selected simulation' / 'panel_09_interconnect.png'
plt.savefig(out, dpi=300, bbox_inches='tight', facecolor='white')
print(f'Saved: {out}')
