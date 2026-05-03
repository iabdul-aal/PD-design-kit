
charge_mat = 'ge_pd_charge_results_oband_ushaped.mat';
fdtd_mat   = 'ge_pd_fdtd_results_oband_ushaped.mat';
cml_dir    = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'system-level');
if ~exist(cml_dir, 'dir'), mkdir(cml_dir); end
cml_mat    = fullfile(cml_dir, 'ge_pd_cml_oband_ushaped.mat');
cml_json   = fullfile(cml_dir, 'ge_pd_cml_oband_ushaped.json');

figure_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
style = thesis_style(figure_dir);

if ~exist(charge_mat, 'file')
    error('Missing %s. Run ge_pd_charge_oband_ushaped.lsf first.', charge_mat);
end
if ~exist(fdtd_mat, 'file')
    error('Missing %s. Run ge_pd_fdtd_oband_ushaped.lsf first.', fdtd_mat);
end

C = load(charge_mat);
F = load(fdtd_mat);

V_dk    = C.V_dk(:);
I_dk    = C.I_dk(:);
In_dk   = C.In_dk(:);
Ip_dk   = C.Ip_dk(:);
V_ill   = C.V_ill(:);
I_ill   = C.I_ill(:);
In_ill  = C.In_ill(:);
Ip_ill  = C.Ip_ill(:);
Id_1V   = C.Id_1V;
I_ph    = C.I_ph;
R_AW    = C.R_AW;
A_eff   = C.A_eff;
P_opt   = C.P_opt;
Ge_L    = C.Ge_L;
Ge_W    = C.Ge_W;
iGe_H   = C.iGe_H;
wg_H    = C.wg_H;
V_stop  = C.V_stop_val;
T_sim   = C.T_sim;
idx1V   = round(double(C.idx1V));

y_carr  = C.x_carr_v(:);  z_carr  = C.z_carr_v(:);
y_field = C.x_field_v(:); z_field = C.z_field_v(:);
y_dope  = C.x_dope_v(:);  z_dope  = C.z_dope_v(:);
y_mob   = C.x_mob_v(:);   z_mob   = C.z_mob_v(:);
y_band  = C.y_band(:);    z_band_v = C.z_band(:);

Ec_data  = C.Ec_data;
Ev_data  = C.Ev_data;
Efn_data = C.Efn_data;
Efp_data = C.Efp_data;
Ei_data  = C.Ei_data;
V_band   = C.V_band(:);

n_e     = C.n_e;
n_h     = C.n_h;
Jn      = C.Jn;
Jp      = C.Jp;
R_opt   = C.R_opt;
R_srh   = C.R_srh;
E_field = C.E_field;
V_pot   = C.V_pot;
NA      = C.NA;
ND      = C.ND;
mu_n    = C.mu_n;
mu_p    = C.mu_p;

A_TE      = F.A_TE;
lambda_c  = 1.31e-6;

q  = 1.602e-19;
kB = 1.381e-23;
h  = 6.626e-34;
c0 = 3e8;

RL = 50;

Eph    = h * c0 / lambda_c;
Phi    = P_opt / Eph;
EQE_f  = A_TE;
EQE_c  = (I_ph / q) / max(Phi, 1e-30);
IQE_c  = EQE_c / max(A_TE, 1e-10);

Sshot  = 2 * q * Id_1V;
Sth    = 4 * kB * T_sim / RL;
Stot   = Sshot + Sth;
NEP    = sqrt(Stot) / max(R_AW, 1e-20);
Dstar  = sqrt(A_eff) / max(NEP, 1e-40) * 1e2;

v_sat_e = 6.0e4;   % m/s, electron
v_sat_h = 4.7e4;   % m/s, hole
v_sat   = 2 * v_sat_e * v_sat_h / (v_sat_e + v_sat_h);  % harmonic mean
tau_tt  = iGe_H / v_sat;
f_tt    = 0.44 / tau_tt;

eps_Ge  = 16 * 8.854e-12;
Cj_geo  = eps_Ge * Ge_L * Ge_W / iGe_H;

Rsh_Si  = 100;  % Ohm/sq (computed from doping 1e20, slab 90nm)
Rs_par  = Rsh_Si * (Ge_W / 2) / Ge_L;
Rs_geo  = Rs_par * 0.64;  % U-shaped electrode: 36% reduction (from geometry analysis)
Cp_geo  = 10e-15;  % stray capacitance (layout-dependent estimate)

L_wire  = 195e-6;   % electrode connection length (from layout)
w_wire  = 2e-6;     % wire width
mu0     = 4*pi*1e-7;
Lp_geo  = mu0 / (2*pi) * L_wire * (log(2*L_wire / w_wire) + 0.25);

A_junc  = Ge_L * Ge_W;
Vbi_est = 0.6;                        % built-in voltage (Si P++ / Ge n-i-p ~ 0.5-0.7 V)
Vbias   = 1.0;                        % operating reverse bias magnitude
Isc_geo = eps_Ge * v_sat * (Vbias + Vbi_est) * A_junc / (iGe_H^2);
Psat_geo = Isc_geo / max(R_AW, 1e-10);

fRC     = 1 / (2 * pi * (Rs_geo + RL) * (Cj_geo + Cp_geo));
f3dB    = 1 / sqrt(1/f_tt^2 + 1/fRC^2);

irms   = sqrt(Stot * f3dB);
SNR    = 20 * log10(max(I_ph / max(irms, 1e-30), 1e-10));
Pmin   = NEP * sqrt(f3dB);
LDR    = 20 * log10(max(P_opt / max(Pmin, 1e-30), 1));

z_rib_top_d  = wg_H;
z_iGe_top_d  = z_rib_top_d + iGe_H;
y_center     = 0;
y_window     = max(50e-9, Ge_W / 100);

fprintf('\n=== Ge-on-Si PD Metrics | V=-1 V | T=%d K | lambda=%d nm ===\n', ...
    T_sim, round(lambda_c*1e9));
fprintf('  Dark current          : %8.4f nA   [paper: 1.3 nA]\n',   Id_1V*1e9);
fprintf('  Photocurrent          : %8.4f uA\n',                       I_ph*1e6);
fprintf('  Responsivity          : %8.4f A/W  [paper: 0.95 A/W]\n',  R_AW);
fprintf('  EQE (FDTD absorption) : %8.2f %%\n',                        EQE_f*100);
fprintf('  EQE (CHARGE current)  : %8.2f %%\n',                        EQE_c*100);
fprintf('  IQE (CHARGE current)  : %8.2f %%\n',                        IQE_c*100);
fprintf('  NEP                   : %.3e W/sqrt(Hz)\n',                 NEP);
fprintf('  D*                    : %.3e cm.Hz^0.5/W  [paper: 2.95e10]\n', Dstar);
fprintf('  SNR @ P_opt           : %8.2f dB\n',                        SNR);
fprintf('  LDR                   : %8.1f dB\n',                        LDR);
fprintf('  Cj (geometry)         : %8.2f fF\n',                       Cj_geo*1e15);
fprintf('  Rs (geometry+U-shape) : %8.2f Ohm\n',                      Rs_geo);
fprintf('  Transit-time BW       : %8.1f GHz\n',                       f_tt/1e9);
fprintf('  RC limit              : %8.1f GHz\n',                       fRC/1e9);
fprintf('  Combined BW (model)   : %8.1f GHz\n',                       f3dB/1e9);

[z_bd, Ec_z]  = extract_z_profile(y_band, z_band_v, squeeze_bias(Ec_data,  idx1V), y_center, y_window);
[~,    Ev_z]  = extract_z_profile(y_band, z_band_v, squeeze_bias(Ev_data,  idx1V), y_center, y_window);
[~,    Efn_z] = extract_z_profile(y_band, z_band_v, squeeze_bias(Efn_data, idx1V), y_center, y_window);
[~,    Efp_z] = extract_z_profile(y_band, z_band_v, squeeze_bias(Efp_data, idx1V), y_center, y_window);
[~,    Ei_z]  = extract_z_profile(y_band, z_band_v, squeeze_bias(Ei_data,  idx1V), y_center, y_window);

[z_cp, n_z]    = extract_z_profile(y_carr,  z_carr,  pick_col(n_e,     idx1V), y_center, y_window);
[~,    p_z]    = extract_z_profile(y_carr,  z_carr,  pick_col(n_h,     idx1V), y_center, y_window);
[~,    Ropt_z] = extract_z_profile(y_carr,  z_carr,  pick_col(R_opt,   idx1V), y_center, y_window);
[~,    Rsrh_z] = extract_z_profile(y_carr,  z_carr,  pick_col(R_srh,   idx1V), y_center, y_window);
[z_fp, E_z]    = extract_z_profile(y_field, z_field, pick_col_vec(E_field, idx1V), y_center, y_window);
[~,    Vp_z]   = extract_z_profile(y_field, z_field, pick_col(V_pot,   idx1V), y_center, y_window);
[z_dp, NA_z]   = extract_z_profile(y_dope,  z_dope,  pick_col(NA,      1),     y_center, y_window);
[~,    ND_z]   = extract_z_profile(y_dope,  z_dope,  pick_col(ND,      1),     y_center, y_window);
[z_mp, mun_z]  = extract_z_profile(y_mob,   z_mob,   pick_col(mu_n,    idx1V), y_center, y_window);
[~,    mup_z]  = extract_z_profile(y_mob,   z_mob,   pick_col(mu_p,    idx1V), y_center, y_window);

[ym, zm, Ropt_map] = interpolate_xz_map(y_carr, z_carr, pick_col(R_opt, idx1V), 260, 220);


if isfield(F, 'f_fdtd') && isfield(F, 'T_after_Ge_data') && isfield(F, 'T_ref_data')
    lam_nm = c0 ./ F.f_fdtd(:) * 1e9;
    T_a = F.T_after_Ge_data(:);
    T_r_spec = F.T_ref_data(:);
    T_r_spec(abs(T_r_spec) < 1e-10) = 1e-10;
    A_spec = max((T_r_spec - T_a) ./ T_r_spec, 0);
    [lam_nm, si] = sort(lam_nm);
    A_spec = A_spec(si);
    figure(1); clf;
    plot(lam_nm, A_spec*100, 'k-');
    xlabel('Wavelength (nm)');
    ylabel('Optical Absorption (%)');
    title('Absorption Spectrum -- O-band, TE mode');
    xlim([min(lam_nm) max(lam_nm)]); ylim([0 105]);
    grid on;
    save_thesis_figure(1, 'opt_absorption_spectrum', style);
end

figure(2); clf;
imagesc(ym*1e6, zm*1e9, log10(max(Ropt_map, 1e10)));
axis xy; colormap(gray_r);
cb = colorbar;
cb.Label.String = 'log_{10}(G_{opt}) (m^{-3} s^{-1})';
xlabel('y (\mum)'); ylabel('z (nm)');
title('Optical Generation Rate -- V = -1 V');
hold on;
yline(z_rib_top_d*1e9,  'w--', 'LineWidth', 1.2);
yline(z_iGe_top_d*1e9, 'w--', 'LineWidth', 1.2);
hold off;
save_thesis_figure(2, 'opt_generation_rate_map', style);

if isfield(F, 'Ex_xz') && isfield(F, 'Ez_xz')
    nF_xz = size(F.Ex_xz, 4);
    fc_idx = round(nF_xz/2);
    Ex_sl = squeeze(F.Ex_xz(:, :, 1, fc_idx));
    Ez_sl = squeeze(F.Ez_xz(:, :, 1, fc_idx));
    E2    = abs(Ex_sl).^2 + abs(Ez_sl).^2;
    figure(3); clf;
    imagesc(F.E_xz_x*1e6, F.E_xz_z*1e9, 10*log10(max(E2./max(E2(:)), 1e-6)).');
    axis xy; colormap(gray_r);
    cb2 = colorbar;
    cb2.Label.String = 'Normalised |E|^2 (dB)';
    xlabel('x (\mum)'); ylabel('z (nm)');
    title(sprintf('E-field Profile (XZ) -- \\lambda = %d nm', round(lambda_c*1e9)));
    caxis([-30 0]);
    save_thesis_figure(3, 'opt_efield_xz_profile', style);
end

if isfield(F, 'Pabs_data') && isfield(F, 'Pabs_total_data')
    lam_arr = c0 ./ F.Pabs_f(:) * 1e9;
    [~, lc_idx] = min(abs(lam_arr - lambda_c*1e9));
    if ndims(F.Pabs_data) >= 4
        Pabs_sl = squeeze(sum(F.Pabs_data(:, :, :, lc_idx), 2));  % sum over y
    else
        Pabs_sl = squeeze(F.Pabs_data(:, :, lc_idx));
    end
    figure(4); clf;
    imagesc(F.Pabs_x*1e6, F.Pabs_z*1e9, log10(max(Pabs_sl.', 1e-30)));
    axis xy; colormap(gray_r);
    cb3 = colorbar;
    cb3.Label.String = 'log_{10}(P_{abs}) (normalized)';
    xlabel('x (\mum)'); ylabel('z (nm)');
    title(sprintf('Power Absorption Distribution -- \\lambda = %d nm', round(lambda_c*1e9)));
    hold on;
    yline(z_rib_top_d*1e9,  'w--', 'LineWidth', 1.2);
    yline(z_iGe_top_d*1e9, 'w--', 'LineWidth', 1.2);
    hold off;
    save_thesis_figure(4, 'opt_power_absorption_map', style);
end

if isfield(F, 'G_data') && isfield(F, 'G_x') && isfield(F, 'G_z')
    G_vol = F.G_data;
    if ndims(G_vol) >= 3
        G_xz = squeeze(sum(G_vol, 2));
    else
        G_xz = G_vol;
    end
    figure(19); clf;
    imagesc(F.G_x*1e6, F.G_z*1e9, log10(max(G_xz.', 1)));
    axis xy; colormap(gray_r);
    cb_g = colorbar;
    cb_g.Label.String = 'log_{10}(G) (m^{-3} s^{-1})';
    xlabel('x (\mum)'); ylabel('z (nm)');
    title(sprintf('FDTD Optical Generation Rate (XZ) - \\lambda = %d nm', round(lambda_c*1e9)));
    hold on;
    yline(z_rib_top_d*1e9,  'w--', 'LineWidth', 1.2);
    yline(z_iGe_top_d*1e9, 'w--', 'LineWidth', 1.2);
    hold off;
    save_thesis_figure(19, 'opt_fdtd_generation_rate_xz', style);
end

figure(5); clf;
semilogy(abs(V_dk), abs(I_dk)*1e9, 'k-');
xlabel('Reverse Bias |V| (V)');
ylabel('|I_{dark}| (nA)');
title(sprintf('Dark I--V -- Ge-on-Si PD (0 to -%d V)', V_stop));
grid on; grid minor;
xlim([0 V_stop]);
save_thesis_figure(5, 'elec_dark_iv', style);

figure(6); clf;
semilogy(abs(V_dk), abs(I_dk)*1e9, 'k-', 'DisplayName', 'Dark');
hold on;
semilogy(abs(V_ill), abs(I_ill)*1e9, 'k--', 'DisplayName', ...
    sprintf('Illuminated (P_{opt}=%g \\muW, \\lambda=%g nm)', ...
    P_opt*1e6, round(lambda_c*1e9)));
hold off;
xlabel('Reverse Bias |V| (V)');
ylabel('|I| (nA)');
title('Dark vs Illuminated I--V');
legend('Location', 'northwest');
grid on;
xlim([0 V_stop]);
save_thesis_figure(6, 'elec_dark_vs_illuminated_iv', style);

figure(7); clf;
semilogy(abs(V_ill), abs(In_ill)*1e9, 'k-',  'DisplayName', 'I_n');
hold on;
semilogy(abs(V_ill), abs(Ip_ill)*1e9, 'k--', 'DisplayName', 'I_p');
semilogy(abs(V_ill), abs(I_ill)*1e9,  'k:',  'DisplayName', 'I_{total}');
hold off;
xlabel('Reverse Bias |V| (V)');
ylabel('Current (nA)');
title(sprintf('Current Components -- Illuminated (\\lambda=%d nm)', round(lambda_c*1e9)));
legend('Location', 'northwest');
grid on;
xlim([0 V_stop]);
save_thesis_figure(7, 'elec_current_components', style);

I_photo_vs_V = abs(I_ill) - abs(I_dk);
I_photo_vs_V = max(I_photo_vs_V, 0);
figure(8); clf;
plot(abs(V_ill), I_photo_vs_V*1e6, 'k-');
xlabel('Reverse Bias |V| (V)');
ylabel('Photocurrent I_{ph} (\muA)');
title(sprintf('Photocurrent vs Bias -- P_{opt}=%g \\muW', P_opt*1e6));
grid on;
xlim([0 V_stop]);
save_thesis_figure(8, 'elec_photocurrent_vs_bias', style);

R_vs_V = I_photo_vs_V / P_opt;
figure(9); clf;
plot(abs(V_ill), R_vs_V, 'k-');
yline(R_AW, 'k--', sprintf('R @ -1V = %.2f A/W', R_AW), ...
    'LabelHorizontalAlignment', 'left');
xlabel('Reverse Bias |V| (V)');
ylabel('Responsivity (A/W)');
title('Responsivity vs Bias');
grid on;
xlim([0 V_stop]);
save_thesis_figure(9, 'elec_responsivity_vs_bias', style);

EQE_vs_V = (I_photo_vs_V / q) / max(Phi, 1e-30);
figure(10); clf;
plot(abs(V_ill), EQE_vs_V*100, 'k-');
xlabel('Reverse Bias |V| (V)');
ylabel('EQE (%)');
title('External Quantum Efficiency vs Bias');
grid on;
xlim([0 V_stop]);
save_thesis_figure(10, 'elec_eqe_vs_bias', style);

z_lbl = sprintf('z (nm)  [y = %.2f \\mum, x = %.2f \\mum]', y_center*1e6, Ge_L/2*1e6);

figure(11); clf; hold on;
plot(z_bd*1e9, Ec_z,  'k-',  'DisplayName', 'E_c');
plot(z_bd*1e9, Ev_z,  'k--', 'DisplayName', 'E_v');
plot(z_bd*1e9, Efn_z, 'k:',  'DisplayName', 'E_{Fn}');
plot(z_bd*1e9, Efp_z, 'k-.', 'DisplayName', 'E_{Fp}');
plot(z_bd*1e9, Ei_z,  'k^',  'MarkerSize', 2, 'DisplayName', 'E_i');
xline(z_rib_top_d*1e9,  'k-', 'Label', 'Si/Ge',      'LabelVerticalAlignment', 'bottom');
xline(z_iGe_top_d*1e9, 'k-', 'Label', 'Ge/N^{++}',  'LabelVerticalAlignment', 'bottom');
hold off;
xlabel(z_lbl); ylabel('Energy (eV)');
title('Band Diagram -- V = -1 V');
legend('Location', 'best'); grid on;
save_thesis_figure(11, 'phys_band_diagram', style);

figure(12); clf; hold on;
semilogy(z_cp*1e9, max(n_z,  1e1), 'k-',  'DisplayName', 'n');
semilogy(z_cp*1e9, max(p_z,  1e1), 'k--', 'DisplayName', 'p');
semilogy(z_dp*1e9, max(NA_z, 1e1), 'k:',  'DisplayName', 'N_A');
semilogy(z_dp*1e9, max(ND_z, 1e1), 'k-.', 'DisplayName', 'N_D');
xline(z_rib_top_d*1e9, 'k-'); xline(z_iGe_top_d*1e9, 'k-');
hold off;
xlabel(z_lbl); ylabel('Carrier / Doping Density (cm^{-3})');
title('Carrier Density and Doping Profile -- V = -1 V');
legend('Location', 'best'); grid on;
save_thesis_figure(12, 'phys_carrier_density', style);

figure(13); clf;
xlabel(z_lbl);
yyaxis left;  plot(z_fp*1e9, E_z/1e6,  'k-');  ylabel('|E| (MV m^{-1})');
yyaxis right; plot(z_fp*1e9, Vp_z,     'k--'); ylabel('Potential V (V)');
xline(z_rib_top_d*1e9, 'k-'); xline(z_iGe_top_d*1e9, 'k-');

title('Electric Field and Electrostatic Potential -- V = -1 V');
grid on;
save_thesis_figure(13, 'phys_field_potential', style);

if ~isempty(mun_z)
    figure(14); clf; hold on;
    plot(z_mp*1e9, mun_z, 'k-',  'DisplayName', '\mu_n');
    plot(z_mp*1e9, mup_z, 'k--', 'DisplayName', '\mu_p');
    xline(z_rib_top_d*1e9, 'k-'); xline(z_iGe_top_d*1e9, 'k-');
    hold off;
    xlabel(z_lbl); ylabel('Mobility (cm^2 V^{-1} s^{-1})');
    title('Carrier Mobility -- V = -1 V');
    legend('Location', 'best'); grid on;
    save_thesis_figure(14, 'phys_carrier_mobility', style);
end

if ~isempty(Ropt_z) && ~isempty(Rsrh_z)
    figure(15); clf; hold on;
    semilogy(z_cp*1e9, max(Ropt_z, 1), 'k-',  'DisplayName', 'R_{opt}');
    semilogy(z_cp*1e9, max(Rsrh_z, 1), 'k--', 'DisplayName', 'R_{SRH}');
    xline(z_rib_top_d*1e9, 'k-'); xline(z_iGe_top_d*1e9, 'k-');
    hold off;
    xlabel(z_lbl); ylabel('Recombination Rate (cm^{-3} s^{-1})');
    title('Recombination Rates -- V = -1 V');
    legend('Location', 'best'); grid on;
    save_thesis_figure(15, 'phys_recombination_rates', style);
end


f_mod = logspace(8, 11.2, 2000);
H2_tt = (sinc(f_mod * tau_tt)).^2;   % sinc = sin(pi*x)/(pi*x) in MATLAB
H2_RC = 1 ./ (1 + (f_mod / fRC).^2);
Htot  = 10*log10(max(H2_tt .* H2_RC, 1e-10));
Htot  = Htot - max(Htot);

figure(16); clf;
semilogx(f_mod/1e9, Htot, 'k-');
yline(-3, 'k--', 'LineWidth', 1);
text(0.15, -4.2, '-3 dB', 'FontName', style.font_name, 'FontSize', 10);
xline(f3dB/1e9, 'k:', sprintf('f_{3dB} = %.0f GHz', f3dB/1e9), ...
    'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'bottom');
xlabel('Frequency (GHz)');
ylabel('Normalised S_{21} (dB)');
title(sprintf('Frequency Response -- R_S = %.1f \\Omega, C_j = %.1f fF', ...
    Rs_geo, Cj_geo*1e15));
xlim([0.1 300]); ylim([-20 1]);
grid on;
save_thesis_figure(16, 'freq_response_model', style);

iGe_sweep = linspace(100e-9, 600e-9, 200);
f_tt_sw   = 0.44 ./ (iGe_sweep / v_sat);
f_rc_sw   = fRC * ones(size(iGe_sweep));   % RC fixed by geometry-derived Cj, Rs
f3dB_sw   = 1 ./ sqrt(1./f_tt_sw.^2 + 1./f_rc_sw.^2);

figure(17); clf; hold on;
plot(iGe_sweep*1e9, f_tt_sw/1e9,  'k-',  'DisplayName', 'Transit-time limit');
plot(iGe_sweep*1e9, f_rc_sw/1e9,  'k--', 'DisplayName', 'RC limit');
plot(iGe_sweep*1e9, f3dB_sw/1e9,  'k:',  'DisplayName', 'Combined f_{3dB}');
xline(iGe_H*1e9, 'k-.',  sprintf('Nominal %.0f nm', iGe_H*1e9), ...
    'LabelVerticalAlignment', 'bottom');
hold off;
xlabel('i-Ge Thickness (nm)');
ylabel('Bandwidth (GHz)');
title('Transit-time vs RC Bandwidth Trade-off');
legend('Location', 'northeast');
grid on;
save_thesis_figure(17, 'tradeoff_bw_vs_iGe', style);

figure(18); clf;
ax = axes;
set(ax, 'Visible', 'off');
tbl_data = {
    'Dark current @ -1 V',  sprintf('%.2f nA',      Id_1V*1e9),  '1.3 nA';
    'Photocurrent @ -1 V',  sprintf('%.3f \muA',    I_ph*1e6),   '--';
    'Responsivity @ -1 V',  sprintf('%.3f A/W',     R_AW),       '0.95 A/W';
    'EQE (FDTD)',           sprintf('%.1f %%',       EQE_f*100),  '--';
    'EQE (CHARGE)',         sprintf('%.1f %%',       EQE_c*100),  '--';
    'IQE (CHARGE)',         sprintf('%.1f %%',       IQE_c*100),  '--';
    'NEP',                  sprintf('%.2e W/\surd{Hz}', NEP),    '--';
    'D*',                   sprintf('%.2e cm\surdHz/W', Dstar),  '2.95e10';
    'f_{3dB} (model)',      sprintf('%.0f GHz',      f3dB/1e9),  '103 GHz';
};
t = uitable(gcf, 'Data', tbl_data, ...
    'ColumnName', {'Metric', 'This Work', 'Paper'}, ...
    'ColumnWidth', {220, 160, 120}, ...
    'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.96], ...
    'FontName', style.font_name, 'FontSize', 10);
drawnow;
save_thesis_figure(18, 'summary_metrics_table', style);

figure(20); clf;
[~, ~, ND_map] = interpolate_xz_map(y_dope, z_dope, pick_col(ND, 1), 260, 220);
[ym_d, zm_d, NA_map] = interpolate_xz_map(y_dope, z_dope, pick_col(NA, 1), 260, 220);
net_dope = ND_map - NA_map;
z_line = zm_d(:,1) * 1e9;
dope_line = net_dope(round(size(net_dope,1)/2), :);
semilogy(z_line, abs(dope_line), 'k-', 'LineWidth', 1.5);
xlabel('z (nm)');
ylabel('|Net Doping| (cm^{-3})');
title('Doping Profile -- Vertical Cut (y = 0)');
grid on;
hold on;
idx_n = dope_line > 0;
idx_p = dope_line < 0;
if any(idx_n)
    plot(z_line(idx_n), abs(dope_line(idx_n)), 'ks', 'MarkerSize', 3);
end
if any(idx_p)
    plot(z_line(idx_p), abs(dope_line(idx_p)), 'ko', 'MarkerSize', 3);
end
legend('|N_D - N_A|', 'n-type', 'p-type', 'Location', 'best');
hold off;
save_thesis_figure(20, 'phys_doping_profile', style);

figure(21); clf;
eps_Ge = 16.2 * 8.854e-12;
V_bi   = 0.3;
A_junc = Ge_L * Ge_W;
N_iGe  = 1e15 * 1e6;
V_cv   = linspace(0, V_stop, 50);
W_dep  = sqrt(2 * eps_Ge * (V_bi + V_cv) / (q * N_iGe));
W_dep  = min(W_dep, iGe_H);
C_j    = eps_Ge * A_junc ./ W_dep;
plot(V_cv, C_j*1e15, 'k-', 'LineWidth', 1.5);
xlabel('Reverse Bias (V)');
ylabel('Junction Capacitance C_j (fF)');
title('C-V Characteristic -- Ge-on-Si PIN PD');
grid on;
xlim([0 V_stop]);
save_thesis_figure(21, 'elec_capacitance_vs_voltage', style);

if isfield(F, 'time_t') && isfield(F, 'time_Ex')
    figure(22); clf;
    t_ps = F.time_t(:) * 1e12;
    Ex_t = squeeze(F.time_Ex(:));
    Ex_norm = abs(Ex_t) / max(abs(Ex_t));
    plot(t_ps, Ex_norm, 'k-', 'LineWidth', 1.2);
    xlabel('Time (ps)');
    ylabel('Normalized |E_x|');
    title(sprintf('Optical Impulse Response -- lambda = %d nm', round(lambda_c*1e9)));
    grid on;
    xlim([min(t_ps) max(t_ps)]);
    ylim([0 1.05]);
    save_thesis_figure(22, 'opt_impulse_response', style);
end

if isfield(F, 'mode_wg_Ex') && isfield(F, 'mode_wg_Ey')
    figure(23); clf;
    Ey_wg = squeeze(F.mode_wg_Ey(:,:,1,1));
    Ex_wg = squeeze(F.mode_wg_Ex(:,:,1,1));
    E2_wg = abs(Ex_wg).^2 + abs(Ey_wg).^2;
    E2_wg = E2_wg / max(E2_wg(:));
    imagesc(F.mode_wg_y*1e6, F.mode_wg_z*1e9, E2_wg.');
    axis xy; colormap(gray_r);
    cb = colorbar; cb.Label.String = 'Normalized |E|^2';
    xlabel('y (\mum)'); ylabel('z (nm)');
    title('Waveguide Input Mode Profile');
    save_thesis_figure(23, 'opt_mode_profile_wg_input', style);
end

if isfield(F, 'mode_tp_Ex') && isfield(F, 'mode_tp_Ey')
    figure(24); clf;
    Ey_tp = squeeze(F.mode_tp_Ey(:,:,1,1));
    Ex_tp = squeeze(F.mode_tp_Ex(:,:,1,1));
    E2_tp = abs(Ex_tp).^2 + abs(Ey_tp).^2;
    E2_tp = E2_tp / max(E2_tp(:));
    imagesc(F.mode_tp_y*1e6, F.mode_tp_z*1e9, E2_tp.');
    axis xy; colormap(gray_r);
    cb = colorbar; cb.Label.String = 'Normalized |E|^2';
    xlabel('y (\mum)'); ylabel('z (nm)');
    title('Taper Output Mode Profile (Ge entrance)');
    save_thesis_figure(24, 'opt_mode_profile_taper_output', style);
end

if isfield(F, 'Ex_xy') && isfield(F, 'Ey_xy')
    figure(25); clf;
    Ex_xyf = squeeze(F.Ex_xy(:,:,1,1));
    Ey_xyf = squeeze(F.Ey_xy(:,:,1,1));
    E2_xy  = abs(Ex_xyf).^2 + abs(Ey_xyf).^2;
    E2_xy_dB = 10*log10(max(E2_xy / max(E2_xy(:)), 1e-6));
    imagesc(F.E_xy_x*1e6, F.E_xy_y*1e6, E2_xy_dB.');
    axis xy; colormap(gray_r);
    cb = colorbar; cb.Label.String = 'Normalized |E|^2 (dB)';
    xlabel('x (\mum)'); ylabel('y (\mum)');
    title(sprintf('XY Power Distribution -- z = Ge mid-height, lambda = %d nm', round(lambda_c*1e9)));
    caxis([-30 0]);
    save_thesis_figure(25, 'opt_power_xy_heatmap', style);
end

figure(26); clf;
V_abs = abs(V_dk);
dI_dV = diff(abs(I_dk)) ./ diff(V_abs);
R_dev = 1 ./ abs(dI_dV);
V_mid = (V_abs(1:end-1) + V_abs(2:end)) / 2;
valid = R_dev < 1e9;
semilogy(V_mid(valid), R_dev(valid), 'k-', 'LineWidth', 1.5);
xlabel('Reverse Bias (V)');
ylabel('Device Resistance (Ohm)');
title('Resistance vs Bias -- Dark Condition');
grid on;
xlim([0 V_stop]);
save_thesis_figure(26, 'elec_resistance_vs_bias', style);

if isfield(C, 'f_ssac') && isfield(C, 'I_ac_mag')
    figure(27); clf;
    f_ssac_GHz = C.f_ssac(:) / 1e9;
    I_ac_norm  = C.I_ac_mag(:) / max(C.I_ac_mag(:));
    S21_dB     = 20 * log10(max(I_ac_norm, 1e-10));
    semilogx(f_ssac_GHz, S21_dB, 'k-', 'LineWidth', 1.5);
    hold on;
    yline(-3, 'k--', '-3 dB', 'LineWidth', 1);
    hold off;
    xlabel('Frequency (GHz)');
    ylabel('Normalized S_{21} (dB)');
    title('Electro-Optic Frequency Response -- SSAC');
    grid on;
    ylim([-20 1]);
    save_thesis_figure(27, 'freq_s21_ssac', style);
end

figure(28); clf;
V_bias_pts = abs(V_ill);
I_ph_arr   = abs(I_ill) - Id_1V;
I_ph_arr   = max(I_ph_arr, 0);
R_arr      = I_ph_arr / P_opt;
valid_ph   = I_ph_arr > 0;
plot(I_ph_arr(valid_ph)*1e6, R_arr(valid_ph), 'k-o', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
xlabel('Photocurrent I_{ph} (\muA)');
ylabel('Responsivity (A/W)');
title('Responsivity vs Photocurrent');
grid on;
save_thesis_figure(28, 'elec_responsivity_vs_photocurrent', style);

figure(29); clf;
yyaxis left;
plot(V_bias_pts, R_arr, 'k-o', 'MarkerSize', 4, 'MarkerFaceColor', 'k');
ylabel('Responsivity (A/W)');
set(gca, 'YColor', 'k');
yyaxis right;
plot(V_bias_pts, I_ph_arr*1e6, 'k--s', 'MarkerSize', 4, 'MarkerFaceColor', 'w');
ylabel('Photocurrent (\muA)');
set(gca, 'YColor', 'k');
xlabel('Reverse Bias |V| (V)');
title('Bias vs Responsivity and Photocurrent');
grid on;
xlim([0 V_stop]);
save_thesis_figure(29, 'elec_bias_vs_R_Iph', style);

fprintf('\n--- Generating CML dataset ---\n');

cml.description       = 'Ge-on-Si PD O-band U-shaped -- CML data for INTERCONNECT';
cml.wavelength_m      = lambda_c;
cml.geometry.lambda_c_m = lambda_c;
cml.geometry.Ge_L_m   = Ge_L;
cml.geometry.Ge_W_m   = Ge_W;
cml.geometry.iGe_H_m  = iGe_H;
cml.geometry.wg_H_m   = wg_H;

cml.optical.A_TE           = A_TE;
cml.optical.EQE_fdtd       = EQE_f;
cml.optical.responsivity_nominal_AW = R_AW;

cml.electrical.V_sweep_V      = V_ill(:).';
cml.electrical.I_dark_A       = abs(I_dk(:)).' ;
cml.electrical.I_photo_A      = I_photo_vs_V(:).';
cml.electrical.responsivity_AW = R_vs_V(:).';
cml.electrical.EQE            = EQE_vs_V(:).';
cml.electrical.Id_at_1V_nA    = Id_1V * 1e9;
cml.electrical.Iph_at_1V_uA   = I_ph  * 1e6;

cml.recombination.tau_SRH_Ge_s       = 1e-9;
cml.recombination.SRV_Ge_SiO2_cms    = 1e4;
cml.recombination.SRV_Ge_Si_cms      = 1e3;

cml.noise.NEP_W_per_sqrtHz = NEP;
cml.noise.Dstar_Jones       = Dstar;
cml.noise.SNR_dB            = SNR;
cml.noise.LDR_dB            = LDR;

cml.bandwidth.tau_tt_s      = tau_tt;
cml.bandwidth.f_tt_GHz      = f_tt  / 1e9;
cml.bandwidth.f_RC_GHz      = fRC   / 1e9;
cml.bandwidth.f3dB_GHz      = f3dB  / 1e9;
cml.bandwidth.Rs_ohm        = Rs_geo;
cml.bandwidth.Cj_fF         = Cj_geo * 1e15;
cml.bandwidth.Cp_fF         = Cp_geo * 1e15;
cml.bandwidth.Lp_pH         = Lp_geo * 1e12;
cml.bandwidth.v_sat_ms      = v_sat;

cml.saturation.Psat_W       = Psat_geo;
cml.saturation.Isc_A        = Isc_geo;

cml.temperature.T_sim_K = T_sim;

save(cml_mat, '-struct', 'cml');
fprintf('CML .mat saved: %s\n', cml_mat);

fid = fopen(cml_json, 'w');
fprintf(fid, '%s', jsonencode(cml, 'PrettyPrint', true));
fclose(fid);
fprintf('CML .json saved: %s\n', cml_json);

fprintf('\nSaved %d figures to %s\n', 29, figure_dir);


function val = squeeze_bias(A, idx)
if isempty(A), val = []; return; end
if ndims(A) == 3
    col = max(1, min(idx, size(A, 3)));
    val = A(:, :, col);
elseif ismatrix(A)
    val = A;
else
    val = A;
end
end

function col = pick_col(A, idx)
if isempty(A), col = []; return; end
if isvector(A), col = A(:); return; end
c = max(1, min(idx, size(A, 2)));
col = A(:, c);
end

function col = pick_col_vec(A, idx)
if isempty(A), col = []; return; end
if ndims(A) == 3
    c = max(1, min(idx, size(A, 2)));
    col = sqrt(sum(abs(squeeze(A(:, c, :))).^2, 2));
else
    col = pick_col(A, idx);
end
end

function [z_line, vals_line] = extract_z_profile(x, z, values, x_target, x_window)
if isempty(x) || isempty(values), z_line = []; vals_line = []; return; end
x = x(:); z = z(:); values = values(:);
valid = isfinite(x) & isfinite(z) & isfinite(values);
x = x(valid); z = z(valid); values = values(valid);
if isempty(x), z_line = []; vals_line = []; return; end
[~, ni] = min(abs(x - x_target));
x_use  = x(ni);
tol    = max(x_window, 1e-12);
mask   = abs(x - x_use) <= tol;
for k = 1:8
    if nnz(mask) >= 25, break; end
    tol  = tol * 2;
    mask = abs(x - x_use) <= tol;
end
[z_line, vals_line] = collapse_duplicates(z(mask), values(mask), 1e-12);
end

function [cu, vu] = collapse_duplicates(coord, vals, tol)
if isempty(coord), cu = []; vu = []; return; end
key = round(coord / tol);
[~, ~, ic] = unique(key);
cu = accumarray(ic, coord, [], @mean);
vu = accumarray(ic, vals,  [], @mean);
[cu, ord] = sort(cu); vu = vu(ord);
end

function [xg, zg, vg] = interpolate_xz_map(x, z, vals, nx, nz)
x = x(:); z = z(:); vals = vals(:);
ok = isfinite(x) & isfinite(z) & isfinite(vals);
x = x(ok); z = z(ok); vals = vals(ok);
key = [round(x/1e-12), round(z/1e-12)];
[~, ~, ic] = unique(key, 'rows');
xu = accumarray(ic, x,    [], @mean);
zu = accumarray(ic, z,    [], @mean);
vu = accumarray(ic, vals, [], @mean);
xg = linspace(min(xu), max(xu), nx);
zg = linspace(min(zu), max(zu), nz);
[Xq, Zq] = meshgrid(xg, zg);
F_int = scatteredInterpolant(xu, zu, vu, 'natural', 'nearest');
vg = F_int(Xq, Zq);
end

function cm = gray_r()
cm = flipud(gray(256));
end

function style = thesis_style(figure_dir)
style = struct( ...
    'figure_dir',  figure_dir, ...
    'font_size',   11, ...
    'font_name',   'Times New Roman', ...
    'line_width',  1.5, ...
    'grid_alpha',  0.15, ...
    'figure_pos',  [80, 80, 1600, 1000], ...
    'dpi',         300);
if ~exist(figure_dir, 'dir'), mkdir(figure_dir); end
set(groot, ...
    'defaultAxesFontSize',   style.font_size, ...
    'defaultAxesFontName',   style.font_name, ...
    'defaultLineLineWidth',  style.line_width, ...
    'defaultAxesBox',        'on', ...
    'defaultAxesLineWidth',  0.9, ...
    'defaultFigureColor',    'w', ...
    'defaultAxesColorOrder', [0 0 0; 0.3 0.3 0.3; 0.6 0.6 0.6]);
end

function save_thesis_figure(fig_id, base_name, style)
fig = figure(fig_id);
set(fig, 'Color', 'w', 'InvertHardcopy', 'off', ...
    'Renderer', 'painters', 'Position', style.figure_pos);
ax_list = findall(fig, 'Type', 'axes');
for k = 1:numel(ax_list)
    set(ax_list(k), ...
        'FontName',       style.font_name, ...
        'FontSize',       style.font_size, ...
        'LineWidth',      1.2, ...
        'GridAlpha',      style.grid_alpha, ...
        'MinorGridAlpha', 0.08, ...
        'TickDir',        'out');
end
drawnow;
out_path = fullfile(style.figure_dir, [base_name, '.png']);
exportgraphics(fig, out_path, 'Resolution', style.dpi, 'BackgroundColor', 'white');
fprintf('  Saved %s\n', out_path);
end
