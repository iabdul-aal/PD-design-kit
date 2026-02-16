function metrics = calculate_metrics(tx_bits, rx_bits, tx_symbols, rx_symbols, photocurrent)

signal_power = var(photocurrent);
noise_power = var(photocurrent - mean(photocurrent));
SNR_linear = signal_power / noise_power;
SNR_dB = 10 * log10(SNR_linear);

min_bits = min(length(tx_bits), length(rx_bits));
bit_errors = sum(tx_bits(1:min_bits) ~= rx_bits(1:min_bits));
BER = bit_errors / min_bits;

min_symbols = min(length(tx_symbols), length(rx_symbols));
symbol_errors = sum(tx_symbols(1:min_symbols) ~= rx_symbols(1:min_symbols));
SER = symbol_errors / min_symbols;

metrics.signal_power = signal_power;
metrics.SNR_linear = SNR_linear;
metrics.SNR_dB = SNR_dB;
metrics.bit_errors = bit_errors;
metrics.symbol_errors = symbol_errors;
metrics.total_bits = min_bits;
metrics.total_symbols = min_symbols;
metrics.BER = BER;
metrics.SER = SER;

end
