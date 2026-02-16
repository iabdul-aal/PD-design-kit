clear all; close all; clc;

addpath('config', 'core', 'models', 'analysis', 'visualization');

params = parameters();
const = constants();
settings = plot_settings();

num_symbols = params.num_bits / 2;
responsivity = params.eta_plateau * const.e * params.lambda_center / (const.h * const.c);
BW_3dB = 0.75 * params.symbol_rate;
Isat = responsivity * params.Psat;
fs = params.symbol_rate * params.samples_per_symbol;
num_samples = num_symbols * params.samples_per_symbol;
P_avg = 10^(params.P_avg_dBm/10) * 1e-3;
P_min = P_avg * 2 / (params.extinction_ratio + 1);
P_max = P_avg * 2 * params.extinction_ratio / (params.extinction_ratio + 1);

rrc_filter = pulse_shaping(params.samples_per_symbol);

[tx_symbols, tx_bits] = data_generation(params.num_bits);

optical_power_tx = modulation(tx_symbols, rrc_filter, P_min, P_max, num_samples, params.samples_per_symbol);

optical_power_rx = channel_model(optical_power_tx, params.channel_noise_variance);

[photocurrent_ideal, ~, ~] = photodiode_model(optical_power_rx, params, const);

[shot_noise, thermal_noise] = noise_model(photocurrent_ideal, params, const);

photocurrent_noisy = photocurrent_ideal + shot_noise + thermal_noise;

photocurrent_rx = bandwidth_limit(photocurrent_noisy, BW_3dB, fs);

[rx_symbols, rx_bits] = detection(photocurrent_rx, rrc_filter, num_symbols, params.samples_per_symbol);

metrics = calculate_metrics(tx_bits, rx_bits, tx_symbols, rx_symbols, photocurrent_rx);

fprintf('=== Simulation Results ===\n');
fprintf('SNR: %.2f dB\n', metrics.SNR_dB);
fprintf('BER: %.2e (%d/%d errors)\n', metrics.BER, metrics.bit_errors, metrics.total_bits);
fprintf('SER: %.2e (%d/%d errors)\n', metrics.SER, metrics.symbol_errors, metrics.total_symbols);

plot_responsivity(params, const, settings);
plot_transfer_function(responsivity, Isat, P_min, P_max, params.Psat, params, settings);
plot_eye_diagram(optical_power_rx, params, settings, 'Optical Power', metrics.SNR_dB);
plot_eye_diagram(photocurrent_rx, params, settings, 'Photocurrent', metrics.SNR_dB);
