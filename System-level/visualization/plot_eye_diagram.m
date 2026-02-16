function plot_eye_diagram(signal, params, settings, signal_type, SNR_dB)

fs = params.symbol_rate * params.samples_per_symbol;
num_samples = length(signal);

fig = figure('Position', [250, 250, 900, 600], 'Color', 'w');
set(fig, 'Name', sprintf('%s Eye Diagram', signal_type));

eye_samples = 2 * params.samples_per_symbol;
num_traces = floor(num_samples / eye_samples);
t_eye = (0:eye_samples-1) / fs * 1e12;

if strcmp(signal_type, 'Optical Power')
    eye_matrix = reshape(signal(1:num_traces*eye_samples)*1e3, eye_samples, num_traces);
    plot(t_eye, eye_matrix, 'Color', [settings.colors.blue, 0.3], 'LineWidth', 0.5);
    ylabel('Power, P (mW)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
else
    eye_matrix = reshape(signal(1:num_traces*eye_samples)*1e3, eye_samples, num_traces);
    plot(t_eye, eye_matrix, 'Color', [settings.colors.green, 0.2], 'LineWidth', 0.5);
    ylabel('Current, i (mA)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
end

grid on;
xlabel('Time, t (ps)', 'FontSize', settings.label_size, 'FontWeight', 'bold');
title(sprintf('%s Eye Diagram (SNR = %.1f dB)', signal_type, SNR_dB), ...
    'FontSize', settings.title_size, 'FontWeight', 'bold');
set(gca, 'FontSize', settings.font_size, 'LineWidth', 1.5, 'GridAlpha', settings.grid_alpha);
xlim([t_eye(1), t_eye(end)]);

end
