% ge_pd_oband_postprocess.m
% Ge-on-Si PD - Performance metrics and publication figures
% Yang Shi et al., Photonics Research 12, 1 (2024)

charge_mat = 'ge_charge_results_oband.mat';
fdtd_mat   = 'fdtd_summary_oband.mat';

if ~exist(charge_mat, 'file')
    error('Missing %s. Run ge_pd_device_oband.lsf first.', charge_mat);
end
if ~exist(fdtd_mat, 'file')
    error('Missing %s. Run ge_pd_fdtd_oband.lsf first.', fdtd_mat);
end

load(charge_mat);
load(fdtd_mat);

if ~isscalar(idx1V)
    idx1V = idx1V(1);
end
idx1V = max(1, round(double(idx1V)));

% CHARGE exports scalar fields as [Npts, NV] and vector fields as
% [Npts, NV, Ncomp]. Build bias slices first, then extract z-profiles near
% the Ge centre from the unstructured x-z point cloud.
x_center = Ge_L / 2;
x_window = max(5e-9, Ge_L / 1000);

Ec_bias   = pick_bias_scalar(Ec_bulk, idx1V);
Ev_bias   = pick_bias_scalar(Ev_bulk, idx1V);
Efn_bias  = pick_bias_scalar(Efn_bulk, idx1V);
Efp_bias  = pick_bias_scalar(Efp_bulk, idx1V);
Ei_bias   = pick_bias_scalar(Ei_bulk, idx1V);
n_bias    = pick_bias_scalar(n_bulk, idx1V);
p_bias    = pick_bias_scalar(p_bulk, idx1V);
Ropt_bias = pick_bias_scalar(Ropt_bulk, idx1V);
E_bias    = pick_bias_vector_magnitude(E_bulk, idx1V);
Vpot_bias = pick_bias_scalar(Vpot_bulk, idx1V);
NA_bias   = pick_static_scalar(NA_bulk);
ND_bias   = pick_static_scalar(ND_bulk);

[z_band, Ec_z, x_profile] = extract_z_profile(x_phys, z_phys, Ec_bias, x_center, x_window);
[~, Ev_z]   = extract_z_profile(x_phys, z_phys, Ev_bias, x_center, x_window);
[~, Efn_z]  = extract_z_profile(x_phys, z_phys, Efn_bias, x_center, x_window);
[~, Efp_z]  = extract_z_profile(x_phys, z_phys, Efp_bias, x_center, x_window);
[~, Ei_z]   = extract_z_profile(x_phys, z_phys, Ei_bias, x_center, x_window);

[z_carr_prof, n_z] = extract_z_profile(x_carr, z_carr, n_bias, x_center, x_window);
[~, p_z]           = extract_z_profile(x_carr, z_carr, p_bias, x_center, x_window);
[z_dope_prof, NA_z] = extract_z_profile(x_dope, z_dope, NA_bias, x_center, x_window);
[~, ND_z]           = extract_z_profile(x_dope, z_dope, ND_bias, x_center, x_window);

[z_field_prof, E_z]    = extract_z_profile(x_field, z_field, E_bias, x_center, x_window);
[~, Vpot_z]            = extract_z_profile(x_field, z_field, Vpot_bias, x_center, x_window);
[x_map, z_map, Ropt_xz] = interpolate_xz_map(x_Ropt, z_Ropt, Ropt_bias, 260, 220);

if exist('mun_bulk', 'var') && exist('mup_bulk', 'var') && ~isempty(mun_bulk) && ~isempty(mup_bulk)
    mun_bias = pick_bias_scalar(mun_bulk, idx1V);
    mup_bias = pick_bias_scalar(mup_bulk, idx1V);
    [z_mob_prof, mun_z] = extract_z_profile(x_mob, z_mob, mun_bias, x_center, x_window);
    [~, mup_z]          = extract_z_profile(x_mob, z_mob, mup_bias, x_center, x_window);
end

fprintf('Center-line profiles extracted near x = %.3f um using a +/- %.1f nm window.\n', ...
    x_profile * 1e6, x_window * 1e9);

% Constants and operating conditions
q  = 1.602e-19;
kB = 1.381e-23;
h  = 6.626e-34;
c0 = 3e8;
T  = 300;
RL = 50;
BW = 103e9;
RS = 12.9;
Cj = 22.6e-15;
Lp_ind = 175.3e-12; %#ok<NASGU>
Cp = 10e-15; %#ok<NASGU>
% Layer boundaries derived from loaded FDTD parameters (no hardcoding)
z_rib_top = 220e-9;                       % fixed SOI rib height
z_iGe_top = z_rib_top + iGe_H;           % from fdtd_summary_oband.mat
z_Npp_top = z_iGe_top + 50e-9; %#ok<NASGU>

% Derived metrics
Eph    = h * c0 / lambda_c;
Phi    = P_opt / Eph;
EQE_f  = A_TE;
EQE_c  = (I_ph / q) / Phi;
IQE_c  = EQE_c / max(A_TE, 1e-10);
Sshot  = 2 * q * Id_1V;
Sth    = 4 * kB * T / RL;
Stot   = Sshot + Sth;
NEP    = sqrt(Stot) / max(R_AW, 1e-20);
Dstar  = sqrt(A_eff) / max(NEP, 1e-40) * 1e2;
irms   = sqrt(Stot * BW);
SNR    = 20 * log10(max(I_ph / max(irms, 1e-30), 1e-10));
Pmin   = NEP * sqrt(BW);
LDR    = 20 * log10(max(P_opt / max(Pmin, 1e-30), 1));
tau_tt = 350e-9 / 6e4;
f_tt   = 0.44 / tau_tt;
fRC    = 1 / (2 * pi * RS * Cj);
f3dB   = 1 / sqrt(1 / f_tt^2 + 1 / fRC^2);

fprintf('=== PD Metrics | V=-1V | T=%dK | lambda=%dnm ===\n', T, round(lambda_c * 1e9));
fprintf('  Dark current      : %.4f nA   [paper: 1.3 nA]\n',  Id_1V * 1e9);
fprintf('  Photocurrent      : %.4f uA\n',                     I_ph * 1e6);
fprintf('  Responsivity      : %.4f A/W  [paper: 0.95 A/W]\n', R_AW);
fprintf('  EQE (FDTD abs)    : %.2f%%\n',                      EQE_f * 100);
fprintf('  EQE (CHARGE curr) : %.2f%%\n',                      EQE_c * 100);
fprintf('  IQE (CHARGE curr) : %.2f%%\n',                      IQE_c * 100);
fprintf('  NEP               : %.3e W/sqrt(Hz)\n',             NEP);
fprintf('  D*                : %.3e cm.Hz^0.5/W  [paper: 2.95e10]\n', Dstar);
fprintf('  SNR @ P_opt       : %.2f dB\n',                     SNR);
fprintf('  LDR               : %.1f dB\n',                     LDR);
fprintf('  R x BW product    : %.1f A/W.GHz\n',                R_AW * BW / 1e9);
fprintf('  Transit-time BW   : %.1f GHz\n',                    f_tt / 1e9);
fprintf('  RC limit (est)    : %.1f GHz\n',                    fRC / 1e9);
fprintf('  Combined BW       : %.1f GHz   [paper: 103 GHz]\n', f3dB / 1e9);

% Global style
set(groot, 'defaultAxesFontSize', 11, 'defaultAxesFontName', 'Times New Roman', ...
    'defaultLineLineWidth', 1.5, 'defaultAxesBox', 'on', 'defaultAxesLineWidth', 0.75, ...
    'defaultFigureColor', 'w');

profile_x_um = x_profile * 1e6;

% Figure 1: Dark I-V (log scale)
figure(1); clf;
semilogy(abs(V_dk), abs(I_dk) * 1e9, 'b-');
xlabel('Reverse Bias |V| (V)');
ylabel('|I_{dark}| (nA)');
title('Dark I-V Characteristic - Ge-on-Si PD (V = 0 to -4 V)');
grid on;
grid minor;
xlim([0 4]);

% Figure 2: Dark vs illuminated I-V
figure(2); clf;
semilogy(abs(V_ill), abs(I_dk) * 1e9, 'b-', abs(V_ill), abs(I_ill) * 1e9, 'r-');
xlabel('Reverse Bias |V| (V)');
ylabel('|I| (nA)');
title(sprintf('I-V Characteristics: Dark vs Illuminated  (P_{opt} = %g \\muW, \\lambda = %g nm)', ...
    P_opt * 1e6, round(lambda_c * 1e9)));
legend('Dark', 'Illuminated', 'Location', 'northwest');
grid on;
xlim([0 4]);

% Figure 3: Electron / hole current components vs bias
figure(3); clf;
semilogy(abs(V_ill), abs(In_ill) * 1e9, 'b-', abs(V_ill), abs(Ip_ill) * 1e9, 'r-', ...
         abs(V_ill), abs(I_ill) * 1e9, 'k--');
xlabel('Reverse Bias |V| (V)');
ylabel('Current (nA)');
title('Current Components vs Bias (Illuminated, \lambda = 1310 nm)');
legend('I_n (electrons)', 'I_p (holes)', 'I_{total}', 'Location', 'northwest');
grid on;
xlim([0 4]);

% Figure 4: Band diagram at V = -1 V
figure(4); clf; hold on;
plot(z_band * 1e9, Ec_z,  'b-',  'DisplayName', 'E_c');
plot(z_band * 1e9, Ev_z,  'r-',  'DisplayName', 'E_v');
plot(z_band * 1e9, Efn_z, 'b--', 'DisplayName', 'E_{Fn}');
plot(z_band * 1e9, Efp_z, 'r--', 'DisplayName', 'E_{Fp}');
plot(z_band * 1e9, Ei_z,  'k:',  'DisplayName', 'E_i');
xline(z_rib_top * 1e9, 'k-', 'LabelVerticalAlignment', 'bottom', ...
    'LabelHorizontalAlignment', 'left', 'Label', 'Si/Ge');
xline(z_iGe_top * 1e9, 'k-', 'LabelVerticalAlignment', 'bottom', ...
    'LabelHorizontalAlignment', 'left', 'Label', 'i-Ge/N^{++}');
xlabel('z (nm)');
ylabel('Energy (eV)');
title(sprintf('Band Diagram at V = -1 V - Cross-section near x = %.3f \\mum', profile_x_um));
legend('Location', 'best');
grid on;
hold off;

% Figure 5: Carrier density at V = -1 V
figure(5); clf; hold on;
semilogy(z_carr_prof * 1e9, max(n_z, 1e1), 'b-', 'DisplayName', 'n  (electrons)');
semilogy(z_carr_prof * 1e9, max(p_z, 1e1), 'r-', 'DisplayName', 'p  (holes)');
semilogy(z_dope_prof * 1e9, max(NA_z, 1e1), 'b:', 'DisplayName', 'N_A');
semilogy(z_dope_prof * 1e9, max(ND_z, 1e1), 'r:', 'DisplayName', 'N_D');
xline(z_rib_top * 1e9, 'k-');
xline(z_iGe_top * 1e9, 'k-');
xlabel('z (nm)');
ylabel('Carrier Density (cm^{-3})');
title(sprintf('Carrier Density at V = -1 V - Cross-section near x = %.3f \\mum', profile_x_um));
legend('Location', 'best');
grid on;
hold off;

% Figure 6: Carrier mobility at V = -1 V
if exist('mun_z', 'var')
    figure(6); clf; hold on;
    plot(z_mob_prof * 1e9, mun_z, 'b-', 'DisplayName', '\mu_n');
    plot(z_mob_prof * 1e9, mup_z, 'r-', 'DisplayName', '\mu_p');
    xline(z_rib_top * 1e9, 'k-');
    xline(z_iGe_top * 1e9, 'k-');
    xlabel('z (nm)');
    ylabel('Mobility (cm^2 V^{-1} s^{-1})');
    title(sprintf('Carrier Mobility at V = -1 V - Cross-section near x = %.3f \\mum', profile_x_um));
    legend('Location', 'best');
    grid on;
    hold off;
end

% Figure 7: 2D optical generation rate map
figure(7); clf;
imagesc(x_map * 1e6, z_map * 1e9, log10(max(Ropt_xz, 1e10)));
axis xy;
colormap('hot');
cb = colorbar;
cb.Label.String = 'log_{10}(G_{opt}) (m^{-3} s^{-1})';
xlabel('x (\mum)');
ylabel('z (nm)');
title('Optical Generation Rate at V = -1 V');
hold on;
yline(z_rib_top * 1e9, 'w--', 'LineWidth', 1.2);
yline(z_iGe_top * 1e9, 'w--', 'LineWidth', 1.2);
hold off;

% Figure 8: Electric field and potential at V = -1 V
figure(8); clf;
yyaxis left;
plot(z_field_prof * 1e9, E_z / 1e6, 'b-');
ylabel('|E| (MV m^{-1})');
yyaxis right;
plot(z_field_prof * 1e9, Vpot_z, 'r-');
ylabel('Electrostatic Potential V (V)');
xlabel('z (nm)');
title(sprintf('Electric Field and Potential at V = -1 V - Cross-section near x = %.3f \\mum', ...
    profile_x_um));
xline(z_rib_top * 1e9, 'k-');
xline(z_iGe_top * 1e9, 'k-');
grid on;

% Figure 9: Frequency response model
figure(9); clf;
f_mod = logspace(8, 11.1, 1000);
H2_tt = (sin(pi * f_mod * tau_tt) ./ max(pi * f_mod * tau_tt, 1e-30)).^2;
H2_RC = 1 ./ (1 + (f_mod / fRC).^2);
Htot  = 10 * log10(H2_tt .* H2_RC + 1e-30);
Htot  = Htot - max(Htot);
semilogx(f_mod / 1e9, Htot, 'b-');
yline(-3, 'r--', 'LineWidth', 1);
text(1, -3.8, '-3 dB', 'Color', 'r', 'FontName', 'Times New Roman', 'FontSize', 10);
xlabel('Frequency (GHz)');
ylabel('Normalized S_{21} (dB)');
title(sprintf(['Frequency Response - U-shaped Electrode  (R_S = %.1f\\Omega,  ', ...
    'C_j = %.1f fF,  BW_{3dB} \\approx %.0f GHz)'], RS, Cj * 1e15, f3dB / 1e9));
xlim([0.1 200]);
ylim([-15 1]);
grid on;

function values = pick_bias_scalar(A, idxBias)
if isempty(A)
    values = [];
    return;
end
if isvector(A)
    values = A(:);
    return;
end
col = max(1, min(idxBias, size(A, 2)));
values = A(:, col);
values = values(:);
end

function values = pick_static_scalar(A)
if isempty(A)
    values = [];
    return;
end
if isvector(A)
    values = A(:);
else
    values = A(:, 1);
end
values = values(:);
end

function values = pick_bias_vector_magnitude(A, idxBias)
if isempty(A)
    values = [];
    return;
end
if ndims(A) < 3
    values = pick_bias_scalar(A, idxBias);
    return;
end
col = max(1, min(idxBias, size(A, 2)));
slice = squeeze(A(:, col, :));
if isvector(slice)
    values = abs(slice(:));
else
    values = sqrt(sum(abs(slice).^2, 2));
end
values = values(:);
end

function [z_line, values_line, x_used] = extract_z_profile(x, z, values, x_target, x_window)
x = x(:);
z = z(:);
values = values(:);
valid = isfinite(x) & isfinite(z) & isfinite(values);
x = x(valid);
z = z(valid);
values = values(valid);

if isempty(x)
    z_line = [];
    values_line = [];
    x_used = x_target;
    return;
end

[~, idx_near] = min(abs(x - x_target));
x_used = x(idx_near);
tol = max(x_window, 1e-12);
mask = abs(x - x_used) <= tol;

grow_count = 0;
while nnz(mask) < 25 && grow_count < 8
    tol = tol * 2;
    mask = abs(x - x_used) <= tol;
    grow_count = grow_count + 1;
end

[z_line, values_line] = collapse_duplicates(z(mask), values(mask), 1e-12);
end

function [coord_unique, values_mean] = collapse_duplicates(coord, values, tol)
if isempty(coord)
    coord_unique = [];
    values_mean = [];
    return;
end

key = round(coord / tol);
[~, ~, ic] = unique(key);
coord_unique = accumarray(ic, coord, [], @mean);
values_mean  = accumarray(ic, values, [], @mean);
[coord_unique, order] = sort(coord_unique);
values_mean = values_mean(order);
end

function [x_grid, z_grid, values_grid] = interpolate_xz_map(x, z, values, nx, nz)
x = x(:);
z = z(:);
values = values(:);
valid = isfinite(x) & isfinite(z) & isfinite(values);
x = x(valid);
z = z(valid);
values = values(valid);

xy_key = [round(x / 1e-12), round(z / 1e-12)];
[~, ~, ic] = unique(xy_key, 'rows');
x_u = accumarray(ic, x, [], @mean);
z_u = accumarray(ic, z, [], @mean);
v_u = accumarray(ic, values, [], @mean);

x_grid = linspace(min(x_u), max(x_u), nx);
z_grid = linspace(min(z_u), max(z_u), nz);
[Xq, Zq] = meshgrid(x_grid, z_grid);
F = scatteredInterpolant(x_u, z_u, v_u, 'natural', 'nearest');
values_grid = F(Xq, Zq);
end
