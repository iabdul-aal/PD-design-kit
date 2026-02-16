function params = parameters()

params.T = 300;
params.Id = 5e-9;
params.Psat = 10e-3;
params.R_load = 50;
params.symbol_rate = 53.125e9;
params.samples_per_symbol = 8;
params.num_bits = 100000;
params.PAM_levels = 4;

params.lambda_center = 1311e-9;
params.lambda_min = 1304.5e-9;
params.lambda_max = 1317.5e-9;
params.lambda_cutoff = 1650e-9;
params.lambda_short = 400e-9;
params.delta_lambda_long = 25e-9;
params.delta_lambda_short = 80e-9;
params.eta_plateau = 0.88;

params.P_avg_dBm = -2;
params.extinction_ratio = 10;
params.channel_noise_variance = 1e-8;
params.enable_shot_noise = true;
params.enable_thermal_noise = true;

params.plot_num_symbols = 100;
params.SNR_range_dB = 0:3:30;

end
