function [photocurrent, responsivity, Isat] = photodiode_model(optical_power, params, const)

responsivity = params.eta_plateau * const.e * params.lambda_center / (const.h * const.c);
Isat = responsivity * params.Psat;

photocurrent = responsivity * optical_power;
photocurrent(photocurrent > Isat) = Isat;

end
