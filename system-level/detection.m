function [detected_symbols, detected_bits] = detection(received_signal, pulse_filter, num_symbols, samples_per_symbol)

matched_filtered = conv(received_signal, pulse_filter, 'same');

mid = round(samples_per_symbol/2);
sample_indices = mid + (0:num_symbols-1) * samples_per_symbol;
sample_indices = sample_indices(sample_indices <= length(matched_filtered));
received_samples = matched_filtered(sample_indices);

sorted_samples = sort(received_samples);
N = length(sorted_samples);
level_estimates = zeros(1, 4);
for i = 1:4
    idx_start = floor((i-1)*N/4) + 1;
    idx_end = floor(i*N/4);
    level_estimates(i) = mean(sorted_samples(idx_start:idx_end));
end

thresholds = [(level_estimates(1) + level_estimates(2))/2, ...
              (level_estimates(2) + level_estimates(3))/2, ...
              (level_estimates(3) + level_estimates(4))/2];

detected_symbols = zeros(length(received_samples), 1);
for i = 1:length(received_samples)
    r = received_samples(i);
    if r < thresholds(1)
        detected_symbols(i) = 0;
    elseif r < thresholds(2)
        detected_symbols(i) = 1;
    elseif r < thresholds(3)
        detected_symbols(i) = 2;
    else
        detected_symbols(i) = 3;
    end
end

detected_bits = zeros(length(detected_symbols)*2, 1);
for i = 1:length(detected_symbols)
    detected_bits(2*i-1) = floor(detected_symbols(i) / 2);
    detected_bits(2*i) = mod(detected_symbols(i), 2);
end

end
