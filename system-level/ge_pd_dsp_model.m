clearvars; close all; clc;
figureDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
cml_mat   = fullfile(fileparts(mfilename('fullpath')), 'ge_pd_cml_oband_ushaped.mat');

assert(exist(cml_mat, 'file') == 2, ...
    'CML data file not found: %s\nRun ge_pd_oband_ushaped_postprocess.m first.', cml_mat);
cml_data = load(cml_mat);

cfg = get_config(figureDir, cml_data);

pd = compute_pd_physics(cfg);
compact = ge_pd_interconnect_model(get_interconnect_cfg(cfg), pd.responsivity);

[txSymbols, txBits] = gen_symbols(cfg.num_bits);
nSym = numel(txSymbols);
fs   = cfg.symbol_rate * cfg.sps;
bw   = min(pd.f3dB_total, 0.75 * cfg.symbol_rate);

Pavg_W  = 1e-3 * 10^(cfg.P_avg_dBm / 10);
Pmin_W  = 2 * Pavg_W / (cfg.ER + 1);
Pmax_W  = 2 * Pavg_W * cfg.ER / (cfg.ER + 1);
Isat    = pd.responsivity * cfg.Psat;
pulse   = rcosdesign(0.35, 6, cfg.sps, 'sqrt');

optTx   = modulate_pam(txSymbols, pulse, Pmin_W, Pmax_W, nSym*cfg.sps, cfg.sps);
optRx   = max(optTx + sqrt(cfg.ch_noise_var)*randn(size(optTx)), 0);
Iph_id  = sat_model(pd.responsivity * optRx, Isat, 'smooth');
[sn, tn, nc] = noise_terms(Iph_id, cfg, pd, fs, bw);
[b_lp, a_lp] = butter(3, min(0.99, 2*bw/fs));
Iref = filter(b_lp, a_lp, Iph_id);
Irx  = filter(b_lp, a_lp, Iph_id + sn + tn);
[rxSym, rxBits] = detect_pam(Irx, pulse, nSym, cfg.sps);
metrics = calc_metrics(txBits, rxBits, txSymbols, rxSym, Iref, Irx);
analytical = analytical_perf(cfg, pd, Pavg_W, Pmin_W, Pmax_W, bw);

fprintf('\n=== PAM-4 DSP Transfer Model Results ===\n');
fprintf('  Symbol rate         : %.3f GBd\n',  cfg.symbol_rate/1e9);
fprintf('  Responsivity        : %.4f A/W\n',  pd.responsivity);
fprintf('  P_avg               : %.1f dBm\n',  cfg.P_avg_dBm);
fprintf('  SNR (simulated)     : %.2f dB\n',   metrics.SNR_dB);
fprintf('  SNR (analytical)    : %.2f dB\n',   analytical.SNR_dB);
fprintf('  Q-factor            : %.2f\n',       analytical.Q);
fprintf('  BER (simulated)     : %.2e (%d/%d errors)\n', metrics.BER, metrics.bit_errors, metrics.total_bits);
fprintf('  BER (analytical)    : %.2e\n',       analytical.BER);
fprintf('  SER                 : %.2e\n',        metrics.SER);
fprintf('  INTERCONNECT f_RC   : %.1f GHz\n',  compact.f_rc/1e9);
fprintf('  INTERCONNECT f_pkg  : %.1f GHz\n',  compact.f_pkg/1e9);
fprintf('  Sensitivity @1e-9   : %.2f dBm\n',  analytical.sensitivity_dBm);

fprintf('\n=== Wartak Photodetector Physics ===\n');
fprintf('  Quantum efficiency    : %.4f\n',          pd.eta_physical);
fprintf('  Absorption coeff.     : %.0f cm^-1\n',    cfg.alpha_abs*1e-2);
fprintf('  Ge absorber length    : %.1f um\n',        cfg.L_absorber*1e6);
fprintf('  Depletion width       : %.0f nm\n',        cfg.d_depletion*1e9);
fprintf('  Transit-time BW f_tr  : %.1f GHz\n',      pd.f_transit/1e9);
fprintf('  RC bandwidth f_RC     : %.1f GHz\n',       pd.f_RC/1e9);
fprintf('  Combined BW f_3dB     : %.1f GHz\n',      pd.f3dB_total/1e9);
fprintf('  Dark current          : %.3e A\n',          pd.Id_physical);
fprintf('  NEP                   : %.3e W/sqrtHz\n',  analytical.NEP);
fprintf('  Detectivity D*        : %.3e Jones\n',     analytical.Dstar);

plot_responsivity(cfg, pd, figureDir, 'system_responsivity_curve');
plot_transfer(cfg, pd.responsivity, Isat, Pmin_W, Pmax_W, figureDir, 'system_transfer_function');
plot_eye(cfg, Irx, 'Photocurrent', metrics.SNR_dB, figureDir, 'system_photocurrent_eye');
plot_pam_histogram(cfg, Irx, pulse, nSym, metrics.SNR_dB, figureDir, 'system_pam4_histogram');
plot_quantum_efficiency(cfg, pd, figureDir, 'system_quantum_efficiency');
plot_bandwidth_budget(cfg, pd, figureDir, 'system_bandwidth_budget');
plot_noise_analysis(cfg, nc, pd, analytical, figureDir, 'system_noise_analysis');
plot_ber_vs_power(cfg, pd, bw, pulse, figureDir, 'system_ber_vs_power');

function cfg = get_config(figureDir, cml)
cfg = struct( ...
    'lambda_center',    cml.geometry.lambda_c_m, ...
    'lambda_min',       1260e-9, ...
    'lambda_max',       1360e-9, ...
    'eta_plateau',      cml.optical.responsivity_nominal_AW * 6.626e-34 * 3e8 / (1.602e-19 * cml.geometry.lambda_c_m), ...
    'Id',               cml.electrical.Id_at_1V_nA * 1e-9, ...
    'Psat',             cml.saturation.Psat_W, ...
    'f3dB',             cml.bandwidth.f3dB_GHz * 1e9, ...
    'Rs',               cml.bandwidth.Rs_ohm, ...
    'Cj',               cml.bandwidth.Cj_fF * 1e-15, ...
    'Lp',               cml.bandwidth.Lp_pH * 1e-12, ...
    'Cp',               cml.bandwidth.Cp_fF * 1e-15, ...
    'alpha_abs',        7e5, ...
    'Eg_direct',        0.80, ...
    'd_depletion',      cml.geometry.iGe_H_m, ...
    'L_absorber',       cml.geometry.Ge_L_m, ...
    'Gamma_conf',       0.70, ...
    'Rf_surface',       0.05, ...
    'v_sat_e',          cml.bandwidth.v_sat_ms / 2 * (1 + 6.0/4.7), ...
    'v_sat_h',          cml.bandwidth.v_sat_ms / 2 * (1 + 4.7/6.0), ...
    'A_detector',       cml.geometry.Ge_L_m * cml.geometry.Ge_W_m, ...
    'Is',               1e-12, ...
    'n_ideality',       1.2, ...
    'Vbias',            -1.0, ...
    'sat_model',        'smooth', ...
    'symbol_rate',      53.125e9, ...
    'sps',              8, ...
    'num_bits',         100000, ...
    'P_avg_dBm',        -2, ...
    'ER',               10, ...
    'R_load',           50, ...
    'T',                cml.temperature.T_sim_K, ...
    'ch_noise_var',     1e-8, ...
    'enable_shot',      true, ...
    'enable_thermal',   true, ...
    'target_BER',       1e-9, ...
    'P_sweep_dBm',      -25:0.5:0, ...
    'ber_mc_runs',      8, ...
    'ber_mc_bits',      20000, ...
    'plot_nSym',        100, ...
    'figure_dir',       figureDir, ...
    'h', 6.626e-34, 'c', 3e8, 'e', 1.602e-19, 'k', 1.381e-23, ...
    'font_size', 11, 'title_size', 13, 'label_size', 12, ...
    'line_width', 1.5, 'grid_alpha', 0.15, 'font_name', 'Times New Roman', ...
    'export_dpi', 300);
end

function ic = get_interconnect_cfg(cfg)
ic.Cj           = cfg.Cj;
ic.Cp           = cfg.Cp;
ic.Rs           = cfg.Rs;
ic.Lp           = cfg.Lp;
ic.R_load       = cfg.R_load;
ic.f3dB         = cfg.f3dB;
ic.Id           = cfg.Id;
ic.Psat         = cfg.Psat;
ic.enable_shot_noise = cfg.enable_shot;
end

function pd = compute_pd_physics(cfg)
eta_p = (1-cfg.Rf_surface) * (1-exp(-cfg.Gamma_conf*cfg.alpha_abs*cfg.L_absorber));
pd.eta_physical = eta_p;
pd.responsivity  = cfg.eta_plateau * cfg.e * cfg.lambda_center / (cfg.h * cfg.c);
v_avg            = 2*cfg.v_sat_e*cfg.v_sat_h / (cfg.v_sat_e+cfg.v_sat_h);
pd.v_drift       = v_avg;
pd.f_transit     = 0.45 * v_avg / cfg.d_depletion;
Ctot             = cfg.Cj + cfg.Cp;
pd.Ctotal        = Ctot;
pd.f_RC          = 1 / (2*pi*(cfg.Rs+cfg.R_load)*Ctot);
pd.f3dB_total    = 1 / sqrt(1/pd.f_transit^2 + 1/pd.f_RC^2);
Vt               = cfg.k * cfg.T / cfg.e;
pd.Id_physical   = abs(cfg.Is*(exp(cfg.Vbias/(cfg.n_ideality*Vt))-1));
E_c              = cfg.h*cfg.c/(cfg.e*cfg.lambda_center);
pd.C_direct      = cfg.alpha_abs / max(sqrt(E_c-cfg.Eg_direct), 1e-6);
pd.E_center      = E_c;
end

function analytical = analytical_perf(cfg, pd, Pavg, Pmin, Pmax, bw)
R  = pd.responsivity;
Id = cfg.Id;
Ip = R * Pavg;
s2sh = 2*cfg.e*(Ip+Id)*bw;
s2th = 4*cfg.k*cfg.T*bw/cfg.R_load;
SNR  = Ip^2 / (s2sh+s2th);
analytical.SNR_dB     = 10*log10(SNR);
analytical.SNR_linear = SNR;
I1   = R*Pmax; I0 = R*Pmin;
M    = 4;
s1   = sqrt(2*cfg.e*(I1+Id)*bw+s2th);
s0   = sqrt(2*cfg.e*(I0+Id)*bw+s2th);
Q    = (I1-I0) / ((M-1)*(s1+s0));
analytical.Q   = Q;
analytical.BER = (3/(2*log2(M)))*0.5*erfc(Q/sqrt(2));
analytical.NEP = sqrt(2*cfg.e*Id+4*cfg.k*cfg.T/cfg.R_load) / R;
Acm2           = cfg.A_detector*1e4;
analytical.Dstar = R*sqrt(Acm2) / sqrt(2*cfg.e*Id+4*cfg.k*cfg.T/cfg.R_load);
Q_req          = sqrt(2)*erfcinv(2*cfg.target_BER*2*log2(M)/3);
s_th           = sqrt(s2th);
dP             = (cfg.ER-1)/(cfg.ER+1);
P_s            = Q_req*(M-1)*2*s_th / (R*2*dP);
analytical.sensitivity_W   = P_s;
analytical.sensitivity_dBm = 10*log10(P_s/1e-3);
analytical.Q_required      = Q_req;
end

function Iout = sat_model(Iin, Isat, mdl)
switch mdl
    case 'hard',   Iout = min(Iin, Isat);
    case 'smooth', Iout = Iin ./ (1 + Iin/Isat);
    case 'tanh',   Iout = Isat*tanh(Iin/Isat);
    otherwise,     Iout = min(Iin, Isat);
end
end

function [sn, tn, nc] = noise_terms(Iph, cfg, pd, fs, bw)
dt   = 1/fs;
sn   = zeros(size(Iph));
if cfg.enable_shot
    lam = (max(Iph,0)+pd.Id_physical)*dt/cfg.e;
    sn  = (poissrnd(lam)-lam)*cfg.e/dt;
end
tn = zeros(size(Iph));
if cfg.enable_thermal
    tn = sqrt(4*cfg.k*cfg.T*bw/cfg.R_load)*randn(size(Iph));
end
nc.shot          = sn;
nc.thermal       = tn;
nc.shot_variance    = var(sn);
nc.thermal_variance = var(tn);
nc.total_variance   = nc.shot_variance + nc.thermal_variance;
nc.shot_fraction    = nc.shot_variance / max(nc.total_variance, eps);
end

function [syms, bits] = gen_symbols(nBits)
syms = randi([0,3], floor(nBits/2), 1);
bits = reshape([floor(syms/2), mod(syms,2)].', [], 1);
end

function optP = modulate_pam(syms, pulse, Pmin, Pmax, nSamp, sps)
lvls = [-3;-1;1;3];
w    = upfirdn(lvls(syms+1), pulse, sps, 1);
gd   = (numel(pulse)-1)/2;
w    = real(w(gd+1:gd+nSamp));
sp   = max(w)-min(w);
w    = (w-min(w)) / max(sp,eps);
optP = Pmin + w*(Pmax-Pmin);
end

function [syms, bits] = detect_pam(sig, pulse, nSym, sps)
mt  = conv(sig, pulse, 'full');
gd  = (numel(pulse)-1)/2;
bs  = -inf; samp = [];
for off = 0:sps-1
    idx = gd+1+off+(0:nSym-1)*sps;
    idx = idx(idx<=numel(mt));
    c   = mt(idx);
    if var(c,1)>bs, bs=var(c,1); samp=c(:); end
end
sr  = sort(samp);
bE  = round(linspace(1,numel(sr)+1,5));
lv  = zeros(1,4);
for i=1:4, lv(i)=mean(sr(bE(i):bE(i+1)-1)); end
thr = (lv(1:3)+lv(2:4))/2;
syms = sum(samp>=thr, 2);
bits = reshape([floor(syms/2), mod(syms,2)].', [], 1);
end

function m = calc_metrics(txB, rxB, txS, rxS, ref, rx)
nB  = min(numel(txB), numel(rxB));
nSy = min(numel(txS), numel(rxS));
spw = var(ref(:),1);
npw = max(var(rx(:)-ref(:),1), eps);
bE  = sum(txB(1:nB)~=rxB(1:nB));
sE  = sum(txS(1:nSy)~=rxS(1:nSy));
m   = struct('signal_power',spw,'noise_power',npw,'SNR_linear',spw/npw, ...
    'SNR_dB',10*log10(spw/npw),'bit_errors',bE,'symbol_errors',sE, ...
    'total_bits',nB,'total_symbols',nSy,'BER',bE/max(nB,1),'SER',sE/max(nSy,1));
end

function plot_responsivity(cfg, pd, figDir, fname)
lnm  = linspace(300, 1800, 2000);
lm   = 1e-9*lnm;
edge = max((cfg.lambda_max-cfg.lambda_min)/8, 5e-9);
rOn  = 1./(1+exp((cfg.lambda_min-lm)/edge));
rOff = 1./(1+exp((lm-cfg.lambda_max)/edge));
R_em = cfg.eta_plateau*rOn.*rOff.*cfg.e.*lm/(cfg.h*cfg.c);
E_ev = cfg.h*cfg.c./(cfg.e*lm);
alp  = pd.C_direct*real(sqrt(max(E_ev-cfg.Eg_direct,0)));
eta_p= (1-cfg.Rf_surface)*(1-exp(-cfg.Gamma_conf*alp*cfg.L_absorber));
R_ph = eta_p.*cfg.e.*lm/(cfg.h*cfg.c);
fig  = figure('Color','w','Position',[60,60,1600,1000]);
plot(lnm, R_em, 'k-',  'LineWidth', cfg.line_width, 'DisplayName','Empirical (sigmoid)'); hold on;
plot(lnm, R_ph, 'k--', 'LineWidth', 2,              'DisplayName','Wartak physical');
xline(cfg.lambda_min*1e9,'k:','LineWidth',1.5,'HandleVisibility','off');
xline(cfg.lambda_max*1e9,'k:','LineWidth',1.5,'HandleVisibility','off');
plot(cfg.lambda_center*1e9, pd.responsivity, 'ko', 'MarkerFaceColor','k','MarkerSize',8, ...
    'DisplayName',sprintf('Op. point (%.4f A/W)',pd.responsivity));
xlabel('Wavelength (nm)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Responsivity (A/W)','FontSize',cfg.label_size,'FontWeight','bold');
title(sprintf('Photodiode Responsivity - O-band (Wartak Ch.10)'),'FontSize',cfg.title_size,'FontWeight','bold');
grid on; xlim([800 1800]); ylim([0 1.1*max(R_em)]);
legend('Location','northwest','FontSize',10,'Box','off');
style_ax(cfg); save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_transfer(cfg, R, Isat, Pmin, Pmax, figDir, fname)
P      = linspace(0, 1.5*cfg.Psat, 1000);
I_id   = R*P;
I_hd   = min(I_id, Isat);
I_sm   = I_id./(1+I_id/Isat);
I_th   = Isat*tanh(I_id/Isat);
fig    = figure('Color','w','Position',[90,90,1600,1000]);
plot(P*1e3, I_hd*1e3,'k-',  'LineWidth',cfg.line_width,'DisplayName','Hard clip'); hold on;
plot(P*1e3, I_sm*1e3,'k--', 'LineWidth',2,             'DisplayName','Smooth');
plot(P*1e3, I_th*1e3,'k:',  'LineWidth',2,             'DisplayName','Tanh');
plot(P*1e3, I_id*1e3,'k-.', 'LineWidth',1.5,           'DisplayName','Ideal');
xline(Pmin*1e3,'k:','LineWidth',1.5,'HandleVisibility','off');
xline(Pmax*1e3,'k:','LineWidth',1.5,'HandleVisibility','off');
xlabel('Optical Power (mW)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Photocurrent (mA)','FontSize',cfg.label_size,'FontWeight','bold');
title(sprintf('Transfer Function - Saturation Models (Wartak Sec. 10.2)'), ...
    'FontSize',cfg.title_size,'FontWeight','bold');
grid on; xlim([0 max(P)*1e3]);
legend('Location','southeast','FontSize',10,'Box','off');
style_ax(cfg); save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_eye(cfg, sig, sigType, snrDb, figDir, fname)
es   = 2*cfg.sps;
nTr  = min(floor(numel(sig)/es), cfg.plot_nSym);
ed   = reshape(sig(1:nTr*es), es, nTr)*1e6;
tE   = (0:es-1)/(cfg.symbol_rate*cfg.sps)*1e12;
fig  = figure('Color','w','Position',[120,120,1600,1000]);
plot(tE, ed, 'k', 'LineWidth', 0.4, 'Color', [0.2 0.2 0.2]);
xlabel('Time (ps)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel(sprintf('%s (\\muA)', sigType),'FontSize',cfg.label_size,'FontWeight','bold');
title(sprintf('%s Eye Diagram (SNR = %.1f dB)', sigType, snrDb), ...
    'FontSize',cfg.title_size,'FontWeight','bold');
grid on; xlim([tE(1) tE(end)]);
style_ax(cfg); save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_pam_histogram(cfg, sig, pulse, nSym, snrDb, figDir, fname)
mt  = conv(sig, pulse, 'full');
gd  = (numel(pulse)-1)/2;
sps = cfg.sps;
bs  = -inf; samp = [];
for off=0:sps-1
    idx = gd+1+off+(0:nSym-1)*sps;
    idx = idx(idx<=numel(mt));
    c   = mt(idx);
    if var(c,1)>bs, bs=var(c,1); samp=c(:); end
end
sr  = sort(samp); bE=round(linspace(1,numel(sr)+1,5));
lv  = zeros(1,4); for i=1:4, lv(i)=mean(sr(bE(i):bE(i+1)-1)); end
thr = (lv(1:3)+lv(2:4))/2;
fig = figure('Color','w','Position',[150,150,1600,1000]);
histogram(samp*1e6, 120,'FaceColor',[0.5 0.5 0.5],'EdgeColor','none');
hold on; for tv=thr, xline(tv*1e6,'k--','LineWidth',1.5); end
xlabel('Matched Filter Output (\muA)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Count','FontSize',cfg.label_size,'FontWeight','bold');
title(sprintf('PAM-4 Level Histogram (SNR = %.1f dB)',snrDb), ...
    'FontSize',cfg.title_size,'FontWeight','bold');
grid on; style_ax(cfg); save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_quantum_efficiency(cfg, pd, figDir, fname)
lnm = linspace(800,1850,2000); lm = 1e-9*lnm;
Eev = cfg.h*cfg.c./(cfg.e*lm);
alp = pd.C_direct*real(sqrt(max(Eev-cfg.Eg_direct,0)));
Lvs = [5e-6,10e-6,20e-6,50e-6];
lbs = {'L=5\mum','L=10\mum','L=20\mum','L=50\mum'};
lss = {'-','--','-.',':'};
fig = figure('Color','w','Position',[160,160,1600,1000]);
subplot(1,2,1);
semilogy(lnm, alp*1e-2,'k-','LineWidth',cfg.line_width);
xlabel('Wavelength (nm)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('\alpha (cm^{-1})','FontSize',cfg.label_size,'FontWeight','bold');
title('Ge Absorption Coefficient (Wartak Eq. 10.3)','FontSize',cfg.title_size,'FontWeight','bold');
xline(cfg.lambda_center*1e9,'k:','LineWidth',1.5); xlim([800 1850]); grid on; style_ax(cfg);
subplot(1,2,2); hold on;
for ii=1:numel(Lvs)
    eta = (1-cfg.Rf_surface)*(1-exp(-cfg.Gamma_conf*alp*Lvs(ii)));
    plot(lnm, eta, lss{ii},'k','LineWidth',2,'DisplayName',lbs{ii});
end
xline(cfg.lambda_min*1e9,'k:','LineWidth',1,'HandleVisibility','off');
xline(cfg.lambda_max*1e9,'k:','LineWidth',1,'HandleVisibility','off');
plot(cfg.lambda_center*1e9, pd.eta_physical,'ko','MarkerFaceColor','k','MarkerSize',8, ...
    'DisplayName',sprintf('\\eta=%.3f @ %.0fnm',pd.eta_physical,cfg.lambda_center*1e9));
xlabel('Wavelength (nm)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Quantum Efficiency \eta','FontSize',cfg.label_size,'FontWeight','bold');
title('\eta(\lambda)=(1-R_f)(1-e^{-\Gamma\alpha L}) - Wartak Eq. 10.7', ...
    'FontSize',cfg.title_size,'FontWeight','bold');
xlim([800 1850]); ylim([0 1.05]); grid on;
legend('Location','southwest','FontSize',10,'Box','off');
style_ax(cfg); save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_bandwidth_budget(cfg, pd, figDir, fname)
fig  = figure('Color','w','Position',[170,170,1600,1000]);
dr   = linspace(50e-9,500e-9,500);
f_tr = 0.45*pd.v_drift./dr;
f_rc = pd.f_RC*ones(size(dr));
f_cb = 1./sqrt(1./f_tr.^2+1./f_rc.^2);
subplot(1,2,1);
plot(dr*1e9, f_tr/1e9,'k--','LineWidth',2,'DisplayName','f_{tr}'); hold on;
plot(dr*1e9, f_rc/1e9,'k:','LineWidth',2,'DisplayName',sprintf('f_{RC}=%.0f GHz',pd.f_RC/1e9));
plot(dr*1e9, f_cb/1e9,'k-','LineWidth',cfg.line_width,'DisplayName','f_{3dB}');
plot(cfg.d_depletion*1e9, pd.f3dB_total/1e9,'ko','MarkerFaceColor','k','MarkerSize',10,'LineWidth',1.5, ...
    'DisplayName',sprintf('Design (%.0f GHz)',pd.f3dB_total/1e9));
xlabel('Depletion Width (nm)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Bandwidth (GHz)','FontSize',cfg.label_size,'FontWeight','bold');
title('BW vs Depletion Width (Wartak Eq. 10.14-10.17)', ...
    'FontSize',cfg.title_size,'FontWeight','bold');
legend('Location','northeast','FontSize',10,'Box','off');
grid on; ylim([0 500]); style_ax(cfg);
subplot(1,2,2);
Lr  = linspace(1e-6,50e-6,500);
Ec  = cfg.h*cfg.c/(cfg.e*cfg.lambda_center);
alc = pd.C_direct*sqrt(max(Ec-cfg.Eg_direct,0));
eta_r = (1-cfg.Rf_surface)*(1-exp(-cfg.Gamma_conf*alc*Lr));
R_r   = eta_r*cfg.e*cfg.lambda_center/(cfg.h*cfg.c);
yyaxis left;  plot(Lr*1e6, eta_r,'k-','LineWidth',cfg.line_width); ylabel('\eta','FontSize',cfg.label_size,'FontWeight','bold'); ylim([0 1.05]);
yyaxis right; plot(Lr*1e6, R_r,'k--','LineWidth',2); ylabel('R (A/W)','FontSize',cfg.label_size,'FontWeight','bold');
hold on; yyaxis left; plot(cfg.L_absorber*1e6, pd.eta_physical,'ko','MarkerFaceColor','k','MarkerSize',10,'LineWidth',1.5);
xlabel('Absorber Length (\mum)','FontSize',cfg.label_size,'FontWeight','bold');
title('QE-Absorber Length Trade-off','FontSize',cfg.title_size,'FontWeight','bold');
grid on; style_ax(cfg); save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_noise_analysis(cfg, nc, pd, ~, figDir, fname)
fig = figure('Color','w','Position',[180,180,1600,1000]);
subplot(2,2,1);
[cnt,edg] = histcounts(nc.shot*1e6,80,'Normalization','pdf');
ctr = (edg(1:end-1)+edg(2:end))/2;
bar(ctr,cnt,'FaceColor',[0.5 0.5 0.5],'EdgeColor','none'); hold on;
xr = linspace(min(ctr),max(ctr),500);
plot(xr, normpdf(xr,0,sqrt(nc.shot_variance)*1e6),'k-','LineWidth',2);
xlabel('i_{shot} (\muA)','FontSize',cfg.label_size,'FontWeight','bold'); ylabel('PDF','FontSize',cfg.label_size,'FontWeight','bold');
title('Shot Noise Distribution','FontSize',cfg.title_size,'FontWeight','bold');
legend({'Simulated','Gaussian'},'Location','northeast','FontSize',9,'Box','off'); grid on; style_ax(cfg);
subplot(2,2,2);
[cnt,edg] = histcounts(nc.thermal*1e6,80,'Normalization','pdf');
ctr = (edg(1:end-1)+edg(2:end))/2;
bar(ctr,cnt,'FaceColor',[0.5 0.5 0.5],'EdgeColor','none'); hold on;
plot(linspace(min(ctr),max(ctr),500), normpdf(linspace(min(ctr),max(ctr),500),0,sqrt(nc.thermal_variance)*1e6),'k-','LineWidth',2);
xlabel('i_{thermal} (\muA)','FontSize',cfg.label_size,'FontWeight','bold'); ylabel('PDF','FontSize',cfg.label_size,'FontWeight','bold');
title('Thermal Noise Distribution','FontSize',cfg.title_size,'FontWeight','bold');
legend({'Simulated','Gaussian'},'Location','northeast','FontSize',9,'Box','off'); grid on; style_ax(cfg);
subplot(2,2,3);
pie([nc.shot_variance, nc.thermal_variance], ...
    {sprintf('Shot (%.1f%%)',100*nc.shot_fraction), sprintf('Thermal (%.1f%%)',100*(1-nc.shot_fraction))});
title('Noise Variance Breakdown','FontSize',cfg.title_size,'FontWeight','bold');
subplot(2,2,4);
bwr = logspace(8,12,500);
R   = pd.responsivity;
Id  = pd.Id_physical;
NEP_bw = sqrt(2*cfg.e*Id*bwr + 4*cfg.k*cfg.T*bwr/cfg.R_load) / R;
yyaxis left;  loglog(bwr/1e9, NEP_bw,'k-','LineWidth',cfg.line_width); ylabel('NEP (W/sqrtHz)','FontSize',cfg.label_size,'FontWeight','bold');
yyaxis right;
Acm2 = cfg.A_detector*1e4;
Ds   = R*sqrt(Acm2)/sqrt(2*cfg.e*Id+4*cfg.k*cfg.T/cfg.R_load)*ones(size(bwr));
loglog(bwr/1e9, Ds,'k--','LineWidth',2); ylabel('D* (Jones)','FontSize',cfg.label_size,'FontWeight','bold');
xlabel('Bandwidth (GHz)','FontSize',cfg.label_size,'FontWeight','bold');
title('NEP and D* (Wartak Eq. 10.20-10.22)','FontSize',cfg.title_size,'FontWeight','bold');
grid on; style_ax(cfg);
save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function plot_ber_vs_power(cfg, pd, bw, pulse, figDir, fname)
R  = pd.responsivity; Id = cfg.Id; M = 4;
Pw = 1e-3*10.^(cfg.P_sweep_dBm/10);
BER_an = zeros(size(Pw)); Qan = zeros(size(Pw));
for ii=1:numel(Pw)
    Pav=Pw(ii); Pm=2*Pav/(cfg.ER+1); Px=2*Pav*cfg.ER/(cfg.ER+1);
    I1=R*Px; I0=R*Pm; s2th=4*cfg.k*cfg.T*bw/cfg.R_load;
    s1=sqrt(2*cfg.e*(I1+Id)*bw+s2th); s0=sqrt(2*cfg.e*(I0+Id)*bw+s2th);
    Qi=(I1-I0)/((M-1)*(s1+s0)); Qan(ii)=Qi;
    BER_an(ii)=(3/(2*log2(M)))*0.5*erfc(Qi/sqrt(2));
end
BER_mc = zeros(size(Pw)); sps=cfg.sps; fs_mc=cfg.symbol_rate*sps;
Isat = R*cfg.Psat;
for ii=1:numel(Pw)
    Pav=Pw(ii); Pm=2*Pav/(cfg.ER+1); Px=2*Pav*cfg.ER/(cfg.ER+1);
    tE=0; tB=0;
    for run=1:cfg.ber_mc_runs
        [tS,tBit] = gen_symbols(cfg.ber_mc_bits); nS=numel(tS); ns=nS*sps;
        oTx = modulate_pam(tS,pulse,Pm,Px,ns,sps);
        oRx = max(oTx,0);
        Id_  = sat_model(R*oRx, Isat,'smooth');
        dt   = 1/fs_mc; lam=(max(Id_,0)+Id)*dt/cfg.e;
        sn   = (poissrnd(lam)-lam)*cfg.e/dt;
        tn   = sqrt(4*cfg.k*cfg.T*bw/cfg.R_load)*randn(size(Id_));
        [bl,al]=butter(3,min(0.99,2*bw/fs_mc));
        rx = filter(bl,al,Id_+sn+tn);
        [~,rBit]=detect_pam(rx,pulse,nS,sps);
        nB=min(numel(tBit),numel(rBit));
        tE=tE+sum(tBit(1:nB)~=rBit(1:nB)); tB=tB+nB;
    end
    BER_mc(ii)=max(tE/tB, 0.5/tB);
end
fig=figure('Color','w','Position',[190,190,1600,1000]);
subplot(1,2,1);
semilogy(cfg.P_sweep_dBm,BER_an,'k-','LineWidth',cfg.line_width,'DisplayName','Analytical (Wartak)'); hold on;
semilogy(cfg.P_sweep_dBm,BER_mc,'ko','MarkerFaceColor','k','MarkerSize',5,'LineWidth',1.5,'DisplayName','Monte Carlo');
yline(cfg.target_BER,'k--','LineWidth',1.5,'DisplayName',sprintf('Target BER=%.0e',cfg.target_BER));
yline(3.8e-3,'k:','LineWidth',1.5,'DisplayName','KP4 FEC');
xlabel('Received Power (dBm)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Bit Error Rate','FontSize',cfg.label_size,'FontWeight','bold');
title('BER vs Received Optical Power (Wartak Ch. 14)','FontSize',cfg.title_size,'FontWeight','bold');
ylim([1e-12 1]); grid on; legend('Location','northeast','FontSize',10,'Box','off'); style_ax(cfg);
subplot(1,2,2);
plot(cfg.P_sweep_dBm,Qan,'k-','LineWidth',cfg.line_width); hold on;
yline(6,'k--','LineWidth',1.5,'DisplayName','Q=6');
yline(3.09,'k:','LineWidth',1.5,'DisplayName','Q=3.09 (KP4)');
xlabel('Received Power (dBm)','FontSize',cfg.label_size,'FontWeight','bold');
ylabel('Q-Factor','FontSize',cfg.label_size,'FontWeight','bold');
title('Q-Factor vs Received Power','FontSize',cfg.title_size,'FontWeight','bold');
grid on; legend('Location','southeast','FontSize',10,'Box','off'); style_ax(cfg);
save_fig_fn(fig, figDir, fname, cfg.export_dpi);
end

function style_ax(cfg)
set(gca,'FontSize',cfg.font_size,'FontName',cfg.font_name,'LineWidth',1.5, ...
    'GridAlpha',cfg.grid_alpha,'MinorGridAlpha',0.08,'TickDir','out', ...
    'XMinorGrid','on','YMinorGrid','on');
end

function save_fig_fn(fig, outDir, baseName, dpi)
if ~exist(outDir,'dir'), mkdir(outDir); end
set(fig,'Color','w','InvertHardcopy','off','Renderer','painters');
drawnow;
exportgraphics(fig, fullfile(outDir,[baseName,'.png']), 'Resolution',dpi,'BackgroundColor','white');
fprintf('  Saved %s\n', fullfile(outDir,[baseName,'.png']));
end
