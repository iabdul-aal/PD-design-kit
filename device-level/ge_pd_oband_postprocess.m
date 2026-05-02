
charge_mat = 'ge_charge_results_oband.mat';
fdtd_mat   = 'fdtd_summary_oband.mat';
figure_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
style = thesis_style(figure_dir);

if ~exist(charge_mat, 'file')
    error('Missing %s. Run ge_pd_device_oband.lsf first.', charge_mat);
end
if ~exist(fdtd_mat, 'file')
    error('Missing %s. Run ge_pd_fdtd_oband.lsf first.', fdtd_mat);
end

load(charge_mat);
load(fdtd_mat);

if ~exist('iGe_H', 'var'), error('iGe_H not found in loaded data.'); end

[~, idx1V] = min(abs(V_dk - 1));
idx1V = max(1, round(double(idx1V)));

x_center = Ge_L / 2;
x_window = max(5e-9, Ge_L / 1000);

Ec_bias   = pick_bias_scalar(Ec_bulk,   idx1V);
Ev_bias   = pick_bias_scalar(Ev_bulk,   idx1V);
Efn_bias  = pick_bias_scalar(Efn_bulk,  idx1V);
Efp_bias  = pick_bias_scalar(Efp_bulk,  idx1V);
Ei_bias   = pick_bias_scalar(Ei_bulk,   idx1V);
n_bias    = pick_bias_scalar(n_bulk,    idx1V);
p_bias    = pick_bias_scalar(p_bulk,    idx1V);
Ropt_bias = pick_bias_scalar(Ropt_bulk, idx1V);
E_bias    = pick_bias_vector_magnitude(E_bulk, idx1V);
Vpot_bias = pick_bias_scalar(Vpot_bulk, idx1V);
NA_bias   = pick_static_scalar(NA_bulk);
ND_bias   = pick_static_scalar(ND_bulk);

[z_band,      Ec_z]    = extract_z_profile(x_phys,  z_phys,  Ec_bias,   x_center, x_window);
[~,           Ev_z]    = extract_z_profile(x_phys,  z_phys,  Ev_bias,   x_center, x_window);
[~,           Efn_z]   = extract_z_profile(x_phys,  z_phys,  Efn_bias,  x_center, x_window);
[~,           Efp_z]   = extract_z_profile(x_phys,  z_phys,  Efp_bias,  x_center, x_window);
[~,           Ei_z]    = extract_z_profile(x_phys,  z_phys,  Ei_bias,   x_center, x_window);
[z_carr_prof, n_z]     = extract_z_profile(x_carr,  z_carr,  n_bias,    x_center, x_window);
[~,           p_z]     = extract_z_profile(x_carr,  z_carr,  p_bias,    x_center, x_window);
[z_dope_prof, NA_z]    = extract_z_profile(x_dope,  z_dope,  NA_bias,   x_center, x_window);
[~,           ND_z]    = extract_z_profile(x_dope,  z_dope,  ND_bias,   x_center, x_window);
[z_field_prof, E_z]    = extract_z_profile(x_field, z_field, E_bias,    x_center, x_window);
[~,           Vpot_z]  = extract_z_profile(x_field, z_field, Vpot_bias, x_center, x_window);
[x_map, z_map, Ropt_xz] = interpolate_xz_map(x_Ropt, z_Ropt, Ropt_bias, 260, 220);

if exist('mun_bulk','var') && exist('mup_bulk','var') && ~isempty(mun_bulk) && ~isempty(mup_bulk)
    mun_bias = pick_bias_scalar(mun_bulk, idx1V);
    mup_bias = pick_bias_scalar(mup_bulk, idx1V);
    [z_mob_prof, mun_z] = extract_z_profile(x_mob, z_mob, mun_bias, x_center, x_window);
    [~,          mup_z] = extract_z_profile(x_mob, z_mob, mup_bias, x_center, x_window);
end

z_rib_top_derived = wg_H;
z_iGe_top_derived = z_rib_top_derived + iGe_H;

q  = 1.602e-19;
kB = 1.381e-23;
h  = 6.626e-34;
c0 = 3e8;

T  = T_sim;
RL = R_L;
BW = fBW_U_paper;
RS = RS_paper;
Cj = Cj_paper;

Eph    = h * c0 / lambda_c;
Phi    = P_opt / Eph;
EQE_f  = A_TE;
EQE_c  = (I_ph / q) / max(Phi, 1e-30);
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
tau_tt = iGe_H / v_sat_Ge;
f_tt   = 0.44 / tau_tt;
fRC    = 1 / (2 * pi * RS * Cj);
f3dB   = 1 / sqrt(1/f_tt^2 + 1/fRC^2);

fprintf('=== PD Metrics | V=-1V | T=%dK | lambda=%dnm ===\n', T, round(lambda_c*1e9));
fprintf('  Dark current      : %.4f nA   [paper: 1.3 nA]\n',  Id_1V*1e9);
fprintf('  Photocurrent      : %.4f uA\n',                     I_ph*1e6);
fprintf('  Responsivity      : %.4f A/W  [paper: 0.95 A/W]\n', R_AW);
fprintf('  EQE (FDTD abs)    : %.2f%%\n',                      EQE_f*100);
fprintf('  EQE (CHARGE curr) : %.2f%%\n',                      EQE_c*100);
fprintf('  IQE (CHARGE curr) : %.2f%%\n',                      IQE_c*100);
fprintf('  NEP               : %.3e W/sqrt(Hz)\n',             NEP);
fprintf('  D*                : %.3e cm.Hz^0.5/W  [paper: 2.95e10]\n', Dstar);
fprintf('  SNR @ P_opt       : %.2f dB\n',                     SNR);
fprintf('  LDR               : %.1f dB\n',                     LDR);
fprintf('  Transit-time BW   : %.1f GHz\n',                    f_tt/1e9);
fprintf('  RC limit (est)    : %.1f GHz\n',                    fRC/1e9);
fprintf('  Combined BW       : %.1f GHz   [paper: 103 GHz]\n', f3dB/1e9);

profile_x_um = x_center * 1e6;

figure(1); clf;
semilogy(abs(V_dk), abs(I_dk)*1e9, 'b-');
xlabel('Reverse Bias |V| (V)');
ylabel('|I_{dark}| (nA)');
title(sprintf('Dark I-V - Ge-on-Si PD (0 to -%d V)', V_stop));
grid on; grid minor;
xlim([0 V_stop]);
save_thesis_figure(1, 'dark_iv', style);

figure(2); clf;
semilogy(abs(V_ill), abs(I_dk)*1e9, 'b-', abs(V_ill), abs(I_ill)*1e9, 'r-');
xlabel('Reverse Bias |V| (V)');
ylabel('|I| (nA)');
title(sprintf('Dark vs Illuminated I-V  (P_{opt}=%g \\muW, \\lambda=%g nm)', ...
    P_opt*1e6, round(lambda_c*1e9)));
legend('Dark','Illuminated','Location','northwest');
grid on;
xlim([0 V_stop]);
save_thesis_figure(2, 'dark_vs_illuminated_iv', style);

figure(3); clf;
semilogy(abs(V_ill), abs(In_ill)*1e9, 'b-', ...
         abs(V_ill), abs(Ip_ill)*1e9, 'r-', ...
         abs(V_ill), abs(I_ill)*1e9,  'k--');
xlabel('Reverse Bias |V| (V)');
ylabel('Current (nA)');
title(sprintf('Current Components (Illuminated, \\lambda=%d nm)', round(lambda_c*1e9)));
legend('I_n','I_p','I_{total}','Location','northwest');
grid on;
xlim([0 V_stop]);
save_thesis_figure(3, 'current_components_vs_bias', style);

figure(4); clf; hold on;
plot(z_band*1e9, Ec_z,  'b-',  'DisplayName', 'E_c');
plot(z_band*1e9, Ev_z,  'r-',  'DisplayName', 'E_v');
plot(z_band*1e9, Efn_z, 'b--', 'DisplayName', 'E_{Fn}');
plot(z_band*1e9, Efp_z, 'r--', 'DisplayName', 'E_{Fp}');
plot(z_band*1e9, Ei_z,  'k:',  'DisplayName', 'E_i');
xline(z_rib_top_derived*1e9, 'k-', 'Label', 'Si/Ge', ...
    'LabelVerticalAlignment','bottom','LabelHorizontalAlignment','left');
xline(z_iGe_top_derived*1e9, 'k-', 'Label', 'i-Ge/N^{++}', ...
    'LabelVerticalAlignment','bottom','LabelHorizontalAlignment','left');
xlabel('z (nm)'); ylabel('Energy (eV)');
title(sprintf('Band Diagram at V=-1V  (x=%.3f \\mum)', profile_x_um));
legend('Location','best'); grid on; hold off;
save_thesis_figure(4, 'band_diagram_vminus1', style);

figure(5); clf; hold on;
semilogy(z_carr_prof*1e9, max(n_z,  1e1), 'b-',  'DisplayName', 'n');
semilogy(z_carr_prof*1e9, max(p_z,  1e1), 'r-',  'DisplayName', 'p');
semilogy(z_dope_prof*1e9, max(NA_z, 1e1), 'b:',  'DisplayName', 'N_A');
semilogy(z_dope_prof*1e9, max(ND_z, 1e1), 'r:',  'DisplayName', 'N_D');
xline(z_rib_top_derived*1e9, 'k-');
xline(z_iGe_top_derived*1e9, 'k-');
xlabel('z (nm)'); ylabel('Carrier Density (cm^{-3})');
title(sprintf('Carrier Density at V=-1V  (x=%.3f \\mum)', profile_x_um));
legend('Location','best'); grid on; hold off;
save_thesis_figure(5, 'carrier_density_vminus1', style);

if exist('mun_z', 'var')
    figure(6); clf; hold on;
    plot(z_mob_prof*1e9, mun_z, 'b-', 'DisplayName', '\mu_n');
    plot(z_mob_prof*1e9, mup_z, 'r-', 'DisplayName', '\mu_p');
    xline(z_rib_top_derived*1e9, 'k-');
    xline(z_iGe_top_derived*1e9, 'k-');
    xlabel('z (nm)'); ylabel('Mobility (cm^2 V^{-1} s^{-1})');
    title(sprintf('Carrier Mobility at V=-1V  (x=%.3f \\mum)', profile_x_um));
    legend('Location','best'); grid on; hold off;
    save_thesis_figure(6, 'carrier_mobility_vminus1', style);
end

figure(7); clf;
imagesc(x_map*1e6, z_map*1e9, log10(max(Ropt_xz, 1e10)));
axis xy; colormap('hot');
cb = colorbar; cb.Label.String = 'log_{10}(G_{opt}) (m^{-3} s^{-1})';
xlabel('x (\mum)'); ylabel('z (nm)');
title('Optical Generation Rate at V=-1V');
hold on;
yline(z_rib_top_derived*1e9, 'w--', 'LineWidth', 1.2);
yline(z_iGe_top_derived*1e9, 'w--', 'LineWidth', 1.2);
hold off;
save_thesis_figure(7, 'optical_generation_rate_map', style);

figure(8); clf;
yyaxis left;
plot(z_field_prof*1e9, E_z/1e6, 'b-');
ylabel('|E| (MV m^{-1})');
yyaxis right;
plot(z_field_prof*1e9, Vpot_z, 'r-');
ylabel('Electrostatic Potential V (V)');
xlabel('z (nm)');
title(sprintf('Electric Field and Potential at V=-1V  (x=%.3f \\mum)', profile_x_um));
xline(z_rib_top_derived*1e9, 'k-');
xline(z_iGe_top_derived*1e9, 'k-');
grid on;
save_thesis_figure(8, 'electric_field_potential_vminus1', style);

figure(9); clf;
f_mod = logspace(8, 11.1, 1000);
H2_tt = (sin(pi*f_mod*tau_tt) ./ max(pi*f_mod*tau_tt, 1e-30)).^2;
H2_RC = 1 ./ (1 + (f_mod/fRC).^2);
Htot  = 10*log10(H2_tt .* H2_RC + 1e-30);
Htot  = Htot - max(Htot);
semilogx(f_mod/1e9, Htot, 'b-');
yline(-3, 'r--', 'LineWidth', 1);
text(1, -3.8, '-3 dB', 'Color', 'r', 'FontName', style.font_name, 'FontSize', 10);
xlabel('Frequency (GHz)'); ylabel('Normalized S_{21} (dB)');
title(sprintf('Frequency Response  (R_S=%.1f\\Omega, C_j=%.1f fF, BW\\approx%.0f GHz)', ...
    RS, Cj*1e15, f3dB/1e9));
xlim([0.1 200]); ylim([-15 1]); grid on;
save_thesis_figure(9, 'frequency_response_model', style);

fprintf('\nSaved 9 figures to %s\n', figure_dir);

function values = pick_bias_scalar(A, idxBias)
if isempty(A), values = []; return; end
if isvector(A), values = A(:); return; end
col = max(1, min(idxBias, size(A, 2)));
values = A(:, col);
end

function values = pick_static_scalar(A)
if isempty(A), values = []; return; end
if isvector(A), values = A(:); else, values = A(:, 1); end
end

function values = pick_bias_vector_magnitude(A, idxBias)
if isempty(A), values = []; return; end
if ndims(A) < 3
    values = pick_bias_scalar(A, idxBias);
    return;
end
col   = max(1, min(idxBias, size(A, 2)));
slice = squeeze(A(:, col, :));
if isvector(slice)
    values = abs(slice(:));
else
    values = sqrt(sum(abs(slice).^2, 2));
end
end

function [z_line, values_line, x_used] = extract_z_profile(x, z, values, x_target, x_window)
x = x(:); z = z(:); values = values(:);
valid = isfinite(x) & isfinite(z) & isfinite(values);
x = x(valid); z = z(valid); values = values(valid);
if isempty(x), z_line = []; values_line = []; x_used = x_target; return; end

[~, idx_near] = min(abs(x - x_target));
x_used = x(idx_near);
tol    = max(x_window, 1e-12);
mask   = abs(x - x_used) <= tol;

grow_count = 0;
while nnz(mask) < 25 && grow_count < 8
    tol  = tol * 2;
    mask = abs(x - x_used) <= tol;
    grow_count = grow_count + 1;
end
[z_line, values_line] = collapse_duplicates(z(mask), values(mask), 1e-12);
end

function [coord_u, val_u] = collapse_duplicates(coord, values, tol)
if isempty(coord), coord_u = []; val_u = []; return; end
key = round(coord / tol);
[~, ~, ic] = unique(key);
coord_u = accumarray(ic, coord,  [], @mean);
val_u   = accumarray(ic, values, [], @mean);
[coord_u, order] = sort(coord_u);
val_u = val_u(order);
end

function [x_grid, z_grid, val_grid] = interpolate_xz_map(x, z, values, nx, nz)
x = x(:); z = z(:); values = values(:);
valid = isfinite(x) & isfinite(z) & isfinite(values);
x = x(valid); z = z(valid); values = values(valid);
xy_key = [round(x/1e-12), round(z/1e-12)];
[~, ~, ic] = unique(xy_key, 'rows');
x_u = accumarray(ic, x,      [], @mean);
z_u = accumarray(ic, z,      [], @mean);
v_u = accumarray(ic, values, [], @mean);
x_grid = linspace(min(x_u), max(x_u), nx);
z_grid = linspace(min(z_u), max(z_u), nz);
[Xq, Zq] = meshgrid(x_grid, z_grid);
F = scatteredInterpolant(x_u, z_u, v_u, 'natural', 'nearest');
val_grid = F(Xq, Zq);
end

function style = thesis_style(figure_dir)
style = struct( ...
    'figure_dir',  figure_dir, ...
    'font_size',   11, ...
    'font_name',   'Times New Roman', ...
    'line_width',  2, ...
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
    'defaultFigureColor',    'w');
end

function save_thesis_figure(fig_id, base_name, style)
fig = figure(fig_id);
set(fig, 'Color', 'w', 'InvertHardcopy', 'off', ...
    'Renderer', 'painters', 'Position', style.figure_pos);
axes_list = findall(fig, 'Type', 'axes');
for k = 1:numel(axes_list)
    set(axes_list(k), ...
        'FontName',       style.font_name, ...
        'FontSize',       style.font_size, ...
        'LineWidth',      1.2, ...
        'GridAlpha',      style.grid_alpha, ...
        'MinorGridAlpha', 0.08, ...
        'TickDir',        'out');
end
drawnow;
exportgraphics(fig, fullfile(style.figure_dir, [base_name, '.png']), ...
    'Resolution', style.dpi, 'BackgroundColor', 'white');
printf('Saved %s.png\n', fullfile(style.figure_dir, base_name));
end
