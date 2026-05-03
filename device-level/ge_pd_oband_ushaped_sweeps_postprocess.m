
charge_sw_mat  = 'ge_pd_charge_sweeps_oband_ushaped.mat';
fdtd_sw_mat    = 'ge_pd_fdtd_sweeps_oband_ushaped.mat';
charge_base    = 'ge_pd_charge_results_oband_ushaped.mat';
fdtd_base      = 'ge_pd_fdtd_results_oband_ushaped.mat';
cml_mat        = 'ge_pd_cml_oband_ushaped.mat';

figure_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
style = thesis_style(figure_dir);

fprintf('\n=== Ge-on-Si PD Sweep Post-processing ===\n');

has_charge_sw = exist(charge_sw_mat, 'file') == 2;
has_fdtd_sw   = exist(fdtd_sw_mat,   'file') == 2;
has_base_c    = exist(charge_base,   'file') == 2;
has_base_f    = exist(fdtd_base,     'file') == 2;

if ~has_charge_sw && ~has_fdtd_sw
    error('Neither sweep file found. Run sweep LSF scripts first.');
end

if has_charge_sw, CS = load(charge_sw_mat); end
if has_fdtd_sw,   FS = load(fdtd_sw_mat);  end
if has_base_c,    CB = load(charge_base);   end
if has_base_f,    FB = load(fdtd_base);     end

q   = 1.602e-19;
kB  = 1.381e-23;
h   = 6.626e-34;
c0  = 3e8;

if has_base_f && isfield(FB, 'lambda_c')
    lambda_c = FB.lambda_c;
else
    lambda_c = 1.31e-6;
end
if has_base_c
    iGe_H_nom = CB.iGe_H;
    wg_H      = CB.wg_H;
    Ge_L      = CB.Ge_L;
    Ge_W      = CB.Ge_W;
    R_AW_nom  = CB.R_AW;
    Id_nom    = CB.Id_1V;
else
    iGe_H_nom = 350e-9;
    wg_H      = 220e-9;
    Ge_L      = 8e-6;
    Ge_W      = 5e-6;
    R_AW_nom  = NaN;
    Id_nom    = NaN;
end
v_sat_e = 6.0e4;
v_sat_h = 4.7e4;
v_sat   = 2 * v_sat_e * v_sat_h / (v_sat_e + v_sat_h);
eps_Ge  = 16 * 8.854e-12;
Cj_geo  = eps_Ge * Ge_L * Ge_W / iGe_H_nom;
Rsh_Si  = 100;
Rs_par  = Rsh_Si * (Ge_W / 2) / Ge_L;
Rs_geo  = Rs_par * 0.64;
Cp_geo  = 10e-15;
RL      = 50;
fRC_nom = 1 / (2*pi * (Rs_geo + RL) * (Cj_geo + Cp_geo));

fig_idx = 20;   % start from fig 20 to avoid collision with base figs


if has_charge_sw

    iGe_arr = CS.iGe_arr(:);
    Id_iGe  = CS.Id_iGe(:);
    T_arr   = CS.T_arr(:);
    Id_T    = CS.Id_T(:);
    invT    = CS.invT(:);
    logId   = CS.logId(:);
    V_u     = CS.V_u(:);
    I_u     = CS.I_u(:);
    Id_U    = CS.Id_U;
    V_p     = CS.V_p(:);
    I_p     = CS.I_p(:);
    Id_P    = CS.Id_P;

    fprintf('\n--- Charge Sweep Results ---\n');
    for k = 1:numel(iGe_arr)
        fprintf('  i-Ge = %3.0f nm   Id@-1V = %.4f nA\n', iGe_arr(k)*1e9, Id_iGe(k)*1e9);
    end
    fprintf('  U-shaped  Id@-1V = %.4f nA\n', Id_U*1e9);
    fprintf('  Parallel  Id@-1V = %.4f nA\n', Id_P*1e9);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    plot(iGe_arr*1e9, Id_iGe*1e9, 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    xlabel('i-Ge Thickness (nm)');
    ylabel('|I_{dark}| @ -1 V (nA)');
    title('Dark Current vs i-Ge Thickness');
    for k = 1:numel(iGe_arr)
        text(iGe_arr(k)*1e9 + 3, Id_iGe(k)*1e9, ...
            sprintf('%.3f nA', Id_iGe(k)*1e9), ...
            'FontName', style.font_name, 'FontSize', 9);
    end
    grid on; grid minor;
    save_thesis_figure(fig_idx-1, 'sweep_dark_current_vs_iGe', style);

    f_tt_arr  = 0.44 ./ (iGe_arr / v_sat);
    Cj_arr    = eps_Ge * Ge_L * Ge_W ./ iGe_arr;
    fRC_arr   = 1 ./ (2*pi * (Rs_geo + RL) .* (Cj_arr + Cp_geo));
    f3dB_arr  = 1 ./ sqrt(1./f_tt_arr.^2 + 1./fRC_arr.^2);
    figure(fig_idx); clf; fig_idx = fig_idx+1; hold on;
    plot(iGe_arr*1e9, f_tt_arr/1e9,  'k-',  'DisplayName', 'f_{tt}');
    plot(iGe_arr*1e9, f3dB_arr/1e9,  'k--', 'DisplayName', 'f_{3dB}');
    xline(iGe_H_nom*1e9, 'k:', sprintf('Nominal %.0f nm', iGe_H_nom*1e9), ...
        'LabelVerticalAlignment', 'bottom');
    hold off;
    xlabel('i-Ge Thickness (nm)'); ylabel('Bandwidth (GHz)');
    title('Bandwidth vs i-Ge Thickness');
    legend('Location', 'northeast'); grid on;
    save_thesis_figure(fig_idx-1, 'sweep_bw_vs_iGe', style);

    if has_base_f && has_fdtd_sw && isfield(FS, 'A_arr')
    end
    if ~isnan(R_AW_nom)
        R_proxy = (iGe_arr / iGe_H_nom) * R_AW_nom;
        R_proxy = min(R_proxy, R_AW_nom * 1.2);   % clip at saturation
        figure(fig_idx); clf; fig_idx = fig_idx+1;
        yyaxis left;  plot(iGe_arr*1e9, R_proxy,      'k-');  ylabel('Responsivity (A/W)');
        yyaxis right; plot(iGe_arr*1e9, f3dB_arr/1e9, 'k--'); ylabel('f_{3dB} (GHz)');
        xline(iGe_H_nom*1e9, 'k:');
        xlabel('i-Ge Thickness (nm)');
        title('Responsivity-Bandwidth Trade-off vs i-Ge Thickness');
        grid on;
        save_thesis_figure(fig_idx-1, 'tradeoff_R_BW_iGe', style);
    end

    p_fit = polyfit(invT, logId, 1);
    Ea_meV = abs(p_fit(1)) * log(10) * kB / q * 1e3;
    fit_y  = polyval(p_fit, invT);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    ax1 = axes;
    plot(invT*1e3, logId, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
    hold on;
    plot(invT*1e3, fit_y, 'k--', 'DisplayName', ...
        sprintf('Linear fit - E_a \\approx %.1f meV', Ea_meV));
    hold off;
    xlabel('1/T (10^{-3} K^{-1})');
    ylabel('log_{10}(|I_{dark}| / nA)');
    title('Arrhenius Plot - Dark Current vs Temperature');
    legend({'Data', 'Linear fit'}, 'Location', 'northeast');
    grid on;
    ax2 = axes('Position', ax1.Position, 'XAxisLocation', 'top', 'Color', 'none');
    ax2.XLim = ax1.XLim;
    ax2.YAxis.Visible = 'off';
    set(ax2, 'XTick', 1e3./T_arr.', ...
        'XTickLabel', arrayfun(@(t) sprintf('%d K', t), T_arr, 'UniformOutput', false));
    xlabel(ax2, 'Temperature T (K)');
    save_thesis_figure(fig_idx-1, 'sweep_arrhenius_dark_current', style);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    semilogy(T_arr, Id_T*1e9, 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    xlabel('Temperature T (K)');
    ylabel('|I_{dark}| @ -1 V (nA)');
    title('Dark Current vs Temperature');
    grid on;
    save_thesis_figure(fig_idx-1, 'sweep_dark_current_vs_T', style);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    semilogy(abs(V_u), I_u*1e9, 'k-', 'DisplayName', ...
        sprintf('U-shaped  (Id@-1V = %.3f nA)', Id_U*1e9));
    hold on;
    semilogy(abs(V_p), I_p*1e9, 'k--', 'DisplayName', ...
        sprintf('Parallel  (Id@-1V = %.3f nA)', Id_P*1e9));
    hold off;
    xlabel('Reverse Bias |V| (V)'); ylabel('|I_{dark}| (nA)');
    title('Dark I-V: U-shaped vs Parallel Electrode');
    legend('Location', 'northwest');
    grid on; xlim([0 max([max(abs(V_u)), max(abs(V_p))])]);
    save_thesis_figure(fig_idx-1, 'sweep_electrode_comparison_iv', style);

    if isfield(CS, 'srv_arr') && isfield(CS, 'Id_srv')
        srv_arr = CS.srv_arr(:);
        Id_srv  = CS.Id_srv(:);
        figure(fig_idx); clf; fig_idx = fig_idx+1;
        semilogx(srv_arr, Id_srv*1e9, 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
        xlabel('Surface Recombination Velocity (cm s^{-1})');
        ylabel('|I_{dark}| @ -1 V (nA)');
        title('Dark Current Sensitivity to Surface Recombination');
        grid on;
        save_thesis_figure(fig_idx-1, 'sweep_dark_current_vs_srv', style);
    end

    if isfield(CS, 'tau_arr') && isfield(CS, 'Id_tau')
        tau_arr = CS.tau_arr(:);
        Id_tau  = CS.Id_tau(:);
        figure(fig_idx); clf; fig_idx = fig_idx+1;
        semilogx(tau_arr*1e9, Id_tau*1e9, 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
        xlabel('\tau_{SRH} (ns)');
        ylabel('|I_{dark}| @ -1 V (nA)');
        title('Dark Current Sensitivity to SRH Lifetime');
        grid on;
        save_thesis_figure(fig_idx-1, 'sweep_dark_current_vs_tau', style);
    end

end  % has_charge_sw


if has_fdtd_sw

    Ge_L_arr    = FS.Ge_L_arr(:);
    A_arr       = FS.A_arr(:);
    A_pol       = FS.A_pol(:);
    PDL_dB      = FS.PDL_dB;
    IL_dB       = FS.IL_dB;
    lambda_sweep = FS.lambda_sweep(:);
    A_sp        = FS.A_sp(:);
    R_sp        = FS.R_sp(:);

    fprintf('\n--- FDTD Sweep Results ---\n');
    for k = 1:numel(Ge_L_arr)
        fprintf('  Ge_L = %3.0f um   A = %.2f%%\n', Ge_L_arr(k)*1e6, A_arr(k)*100);
    end
    fprintf('  TE absorption = %.2f%%   TM absorption = %.2f%%   PDL = %.3f dB\n', ...
        A_pol(1)*100, A_pol(2)*100, PDL_dB);
    fprintf('  Taper insertion loss = %.3f dB\n', IL_dB);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    plot(Ge_L_arr*1e6, A_arr*100, 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    yline(95, 'k--', '95%', 'LabelHorizontalAlignment', 'left');
    xlabel('Ge Absorber Length L_{Ge} (\mum)');
    ylabel('Optical Absorption (%)');
    title('Absorption vs Ge Length - O-band TE');
    ylim([0 105]); grid on;
    text(Ge_L_arr(end)*1e6 + 0.15, A_arr(end)*100, ...
        sprintf('%.1f%%', A_arr(end)*100), ...
        'FontName', style.font_name, 'FontSize', 10);
    save_thesis_figure(fig_idx-1, 'sweep_absorption_vs_Ge_length', style);

    R_Ge_L = A_arr * q * lambda_c / (h * c0);
    figure(fig_idx); clf; fig_idx = fig_idx+1;
    plot(Ge_L_arr*1e6, R_Ge_L, 'ko-', 'MarkerFaceColor', 'k', 'MarkerSize', 6);
    xlabel('Ge Absorber Length L_{Ge} (\mum)');
    ylabel('Responsivity (A/W) - IQE = 1');
    title('Responsivity vs Ge Length - O-band TE');
    grid on;
    save_thesis_figure(fig_idx-1, 'sweep_responsivity_vs_Ge_length', style);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    yyaxis left;
    plot(lambda_sweep*1e9, R_sp, 'k-o', 'MarkerFaceColor', 'k', 'MarkerSize', 5);
    ylabel('Responsivity (A/W)');
    yyaxis right;
    plot(lambda_sweep*1e9, A_sp*100, 'k--s', 'MarkerFaceColor', 'k', 'MarkerSize', 5);
    ylabel('Optical Absorption (%)');
    xlabel('Wavelength (nm)');
    title('Responsivity and Absorption Spectrum - O-band (IQE = 1)');
    legend({'Responsivity', 'Absorption'}, 'Location', 'southwest');
    grid on;
    save_thesis_figure(fig_idx-1, 'sweep_responsivity_absorption_spectrum', style);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    plot(lambda_sweep*1e9, A_sp*100, 'k-o', 'MarkerFaceColor', 'k', 'MarkerSize', 5);
    xlabel('Wavelength (nm)');
    ylabel('Optical Absorption (%)');
    title('O-band Absorption Spectrum');
    grid on;
    save_thesis_figure(fig_idx-1, 'sweep_absorption_spectrum', style);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    bar([1 2], [A_pol(1) A_pol(2)]*100, 0.4, 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'k');
    set(gca, 'XTick', [1 2], 'XTickLabel', {'TE', 'TM'});
    ylabel('Optical Absorption (%)');
    title(sprintf('Polarisation Comparison  (PDL = %.3f dB,  Taper IL = %.3f dB)', ...
        PDL_dB, IL_dB));
    ylim([0 105]); grid on;
    text(1, A_pol(1)*100 + 1, sprintf('%.2f%%', A_pol(1)*100), ...
        'HorizontalAlignment', 'center', 'FontName', style.font_name, 'FontSize', 10);
    text(2, A_pol(2)*100 + 1, sprintf('%.2f%%', A_pol(2)*100), ...
        'HorizontalAlignment', 'center', 'FontName', style.font_name, 'FontSize', 10);
    save_thesis_figure(fig_idx-1, 'sweep_polarisation_absorption', style);

end  % has_fdtd_sw


if has_fdtd_sw && has_charge_sw && isfield(FS, 'A_arr') && isfield(CS, 'iGe_arr')


    if isfield(CS, 'iGe_arr') && isfield(CS, 'Id_iGe')
        f_tt_iGe   = 0.44 ./ (CS.iGe_arr(:) / v_sat);
        Cj_iGe     = eps_Ge * Ge_L * Ge_W ./ CS.iGe_arr(:);
        fRC_iGe    = 1 ./ (2*pi * (Rs_geo + RL) .* (Cj_iGe + Cp_geo));
        f3dB_iGe   = 1 ./ sqrt(1./f_tt_iGe.^2 + 1./fRC_iGe.^2);

        figure(fig_idx); clf; fig_idx = fig_idx+1;
        yyaxis left;
        plot(CS.iGe_arr(:)*1e9, CS.Id_iGe(:)*1e9, 'ko-', 'MarkerFaceColor','k','MarkerSize',6);
        ylabel('|I_{dark}| @ -1 V (nA)');
        yyaxis right;
        plot(CS.iGe_arr(:)*1e9, f3dB_iGe/1e9, 'k--^', 'MarkerFaceColor','k','MarkerSize',6);
        ylabel('f_{3dB} (GHz)');
        xline(iGe_H_nom*1e9, 'k:', sprintf('Nom. %.0f nm', iGe_H_nom*1e9), ...
            'LabelVerticalAlignment','bottom');
        xlabel('i-Ge Thickness (nm)');
        title('Dark Current vs Bandwidth Trade-off (i-Ge Thickness)');
        grid on;
        save_thesis_figure(fig_idx-1, 'tradeoff_Idark_BW_iGe', style);
    end

    if isfield(FS, 'Ge_L_arr') && isfield(FS, 'A_arr')
        R_len = FS.A_arr(:) * q * lambda_c / (h * c0);
        figure(fig_idx); clf; fig_idx = fig_idx+1; hold on;
        yyaxis left;
        plot(FS.Ge_L_arr(:)*1e6, R_len, 'k-o', 'MarkerFaceColor','k','MarkerSize',6);
        ylabel('Responsivity (A/W) - IQE = 1');
        yyaxis right;
        plot(FS.Ge_L_arr(:)*1e6, FS.A_arr(:)*100, 'k--s','MarkerFaceColor','k','MarkerSize',6);
        ylabel('Absorption (%)');
        hold off;
        xlabel('Ge Absorber Length (\mum)');
        title('Responsivity and Absorption vs Ge Length Trade-off');
        grid on;
        save_thesis_figure(fig_idx-1, 'tradeoff_R_absorption_GeL', style);
    end

end

fprintf('\n--- Generating PD Design Octagon ---\n');

if has_base_c && ~isnan(R_AW_nom) && ~isnan(Id_nom)
    f_tt_nom  = 0.44 / (iGe_H_nom / v_sat);
    f3dB_nom  = 1 / sqrt(1/f_tt_nom^2 + 1/fRC_nom^2);
    EQE_nom   = R_AW_nom * h * c0 / (q * lambda_c);
    NEP_nom   = sqrt(2 * q * abs(Id_nom)) / max(R_AW_nom, 1e-20);
    Dstar_nom = sqrt(Ge_L * Ge_W) / max(NEP_nom, 1e-40) * 1e2;
    RBW_nom   = R_AW_nom * f3dB_nom / 1e9;   % A/W * GHz

    oct_labels = {'R (A/W)', 'BW (GHz)', 'D* (Jones)', 'EQE', ...
                  '1/I_d (1/nA)', 'R\timesf_{3dB}', 'NEP^{-1}', 'LDR_{est}'};
    oct_this   = [R_AW_nom, f3dB_nom/1e9, log10(max(Dstar_nom,1)), EQE_nom, ...
                  1/(abs(Id_nom)*1e9), log10(max(RBW_nom,1)), ...
                  -log10(max(NEP_nom,1e-30)), 40];

    oct_shi2024  = [0.95, 103, 10.47, 0.76, 1/1.3, log10(97.85), 12.5, 40];
    oct_shi2021  = [0.85, 80,  9.9,  0.68, 1/4.5, log10(68.0),  11.8, 35];
    oct_lischke  = [0.30, 265, 8.5,  0.24, 1/50,  log10(79.5),  10.0, 30];
    oct_vivien   = [0.80, 120, 9.7,  0.64, 1/8.0, log10(96.0),  11.5, 35];

    all_pts = [oct_this; oct_shi2024; oct_shi2021; oct_lischke; oct_vivien];
    oct_max = max(all_pts, [], 1);
    oct_min = min(all_pts, [], 1);
    oct_range = max(oct_max - oct_min, 1e-10);
    norm_fn = @(v) (v - oct_min) ./ oct_range;

    n_axes = numel(oct_labels);
    theta  = linspace(0, 2*pi, n_axes + 1);

    figure(fig_idx); clf; fig_idx = fig_idx+1;
    ax = polaraxes; hold(ax, 'on');

    designs = {norm_fn(oct_this), norm_fn(oct_shi2024), norm_fn(oct_shi2021), ...
               norm_fn(oct_lischke), norm_fn(oct_vivien)};
    colors  = {[0 0 0], [0.2 0.2 0.8], [0.1 0.6 0.1], [0.7 0.1 0.1], [0.5 0.3 0.7]};
    names   = {'This work', 'Shi 2024 (103 GHz)', 'Shi 2021 (80 GHz)', ...
               'Lischke (265 GHz)', 'Vivien (120 GHz)'};
    lstyles = {'-', '--', '-.', ':', '-'};
    for dd = 1:numel(designs)
        vals = [designs{dd}, designs{dd}(1)];
        polarplot(ax, theta, vals, lstyles{dd}, 'Color', colors{dd}, ...
            'LineWidth', 2, 'MarkerSize', 6, 'Marker', 'o', ...
            'MarkerFaceColor', colors{dd}, 'DisplayName', names{dd});
    end
    ax.ThetaTick = theta(1:end-1) * 180 / pi;
    ax.ThetaTickLabel = oct_labels;
    ax.RLim = [0 1.05];
    ax.RTickLabel = {};
    ax.FontSize = 10;
    ax.FontName = style.font_name;
    legend('Location', 'southoutside', 'NumColumns', 2, 'FontSize', 9);
    title('PD Design Octagon - Multi-Dimensional FoM Comparison', ...
        'FontSize', 13, 'FontWeight', 'bold');
    save_thesis_figure(fig_idx-1, 'design_octagon_radar', style);
end

fprintf('\n--- Generating Literature Benchmark Table ---\n');

lit_headers = {'Device', 'Type', 'R (A/W)', 'BW (GHz)', 'I_d (nA)', ...
               'D* (Jones)', 'R x BW', 'Year'};
lit_data = { ...
    'This work (sim)',       'V-PIN',  sprintf('%.2f', R_AW_nom), ...
        sprintf('%.0f', f3dB_nom/1e9), sprintf('%.2f', abs(Id_nom)*1e9), ...
        sprintf('%.2e', Dstar_nom), sprintf('%.0f', RBW_nom), '2026'; ...
    'Shi et al.',            'V-PIN',  '0.95', '103', '1.3', '2.95e10', '98',  '2024'; ...
    'Shi et al.',            'V-PIN',  '0.85', '80',  '4.5', '7.9e9',  '68',  '2021'; ...
    'Lischke et al.',        'L-PIN',  '0.30', '265', '50',  '3.2e8',  '80',  '2021'; ...
    'Vivien et al.',         'V-PIN',  '0.80', '120', '8.0', '5.0e9',  '96',  '2012'; ...
    'Chen et al.',           'V-PIN',  '0.74', '67',  '3.0', '7.6e9',  '50',  '2024'; ...
    'Hu et al.',             'L-PIN',  '0.50', '100', '20',  '2.0e9',  '50',  '2023'; ...
    'Lischke 2020',          'V-PIN',  '0.75', '110', '10',  '4.2e9',  '83',  '2020'; ...
};

figure(fig_idx); clf; fig_idx = fig_idx+1;
set(gcf, 'Color', 'w', 'Position', style.figure_pos);
uitable('Data', lit_data, 'ColumnName', lit_headers, ...
    'RowName', [], ...
    'ColumnWidth', {130, 60, 70, 70, 70, 90, 60, 50}, ...
    'Units', 'normalized', 'Position', [0.02 0.1 0.96 0.80], ...
    'FontName', style.font_name, 'FontSize', 10);
annotation('textbox', [0.02, 0.92, 0.96, 0.07], ...
    'String', 'Table: State-of-the-Art Ge-on-Si Photodetector Benchmarking', ...
    'FontSize', 13, 'FontWeight', 'bold', 'FontName', style.font_name, ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center');
annotation('textbox', [0.02, 0.01, 0.96, 0.08], ...
    'String', 'V-PIN = vertical PIN;  L-PIN = lateral PIN;  R x BW = responsivity-bandwidth product (A/W*GHz)', ...
    'FontSize', 9, 'FontName', style.font_name, 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4]);
save_thesis_figure(fig_idx-1, 'literature_benchmark_table', style);

fprintf('\n--- Generating 2D Design Space Contour ---\n');

iGe_grid = linspace(150e-9, 600e-9, 80);
GeL_grid = linspace(2e-6,   20e-6,  80);
[IGE, GL] = meshgrid(iGe_grid, GeL_grid);

F_TT  = 0.44 ./ (IGE / v_sat);
CJ_2D = eps_Ge * GL .* Ge_W ./ IGE;
RS_2D = Rsh_Si * (Ge_W / 2) ./ GL * 0.64;
FRC_2D = 1 ./ (2*pi * (RS_2D + RL) .* (CJ_2D + Cp_geo));
F3DB  = 1 ./ sqrt(1./F_TT.^2 + 1./FRC_2D.^2) / 1e9;

alpha_abs = 7e5;  % 1/m at 1310 nm for Ge
A_2D = 1 - exp(-alpha_abs * GL);
R_2D = A_2D * q * lambda_c / (h * c0);

RBW_2D = R_2D .* F3DB;

figure(fig_idx); clf; fig_idx = fig_idx+1;
t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
contourf(IGE*1e9, GL*1e6, F3DB, 20, 'LineWidth', 0.3);
hold on;
contour(IGE*1e9, GL*1e6, F3DB, [100 100], 'k-', 'LineWidth', 2);
plot(iGe_H_nom*1e9, Ge_L*1e6, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
hold off;
xlabel('i-Ge Thickness (nm)'); ylabel('Ge Length (\mum)');
title('f_{3dB} (GHz)'); colorbar; colormap(gca, parula);

nexttile;
contourf(IGE*1e9, GL*1e6, R_2D, 20, 'LineWidth', 0.3);
hold on;
plot(iGe_H_nom*1e9, Ge_L*1e6, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
hold off;
xlabel('i-Ge Thickness (nm)'); ylabel('Ge Length (\mum)');
title('Responsivity (A/W)'); colorbar; colormap(gca, hot);

nexttile;
contourf(IGE*1e9, GL*1e6, RBW_2D, 20, 'LineWidth', 0.3);
hold on;
contour(IGE*1e9, GL*1e6, F3DB, [100 100], 'w--', 'LineWidth', 1.5);
plot(iGe_H_nom*1e9, Ge_L*1e6, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
hold off;
xlabel('i-Ge Thickness (nm)'); ylabel('Ge Length (\mum)');
title('R \times BW (A/W \cdot GHz)'); colorbar; colormap(gca, turbo);

title(t, 'Design Space Exploration: i-Ge Thickness x Ge Length', ...
    'FontSize', 14, 'FontWeight', 'bold');
save_thesis_figure(fig_idx-1, 'design_space_contour_2D', style);

fprintf('\n--- Generating Sensitivity Tornado Chart ---\n');

base_f3dB = f3dB_nom / 1e9;
params = struct( ...
    'name', {'i-Ge height', 'Ge length', 'Ge width', 'R_{sh} (P++ Si)', ...
             'v_{sat}', 'C_p (stray)', 'R_L (load)'}, ...
    'base', {iGe_H_nom, Ge_L, Ge_W, Rsh_Si, v_sat, Cp_geo, RL}, ...
    'delta', {0.20, 0.20, 0.20, 0.20, 0.20, 0.50, 0.20});

n_params = numel(params);
delta_bw = zeros(n_params, 2);  % [low_pct, high_pct] deviation from base

for pp = 1:n_params
    for dir = [-1, +1]
        v = params(pp).base * (1 + dir * params(pp).delta);
        igH = iGe_H_nom; gL = Ge_L; gW = Ge_W;
        rsh = Rsh_Si; vs = v_sat; cp = Cp_geo; rl = RL;
        switch pp
            case 1, igH = v;
            case 2, gL  = v;
            case 3, gW  = v;
            case 4, rsh = v;
            case 5, vs  = v;
            case 6, cp  = v;
            case 7, rl  = v;
        end
        ftt_p  = 0.44 / (igH / vs);
        cj_p   = eps_Ge * gL * gW / igH;
        rs_p   = rsh * (gW / 2) / gL * 0.64;
        frc_p  = 1 / (2*pi * (rs_p + rl) * (cj_p + cp));
        f3dB_p = 1 / sqrt(1/ftt_p^2 + 1/frc_p^2) / 1e9;
        col = (dir + 1)/2 + 1;  % 1 or 2
        delta_bw(pp, col) = (f3dB_p - base_f3dB) / base_f3dB * 100;
    end
end

total_swing = abs(delta_bw(:,2) - delta_bw(:,1));
[~, sort_idx] = sort(total_swing, 'ascend');
delta_sorted = delta_bw(sort_idx, :);
names_sorted = {params(sort_idx).name};

figure(fig_idx); clf; fig_idx = fig_idx+1;
barh(1:n_params, delta_sorted(:,1), 'FaceColor', [0.3 0.3 0.3], ...
    'DisplayName', sprintf('-%.0f%%', params(1).delta*100));
hold on;
barh(1:n_params, delta_sorted(:,2), 'FaceColor', [0.7 0.7 0.7], ...
    'DisplayName', sprintf('+%.0f%%', params(1).delta*100));
hold off;
set(gca, 'YTick', 1:n_params, 'YTickLabel', names_sorted);
xlabel('\Deltaf_{3dB} (%)');
title(sprintf('Bandwidth Sensitivity Tornado (base = %.0f GHz)', base_f3dB), ...
    'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'southeast');
xline(0, 'k-', 'LineWidth', 1);
grid on;
save_thesis_figure(fig_idx-1, 'sensitivity_tornado_bw', style);


if exist(cml_mat, 'file')
    cml = load(cml_mat);

    if has_charge_sw
        cml.sweeps.iGe_thickness.iGe_H_m   = CS.iGe_arr(:).';
        cml.sweeps.iGe_thickness.Id_1V_A    = CS.Id_iGe(:).';
        cml.sweeps.temperature.T_K           = CS.T_arr(:).';
        cml.sweeps.temperature.Id_1V_A       = CS.Id_T(:).';
        cml.sweeps.temperature.activation_energy_meV = ...
            abs(polyfit(CS.invT(:), CS.logId(:), 1) * [log(10)*kB/q*1e3; 0]);
        cml.sweeps.electrode.Id_U_A          = CS.Id_U;
        cml.sweeps.electrode.Id_P_A          = CS.Id_P;
        if isfield(CS, 'srv_arr')
            cml.sweeps.srv.srv_cms           = CS.srv_arr(:).';
            cml.sweeps.srv.Id_1V_A           = CS.Id_srv(:).';
        end
        if isfield(CS, 'tau_arr')
            cml.sweeps.lifetime.tau_SRH_s    = CS.tau_arr(:).';
            cml.sweeps.lifetime.Id_1V_A      = CS.Id_tau(:).';
        end
    end

    if has_fdtd_sw
        cml.sweeps.Ge_length.Ge_L_m          = FS.Ge_L_arr(:).';
        cml.sweeps.Ge_length.absorption       = FS.A_arr(:).';
        cml.sweeps.wavelength.lambda_m        = FS.lambda_sweep(:).';
        cml.sweeps.wavelength.absorption      = FS.A_sp(:).';
        cml.sweeps.wavelength.responsivity_AW = FS.R_sp(:).';
        cml.sweeps.polarisation.A_TE          = FS.A_pol(1);
        cml.sweeps.polarisation.A_TM          = FS.A_pol(2);
        cml.sweeps.polarisation.PDL_dB        = FS.PDL_dB;
        cml.sweeps.taper.IL_dB               = FS.IL_dB;
    end

    save(cml_mat, '-struct', 'cml');
    fprintf('\nCML dataset updated with sweep results: %s\n', cml_mat);

    cml_json = strrep(cml_mat, '.mat', '.json');
    fid = fopen(cml_json, 'w');
    fprintf(fid, '%s', jsonencode(cml, 'PrettyPrint', true));
    fclose(fid);
    fprintf('CML .json updated: %s\n', cml_json);
end

n_figs = fig_idx - 20;
fprintf('\n=== Sweep post-processing complete: %d figures saved to %s ===\n', ...
    n_figs, figure_dir);


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
