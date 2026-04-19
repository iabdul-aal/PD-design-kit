function [shot_noise, thermal_noise] = noise_model(photocurrent, params, const)

fs = params.symbol_rate * params.samples_per_symbol;
BW_3dB = 0.75 * params.symbol_rate;

shot_noise = zeros(size(photocurrent));
if params.enable_shot_noise
    dt = 1 / fs;
    for i = 1:length(photocurrent)
        I_total = max(photocurrent(i), 0) + params.Id;
        lambda = (I_total * dt) / const.e;
        N = poissrnd(lambda);
        shot_noise(i) = (N - lambda) * const.e / dt;
    end
end

thermal_noise = zeros(size(photocurrent));
if params.enable_thermal_noise
    thermal_noise_variance = 4 * const.k * params.T * BW_3dB / params.R_load;
    thermal_noise = sqrt(thermal_noise_variance) * randn(size(photocurrent));
end

end
