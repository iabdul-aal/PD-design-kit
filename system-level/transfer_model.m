
clearvars; close all; clc;
figureDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
cfg = getConfig(figureDir);

pdPhysics = computePDPhysics(cfg);

[txSymbols, txBits] = generateSymbols(cfg.num_bits);
numSymbols = numel(txSymbols);
fs = cfg.symbol_rate * cfg.samples_per_symbol;
bw = min(pdPhysics.f3dB_total, 0.75 * cfg.symbol_rate);
responsivity = pdPhysics.responsivity;
Isat = responsivity * cfg.Psat;
Pavg = 1e-3 * 10^(cfg.P_avg_dBm / 10);
Pmin = 2 * Pavg / (cfg.extinction_ratio + 1);
Pmax = 2 * Pavg * cfg.extinction_ratio / (cfg.extinction_ratio + 1);
pulse = rcosdesign(0.35, 6, cfg.samples_per_symbol, 'sqrt');

opticalTx = modulatePAM(txSymbols, pulse, Pmin, Pmax, ...
    numSymbols * cfg.samples_per_symbol, cfg.samples_per_symbol);
opticalRx = max(opticalTx + sqrt(cfg.channel_noise_variance) * randn(size(opticalTx)), 0);

photocurrentIdeal = smoothSaturation(responsivity * opticalRx, Isat, cfg.saturation_model);
[shotNoise, thermalNoise, noiseComponents] = noiseTerms(photocurrentIdeal, cfg, pdPhysics, fs, bw);
referenceRx = lowpassTrace(photocurrentIdeal, bw, fs);
photocurrentRx = lowpassTrace(photocurrentIdeal + shotNoise + thermalNoise, bw, fs);
[rxSymbols, rxBits] = detectPAM(photocurrentRx, pulse, numSymbols, cfg.samples_per_symbol);
metrics = calcMetrics(txBits, rxBits, txSymbols, rxSymbols, referenceRx, photocurrentRx);

analytical = computeAnalyticalPerformance(cfg, pdPhysics, Pavg, Pmin, Pmax, bw);

compact = interconnect_model(cfg, responsivity);

fprintf('=== PAM-4 System Simulation Results ===\n');
fprintf('  Symbol rate         : %.3f GBd\n', cfg.symbol_rate / 1e9);
fprintf('  Responsivity        : %.4f A/W\n', responsivity);
fprintf('  P_avg               : %.1f dBm\n', cfg.P_avg_dBm);
fprintf('  SNR (simulated)     : %.2f dB\n', metrics.SNR_dB);
fprintf('  SNR (analytical)    : %.2f dB\n', analytical.SNR_dB);
fprintf('  Q-factor            : %.2f\n', analytical.Q);
fprintf('  BER (simulated)     : %.2e (%d/%d errors)\n', metrics.BER, metrics.bit_errors, metrics.total_bits);
fprintf('  BER (analytical)    : %.2e\n', analytical.BER);
fprintf('  SER                 : %.2e (%d/%d errors)\n', metrics.SER, metrics.symbol_errors, metrics.total_symbols);
fprintf('  INTERCONNECT model  : Zt(DC)=%.2f V/W | fRC=%.1f GHz | fPKG=%.1f GHz\n', ...
    compact.zt_VW(1), compact.f_rc / 1e9, compact.f_pkg / 1e9);

fprintf('\n=== Wartak Ch.10: Photodetector Physics ===\n');
fprintf('  Quantum efficiency    : %.4f (physical)  |  %.4f (config)\n', pdPhysics.eta_physical, cfg.eta_plateau);
fprintf('  Absorption coeff.     : %.0f cm^-1 @ %.0f nm\n', cfg.alpha_abs * 1e-2, cfg.lambda_center * 1e9);
fprintf('  Ge absorber length    : %.1f um\n', cfg.L_absorber * 1e6);
fprintf('  Depletion width       : %.0f nm\n', cfg.d_depletion * 1e9);
fprintf('  Confinement factor    : %.2f\n', cfg.Gamma_conf);
fprintf('  Transit-time BW f_tr  : %.1f GHz\n', pdPhysics.f_transit / 1e9);
fprintf('  RC bandwidth f_RC     : %.1f GHz\n', pdPhysics.f_RC / 1e9);
fprintf('  Combined BW f_3dB     : %.1f GHz\n', pdPhysics.f3dB_total / 1e9);
fprintf('  Dark current (diode)  : %.3e A\n', pdPhysics.Id_physical);
fprintf('  NEP                   : %.3e W/sqrt(Hz)\n', analytical.NEP);
fprintf('  Detectivity D*        : %.3e Jones\n', analytical.Dstar);
fprintf('  Sensitivity @BER=1e-9 : %.2f dBm\n', analytical.sensitivity_dBm);

plotResponsivity(cfg, pdPhysics, 'system_responsivity_curve');
plotTransfer(cfg, responsivity, Isat, Pmin, Pmax, 'system_transfer_function');
plotEye(cfg, opticalRx, 'Optical Power', metrics.SNR_dB, 'system_optical_eye');
plotEye(cfg, photocurrentRx, 'Photocurrent', metrics.SNR_dB, 'system_photocurrent_eye');
plotPAMHistogram(cfg, photocurrentRx, pulse, numSymbols, metrics.SNR_dB, 'system_pam4_histogram');

plotQuantumEfficiency(cfg, pdPhysics, 'system_quantum_efficiency');
plotBandwidthBudget(cfg, pdPhysics, 'system_bandwidth_budget');
plotNoiseAnalysis(cfg, noiseComponents, pdPhysics, analytical, 'system_noise_analysis');
plotBERvsPower(cfg, pdPhysics, bw, pulse, 'system_ber_vs_power');

function cfg = getConfig(figureDir)

cfg = struct( ...
    ...
    'lambda_center', 1310e-9, ...
    'lambda_min',    1260e-9, ...
    'lambda_max',    1360e-9, ...
    ...
    ...
    'eta_plateau', 0.95, ...
    'Id',          1.3e-9, ...
    'Psat',        10e-3, ...
    'f3dB',        103e9, ...
    'Rs',          12.9, ...
    'Cj',          22.6e-15, ...
    'Lp',          175.3e-12, ...
    'Cp',          10e-15, ...
    ...
    ...
    'alpha_abs',      7e5, ...
    'Eg_direct',      0.80, ...
    'd_depletion',    150e-9, ...
    'L_absorber',     10e-6, ...
    'Gamma_conf',     0.70, ...
    'Rf_surface',     0.05, ...
    'v_sat_e',        6.0e4, ...
    'v_sat_h',        4.7e4, ...
    'A_detector',     3e-12, ...
    'Is',             1e-12, ...
    'n_ideality',     1.2, ...
    'Vbias',          -1.0, ...
    'saturation_model', 'smooth', ...
    ...
    ...
    'symbol_rate',           53.125e9, ...
    'samples_per_symbol',    8, ...
    'num_bits',              100000, ...
    'P_avg_dBm',             -2, ...
    'extinction_ratio',      10, ...
    'R_load',                50, ...
    'T',                     300, ...
    'channel_noise_variance', 1e-8, ...
    'enable_shot_noise',     true, ...
    'enable_thermal_noise',  true, ...
    ...
    ...
    'target_BER',        1e-9, ...
    'P_sweep_dBm',       -25:0.5:0, ...
    'ber_mc_runs',       8, ...
    'ber_mc_bits',       20000, ...
    ...
    ...
    'plot_num_symbols', 100, ...
    'figure_dir',       figureDir, ...
    ...
    ...
    'h', 6.626e-34, ...
    'c', 3e8, ...
    'e', 1.602e-19, ...
    'k', 1.381e-23, ...
    ...
    ...
    'font_size',  11, ...
    'title_size', 13, ...
    'label_size', 12, ...
    'line_width', 2.5, ...
    'grid_alpha', 0.15, ...
    'font_name',  'Times New Roman', ...
    'export_dpi', 300);

cfg.colors = struct( ...
    'blue',    [0, 0.447, 0.741], ...
    'red',     [0.85, 0.325, 0.098], ...
    'green',   [0.466, 0.674, 0.188], ...
    'purple',  [0.494, 0.184, 0.556], ...
    'darkred', [0.635, 0.078, 0.184], ...
    'orange',  [0.929, 0.694, 0.125], ...
    'gray',    [0.5, 0.5, 0.5]);
end

function pd = computePDPhysics(cfg)

    eta_physical = (1 - cfg.Rf_surface) * (1 - exp(-cfg.Gamma_conf * cfg.alpha_abs * cfg.L_absorber));
    pd.eta_physical = eta_physical;

    pd.responsivity = cfg.eta_plateau * cfg.e * cfg.lambda_center / (cfg.h * cfg.c);

    v_avg = 2 * cfg.v_sat_e * cfg.v_sat_h / (cfg.v_sat_e + cfg.v_sat_h);
    pd.v_drift = v_avg;
    pd.f_transit = 0.45 * v_avg / cfg.d_depletion;

    Ctotal = cfg.Cj + cfg.Cp;
    pd.Ctotal = Ctotal;
    pd.f_RC = 1 / (2 * pi * (cfg.Rs + cfg.R_load) * Ctotal);

    pd.f3dB_total = 1 / sqrt(1 / pd.f_transit^2 + 1 / pd.f_RC^2);

    Vt = cfg.k * cfg.T / cfg.e;
    pd.Id_physical = cfg.Is * (exp(cfg.Vbias / (cfg.n_ideality * Vt)) - 1);
    pd.Id_physical = abs(pd.Id_physical);

    E_center = cfg.h * cfg.c / (cfg.e * cfg.lambda_center);
    C_direct = cfg.alpha_abs / max(sqrt(E_center - cfg.Eg_direct), 1e-6);
    pd.C_direct = C_direct;
    pd.E_center = E_center;
end

function analytical = computeAnalyticalPerformance(cfg, pdPhysics, Pavg, Pmin, Pmax, bw)

    R = pdPhysics.responsivity;
    Id = cfg.Id;

    Ip = R * Pavg;
    sigma2_shot   = 2 * cfg.e * (Ip + Id) * bw;
    sigma2_thermal = 4 * cfg.k * cfg.T * bw / cfg.R_load;
    SNR_linear = Ip^2 / (sigma2_shot + sigma2_thermal);
    analytical.SNR_dB = 10 * log10(SNR_linear);
    analytical.SNR_linear = SNR_linear;
    analytical.sigma2_shot = sigma2_shot;
    analytical.sigma2_thermal = sigma2_thermal;

    I1 = R * Pmax;
    I0 = R * Pmin;
    sigma1 = sqrt(2 * cfg.e * (I1 + Id) * bw + sigma2_thermal);
    sigma0 = sqrt(2 * cfg.e * (I0 + Id) * bw + sigma2_thermal);
    M = 4;
    Q_pam4 = (I1 - I0) / ((M - 1) * (sigma1 + sigma0));
    analytical.Q = Q_pam4;

    analytical.BER = (3 / (2 * log2(M))) * 0.5 * erfc(Q_pam4 / sqrt(2));

    analytical.NEP = sqrt(2 * cfg.e * Id + 4 * cfg.k * cfg.T / cfg.R_load) / R;

    A_cm2 = cfg.A_detector * 1e4;
    analytical.Dstar = R * sqrt(A_cm2) / sqrt(2 * cfg.e * Id + 4 * cfg.k * cfg.T / cfg.R_load);

    Q_req = sqrt(2) * erfcinv(2 * cfg.target_BER * 2 * log2(M) / 3);
    sigma_th = sqrt(sigma2_thermal);
    dP = (cfg.extinction_ratio - 1) / (cfg.extinction_ratio + 1);
    P_sens = Q_req * (M - 1) * 2 * sigma_th / (R * 2 * dP);
    analytical.sensitivity_W = P_sens;
    analytical.sensitivity_dBm = 10 * log10(P_sens / 1e-3);
    analytical.Q_required = Q_req;
end

function Iout = smoothSaturation(Iin, Isat, model)
    switch model
        case 'hard'
            Iout = min(Iin, Isat);
        case 'smooth'
            Iout = Iin ./ (1 + Iin / Isat);
        case 'tanh'
            Iout = Isat * tanh(Iin / Isat);
        otherwise
            Iout = min(Iin, Isat);
    end
end

function [shotNoise, thermalNoise, nc] = noiseTerms(photocurrent, cfg, pdPhysics, fs, bw)
    Id = pdPhysics.Id_physical;

    shotNoise = zeros(size(photocurrent));
    if cfg.enable_shot_noise
        dt = 1 / fs;
        lambda = (max(photocurrent, 0) + Id) * dt / cfg.e;
        shotNoise = (poissrnd(lambda) - lambda) * cfg.e / dt;
    end

    thermalNoise = zeros(size(photocurrent));
    if cfg.enable_thermal_noise
        thermalNoise = sqrt(4 * cfg.k * cfg.T * bw / cfg.R_load) * randn(size(photocurrent));
    end

    nc.shot = shotNoise;
    nc.thermal = thermalNoise;
    nc.shot_variance = var(shotNoise);
    nc.thermal_variance = var(thermalNoise);
    nc.total_variance = nc.shot_variance + nc.thermal_variance;
    nc.shot_fraction = nc.shot_variance / max(nc.total_variance, eps);
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

function plotResponsivity(cfg, pdPhysics, fileName)
    lambdaNm = linspace(300, 1800, 2000);
    lambdaM = 1e-9 * lambdaNm;
    E_eV = cfg.h * cfg.c ./ (cfg.e * lambdaM);

    edge = max((cfg.lambda_max - cfg.lambda_min) / 8, 5e-9);
    rollOn = 1 ./ (1 + exp((cfg.lambda_min - lambdaM) / edge));
    rollOff = 1 ./ (1 + exp((lambdaM - cfg.lambda_max) / edge));
    R_empirical = cfg.eta_plateau * rollOn .* rollOff .* cfg.e .* lambdaM / (cfg.h * cfg.c);

    alpha_spec = pdPhysics.C_direct * real(sqrt(max(E_eV - cfg.Eg_direct, 0)));
    eta_spec = (1 - cfg.Rf_surface) * (1 - exp(-cfg.Gamma_conf * alpha_spec * cfg.L_absorber));
    R_physical = eta_spec .* cfg.e .* lambdaM / (cfg.h * cfg.c);

    fig = figure('Color', 'w', 'Position', [60, 60, 1600, 1000], 'Name', 'Photodiode Responsivity');
    plot(lambdaNm, R_empirical, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width, ...
        'DisplayName', 'Empirical (sigmoid)'); hold on;
    plot(lambdaNm, R_physical, '--', 'Color', cfg.colors.red, 'LineWidth', 2, ...
        'DisplayName', 'Wartak physical model');
    xline(cfg.lambda_min * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(cfg.lambda_max * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(cfg.lambda_center * 1e9, pdPhysics.responsivity, 'o', 'Color', cfg.colors.red, ...
        'MarkerFaceColor', cfg.colors.red, 'LineWidth', 1.5, 'DisplayName', ...
        sprintf('Operating point (%.4f A/W)', pdPhysics.responsivity));
    xlabel('Wavelength, \lambda (nm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Responsivity, R (A/W)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title(sprintf('Photodiode Responsivity â€” %.0fâ€“%.0f nm (Wartak Ch.10)', ...
        cfg.lambda_min * 1e9, cfg.lambda_max * 1e9), 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    grid on; xlim([800, 1800]); ylim([0, max(1, 1.1 * max(R_empirical))]);
    legend('Location', 'northwest', 'FontSize', 10, 'Box', 'off');
    styleAxes(cfg); saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotTransfer(cfg, responsivity, Isat, Pmin, Pmax, fileName)
    P = linspace(0, 1.5 * cfg.Psat, 1000);
    Iideal = responsivity * P;
    I_hard = min(Iideal, Isat);
    I_smooth = Iideal ./ (1 + Iideal / Isat);
    I_tanh = Isat * tanh(Iideal / Isat);

    fig = figure('Color', 'w', 'Position', [90, 90, 1600, 1000], 'Name', 'Photodiode Transfer Function');
    plot(P * 1e3, I_hard * 1e3, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width, ...
        'DisplayName', 'Hard clip'); hold on;
    plot(P * 1e3, I_smooth * 1e3, '--', 'Color', cfg.colors.red, 'LineWidth', 2, ...
        'DisplayName', 'Smooth I/(1+I/I_{sat})');
    plot(P * 1e3, I_tanh * 1e3, ':', 'Color', cfg.colors.purple, 'LineWidth', 2, ...
        'DisplayName', 'Tanh compression');
    plot(P * 1e3, Iideal * 1e3, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5, ...
        'DisplayName', 'Ideal linear');
    xline(Pmin * 1e3, '--', 'Color', cfg.colors.green, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(Pmax * 1e3, '--', 'Color', cfg.colors.red, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xline(cfg.Psat * 1e3, ':', 'Color', cfg.colors.darkred, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    yline(Isat * 1e3, ':', 'Color', cfg.colors.darkred, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xlabel('Optical Power, P (mW)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Photocurrent, I (mA)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title(sprintf('Transfer Function at %d nm â€” Saturation Models (Wartak Sec. 10.2)', ...
        round(cfg.lambda_center * 1e9)), 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    grid on; xlim([0, max(P) * 1e3]); ylim([0, 1.1 * max(I_hard) * 1e3]);
    legend('Location', 'southeast', 'FontSize', 10, 'Box', 'off');
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

function plotQuantumEfficiency(cfg, pdPhysics, fileName)

    lambdaNm = linspace(800, 1850, 2000);
    lambdaM = 1e-9 * lambdaNm;
    E_eV = cfg.h * cfg.c ./ (cfg.e * lambdaM);

    alpha_spec = pdPhysics.C_direct * real(sqrt(max(E_eV - cfg.Eg_direct, 0)));

    L_variants = [5e-6, 10e-6, 20e-6, 50e-6];
    labels = {'L = 5 \mum', 'L = 10 \mum', 'L = 20 \mum', 'L = 50 \mum'};
    lineStyles = {'-', '--', '-.', ':'};
    clrs = {cfg.colors.blue, cfg.colors.red, cfg.colors.green, cfg.colors.purple};

    fig = figure('Color', 'w', 'Position', [160, 160, 1600, 1000], 'Name', 'Quantum Efficiency');

    subplot(1, 2, 1);
    semilogy(lambdaNm, alpha_spec * 1e-2, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width);
    xlabel('Wavelength, \lambda (nm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Absorption Coefficient, \alpha (cm^{-1})', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('Ge Absorption Coefficient (Wartak Eq. 10.3)', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    xline(cfg.lambda_center * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5);
    xlim([800, 1850]); grid on; styleAxes(cfg);

    subplot(1, 2, 2);
    hold on;
    for ii = 1:numel(L_variants)
        eta = (1 - cfg.Rf_surface) * (1 - exp(-cfg.Gamma_conf * alpha_spec * L_variants(ii)));
        plot(lambdaNm, eta, lineStyles{ii}, 'Color', clrs{ii}, 'LineWidth', 2, ...
            'DisplayName', labels{ii});
    end
    xline(cfg.lambda_min * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(cfg.lambda_max * 1e9, '--', 'Color', cfg.colors.gray, 'LineWidth', 1, 'HandleVisibility', 'off');
    plot(cfg.lambda_center * 1e9, pdPhysics.eta_physical, 'o', 'Color', cfg.colors.darkred, ...
        'MarkerFaceColor', cfg.colors.darkred, 'MarkerSize', 8, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('\\eta = %.3f @ %.0f nm', pdPhysics.eta_physical, cfg.lambda_center * 1e9));
    xlabel('Wavelength, \lambda (nm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Quantum Efficiency, \eta', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('\eta(\lambda) = (1-R_f)(1-e^{-\Gamma\alpha L}) â€” Wartak Eq. 10.7', ...
        'FontSize', cfg.title_size, 'FontWeight', 'bold');
    xlim([800, 1850]); ylim([0, 1.05]); grid on;
    legend('Location', 'southwest', 'FontSize', 10, 'Box', 'off');
    styleAxes(cfg);
    saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotBandwidthBudget(cfg, pdPhysics, fileName)

    fig = figure('Color', 'w', 'Position', [170, 170, 1600, 1000], 'Name', 'Bandwidth Budget');

    d_range = linspace(50e-9, 500e-9, 500);
    f_tr = 0.45 * pdPhysics.v_drift ./ d_range;
    f_rc = pdPhysics.f_RC * ones(size(d_range));
    f_combined = 1 ./ sqrt(1 ./ f_tr.^2 + 1 ./ f_rc.^2);

    subplot(1, 2, 1);
    plot(d_range * 1e9, f_tr / 1e9, '--', 'Color', cfg.colors.blue, 'LineWidth', 2, ...
        'DisplayName', 'f_{tr} (transit time)'); hold on;
    plot(d_range * 1e9, f_rc / 1e9, ':', 'Color', cfg.colors.green, 'LineWidth', 2, ...
        'DisplayName', sprintf('f_{RC} = %.0f GHz', pdPhysics.f_RC / 1e9));
    plot(d_range * 1e9, f_combined / 1e9, '-', 'Color', cfg.colors.red, 'LineWidth', cfg.line_width, ...
        'DisplayName', 'f_{3dB} combined');
    plot(cfg.d_depletion * 1e9, pdPhysics.f3dB_total / 1e9, 'o', 'Color', cfg.colors.darkred, ...
        'MarkerFaceColor', cfg.colors.darkred, 'MarkerSize', 10, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Design point (%.0f GHz)', pdPhysics.f3dB_total / 1e9));
    xlabel('Depletion Width, d (nm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Bandwidth (GHz)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('Bandwidth vs Depletion Width (Wartak Eq. 10.14â€“10.17)', ...
        'FontSize', cfg.title_size, 'FontWeight', 'bold');
    legend('Location', 'northeast', 'FontSize', 10, 'Box', 'off');
    grid on; ylim([0, 500]); styleAxes(cfg);

    subplot(1, 2, 2);
    L_range = linspace(1e-6, 50e-6, 500);
    E_center = cfg.h * cfg.c / (cfg.e * cfg.lambda_center);
    alpha_center = pdPhysics.C_direct * sqrt(max(E_center - cfg.Eg_direct, 0));
    eta_range = (1 - cfg.Rf_surface) * (1 - exp(-cfg.Gamma_conf * alpha_center * L_range));
    R_range = eta_range * cfg.e * cfg.lambda_center / (cfg.h * cfg.c);

    yyaxis left;
    plot(L_range * 1e6, eta_range, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width);
    ylabel('Quantum Efficiency, \eta', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylim([0, 1.05]);

    yyaxis right;
    plot(L_range * 1e6, R_range, 'Color', cfg.colors.red, 'LineWidth', 2);
    ylabel('Responsivity, R (A/W)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');

    hold on;
    yyaxis left;
    plot(cfg.L_absorber * 1e6, pdPhysics.eta_physical, 'o', 'Color', cfg.colors.darkred, ...
        'MarkerFaceColor', cfg.colors.darkred, 'MarkerSize', 10, 'LineWidth', 1.5);
    xlabel('Absorber Length, L (\mum)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('QEâ€“Absorber Length Trade-off', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    grid on; styleAxes(cfg);

    saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotNoiseAnalysis(cfg, nc, pdPhysics, analytical, fileName)

    fig = figure('Color', 'w', 'Position', [180, 180, 1600, 1000], 'Name', 'Noise Analysis');

    subplot(2, 2, 1);
    [counts, edges] = histcounts(nc.shot * 1e6, 80, 'Normalization', 'pdf');
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    bar(centers, counts, 'FaceColor', cfg.colors.blue, 'EdgeColor', 'none', 'FaceAlpha', 0.6); hold on;
    x_range = linspace(min(centers), max(centers), 500);
    pdf_gauss = normpdf(x_range, 0, sqrt(nc.shot_variance) * 1e6);
    plot(x_range, pdf_gauss, 'Color', cfg.colors.red, 'LineWidth', 2);
    xlabel('Current, i_{shot} (\muA)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('PDF', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('Shot Noise Distribution', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    legend({'Simulated', 'Gaussian fit'}, 'Location', 'northeast', 'FontSize', 9, 'Box', 'off');
    grid on; styleAxes(cfg);

    subplot(2, 2, 2);
    [counts, edges] = histcounts(nc.thermal * 1e6, 80, 'Normalization', 'pdf');
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    bar(centers, counts, 'FaceColor', cfg.colors.green, 'EdgeColor', 'none', 'FaceAlpha', 0.6); hold on;
    x_range = linspace(min(centers), max(centers), 500);
    pdf_gauss = normpdf(x_range, 0, sqrt(nc.thermal_variance) * 1e6);
    plot(x_range, pdf_gauss, 'Color', cfg.colors.red, 'LineWidth', 2);
    xlabel('Current, i_{thermal} (\muA)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('PDF', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('Thermal Noise Distribution', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    legend({'Simulated', 'Gaussian fit'}, 'Location', 'northeast', 'FontSize', 9, 'Box', 'off');
    grid on; styleAxes(cfg);

    subplot(2, 2, 3);
    pie_data = [nc.shot_variance, nc.thermal_variance];
    labels = {sprintf('Shot (%.1f%%)', 100 * nc.shot_fraction), ...
              sprintf('Thermal (%.1f%%)', 100 * (1 - nc.shot_fraction))};
    p = pie(pie_data, labels);
    for ii = 1:numel(p)
        if isprop(p(ii), 'FontSize'), p(ii).FontSize = 11; end
        if isprop(p(ii), 'FontName'), p(ii).FontName = cfg.font_name; end
    end
    title('Noise Variance Breakdown', 'FontSize', cfg.title_size, 'FontWeight', 'bold');

    subplot(2, 2, 4);
    bw_range = logspace(8, 12, 500);
    R = pdPhysics.responsivity;
    Id = pdPhysics.Id_physical;
    NEP_bw = sqrt(2 * cfg.e * Id * bw_range + 4 * cfg.k * cfg.T * bw_range / cfg.R_load) / R;

    yyaxis left;
    loglog(bw_range / 1e9, NEP_bw, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width);
    ylabel('NEP (W/\surdHz)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');

    yyaxis right;
    A_cm2 = cfg.A_detector * 1e4;
    Dstar_bw = R * sqrt(A_cm2) ./ sqrt(2 * cfg.e * Id + 4 * cfg.k * cfg.T / cfg.R_load) * ones(size(bw_range));
    loglog(bw_range / 1e9, Dstar_bw, '--', 'Color', cfg.colors.red, 'LineWidth', 2);
    ylabel('Detectivity D* (Jones)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');

    xlabel('Bandwidth (GHz)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('NEP and D* (Wartak Eq. 10.20â€“10.22)', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    grid on; styleAxes(cfg);

    saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
end

function plotBERvsPower(cfg, pdPhysics, bw, pulse, fileName)

    R = pdPhysics.responsivity;
    Id = cfg.Id;
    M = 4;
    P_dBm = cfg.P_sweep_dBm;
    P_W = 1e-3 * 10.^(P_dBm / 10);

    BER_analytical = zeros(size(P_W));
    Q_analytical = zeros(size(P_W));
    for ii = 1:numel(P_W)
        Pavg_i = P_W(ii);
        Pmin_i = 2 * Pavg_i / (cfg.extinction_ratio + 1);
        Pmax_i = 2 * Pavg_i * cfg.extinction_ratio / (cfg.extinction_ratio + 1);
        I1 = R * Pmax_i;
        I0 = R * Pmin_i;
        sig2_th = 4 * cfg.k * cfg.T * bw / cfg.R_load;
        sig1 = sqrt(2 * cfg.e * (I1 + Id) * bw + sig2_th);
        sig0 = sqrt(2 * cfg.e * (I0 + Id) * bw + sig2_th);
        Q_i = (I1 - I0) / ((M - 1) * (sig1 + sig0));
        Q_analytical(ii) = Q_i;
        BER_analytical(ii) = (3 / (2 * log2(M))) * 0.5 * erfc(Q_i / sqrt(2));
    end

    BER_mc = zeros(size(P_W));
    sps = cfg.samples_per_symbol;
    mcBits = cfg.ber_mc_bits;
    mcRuns = cfg.ber_mc_runs;
    fs_mc = cfg.symbol_rate * sps;

    for ii = 1:numel(P_W)
        Pavg_i = P_W(ii);
        Pmin_i = 2 * Pavg_i / (cfg.extinction_ratio + 1);
        Pmax_i = 2 * Pavg_i * cfg.extinction_ratio / (cfg.extinction_ratio + 1);
        totalErr = 0;
        totalBit = 0;

        for run = 1:mcRuns
            [txSym, txBit] = generateSymbols(mcBits);
            nSym = numel(txSym);
            nSamp = nSym * sps;
            optTx = modulatePAM(txSym, pulse, Pmin_i, Pmax_i, nSamp, sps);
            optRx = max(optTx + sqrt(cfg.channel_noise_variance) * randn(size(optTx)), 0);
            Iideal = smoothSaturation(R * optRx, R * cfg.Psat, cfg.saturation_model);

            dt = 1 / fs_mc;
            lam = (max(Iideal, 0) + Id) * dt / cfg.e;
            sn = (poissrnd(lam) - lam) * cfg.e / dt;
            tn = sqrt(4 * cfg.k * cfg.T * bw / cfg.R_load) * randn(size(Iideal));
            rx = lowpassTrace(Iideal + sn + tn, bw, fs_mc);
            [~, rxBit] = detectPAM(rx, pulse, nSym, sps);

            nB = min(numel(txBit), numel(rxBit));
            totalErr = totalErr + sum(txBit(1:nB) ~= rxBit(1:nB));
            totalBit = totalBit + nB;
        end
        BER_mc(ii) = max(totalErr / totalBit, 0.5 / totalBit);
    end

    fig = figure('Color', 'w', 'Position', [190, 190, 1600, 1000], 'Name', 'BER vs Received Power');

    subplot(1, 2, 1);
    semilogy(P_dBm, BER_analytical, '-', 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width, ...
        'DisplayName', 'Analytical (Wartak)'); hold on;
    semilogy(P_dBm, BER_mc, 'o', 'Color', cfg.colors.red, 'MarkerFaceColor', cfg.colors.red, ...
        'MarkerSize', 5, 'LineWidth', 1.5, 'DisplayName', 'Monte Carlo');
    yline(cfg.target_BER, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Target BER = %.0e', cfg.target_BER));
    yline(3.8e-3, ':', 'Color', cfg.colors.orange, 'LineWidth', 1.5, ...
        'DisplayName', 'KP4 FEC threshold');
    xlabel('Received Power (dBm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Bit Error Rate', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('BER vs Received Optical Power (Wartak Ch. 14)', ...
        'FontSize', cfg.title_size, 'FontWeight', 'bold');
    ylim([1e-12, 1]); grid on;
    legend('Location', 'northeast', 'FontSize', 10, 'Box', 'off');
    styleAxes(cfg);

    subplot(1, 2, 2);
    plot(P_dBm, Q_analytical, 'Color', cfg.colors.blue, 'LineWidth', cfg.line_width); hold on;
    yline(6, '--', 'Color', cfg.colors.gray, 'LineWidth', 1.5, 'DisplayName', 'Q = 6 (BER=1e-9)');
    yline(3.09, ':', 'Color', cfg.colors.orange, 'LineWidth', 1.5, 'DisplayName', 'Q = 3.09 (KP4 FEC)');
    xlabel('Received Power (dBm)', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    ylabel('Q-Factor', 'FontSize', cfg.label_size, 'FontWeight', 'bold');
    title('Q-Factor vs Received Power', 'FontSize', cfg.title_size, 'FontWeight', 'bold');
    grid on;
    legend('Location', 'southeast', 'FontSize', 10, 'Box', 'off');
    styleAxes(cfg);

    saveThesisFigure(fig, cfg.figure_dir, fileName, cfg.export_dpi);
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
