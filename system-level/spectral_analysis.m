function [f_axis, psd] = spectral_analysis(signal, fs, num_samples)

NFFT = 2^nextpow2(num_samples);
f_axis = fs * (0:NFFT/2-1) / NFFT / 1e9;
psd = abs(fft(signal - mean(signal), NFFT)).^2 / NFFT;
psd = 10*log10(psd(1:NFFT/2)+eps);

end
