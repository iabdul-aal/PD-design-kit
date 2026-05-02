function model = interconnect_model(cfg, responsivity)
scriptDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(scriptDir, 'interconnect');
if ~exist(dataDir, 'dir'), mkdir(dataDir); end

f = logspace(8, 11.4, 1600);
w = 2 * pi * f;
ctot = cfg.Cj + cfg.Cp;
zcap = 1 ./ (1i * w * ctot);
zload = 1 ./ (1 / cfg.R_load + 1 ./ zcap);
divider = abs(zload ./ (cfg.Rs + 1i * w * cfg.Lp + zload));
zt = responsivity * abs(zload) .* divider ./ sqrt(1 + (f / cfg.f3dB).^2);
model = struct('f_Hz', f(:), 'f_GHz', f(:) / 1e9, 'zt_VW', zt(:), ...
    'norm_dB', 20 * log10(zt(:) / max(zt)), 'f_rc', 1 / (2 * pi * (cfg.Rs + cfg.R_load) * ctot), ...
    'f_pkg', 1 / (2 * pi * sqrt(cfg.Lp * ctot)), 'resp_AW', responsivity ./ sqrt(1 + (f(:) / cfg.f3dB).^2));

bias = [-1.0, -0.9];
bandwidth_data = struct('voltage', bias, 'bandwidth', [cfg.f3dB, cfg.f3dB]);
Idark_data = struct('voltage', bias, 'current', [cfg.Id, cfg.Id]);
resp_data = struct('frequency', model.f_Hz, 'responsivity', model.resp_AW);
elec_eq_ckt_data = struct('Rj', cfg.Rs, 'Cj_data', cfg.Cj, 'Rp', cfg.R_load, 'Cp', cfg.Cp);

notes = {struct('property', 'source', 'value', 'Derived from PD-Design-Kit device/system calibration.'), ...
    struct('property', 'bias sweep note', 'value', 'Bias-dependent values are duplicated from the calibrated -1 V operating point as an INTERCONNECT starter template.')};
general = struct('description', 'Ge-on-Si PD compact model for Lumerical INTERCONNECT.', 'notes', {notes});
ports = struct('opt_1', struct('name', 'opt_1', 'dir', 'Input', 'pos', 'Left', 'order', 1), ...
    'ele_an', struct('name', 'ele_an', 'dir', 'Bidirectional', 'pos', 'Right', 'order', 2), ...
    'ele_cat', struct('name', 'ele_cat', 'dir', 'Bidirectional', 'pos', 'Bottom', 'order', 3));
model_data = struct('photonic_model', 'photodetector_simple', 'bandwidth_data', bandwidth_data, ...
    'Idark_data', Idark_data, 'resp_data', resp_data, 'enable_shot_noise', cfg.enable_shot_noise, ...
    'DC_operation_only', false, 'enable_power_saturation', true, 'saturation_power_data', cfg.Psat, ...
    'elec_eq_ckt_data', elec_eq_ckt_data);

save(fullfile(dataDir, 'ge_pd_interconnect_model_data.mat'), 'general', 'ports', 'model_data');
writematrix([model.f_Hz, model.resp_AW], fullfile(dataDir, 'ge_pd_interconnect_resp.csv'));
writematrix([bandwidth_data.voltage(:), bandwidth_data.bandwidth(:)], fullfile(dataDir, 'ge_pd_interconnect_bandwidth.csv'));
writematrix([Idark_data.voltage(:), Idark_data.current(:)], fullfile(dataDir, 'ge_pd_interconnect_dark_current.csv'));
writetable(struct2table(struct('parameter', {'responsivity_A_W'; 'dark_current_A'; 'bandwidth_Hz'; 'Rs_Ohm'; 'Cj_F'; 'Cp_F'; 'Rload_Ohm'; 'Lp_H'; 'Psat_W'}, ...
    'value', {responsivity; cfg.Id; cfg.f3dB; cfg.Rs; cfg.Cj; cfg.Cp; cfg.R_load; cfg.Lp; cfg.Psat})), ...
    fullfile(dataDir, 'ge_pd_interconnect_parameters.csv'));

fig = figure('Color', 'w', 'Position', [150, 150, 1600, 1000], 'Name', 'INTERCONNECT Compact Model');
yyaxis left; semilogx(model.f_GHz, model.zt_VW, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width); hold on;
ylabel('Optical-to-electrical gain |Z_t| (V/W)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
yyaxis right; semilogx(model.f_GHz, model.norm_dB, '--', 'Color', cfg.colors.red, 'LineWidth', 2);
ylabel('Normalized response (dB)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
xline(model.f_rc / 1e9, ':', 'Color', cfg.colors.gray, 'LineWidth', 1.5); xline(model.f_pkg / 1e9, '-.', 'Color', cfg.colors.green, 'LineWidth', 1.5);
xlabel('Frequency (GHz)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
title('Lumerical INTERCONNECT-ready compact PD model', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
legend('|Z_t|', 'Normalized EO response', 'f_{RC}', 'f_{pkg}', 'Location', 'southwest'); grid on;
set(gca, 'FontSize', cfg.font_size, 'FontName', cfg.font_name, 'LineWidth', 1.5, 'GridAlpha', cfg.grid_alpha, ...
    'MinorGridAlpha', 0.08, 'TickDir', 'out', 'XMinorGrid', 'on', 'YMinorGrid', 'on');
save_interconnect_figure(fig, cfg.figure_dir, 'system_interconnect_compact_model', cfg.export_dpi);
fprintf('Saved INTERCONNECT model data in %s\n', dataDir);
end

function save_interconnect_figure(fig, outDir, baseName, dpi)
if ~exist(outDir, 'dir'), mkdir(outDir); end
set(fig, 'Color', 'w', 'InvertHardcopy', 'off', 'Renderer', 'painters');
drawnow;
exportgraphics(fig, fullfile(outDir, [baseName, '.png']), 'Resolution', dpi, 'BackgroundColor', 'white');
end
