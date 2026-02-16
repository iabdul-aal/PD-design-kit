function plot_transfer_function(responsivity, Isat, P_min, P_max, Psat, params, settings)

fig = figure('Position', [75, 75, 900, 600], 'Color', 'w');
set(fig, 'Name', 'Photodiode Transfer Function');

P_range = linspace(0, Psat * 1.5, 1000);
I_ideal = responsivity * P_range;
I_actual = min(I_ideal, Isat);

plot(P_range * 1e3, I_actual * 1e3, 'Color', settings.colors.blue, 'LineWidth', settings.line_width);
hold on;
plot(P_range * 1e3, I_ideal * 1e3, '--', 'Color', settings.colors.gray, 'LineWidth', 2);

xline(P_min * 1e3, '--', 'Color', settings.colors.green, 'LineWidth', 2);
xline(P_max * 1e3, '--', 'Color', settings.colors.red, 'LineWidth', 2);
yline(Isat * 1e3, ':', 'Color', settings.colors.darkred, 'LineWidth', 2);
xline(Psat * 1e3, ':', 'Color', settings.colors.darkred, 'LineWidth', 2);

grid on;
xlabel('Optical Power, P (mW)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
ylabel('Photocurrent, I (mA)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
title(sprintf('Transfer Function (R = %.3f A/W, λ = %d nm)', ...
    responsivity, round(params.lambda_center*1e9)), ...
    'FontSize', settings.title_size, 'FontWeight', 'bold');
set(gca, 'FontSize', settings.font_size, 'LineWidth', 1.5, 'GridAlpha', settings.grid_alpha);
xlim([0, max(P_range) * 1e3]);
ylim([0, max(I_actual) * 1.1 * 1e3]);

end
