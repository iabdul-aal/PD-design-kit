function plot_responsivity(params, const, settings)

fig = figure('Position', [50, 50, 900, 600], 'Color', 'w');
set(fig, 'Name', 'Photodiode Responsivity');

lambda = linspace(300, 1800, 2000);
lambda_m = lambda * 1e-9;

f_long = 1 ./ (1 + exp((lambda_m - params.lambda_cutoff) / params.delta_lambda_long));
f_short = 1 ./ (1 + exp((params.lambda_short - lambda_m) / params.delta_lambda_short));
eta = params.eta_plateau * f_short .* f_long;
R = eta .* const.e .* lambda_m / (const.h * const.c);

yyaxis left
plot(lambda, R, 'Color', settings.colors.blue, 'LineWidth', settings.line_width);
ylabel('Responsivity, R (A/W)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
ylim([0, 1.0]);
ax = gca;
ax.YColor = settings.colors.blue;
hold on;

idx_center = find(abs(lambda_m - params.lambda_center) < 1e-10, 1);
if ~isempty(idx_center)
    plot(lambda(idx_center), R(idx_center), 'o', 'MarkerSize', 10, ...
        'LineWidth', settings.line_width, 'MarkerFaceColor', settings.colors.red, ...
        'MarkerEdgeColor', settings.colors.red);
end

xline(params.lambda_min*1e9, '--', 'Color', settings.colors.gray, 'LineWidth', 2);
xline(params.lambda_max*1e9, '--', 'Color', settings.colors.gray, 'LineWidth', 2);

yyaxis right
eta_levels = [0.9, 0.7, 0.5, 0.3, 0.1];
line_styles = {'-', '--', '-.', ':', '-'};
colors_gray = [0.2, 0.35, 0.5, 0.65, 0.8];
for i = 1:length(eta_levels)
    R_diagonal = eta_levels(i) * const.e * lambda_m / (const.h * const.c);
    plot(lambda, R_diagonal, line_styles{i}, 'Color', [colors_gray(i), colors_gray(i), colors_gray(i)], 'LineWidth', 1.5);
end
ylabel('Quantum Efficiency, η', 'FontSize', settings.label_size, 'FontWeight', 'bold');
ylim([0, 1.0]);
ax = gca;
ax.YColor = [0, 0, 0];

xlabel('Wavelength, λ (nm)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
title(sprintf('Photodiode Responsivity (%.1f–%.1f nm, %.3f GBd PAM-4)', ...
    params.lambda_min*1e9, params.lambda_max*1e9, params.symbol_rate/1e9), ...
    'FontSize', settings.title_size, 'FontWeight', 'bold');
grid on;
xlim([300, 1800]);
set(gca, 'FontSize', settings.font_size, 'LineWidth', 1.5, 'GridAlpha', settings.grid_alpha);

end
