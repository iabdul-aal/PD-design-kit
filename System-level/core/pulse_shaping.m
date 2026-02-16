function rrc_filter = pulse_shaping(samples_per_symbol)

beta = 0.35;
span = 6;
rrc_filter = rcosdesign(beta, span, samples_per_symbol, 'sqrt');

end
