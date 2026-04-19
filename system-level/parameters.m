function params = parameters()
% parameters.m  — System-level config for Ge-on-Si O-band PAM-4 receiver
% Calibrated from Device-Level simulation results.
% Ref: Yang Shi et al., Photonics Research 12, 1 (2024)

% --- Photodetector (calibrated from Device-Level CHARGE) ---
params.lambda_center    = 1310e-9;       % O-band centre wavelength [m]
params.lambda_min       = 1260e-9;       % O-band lower edge [m]
params.lambda_max       = 1360e-9;       % O-band upper edge [m]
params.eta_plateau      = 0.95;          % peak IQE (R = 0.95 A/W @ 1310 nm)
params.Id               = 1.3e-9;        % dark current @ -1 V [A]
params.Psat             = 10e-3;         % optical saturation power [W]
params.Cj               = 22.6e-15;      % junction capacitance [F]
params.Rs               = 12.9;          % series resistance [Ohm]
params.f3dB             = 103e9;         % 3 dB bandwidth [Hz]
params.Dstar            = 2.95e10;       % detectivity [cm Hz^0.5 W^-1]

% --- PAM-4 link (IEEE 802.3bs 400G-DR4) ---
params.symbol_rate          = 53.125e9;  % baud rate [Bd]
params.samples_per_symbol   = 8;
params.num_bits             = 100000;
params.PAM_levels           = 4;
params.P_avg_dBm            = -2;        % average received power [dBm]
params.extinction_ratio     = 10;        % OMA extinction ratio
params.R_load               = 50;        % load resistance [Ohm]

% --- Noise ---
params.T                    = 300;       % temperature [K]
params.channel_noise_variance = 1e-8;
params.enable_shot_noise    = true;
params.enable_thermal_noise = true;

% --- Sweep/plot ---
params.plot_num_symbols     = 100;
params.SNR_range_dB         = 0:3:30;

end
