function optical_power_noisy = channel_model(optical_power, channel_noise_variance)

channel_noise = sqrt(channel_noise_variance) * randn(size(optical_power));
optical_power_noisy = max(optical_power + channel_noise, 0);

end
