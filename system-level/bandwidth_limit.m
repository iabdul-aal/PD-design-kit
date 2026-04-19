function photocurrent_bw = bandwidth_limit(photocurrent, BW_3dB, fs)

[b_bw, a_bw] = butter(3, 2*BW_3dB/fs);
photocurrent_bw = filter(b_bw, a_bw, photocurrent);

end
