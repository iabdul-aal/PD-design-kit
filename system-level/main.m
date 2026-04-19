% system-level/main.m
% Ge-on-Si PD - PAM-4 System-Level Simulation
% Ref: Yang Shi et al., Photonics Research 12, 1 (2024)
%
% Runs the full PAM-4 receiver chain, exports thesis figures,
% and calls interconnect_model() for INTERCONNECT-ready PD data.
%
% All parameters are set in getConfig(). Nothing is hardcoded in the
% simulation pipeline itself.

clearvars; close all; clc;
figureDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
cfg = getConfig(figureDir);
[txSymbols, txBits] = generateSymbols(cfg.num_bits);
numSymbols = numel(txSymbols);
fs = cfg.symbol_rate * cfg.samples_per_symbol;
bw = min(cfg.f3dB, 0.75 * cfg.symbol_rate);
responsivity = cfg.eta_plateau * cfg.e * cfg.lambda_center / (cfg.h * cfg.c);
Isat = responsivity * cfg.Psat;
Pavg = 1e-3 * 10^(cfg.P_avg_dBm / 10);
Pmin = 2 * Pavg / (cfg.extinction_ratio + 1);
Pmax = 2 * Pavg * cfg.extinction_ratio / (cfg.extinction_ratio + 1);
pulse = rcosdesign(0.35, 6, cfg.samples_per_symbol, 'sqrt');
opticalTx = modulatePAM(txSymbols, pulse, Pmin, Pmax, numSymbols * cfg.samples_per_symbol, cfg.samples_per_symbol);
opticalRx = max(opticalTx + sqrt(cfg.channel_noise_variance) * randn(size(opticalTx)), 0);
photocurrentIdeal = min(responsivity * opticalRx, Isat);
[shotNoise, thermalNoise] = noiseTerms(photocurrentIdeal, cfg, fs, bw);
referenceRx = lowpassTrace(photocurrentIdeal, bw, fs);
photocurrentRx = lowpassTrace(photocurrentIdeal + shotNoise + thermalNoise, bw, fs);
[rxSymbols, rxBits] = detectPAM(photocurrentRx, pulse, numSymbols, cfg.samples_per_symbol);
metrics = calcMetrics(txBits, rxBits, txSymbols, rxSymbols, referenceRx, photocurrentRx);
compact = interconnect_model(cfg, responsivity);

fprintf('=== PAM-4 System Simulation Results ===\n');
fprintf('  Symbol rate       : %.3f GBd\n', cfg.symbol_rate / 1e9);
fprintf('  Responsivity      : %.4f A/W\n', responsivity);
fprintf('  P_avg             : %.1f dBm\n', cfg.P_avg_dBm);
fprintf('  SNR               : %.2f dB\n', metrics.SNR_dB);
fprintf('  BER               : %.2e (%d/%d errors)\n', metrics.BER, metrics.bit_errors, metrics.total_bits);
fprintf('  SER               : %.2e (%d/%d errors)\n', metrics.SER, metrics.symbol_errors, metrics.total_symbols);
fprintf('  INTERCONNECT model: Zt(DC)=%.2f V/W | fRC=%.1f GHz | fPKG=%.1f GHz\n', ...
    compact.zt_VW(1), compact.f_rc / 1e9, compact.f_pkg / 1e9);

plotResponsivity(cfg, responsivity, 'system_responsivity_curve');
plotTransfer(cfg, responsivity, Isat, Pmin, Pmax, 'system_transfer_function');
plotEye(cfg, opticalRx, 'Optical Power', metrics.SNR_dB, 'system_optical_eye');
plotEye(cfg, photocurrentRx, 'Photocurrent', metrics.SNR_dB, 'system_photocurrent_eye');
plotPAMHistogram(cfg, photocurrentRx, pulse, numSymbols, metrics.SNR_dB, 'system_pam4_histogram');

function cfg = getConfig(figureDir)
% getConfig  All simulation parameters in one place.
% Physics constants, device parameters, and simulation settings.
cfg = struct( ...
    'lambda_center', 1310e-9, ...
    'lambda_min', 1260e-9, ...
    'lambda_max', 1360e-9, ...
    'eta_plateau', 0.95, ...
    'Id', 1.3e-9, ...
    'Psat', 10e-3, ...
    'f3dB', 103e9, ...
    'Rs', 12.9, ...
    'Cj', 22.6e-15, ...
    'Lp', 175.3e-12, ...
    'Cp', 10e-15, ...
    'symbol_rate', 53.125e9, ...
    'samples_per_symbol', 8, ...
    'num_bits', 100000, ...
    'P_avg_dBm', -2, ...
    'extinction_ratio', 10, ...
    'R_load', 50, ...
    'T', 300, ...
    'channel_noise_variance', 1e-8, ...
    'enable_shot_noise', true, ...
    'enable_thermal_noise', true, ...
    'plot_num_symbols', 100, ...
    'figure_dir', figureDir, ...
    'h', 6.626e-34, ...
    'c', 3e8, ...
    'e', 1.602e-19, ...
    'k', 1.381e-23, ...
    'font_size', 11, ...
    'title_size', 13, ...
    'label_size', 12, ...
    'line_width', 2.5, ...
    'grid_alpha', 0.15, ...
    'font_name', 'Times New Roman', ...
    'export_dpi', 300);
cfg.colors = struct( ...
    'blue',    [0, 0.447, 0.741], ...
    'red',     [0.85, 0.325, 0.098], ...
    'green',   [0.466, 0.674, 0.188], ...
    'darkred', [0.635, 0.078, 0.184], ...
    'gray',    [0.5, 0.5, 0.5]);
end

function [symbols, bits] = generateSymbols(numBits)
symbols = randi([0, 3], floor(numBits / 2), 1);
bits = reshape([floor(symbols / 2), mod(symbols, 2)].', [], 1);
end

function opticalPower = modulatePAM(symbols, pulse, Pmin, Pmax, numSamples, sps)
pamLevels = [-3; -1; 1; 3];
waveform = upfirdn(pamLevels(symbols + 1), pulse, sps, 1);
groupDelay = (numel(pulse) - 1) / 2;
waveform = real(waveform(groupDelay + 1:groupDelay + numSamples));
span = max(waveform) - min(waveform);
waveform = (waveform - min(waveform)) / max(span, eps);
opticalPower = Pmin + waveform * (Pmax - Pmin);
end

function [shotNoise, thermalNoise] = noiseTerms(photocurrent, cfg, fs, bw)
shotNoise = zeros(size(photocurrent));
if cfg.enable_shot_noise
    dt = 1 / fs;
    lambda = (max(photocurrent, 0) + cfg.Id) * dt / cfg.e;
    shotNoise = (poissrnd(lambda) - lambda) * cfg.e / dt;
end
thermalNoise = zeros(size(photocurrent));
if cfg.enable_thermal_noise
    thermalNoise = sqrt(4 * cfg.k * cfg.T * bw / cfg.R_load) * randn(size(photocurrent));
end
end

function y = lowpassTrace(x, bw, fs)
[b, a] = butter(3, min(0.99, 2 * bw / fs));
y = filter(b, a, x);
end

function [symbols, bits] = detectPAM(signal, pulse, numSymbols, sps)
matched = conv(signal, pulse, 'full');
groupDelay = (numel(pulse) - 1) / 2;
bestScore = -inf;
samples = [];
for offset = 0:sps - 1
    indices = groupDelay + 1 + offset + (0:numSymbols - 1) * sps;
    indices = indices(indices <= numel(matched));
    candidate = matched(indices);
    if var(candidate, 1) > bestScore, bestScore = var(candidate, 1); samples = candidate(:); end
end
sortedSamples = sort(samples);
binEdges = round(linspace(1, numel(sortedSamples) + 1, 5));
levelMeans = zeros(1, 4);
for idx = 1:4, levelMeans(idx) = mean(sortedSamples(binEdges(idx):binEdges(idx + 1) - 1)); end
thresholds = (levelMeans(1:3) + levelMeans(2:4)) / 2;
symbols = sum(samples >= thresholds, 2);
bits = reshape([floor(symbols / 2), mod(symbols, 2)].', [], 1);
end

function metrics = calcMetrics(txBits, rxBits, txSymbols, rxSymbols, reference, received)
nBits = min(numel(txBits), numel(rxBits));
nSym = min(numel(txSymbols), numel(rxSymbols));
reference = reference(:);
noise = received(:) - reference;
signalPower = var(reference, 1);
noisePower = max(var(noise, 1), eps);
bitErrors = sum(txBits(1:nBits) ~= rxBits(1:nBits));
symbolErrors = sum(txSymbols(1:nSym) ~= rxSymbols(1:nSym));
metrics = struct('signal_power', signalPower, 'noise_power', noisePower, 'SNR_linear', signalPower / noisePower, ...
    'SNR_dB', 10 * log10(signalPower / noisePower), 'bit_errors', bitErrors, 'symbol_errors', symbolErrors, ...
    'total_bits', nBits, 'total_symbols', nSym, 'BER', bitErrors / max(nBits, 1), 'SER', symbolErrors / max(nSym, 1));
end

function plotResponsivity(cfg, responsivity, fileName)
lambdaNm = linspace(300, 1800, 2000);
lambdaM = 1e-9 * lambdaNm;
edge = max((cfg.lambda_max - cfg.lambda_min) / 8, 5e-9);
rollOn = 1 ./ (1 + exp((cfg.lambda_min - lambdaM) / edge));
rollOff = 1 ./ (1 + exp((lambdaM - cfg.lambda_max) / edge));
R = cfg.eta_plateau * rollOn .* rollOff .* cfg.e .* lambdaM / (cfg.h * cfg.c);
fig = figure('Color', 'w', 'Position', [60, 60, 1600, 1000], 'Name', 'Photodiode Responsivity');
plot(lambdaNm, R, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width); hold on;
xline(cfg.lambda_min * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5);
xline(cfg.lambda_max * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5);
plot(cfg.lambda_center * 1e9, responsivity, 'o', 'Color', cfg.colors.red, ...
    'MarkerFaceColor', cfg.colors.red, 'LineWidth', 1.5);
xlabel('Wavelength, \lambda (nm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
ylabel('Responsivity, R (A/W)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
title(sprintf('Photodiode Responsivity over %.0f-%.0f nm', cfg.lambda_min * 1e9, cfg.lambda_max * 1e9), ...
    'FontSize', cfg.title_size, 'FontWeight', 'bold');
grid on; xlim([300, 1800]); ylim([0, max(1, 1.1 * max(R))]);
styleAxes(cfg); saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotTransfer(cfg, responsivity, Isat, Pmin, Pmax, fileName)
P = linspace(0, 1.5 * cfg.Psat, 1000);
Iideal = responsivity * P;
Iactual = min(Iideal, Isat);
fig = figure('Color', 'w', 'Position', [90, 90, 1600, 1000], 'Name', 'Photodiode Transfer Function');
plot(P * 1e3, Iactual * 1e3, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width); hold on;
plot(P * 1e3, Iideal * 1e3, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5);
xline(Pmin * 1e3, '--', 'Color', cfg.colors.green, 'LineWidth', 1.5);
xline(Pmax * 1e3, '--', 'Color', cfg.colors.red, 'LineWidth', 1.5);
xline(cfg.Psat * 1e3, ':', 'Color', cfg.colors.darkred, 'LineWidth', 1.5);
yline(Isat * 1e3, ':', 'Color', cfg.colors.darkred, 'LineWidth', 1.5);
xlabel('Optical Power, P (mW)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
ylabel('Photocurrent, I (mA)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
title(sprintf('Transfer Function at %d nm', round(cfg.lambda_center * 1e9)), ...
    'FontSize', cfg.title_size, 'FontWeight', 'bold');
grid on; xlim([0, max(P) * 1e3]); ylim([0, 1.1 * max(Iactual) * 1e3]);
styleAxes(cfg); saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotEye(cfg, signal, signalType, snrDb, fileName)
eyeSamples = 2 * cfg.samples_per_symbol;
numTraces = min(floor(numel(signal) / eyeSamples), cfg.plot_num_symbols);
eyeData = reshape(signal(1:numTraces * eyeSamples), eyeSamples, numTraces) * 1e3;
tEye = (0:eyeSamples - 1) / (cfg.symbol_rate * cfg.samples_per_symbol) * 1e12;
isPower = strcmp(signalType, 'Optical Power');
tone = 0.75 * cfg.colors.green + 0.25 * [1, 1, 1];
if isPower, tone = 0.75 * cfg.colors.blue + 0.25 * [1, 1, 1]; yLabel = 'Power, P (mW)';
else, yLabel = 'Current, I (mA)'; end
fig = figure('Color', 'w', 'Position', [120, 120, 1600, 1000], 'Name', [signalType, ' Eye Diagram']);
plot(tEye, eyeData, 'Color', tone, 'LineWidth', 0.6);
xlabel('Time, t (ps)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
ylabel(yLabel, 'FontSize', cfg.label_size, 'FontWeight', 'bold');
title(sprintf('%s Eye Diagram (SNR = %.1f dB)', signalType, snrDb), ...
    'FontSize', cfg.title_size, 'FontWeight', 'bold');
grid on; xlim([tEye(1), tEye(end)]);
styleAxes(cfg); saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotPAMHistogram(cfg, signal, pulse, numSymbols, snrDb, fileName)
% plotPAMHistogram  Matched-filter output histogram showing PAM-4 levels.
matched = conv(signal, pulse, 'full');
groupDelay = (numel(pulse) - 1) / 2;
sps = cfg.samples_per_symbol;
bestScore = -inf;
samples = [];
for offset = 0:sps - 1
    indices = groupDelay + 1 + offset + (0:numSymbols - 1) * sps;
    indices = indices(indices <= numel(matched));
    candidate = matched(indices);
    if var(candidate, 1) > bestScore, bestScore = var(candidate, 1); samples = candidate(:); end
end
fig = figure('Color', 'w', 'Position', [150, 150, 1600, 1000], 'Name', 'PAM-4 Level Histogram');
histogram(samples * 1e3, 120, 'FaceColor', cfg.colors.blue, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
xlabel('Matched Filter Output (mA)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
ylabel('Count', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
title(sprintf('PAM-4 Level Histogram (SNR = %.1f dB)', snrDb), ...
    'FontSize', cfg.title_size, 'FontWeight', 'bold');
grid on;
% Draw decision thresholds
sortedSamples = sort(samples);
binEdges = round(linspace(1, numel(sortedSamples) + 1, 5));
levelMeans = zeros(1, 4);
for idx = 1:4, levelMeans(idx) = mean(sortedSamples(binEdges(idx):binEdges(idx+1)-1)); end
thresholds = (levelMeans(1:3) + levelMeans(2:4)) / 2;
hold on;
for thr = thresholds
    xline(thr * 1e3, '--', 'Color', cfg.colors.red, 'LineWidth', 1.5);
end
hold off;
styleAxes(cfg); saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function styleAxes(cfg)
set(gca, 'FontSize', cfg.font_size, 'FontName', cfg.font_name, 'LineWidth', 1.5, ...
    'GridAlpha', cfg.grid_alpha, 'MinorGridAlpha', 0.08, 'TickDir', 'out', ...
    'XMinorGrid', 'on', 'YMinorGrid', 'on');
end

function saveThesisFigure(fig, outDir, baseName, dpi)
if ~exist(outDir, 'dir'), mkdir(outDir); end
set(fig, 'Color', 'w', 'InvertHardcopy', 'off', 'Renderer', 'painters');
drawnow;
exportgraphics(fig, fullfile(outDir, [baseName, '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig, fullfile(outDir, [baseName, '.png']), 'Resolution', dpi, 'BackgroundColor', 'white');
fprintf('Saved %s.[pdf|png]\n', fullfile(outDir, baseName));
end
