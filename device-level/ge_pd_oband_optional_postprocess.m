% ge_pd_oband_optional_postprocess.m
% Ge-on-Si PD - Optional FDTD + DEVICE postprocess figures
% Yang Shi et al., Photonics Research 12, 1 (2024)
%
% Data sources:
%   ge_charge_optional_oband.mat from ge_pd_device_oband_optional.lsf
%   ge_fdtd_optional_oband.mat   from ge_pd_fdtd_oband_optional.lsf
%
% Behavior:
%   - DEVICE optional figures are generated when ge_charge_optional_oband.mat exists.
%   - FDTD optional figures are generated from ge_fdtd_optional_oband.mat when present,
%     otherwise the script falls back to the hardcoded O-band results below.

device_mat = 'ge_charge_optional_oband.mat';
fdtd_mat   = 'ge_fdtd_optional_oband.mat';

set(groot, 'defaultAxesFontSize', 11, 'defaultAxesFontName', 'Times New Roman', ...
    'defaultLineLineWidth', 1.5, 'defaultAxesBox', 'on', 'defaultAxesLineWidth', 0.75, ...
    'defaultFigureColor', 'w');

fprintf('\n=== Optional Postprocess | FDTD + DEVICE ===\n');

% DEVICE optional postprocess
if exist(device_mat, 'file')
    load(device_mat);
    fprintf('Loaded %s\n', device_mat);

    fprintf('\n=== DEVICE Optional Results | T=300 K (except Arrhenius) ===\n');
    fprintf('  Section A - i-Ge thickness sweep:\n');
    for k = 1:numel(iGe_arr)
        fprintf('    i-Ge = %g nm  Id@-1V = %.4f nA\n', iGe_arr(k) * 1e9, Id_iGe(k) * 1e9);
    end

    fprintf('  Section B - Arrhenius (dark current vs temperature):\n');
    for k = 1:numel(T_arr)
        fprintf('    T = %g K  Id@-1V = %.4f nA\n', T_arr(k), Id_T(k) * 1e9);
    end

    fprintf('  Section C - Electrode comparison @ V = -1 V:\n');
    fprintf('    U-shaped   Id = %.4f nA\n', Id_U * 1e9);
    fprintf('    Parallel   Id = %.4f nA\n', Id_P * 1e9);

    figure(14); clf;
    plot(iGe_arr * 1e9, Id_iGe * 1e9, 'bo-', 'MarkerFaceColor', 'b');
    xlabel('i-Ge Thickness (nm)');
    ylabel('|I_{dark}| @ -1 V (nA)');
    title('Dark Current vs i-Ge Thickness - Ge-on-Si PD (T = 300 K)');
    grid on;
    grid minor;
    for k = 1:numel(iGe_arr)
        text(iGe_arr(k) * 1e9 + 3, Id_iGe(k) * 1e9, sprintf('%.3f nA', Id_iGe(k) * 1e9), ...
            'FontName', 'Times New Roman', 'FontSize', 9);
    end

    figure(15); clf;
    p = polyfit(invT, logId, 1);
    Ea_meV = abs(p(1)) * log(10) * 1.381e-23 / 1.602e-19 * 1e3;
    fit_y = polyval(p, invT);

    plot(invT * 1e3, logId, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 7);
    hold on;
    plot(invT * 1e3, fit_y, 'r--', 'DisplayName', ...
        sprintf('Linear fit  E_a \\approx %.1f meV', Ea_meV));
    hold off;
    xlabel('1/T (10^{-3} K^{-1})');
    ylabel('log_{10}(|I_{dark}| / nA)');
    title('Arrhenius Plot - Dark Current vs Temperature');
    legend('Simulation', 'Location', 'northeast');
    grid on;

    ax1 = gca;
    ax2 = axes('Position', ax1.Position, 'XAxisLocation', 'top', 'Color', 'none');
    ax2.XLim = ax1.XLim;
    ax2.YAxis.Visible = 'off';
    T_ticks = [250, 273, 300, 325, 350, 375, 400];
    set(ax2, 'XTick', 1e3 ./ T_ticks, ...
        'XTickLabel', arrayfun(@(t) sprintf('%d K', t), T_ticks, 'UniformOutput', false));
    xlabel(ax2, 'Temperature T (K)');

    figure(16); clf;
    semilogy(abs(V_u), I_u * 1e9, 'b-', 'DisplayName', ...
        sprintf('U-shaped  (Id@-1V = %.3f nA)', Id_U * 1e9));
    hold on;
    semilogy(abs(V_p), I_p * 1e9, 'r--', 'DisplayName', ...
        sprintf('Parallel  (Id@-1V = %.3f nA)', Id_P * 1e9));
    hold off;
    xlabel('Reverse Bias |V| (V)');
    ylabel('|I_{dark}| (nA)');
    title('Dark I-V - U-shaped vs Parallel Electrode (T = 300 K)');
    legend('Location', 'northwest');
    grid on;
    xlim([0 4]);
else
    fprintf('Skipping DEVICE optional figures: %s not found.\n', device_mat);
end

% FDTD optional postprocess
if ~exist(fdtd_mat, 'file')
    error('Missing %s — run ge_pd_fdtd_oband_optional.lsf first.', fdtd_mat);
end
load(fdtd_mat);
fprintf('Loaded %s\n', fdtd_mat);

fprintf('\n=== FDTD Optional Results | O-band 1310 nm ===\n');
fprintf('  Section A - Ge_L sweep:\n');
for k = 1:numel(Ge_L_arr)
    fprintf('    Ge_L = %g um  A = %.2f%%\n', Ge_L_arr(k) * 1e6, A_arr(k) * 100);
end
fprintf('  Section B - Polarisation:\n');
fprintf('    TE  A = %.2f%%\n', A_pol(1) * 100);
fprintf('    TM  A = %.2f%%\n', A_pol(2) * 100);
fprintf('    PDL = %.3f dB\n', PDL_dB);
fprintf('  Section C - Taper insertion loss @ 1310 nm: %.3f dB\n', IL_dB);
fprintf('  Section D - Spectral responsivity:\n');
for k = 1:numel(lambda_sweep)
    fprintf('    %g nm  A = %.2f%%  R = %.3f A/W\n', ...
        lambda_sweep(k) * 1e9, A_sp(k) * 100, R_sp(k));
end

figure(10); clf;
plot(Ge_L_arr * 1e6, A_arr * 100, 'bo-', 'MarkerFaceColor', 'b');
xlabel('Ge Absorber Length L_{Ge} (\mum)');
ylabel('Optical Absorption (%)');
title('Absorption vs Ge Length - O-band 1310 nm (TE mode)');
ylim([75 102]);
grid on;
text(Ge_L_arr(end) * 1e6 + 0.1, A_arr(end) * 100, sprintf('%.2f%%', A_arr(end) * 100), ...
    'FontName', 'Times New Roman', 'FontSize', 10);

figure(11); clf;
bar([A_pol(1), A_pol(2)] * 100, 0.4, 'FaceColor', [0.2 0.4 0.8]);
set(gca, 'XTickLabel', {'TE', 'TM'});
ylabel('Optical Absorption (%)');
title(sprintf('Polarisation Absorption - O-band 1310 nm  (PDL = %.3f dB, Taper IL = %.3f dB)', ...
    PDL_dB, IL_dB));
ylim([97 101]);
grid on;
grid minor;
text(1, A_pol(1) * 100 + 0.05, sprintf('%.2f%%', A_pol(1) * 100), ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 10);
text(2, A_pol(2) * 100 + 0.05, sprintf('%.2f%%', A_pol(2) * 100), ...
    'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', 'FontSize', 10);

figure(12); clf;
yyaxis left;
plot(lambda_sweep * 1e9, R_sp, 'b-o', 'MarkerFaceColor', 'b', 'MarkerSize', 5);
ylabel('Responsivity (A/W)');
ylim([0.98 1.12]);
yyaxis right;
plot(lambda_sweep * 1e9, A_sp * 100, 'r--s', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
ylabel('Optical Absorption (%)');
ylim([98 100.5]);
xlabel('Wavelength (nm)');
title('Responsivity and Absorption Spectrum - O-band (IQE = 1 assumed)');
grid on;
legend('Responsivity (A/W)', 'Absorption (%)', 'Location', 'southwest');
xlim([1255 1365]);

figure(13); clf;
plot(lambda_sweep * 1e9, A_sp * 100, 'b-o', 'MarkerFaceColor', 'b', 'MarkerSize', 5);
xlabel('Wavelength (nm)');
ylabel('Optical Absorption (%)');
title('O-band Absorption Spectrum - Ge-on-Si PD (L_{Ge} = 8 \mum)');
ylim([98 100]);
xlim([1255 1365]);
grid on;

fprintf('=== Optional postprocess complete ===\n');
