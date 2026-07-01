% Copyright (c) 2026 Islam Ibrahim. All rights reserved.

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));

charge_dir   = fullfile(repo_root, 'results', 'device');
fdtd_dir     = fullfile(repo_root, 'results', 'fdtd');
ic_dir       = fullfile(repo_root, 'results', 'interconnect');
bridge_dir   = fullfile(repo_root, 'matlab', 'cml-bridge');
foundry_dir  = fullfile(repo_root, 'lumerical', 'interconnect', 'ge_pd_foundry_model');
source_dir   = fullfile(foundry_dir, 'source', 'ge_pd_cml_oband_ushaped');
artifact_dir = fullfile(foundry_dir, 'artifacts', 'interconnect');

q      = 1.602176634e-19;
h_p    = 6.62607015e-34;
c0     = 2.99792458e8;
kB_J   = 1.380649e-23;
lam_c  = 1.31e-6;
R_load = 50;
V_ac   = 0.001;

Ge_W_nom   = 5e-6;
Ge_L_nom   = 8e-6;
iGe_H_nom  = 350e-9;
wg_H_nom   = 220e-9;
vsat_h_Ge  = 4e6;
vsat_e_Ge  = 6e6;
mu_e_Ge    = 3900;
P_opt_nom  = 100e-6;
Cp_nom_fF  = 10;
Lp_nom_nH  = 0.3;
Psat_nom_W = 10e-3;

E_photon = h_p * c0 / lam_c;
R_ideal  = q / E_photon;

chf.dark_iv        = fullfile(charge_dir, 'ge_pd_charge_dark_iv.mat');
chf.illuminated_iv = fullfile(charge_dir, 'ge_pd_charge_illuminated_iv.mat');
chf.ssac           = fullfile(charge_dir, 'ge_pd_charge_ssac.mat');
chf.transient      = fullfile(charge_dir, 'ge_pd_charge_transient.mat');

fdf.solver     = fullfile(fdtd_dir, 'ge_pd_fdtd_solver.mat');
fdf.T_ref      = fullfile(fdtd_dir, 'ge_pd_fdtd_T_ref.mat');
fdf.T_after_Ge = fullfile(fdtd_dir, 'ge_pd_fdtd_T_after_Ge.mat');
fdf.gen_rate   = fullfile(fdtd_dir, 'ge_pd_fdtd_gen_rate.mat');

ic_pam4_mat = fullfile(ic_dir, 'ge_pd_interconnect_pam4_eye.mat');

charge_mono = fullfile(charge_dir, 'ge_pd_charge_results_oband_ushaped.mat');
fdtd_mono   = fullfile(fdtd_dir, 'ge_pd_fdtd_results_oband_ushaped.mat');
ic_mono     = fullfile(ic_dir, 'ge_pd_interconnect_results_oband_ushaped.mat');

use_new_format = false;

if exist(chf.dark_iv, 'file') && exist(chf.illuminated_iv, 'file')
    use_new_format = true;
elseif exist(charge_mono, 'file')
    use_new_format = false;
else
    error('No CHARGE result files found.');
end

if use_new_format
    D_dk = load(chf.dark_iv);
    V_dk = try_fields(D_dk, {'V', 'V_bias', 'V_dk'});
    I_dk = try_fields(D_dk, {'I', 'I_total', 'I_dk'});

    D_ill = load(chf.illuminated_iv);
    V_ill = try_fields(D_ill, {'V', 'V_bias', 'V_ill'});
    I_ill = try_fields(D_ill, {'I', 'I_total', 'I_ill'});
    P_opt_val = try_fields(D_ill, {'P_opt', 'P_source', 'optical_power'}, P_opt_nom);
    P_opt = scalar_val(P_opt_val);

    Ge_W  = scalar_val(try_fields(D_ill, {'Ge_W', 'W_Ge'}, Ge_W_nom));
    iGe_H = scalar_val(try_fields(D_ill, {'iGe_H', 'H_Ge', 'W_i'}, iGe_H_nom));
    wg_H  = scalar_val(try_fields(D_ill, {'wg_H', 'H_Si'}, wg_H_nom));
    A_eff = scalar_val(try_fields(D_ill, {'A_eff', 'A_active'}, Ge_W * Ge_L_nom));
    T_op  = scalar_val(try_fields(D_ill, {'T_sim', 'T', 'temperature'}, 300));
    if T_op < 200; T_op = T_op + 273.15; end

    has_ssac = exist(chf.ssac, 'file') == 2;
    if has_ssac
        D_ssac = load(chf.ssac);
        f_ssac = try_fields(D_ssac, {'f', 'f_ssac', 'frequency'});
        V_ssac_arr = try_fields(D_ssac, {'V_bias', 'V_ssac_arr', 'V'}, []);

        ssac_fn = fieldnames(D_ssac);
        ssac_bias_I = ssac_fn(contains(ssac_fn, 'ssac_V') & contains(ssac_fn, '_I'));
        if ~isempty(ssac_bias_I)
            n_bias_ssac = numel(ssac_bias_I);
            I_ac_mag_raw = zeros(n_bias_ssac, numel(f_ssac));
            I_ac_phase_raw = zeros(n_bias_ssac, numel(f_ssac));
            for ib = 1:n_bias_ssac
                fn = ssac_bias_I{ib};
                I_ac_mag_raw(ib, :) = D_ssac.(fn)(:) .';
                fn_ph = strrep(fn, '_I', '_phase');
                if isfield(D_ssac, fn_ph)
                    I_ac_phase_raw(ib, :) = D_ssac.(fn_ph)(:) .';
                end
            end
        else
            I_ac_mag_raw   = try_fields(D_ssac, {'I_ac_mag', 'I_ac', 'I_ac_bias'}, []);
            I_ac_phase_raw = try_fields(D_ssac, {'I_ac_phase', 'phase', 'I_ac_phase_bias'}, []);
        end

        Z_ssac_re = try_fields(D_ssac, {'Z_ssac_re', 'Z_re', 'Z_ac_re'}, []);
        Z_ssac_im = try_fields(D_ssac, {'Z_ssac_im', 'Z_im', 'Z_ac_im'}, []);
    end

    has_transient = exist(chf.transient, 'file') == 2;
    if has_transient
        D_tr = load(chf.transient);
        t_tr_raw = try_fields(D_tr, {'t', 't_tr', 'time'});
        I_tr_raw = try_fields(D_tr, {'I', 'I_tr', 'I_total'});
    end
else
    C = load(charge_mono);
    V_dk  = C.V_dk(:);
    I_dk  = C.I_dk(:);
    V_ill = C.V_ill(:);
    I_ill = C.I_ill(:);
    P_opt = scalar_val(try_fields(C, {'P_opt'}, P_opt_nom));
    Ge_W  = scalar_val(try_fields(C, {'Ge_W'}, Ge_W_nom));
    iGe_H = scalar_val(try_fields(C, {'iGe_H'}, iGe_H_nom));
    wg_H  = scalar_val(try_fields(C, {'wg_H'}, wg_H_nom));
    A_eff = scalar_val(try_fields(C, {'A_eff'}, Ge_W * Ge_L_nom));
    T_op  = scalar_val(try_fields(C, {'T_sim', 'T'}, 300));
    if T_op < 200; T_op = T_op + 273.15; end

    has_ssac     = isfield(C, 'f_ssac');
    has_transient = isfield(C, 't_tr') || isfield(C, 'I_tr');

    if has_ssac
        f_ssac        = C.f_ssac(:);
        V_ssac_arr    = try_fields(C, {'V_ssac_arr', 'V_bias'}, []);
        I_ac_mag_raw  = try_fields(C, {'I_ac_mag', 'I_ac_bias'}, []);
        I_ac_phase_raw = try_fields(C, {'I_ac_phase', 'I_ac_phase_bias'}, []);
        Z_ssac_re     = try_fields(C, {'Z_ssac_re', 'Z_re'}, []);
        Z_ssac_im     = try_fields(C, {'Z_ssac_im', 'Z_im'}, []);
    end
    if has_transient
        t_tr_raw = C.t_tr(:);
        I_tr_raw = C.I_tr(:);
    end
end

if use_new_format && exist(fdf.T_ref, 'file')
    F_solver = load(fdf.solver);
    F_Tref   = load(fdf.T_ref);
    F_Tafter = load(fdf.T_after_Ge);

    f_fdtd       = try_fields(F_solver, {'f', 'f_fdtd', 'frequency'});
    T_ref_data   = try_fields(F_Tref, {'T', 'T_ref_data', 'transmission'});
    T_after_data = try_fields(F_Tafter, {'T', 'T_after_Ge_data', 'transmission'});

    use_real_G = false;
    if exist(fdf.gen_rate, 'file')
        GN = load(fdf.gen_rate);
        if isfield(GN, 'G')
            G_TE = GN.G(:, :, 1);
            y_gen = GN.y(:)' * 1e6;
            z_gen = GN.z(:)' * 1e6;
            use_real_G = true;
        end
    end
elseif exist(fdtd_mono, 'file')
    F = load(fdtd_mono);
    f_fdtd       = F.f_fdtd(:);
    T_ref_data   = F.T_ref_data(:);
    T_after_data = F.T_after_Ge_data(:);
else
    f_fdtd = c0 / lam_c;
    T_ref_data = 1;
    T_after_data = 0.15;
end

f_fdtd = f_fdtd(:);
lam_nm = c0 ./ f_fdtd * 1e9;

idx_lam_c = nearest_index(lam_nm, lam_c * 1e9);

T_ref   = T_ref_data(:);
T_after = T_after_data(:);
A_lam   = max((T_ref - T_after) ./ max(T_ref, eps), 0);
R_lam   = A_lam .* (q .* lam_nm * 1e-9) ./ (h_p * c0);
R_AW_fdtd = R_lam(idx_lam_c);
A_TE_avg  = A_lam(idx_lam_c);

I_photo = abs(I_ill - interp1(V_dk, I_dk, V_ill, 'linear', 'extrap'));
R_vs_V  = I_photo / max(P_opt, eps);

idx_v = nearest_index(V_ill, -1.0);
idx_d = nearest_index(V_dk, -1.0);

R_AW   = R_vs_V(idx_v);
Id_1V  = abs(interp1(V_dk, I_dk, -1.0, 'linear', 'extrap'));
Iph_1V = I_photo(idx_v);

R_ceiling = R_ideal * max(A_TE_avg, eps);
IQE_pct   = min(R_AW / max(R_ceiling, eps), 1.0) * 100;

C_j_est = NaN;
Rs_est  = NaN;
f_3dB_total = NaN;

if has_ssac
    f_ac = f_ssac(:).';
    if ~isempty(V_ssac_arr) && ~isempty(I_ac_mag_raw)
        if ~isempty(size(I_ac_mag_raw)) && size(I_ac_mag_raw, 1) == numel(V_ssac_arr)
            [~, i_ssac] = min(abs(V_ssac_arr(:) + 1));
            ac_mag = squeeze(I_ac_mag_raw(i_ssac, :)).';
            if ~isempty(I_ac_phase_raw) && any(size(I_ac_phase_raw) == numel(V_ssac_arr))
                ac_phase = squeeze(I_ac_phase_raw(i_ssac, :)).' * 180/pi;
            else
                ac_phase = zeros(size(ac_mag));
            end
        else
            ac_mag = I_ac_mag_raw(:).';
            ac_phase = zeros(size(ac_mag));
            if ~isempty(I_ac_phase_raw)
                ac_phase = I_ac_phase_raw(:).';
            end
        end
    else
        ac_mag = I_ac_mag_raw(:).';
        ac_phase = zeros(size(ac_mag));
        if ~isempty(I_ac_phase_raw)
            ac_phase = I_ac_phase_raw(:).';
        end
    end

    Im_Iac = abs(ac_mag) .* abs(sind(ac_phase));
    C_j_f  = Im_Iac ./ (2 * pi * f_ac * V_ac + eps);
    if any(f_ac > 1e9)
        C_j_est = median(C_j_f(f_ac > 1e9));
    else
        C_j_est = median(C_j_f);
    end

    if ~isempty(Z_ssac_re) && ~isempty(Z_ssac_im)
        omega_low = 2*pi*f_ssac(1);
        Z_low = complex(Z_ssac_re(:,1), Z_ssac_im(:,1));
        C_j_bias = imag(1./Z_low) ./ omega_low;
        f_RC_bias = 1 ./ (2*pi*R_load .* C_j_bias);
        Rs_est = mean(Z_ssac_re(:,1));
    end
end

if has_transient
    t_tr = t_tr_raw(:);
    I_tr = I_tr_raw(:);

    dt_tr = mean(diff(t_tr));
    h_imp = diff(I_tr) ./ diff(t_tr);
    t_imp = t_tr(1:end-1) + dt_tr/2;
    h_imp = h_imp - min(h_imp);
    h_imp = h_imp / max(h_imp + eps);

    N_fft = max(2^nextpow2(length(h_imp)), 4096);
    H_f = fft(h_imp, N_fft);
    f_fft = (0:N_fft-1) / (N_fft * dt_tr);
    H_mag = abs(H_f(1:N_fft/2));
    H_mag = H_mag / max(H_mag + eps);
    H_tr_dB = 20*log10(H_mag + eps);
    H_tr_dB = H_tr_dB - max(H_tr_dB);
    f_tr_Hz = f_fft(1:N_fft/2);

    idx_3dB = find(H_tr_dB <= -3, 1, 'first');
    if ~isempty(idx_3dB) && idx_3dB > 1
        f_3dB_total = interp1(H_tr_dB(idx_3dB-1:idx_3dB), f_tr_Hz(idx_3dB-1:idx_3dB)*1e-9, -3);
    elseif ~isempty(idx_3dB)
        f_3dB_total = f_tr_Hz(idx_3dB) * 1e-9;
    else
        f_3dB_total = max(f_tr_Hz) * 1e-9;
    end
elseif has_ssac && ~isnan(C_j_est)
    f_RC_GHz = 1 / (2 * pi * max(C_j_est, 1e-18) * R_load) * 1e-9;
    f_transit_GHz = 0.44 * vsat_h_Ge / iGe_H_nom * 1e-9;
    f_3dB_total = 1 / sqrt(1/f_RC_GHz^2 + 1/f_transit_GHz^2);
end

if ~isnan(C_j_est) && isnan(Rs_est)
    Rs_est = 50;
end
if isnan(C_j_est)
    C_j_est = 20e-15;
end
if isnan(Rs_est)
    Rs_est = 50;
end
if isnan(f_3dB_total)
    f_3dB_total = 40;
end

Cp_F  = Cp_nom_fF * 1e-15;
Lp_H  = Lp_nom_nH * 1e-9;
Psat_W = Psat_nom_W;

bridge = struct();
bridge.geometry.lambda_c_m = lam_c;
bridge.optical.responsivity_nominal_AW = R_AW;
bridge.electrical.Id_at_1V_nA = Id_1V * 1e9;
bridge.electrical.V_sweep_V = V_dk(:);
bridge.electrical.I_dark_A = abs(I_dk(:));
bridge.bandwidth.f3dB_GHz = f_3dB_total;
bridge.bandwidth.Rs_ohm = Rs_est;
bridge.bandwidth.Cj_fF = C_j_est * 1e15;
bridge.bandwidth.Cp_fF = Cp_nom_fF;
bridge.saturation.Psat_W = Psat_W;

if numel(lam_nm) > 2
    bridge.sweeps.wavelength.lambda_m = c0 ./ f_fdtd * 1e-9;
    bridge.sweeps.wavelength.responsivity_AW = R_lam;
else
    bridge.sweeps.wavelength.lambda_m = [1.26e-6; lam_c; 1.36e-6];
    bridge.sweeps.wavelength.responsivity_AW = [R_AW * 0.95; R_AW; R_AW * 0.92];
end

f_zt = logspace(8, 11.4, 1600);
w_zt = 2 * pi * f_zt;
ctot = C_j_est + Cp_F;
zcap = 1 ./ (1i * w_zt * ctot);
zload = 1 ./ (1 / R_load + 1 ./ zcap);
divider = abs(zload ./ (Rs_est + 1i * w_zt * Lp_H + zload));
zt_VW = R_AW * abs(zload) .* divider ./ sqrt(1 + (f_zt / (f_3dB_total * 1e9)).^2);
norm_dB_zt = 20 * log10(zt_VW / max(zt_VW + eps));

model = struct();
model.f_Hz    = f_zt(:);
model.f_GHz   = f_zt(:) / 1e9;
model.zt_VW   = zt_VW(:);
model.norm_dB = norm_dB_zt(:);
model.f_rc    = 1 / (2 * pi * (Rs_est + R_load) * ctot);
model.f_pkg   = 1 / (2 * pi * sqrt(Lp_H * ctot));
model.resp_AW = R_AW ./ sqrt(1 + (f_zt(:) / (f_3dB_total * 1e9)).^2);

bias_pts = [-1.0; -1.5];
bw_data = struct('voltage', bias_pts, 'bandwidth', [f_3dB_total, f_3dB_total]);
Idark_data = struct('voltage', bias_pts, 'current', [Id_1V, Id_1V]);

lambda_min_OB = 1260e-9;
lambda_max_OB = 1360e-9;
f_cml = [c0/lambda_max_OB; c0/lambda_min_OB];
R_cml = [R_AW; R_AW];
resp_data = struct('frequency', f_cml(:), 'responsivity', R_cml(:));

elec_eq = struct('Rj', Rs_est, 'Cj_data', C_j_est, 'Rp', R_load, 'Cp', Cp_F);

cfg = struct();
cfg.Cj = C_j_est;
cfg.Cp = Cp_F;
cfg.R_load = R_load;
cfg.Rs = Rs_est;
cfg.Lp = Lp_H;
cfg.f3dB = f_3dB_total * 1e9;
cfg.Id = Id_1V;
cfg.Psat = Psat_W;
cfg.enable_shot_noise = 1;

notes = { ...
    struct('property', 'source',        'value', 'Ge-on-Si O-band U-shaped VPD - INTERCONNECT compact model.'), ...
    struct('property', 'design_target', 'value', '400G DR4 IEEE 802.3, PAM-4, 4x100G lanes.'), ...
    struct('property', 'bias_note',     'value', 'Bias-dependent entries duplicated from -1 V operating point.')};

general = struct('description', 'Ge-on-Si O-band U-shaped PD compact model for Lumerical INTERCONNECT.', ...
    'prefix', 'PD', 'notes', {notes});

ports = struct( ...
    'input',  struct('name','input',  'dir','Bidirectional','pos','Left',  'type','Optical Signal',     'order',1), ...
    'output', struct('name','output', 'dir','Bidirectional','pos','Right', 'type','Electrical Signal', 'order',2));

compound_elements = { ...
    struct('element','PIN Photodetector','name','pin'), ...
    struct('element','LP Bessel Filter', 'name','lpf')};

compound_connection = { ...
    struct('e1_name','PD',  'e1_port','input',  'e2_name','pin', 'e2_port','input'), ...
    struct('e1_name','pin', 'e1_port','output', 'e2_name','lpf', 'e2_port','input'), ...
    struct('e1_name','lpf', 'e1_port','output', 'e2_name','PD',  'e2_port','output')};

compound_data = struct( ...
    'center_frequency_Hz', mean(f_cml), ...
    'responsivity_AW',     R_AW, ...
    'dark_current_A',      Id_1V, ...
    'bandwidth_Hz',        f_3dB_total * 1e9, ...
    'saturation_power_W',  Psat_W, ...
    'filter_order',        4);

model_data = struct( ...
    'photonic_model',         'compound_element', ...
    'get_compound',           'script', ...
    'debug_mode',             0, ...
    'elements',               {compound_elements}, ...
    'connection',             {compound_connection}, ...
    'data',                   compound_data, ...
    'setup_script_file',      'ge_pd_cml_oband_ushaped_setup_script.lsf', ...
    'bandwidth_data',         bw_data, ...
    'Idark_data',             Idark_data, ...
    'resp_data',              resp_data, ...
    'enable_shot_noise',      cfg.enable_shot_noise, ...
    'DC_operation_only',      false, ...
    'enable_power_saturation',true, ...
    'saturation_power_data',  Psat_W, ...
    'elec_eq_ckt_data',       elec_eq);

bridge_json_path = fullfile(bridge_dir, 'ge_pd_cml_oband_ushaped.json');
bridge_mat_path  = fullfile(bridge_dir, 'ge_pd_cml_oband_ushaped.mat');
source_json_path = fullfile(source_dir, 'ge_pd_cml_oband_ushaped.json');
source_mat_path  = fullfile(source_dir, 'ge_pd_cml_oband_ushaped.mat');
setup_script_path  = fullfile(source_dir, 'ge_pd_cml_oband_ushaped.lsf');
setup_script_path2 = fullfile(source_dir, 'ge_pd_cml_oband_ushaped_setup_script.lsf');
ic_script_path     = fullfile(repo_root, 'lumerical', 'interconnect', 'ge_pd_interconnect_setup.lsf');

bridge_text = jsonencode(bridge, 'PrettyPrint', true);
write_if_changed(bridge_json_path, bridge_text);

save(bridge_mat_path, 'bridge', 'cfg', 'model', 'model_data', 'general', 'ports');

if exist(source_json_path, 'file')
    source = jsondecode(fileread(source_json_path));

    source.model_data.data.center_frequency_Hz = c0 / bridge.geometry.lambda_c_m;
    source.model_data.data.responsivity_AW     = bridge.optical.responsivity_nominal_AW;
    source.model_data.data.dark_current_A      = bridge.electrical.Id_at_1V_nA * 1e-9;
    source.model_data.data.bandwidth_Hz        = bridge.bandwidth.f3dB_GHz * 1e9;
    source.model_data.data.saturation_power_W  = bridge.saturation.Psat_W;

    if ~isfield(source.model_data.data, 'filter_order')
        source.model_data.data.filter_order = 4;
    end
    if ~isfield(source.model_data.data, 'slope_resp_height')
        source.model_data.data.slope_resp_height = 0.006;
    end
    if ~isfield(source.model_data.data, 'slope_resp_width')
        source.model_data.data.slope_resp_width = 0.007;
    end
    if ~isfield(source.model_data.data, 'slope_bw')
        source.model_data.data.slope_bw = 2e9;
    end

    v_sweep = bridge.electrical.V_sweep_V(:);
    i_dark  = bridge.electrical.I_dark_A(:);
    source.model_data.Idark_data.voltage.x_complex = false;
    source.model_data.Idark_data.voltage.x_data    = v_sweep;
    source.model_data.Idark_data.voltage.x_size    = [numel(v_sweep), 1];
    source.model_data.Idark_data.voltage.x_type    = 'matrix';
    source.model_data.Idark_data.current.x_complex = false;
    source.model_data.Idark_data.current.x_data    = i_dark;
    source.model_data.Idark_data.current.x_size    = [numel(i_dark), 1];
    source.model_data.Idark_data.current.x_type    = 'matrix';

    sweeps = [];
    if isfield(bridge, 'sweeps') && isfield(bridge.sweeps, 'wavelength')
        sweeps = bridge.sweeps.wavelength;
    end
    if ~isempty(sweeps) && isfield(sweeps, 'lambda_m') && isfield(sweeps, 'responsivity_AW')
        lam_s = sweeps.lambda_m(:);
        resp_s = sweeps.responsivity_AW(:);
        freq_s = c0 ./ lam_s;
        [freq_s, idx_s] = sort(freq_s);
        resp_s = resp_s(idx_s);
    else
        fallback = source.model_data.data.responsivity_AW;
        freq_s = [c0/1360e-9; c0/1260e-9];
        resp_s = [fallback; fallback];
    end
    source.model_data.resp_data.frequency.x_data    = freq_s;
    source.model_data.resp_data.frequency.x_complex  = false;
    source.model_data.resp_data.frequency.x_size     = [numel(freq_s), 1];
    source.model_data.resp_data.frequency.x_type     = 'matrix';
    source.model_data.resp_data.responsivity.x_data    = resp_s;
    source.model_data.resp_data.responsivity.x_complex = false;
    source.model_data.resp_data.responsivity.x_size    = [numel(resp_s), 1];
    source.model_data.resp_data.responsivity.x_type    = 'matrix';

    bw_voltage = [-1.0; -1.5];
    bw_val = source.model_data.data.bandwidth_Hz;
    source.model_data.bandwidth_data.voltage.x_data    = bw_voltage;
    source.model_data.bandwidth_data.voltage.x_complex = false;
    source.model_data.bandwidth_data.voltage.x_size    = [2, 1];
    source.model_data.bandwidth_data.voltage.x_type    = 'matrix';
    source.model_data.bandwidth_data.bandwidth.x_data    = [bw_val; bw_val];
    source.model_data.bandwidth_data.bandwidth.x_complex = false;
    source.model_data.bandwidth_data.bandwidth.x_size    = [2, 1];
    source.model_data.bandwidth_data.bandwidth.x_type    = 'matrix';

    source.model_data.saturation_power_data   = source.model_data.data.saturation_power_W;
    source.model_data.enable_power_saturation = 1.0;
    source.model_data.enable_shot_noise       = 1.0;
    source.model_data.DC_operation_only       = 0.0;

    source.model_data.elec_eq_ckt_data.Rj = bridge.bandwidth.Rs_ohm;
    source.model_data.elec_eq_ckt_data.Rp = 50.0;
    source.model_data.elec_eq_ckt_data.Cp = bridge.bandwidth.Cp_fF * 1e-15;
    source.model_data.elec_eq_ckt_data.Cj_data.voltage.x_data    = bw_voltage;
    source.model_data.elec_eq_ckt_data.Cj_data.voltage.x_complex = false;
    source.model_data.elec_eq_ckt_data.Cj_data.voltage.x_size    = [2, 1];
    source.model_data.elec_eq_ckt_data.Cj_data.voltage.x_type    = 'matrix';
    cj_val = bridge.bandwidth.Cj_fF * 1e-15;
    source.model_data.elec_eq_ckt_data.Cj_data.cap.x_data    = [cj_val; cj_val];
    source.model_data.elec_eq_ckt_data.Cj_data.cap.x_complex = false;
    source.model_data.elec_eq_ckt_data.Cj_data.cap.x_size    = [2, 1];
    source.model_data.elec_eq_ckt_data.Cj_data.cap.x_type    = 'matrix';

    bridge_note = struct('property', 'bridge_source', ...
        'value', 'Synchronized from matlab/cml-bridge/ge_pd_cml_oband_ushaped.json');
    if isfield(source, 'general') && isfield(source.general, 'notes')
        notes_src = source.general.notes;
        keep = true(size(notes_src));
        for kn = 1:numel(notes_src)
            if isfield(notes_src(kn), 'property') && strcmp(notes_src(kn).property, 'bridge_source')
                keep(kn) = false;
            end
        end
        notes_src = notes_src(keep);
        source.general.notes = [notes_src; bridge_note];
    else
        if ~isfield(source, 'general'); source.general = struct(); end
        source.general.notes = bridge_note;
    end

    if ~isfield(source, 'statistical'); source.statistical = struct(); end
    if ~isfield(source.statistical, 'QA'); source.statistical.QA = struct(); end
    if ~isfield(source.statistical.QA, 'absolute_tolerances')
        source.statistical.QA.absolute_tolerances = struct();
    end
    source.statistical.QA.absolute_tolerances.BW    = max(bw_val * 0.03, 1e9);
    source.statistical.QA.absolute_tolerances.Idark = max(source.model_data.data.dark_current_A * 0.1, 1e-10);
    source.statistical.QA.absolute_tolerances.Resp  = max(source.model_data.data.responsivity_AW * 0.02, 0.005);

    new_source_text = jsonencode(source, 'PrettyPrint', true);
    write_if_changed(source_json_path, new_source_text);

    if exist(bridge_mat_path, 'file')
        copy_mat_if_changed(bridge_mat_path, source_mat_path);
    end
end

errors = {};

if ~exist(bridge_json_path, 'file')
    errors{end+1} = 'bridge JSON not found after write';
end
if ~exist(bridge_mat_path, 'file')
    errors{end+1} = 'bridge MAT not found after save';
end

if exist(source_json_path, 'file') && exist(bridge_json_path, 'file')
    src_check = jsondecode(fileread(source_json_path));
    brg_check = jsondecode(fileread(bridge_json_path));

    expected_cf = c0 / brg_check.geometry.lambda_c_m;
    expected_R  = brg_check.optical.responsivity_nominal_AW;
    expected_Id = brg_check.electrical.Id_at_1V_nA * 1e-9;
    expected_bw = brg_check.bandwidth.f3dB_GHz * 1e9;
    expected_Ps = brg_check.saturation.Psat_W;

    data_check = src_check.model_data.data;
    checks = { ...
        'center_frequency_Hz', expected_cf; ...
        'responsivity_AW',     expected_R; ...
        'dark_current_A',      expected_Id; ...
        'bandwidth_Hz',        expected_bw; ...
        'saturation_power_W',  expected_Ps};
    for kc = 1:size(checks, 1)
        key = checks{kc, 1};
        exp_val = checks{kc, 2};
        if isfield(data_check, key)
            act_val = data_check.(key);
            if ~is_close(act_val, exp_val, 5e-10)
                errors{end+1} = sprintf('source model_data.data.%s mismatch', key);
            end
        end
    end

    if exist(source_mat_path, 'file')
        if ~strcmp(file_hash_skip(bridge_mat_path, 128), file_hash_skip(source_mat_path, 128))
            errors{end+1} = 'source MAT differs from bridge MAT; re-run sync';
        end
    end

    idark_v_src = numel(src_check.model_data.Idark_data.voltage.x_data);
    idark_i_src = numel(src_check.model_data.Idark_data.current.x_data);
    n_vsweep_brg = numel(brg_check.electrical.V_sweep_V);
    n_idark_brg  = numel(brg_check.electrical.I_dark_A);
    if idark_v_src ~= n_vsweep_brg
        errors{end+1} = 'source Idark_data voltage table length mismatch';
    end
    if idark_i_src ~= n_idark_brg
        errors{end+1} = 'source Idark_data current table length mismatch';
    end

    resp_f_src = numel(src_check.model_data.resp_data.frequency.x_data);
    resp_r_src = numel(src_check.model_data.resp_data.responsivity.x_data);
    if resp_f_src < 2
        errors{end+1} = 'source resp_data has fewer than two frequency samples';
    end
    if resp_r_src < 2
        errors{end+1} = 'source resp_data has fewer than two responsivity samples';
    end
end

if exist(setup_script_path2, 'file')
    setup_text = fileread(setup_script_path2);
    required_params = {'center_frequency_Hz','responsivity_AW','dark_current_A', ...
                       'bandwidth_Hz','saturation_power_W'};
    for kp = 1:numel(required_params)
        if ~contains(setup_text, required_params{kp})
            errors{end+1} = sprintf('setup script missing %s', required_params{kp});
        end
    end
end

if exist(source_dir, 'dir')
    src_script = fullfile(source_dir, 'ge_pd_cml_oband_ushaped.lsf');
    if exist(src_script, 'file')
        source_text = fileread(src_script);
        stale_refs = {'PD_core','Rs_1','Cj_1','Cp_1','Lp_1','LPF_1'};
        for ks = 1:numel(stale_refs)
            if contains(source_text, stale_refs{ks})
                errors{end+1} = sprintf('stale source script references %s', stale_refs{ks});
            end
        end
    end
end

if exist(ic_script_path, 'file')
    ic_text = fileread(ic_script_path);
    if contains(ic_text, 'addelement("LP Bessel Filter")')
        errors{end+1} = 'INTERCONNECT setup adds external LP Bessel Filter after CML element';
    end
    if ~contains(ic_text, 'connect("PIN_1",  "output",  "EYE_1",    "input")')
        errors{end+1} = 'INTERCONNECT setup does not connect CML output directly to EYE_1';
    end
end

if exist(artifact_dir, 'dir')
    arts = dir(fullfile(artifact_dir, '**', '*'));
    arts = arts(~[arts.isdir]);
    if ~isempty(arts)
        src_files_check = {source_json_path, source_mat_path};
        if exist(setup_script_path2, 'file')
            src_files_check{end+1} = setup_script_path2;
        end
        foundry_json = fullfile(foundry_dir, 'ge_pd_foundry.json');
        if exist(foundry_json, 'file')
            src_files_check{end+1} = foundry_json;
        end
        latest_src = 0;
        for kf = 1:numel(src_files_check)
            if isfile(src_files_check{kf})
                info_f = dir(src_files_check{kf});
                latest_src = max(latest_src, info_f.datenum);
            end
        end
        latest_art = max([arts.datenum]);
        if latest_art < latest_src
            errors{end+1} = 'compiled CML artifacts older than source files';
        end

        html_path = fullfile(artifact_dir, 'ge_pd_foundry', ...
                             'ge_pd_ge_pd_cml_oband_ushaped.html');
        if isfile(html_path)
            html_text = fileread(html_path);
            if ~contains(html_text, 'bridge_source')
                errors{end+1} = 'compiled CML HTML missing bridge_source note';
            end
        end
    end
end

if ~isempty(errors)
    error('post_cml_bridge: validation failed with %d issue(s): %s', ...
        numel(errors), strjoin(errors, '; '));
end

% ── CML-required tabular exports for INTERCONNECT ─────────────────────────────
model_out_path = fullfile(ic_dir, 'ge_pd_interconnect_model_data.mat');
save(model_out_path, 'general', 'ports', 'model_data', 'model', 'cfg', 'bridge');

writematrix([model.f_Hz, model.resp_AW], fullfile(ic_dir, 'ge_pd_interconnect_resp.csv'));
writematrix([bias_pts, [f_3dB_total, f_3dB_total]], fullfile(ic_dir, 'ge_pd_interconnect_bandwidth.csv'));
writematrix([bias_pts, [Id_1V, Id_1V]], fullfile(ic_dir, 'ge_pd_interconnect_dark_current.csv'));

param_tbl = table( ...
    {'responsivity_A_W'; 'dark_current_A'; 'bandwidth_Hz'; 'Rs_Ohm'; 'Cj_F'; 'Cp_F'; 'Rload_Ohm'; 'Lp_H'; 'Psat_W'}, ...
    {R_AW; Id_1V; f_3dB_total*1e9; Rs_est; C_j_est; Cp_F; R_load; Lp_H; Psat_W}, ...
    'VariableNames', {'parameter', 'value'});
writetable(param_tbl, fullfile(ic_dir, 'ge_pd_interconnect_parameters.csv'));


function val = try_fields(S, names, default)
    val = default;
    if nargin < 3; default = []; end
    for k = 1:numel(names)
        if isfield(S, names{k})
            val = S.(names{k});
            return;
        end
    end
end

function v = scalar_val(x)
    if numel(x) == 1
        v = x;
    else
        v = x(1);
    end
end

function idx = nearest_index(vec, target)
    [~, idx] = min(abs(vec - target));
end

function ok = is_close(a, b, rel)
    if b == 0
        ok = abs(a - b) < 1e-18;
    else
        ok = abs(a - b) / abs(b) <= rel;
    end
end

function write_if_changed(path, new_text)
    if isfile(path)
        old_text = fileread(path);
        if strcmp(old_text, new_text)
            return;
        end
    end
    fid = fopen(path, 'w', 'n', 'UTF-8');
    fwrite(fid, new_text, 'char');
    fclose(fid);
end

function copy_mat_if_changed(src, dst)
    if isfile(dst)
        src_hash = file_hash_skip(src, 128);
        dst_hash = file_hash_skip(dst, 128);
        if strcmp(src_hash, dst_hash)
            return;
        end
    end
    copyfile(src, dst);
end

function h = file_hash_skip(path, skip)
    fid  = fopen(path, 'rb');
    fread(fid, skip, 'uint8');
    data = fread(fid, Inf, 'uint8');
    fclose(fid);
    import java.security.MessageDigest;
    import java.math.BigInteger;
    md  = MessageDigest.getInstance('SHA-256');
    raw = md.digest(int8(data));
    bi  = BigInteger(1, raw);
    h = lower(char(bi.toString(16)));
    if numel(h) < 64
        h = [repmat('0', 1, 64-numel(h)), h];
    end
end

