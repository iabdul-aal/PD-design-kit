function optical_power = modulation(symbols, pulse_filter, P_min, P_max, num_samples, samples_per_symbol)

modulated_symbols = pammod(symbols, 4, 0, 'gray');
tx_signal = upfirdn(modulated_symbols, pulse_filter, samples_per_symbol, 1);
tx_signal = tx_signal(1:num_samples);
tx_normalized = (real(tx_signal) - min(real(tx_signal))) / (max(real(tx_signal)) - min(real(tx_signal)));
optical_power = P_min + tx_normalized * (P_max - P_min);

end
