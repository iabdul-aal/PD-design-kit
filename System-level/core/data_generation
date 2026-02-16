function [symbols, bits] = data_generation(num_bits)

M = 4;
k = log2(M);
symbols = randi([0 M-1], num_bits/k, 1);
bits = reshape(de2bi(symbols, k, 'left-msb').', [], 1);

end
