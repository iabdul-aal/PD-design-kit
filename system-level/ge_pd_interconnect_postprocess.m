figure_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'thesis', 'figures');
if ~exist(figure_dir, 'dir'), mkdir(figure_dir); end

sys_dir = fileparts(mfilename('fullpath'));
cml_mat = fullfile(sys_dir, 'ge_pd_cml_oband_ushaped.mat');

q  = 1.602e-19;
kB = 1.381e-23;
h  = 6.626e-34;
c0 = 3e8;

assert(exist(cml_mat, 'file') == 2, ...
    'CML data file not found: %s\nRun ge_pd_oband_ushaped_postprocess.m first.', cml_mat);
cml = load(cml_mat);

lambda_c = cml.geometry.lambda_c_m;
R_AW     = cml.optical.responsivity_nominal_AW;
Id_A     = cml.electrical.Id_at_1V_nA * 1e-9;
f3dB_Hz  = cml.bandwidth.f3dB_GHz * 1e9;
Rs_ohm   = cml.bandwidth.Rs_ohm;
Cj_F     = cml.bandwidth.Cj_fF * 1e-15;
Cp_F     = cml.bandwidth.Cp_fF * 1e-15;
Psat_W   = cml.saturation.Psat_W;
Lp_H     = cml.bandwidth.Lp_pH * 1e-12;
R_load   = 50;
T_K      = cml.temperature.T_sim_K;

fprintf('CML loaded: R=%.4f A/W  Id=%.3f nA  f3dB=%.1f GHz  Rs=%.1f Ohm  Cj=%.1f fF\n', ...
    R_AW, Id_A*1e9, f3dB_Hz/1e9, Rs_ohm, Cj_F*1e15);

symbol_rate = 53.125e9;
M           = 4;
ER          = 10;
P_avg_dBm   = -2;
sps         = 16;
num_bits    = 80000;

cfg.f3dB         = f3dB_Hz;
cfg.Id           = Id_A;
cfg.Psat         = Psat_W;
cfg.Rs           = Rs_ohm;
cfg.Cj           = Cj_F;
cfg.Lp           = Lp_H;
cfg.Cp           = Cp_F;
cfg.R_load       = R_load;
cfg.enable_shot_noise = true;
cfg.font_name    = 'Times New Roman';
cfg.font_size    = 11;
cfg.title_size   = 13;
cfg.label_size   = 12;
cfg.line_width   = 1.5;
cfg.grid_alpha   = 0.15;
cfg.dpi          = 300;

model = ge_pd_interconnect_model(cfg, R_AW);

Pavg_W  = 1e-3 * 10^(P_avg_dBm / 10);
Pmin_W  = 2 * Pavg_W / (ER + 1);
Pmax_W  = 2 * Pavg_W * ER / (ER + 1);
fs      = symbol_rate * sps;
bw_eff  = min(f3dB_Hz, 0.75 * symbol_rate);

txSymbols = randi([0, 3], floor(num_bits / 2), 1);
txBits    = reshape([floor(txSymbols/2), mod(txSymbols,2)].', [], 1);
nSym      = numel(txSymbols);
nSamp     = nSym * sps;

pulse = rcosdesign(0.35, 6, sps, 'sqrt');
pamLevels = [-3; -1; 1; 3];
wave = upfirdn(pamLevels(txSymbols + 1), pulse, sps, 1);
gd   = (numel(pulse) - 1) / 2;
wave = real(wave(gd+1 : gd+nSamp));
span = max(wave) - min(wave);
wave = (wave - min(wave)) / max(span, eps);
optTx = Pmin_W + wave * (Pmax_W - Pmin_W);
optRx = max(optTx, 0);

Iideal = R_AW * optRx;
Isat   = R_AW * Psat_W;
Iideal = Iideal ./ (1 + Iideal / Isat);

dt     = 1 / fs;
lam_p  = (max(Iideal, 0) + Id_A) * dt / q;
sn     = (poissrnd(lam_p) - lam_p) * q / dt;
tn     = sqrt(4 * kB * T_K * bw_eff / R_load) * randn(size(Iideal));

[b_lp, a_lp] = butter(3, min(0.99, 2 * bw_eff / fs));
Irx = filter(b_lp, a_lp, Iideal + sn + tn);
Iref = filter(b_lp, a_lp, Iideal);

matched   = conv(Irx, pulse, 'full');
gd_m      = (numel(pulse)-1)/2;
bestScore = -inf;
samples   = [];
for offset = 0:sps-1
    idx = gd_m + 1 + offset + (0:nSym-1)*sps;
    idx = idx(idx <= numel(matched));
    cand = matched(idx);
    if var(cand,1) > bestScore
        bestScore = var(cand,1);
        samples   = cand(:);
    end
end
srtd = sort(samples);
bE   = round(linspace(1, numel(srtd)+1, 5));
lvls = zeros(1,4);
for ii=1:4, lvls(ii) = mean(srtd(bE(ii):bE(ii+1)-1)); end
thr  = (lvls(1:3) + lvls(2:4)) / 2;
rxSym = sum(samples >= thr, 2);
rxBit = reshape([floor(rxSym/2), mod(rxSym,2)].', [], 1);

nB  = min(numel(txBits), numel(rxBit));
nSy = min(numel(txSymbols), numel(rxSym));
sig_pwr  = var(Iref(:),1);
ns_pwr   = max(var(Irx(:) - Iref(:),1), eps);
SNR_dB   = 10*log10(sig_pwr / ns_pwr);
BER_sim  = sum(txBits(1:nB) ~= rxBit(1:nB)) / max(nB,1);
SER_sim  = sum(txSymbols(1:nSy) ~= rxSym(1:nSy)) / max(nSy,1);

P_sw_dBm = -25:0.5:0;
P_sw_W   = 1e-3 * 10.^(P_sw_dBm/10);
BER_an   = zeros(size(P_sw_W));
Q_an     = zeros(size(P_sw_W));
for ii = 1:numel(P_sw_W)
    Pav_i = P_sw_W(ii);
    Pm_i  = 2*Pav_i / (ER+1);
    Px_i  = 2*Pav_i*ER / (ER+1);
    I1    = R_AW * Px_i;
    I0    = R_AW * Pm_i;
    s2th  = 4*kB*T_K*bw_eff / R_load;
    s1    = sqrt(2*q*(I1+Id_A)*bw_eff + s2th);
    s0    = sqrt(2*q*(I0+Id_A)*bw_eff + s2th);
    Qi    = (I1-I0) / ((M-1)*(s1+s0));
    Q_an(ii)   = Qi;
    BER_an(ii) = (3/(2*log2(M))) * 0.5 * erfc(Qi/sqrt(2));
end

Q_req = sqrt(2) * erfcinv(2 * 1e-9 * 2*log2(M) / 3);
s2th_nom = 4*kB*T_K*bw_eff / R_load;
dP  = (ER-1)/(ER+1);
Psen_W  = Q_req*(M-1)*2*sqrt(s2th_nom) / (R_AW * 2*dP);
Psen_dBm = 10*log10(Psen_W/1e-3);

fprintf('\n=== INTERCONNECT System Results ===\n');
fprintf('  Symbol rate          : %.3f GBd\n',  symbol_rate/1e9);
fprintf('  Line rate (PAM-4)    : %.1f Gb/s\n',  symbol_rate*2/1e9);
fprintf('  Responsivity         : %.4f A/W\n',   R_AW);
fprintf('  Dark current         : %.3f nA\n',    Id_A*1e9);
fprintf('  Bandwidth f3dB       : %.1f GHz\n',   f3dB_Hz/1e9);
fprintf('  SNR (simulated)      : %.2f dB\n',    SNR_dB);
fprintf('  BER (simulated)      : %.2e\n',        BER_sim);
fprintf('  SER (simulated)      : %.2e\n',        SER_sim);
fprintf('  Sensitivity @BER1e-9 : %.2f dBm\n',   Psen_dBm);

eyeSamp  = 2 * sps;
nTraces  = min(floor(nSamp / eyeSamp), 200);
eyeData  = reshape(Irx(1:nTraces*eyeSamp), eyeSamp, nTraces) * 1e6;
tEye_ps  = (0:eyeSamp-1) / (symbol_rate * sps) * 1e12;

fig1 = figure('Color','w','Position',[80,80,1600,1000],'Name','PAM-4 Eye Diagram');
plot(tEye_ps, eyeData, 'k', 'LineWidth', 0.4, 'Color', [0.2 0.2 0.2]);
xlabel('Time (ps)',       'FontSize', cfg.label_size, 'FontWeight','bold');
ylabel('Photocurrent (\muA)', 'FontSize', cfg.label_size, 'FontWeight','bold');
title(sprintf('PAM-4 Eye Diagram - %.1f GBd, SNR = %.1f dB', symbol_rate/1e9, SNR_dB), ...
    'FontSize', cfg.title_size, 'FontWeight','bold');
xlim([tEye_ps(1), tEye_ps(end)]);
grid on;
style_ax(cfg);
save_fig(fig1, figure_dir, 'system_pam4_eye_diagram', cfg.dpi);

fig2 = figure('Color','w','Position',[100,100,1600,1000],'Name','BER vs Power');
subplot(1,2,1);
semilogy(P_sw_dBm, BER_an,  'k-',  'LineWidth', cfg.line_width, 'DisplayName', 'Analytical (PAM-4)');
hold on;
semilogy(P_avg_dBm, BER_sim, 'k^', 'MarkerFaceColor','k','MarkerSize',8,'DisplayName','Simulated point');
yline(1e-9,  'k--', 'BER=10^{-9}',   'LineWidth', 1.5);
yline(3.8e-3,'k:',  'KP4 FEC limit', 'LineWidth', 1.5);
xlabel('Received Power (dBm)', 'FontSize', cfg.label_size, 'FontWeight','bold');
ylabel('Bit Error Rate',        'FontSize', cfg.label_size, 'FontWeight','bold');
title('BER vs Received Power - PAM-4', 'FontSize', cfg.title_size, 'FontWeight','bold');
ylim([1e-12 1]); grid on;
legend('Location','northeast','FontSize',9);
style_ax(cfg);
subplot(1,2,2);
plot(P_sw_dBm, Q_an, 'k-', 'LineWidth', cfg.line_width);
hold on;
yline(6,    'k--', 'Q=6 (BER=10^{-9})',  'LineWidth', 1.5);
yline(3.09, 'k:',  'Q=3.09 (KP4 FEC)', 'LineWidth', 1.5);
xlabel('Received Power (dBm)', 'FontSize', cfg.label_size, 'FontWeight','bold');
ylabel('Q-Factor',              'FontSize', cfg.label_size, 'FontWeight','bold');
title('Q-Factor vs Received Power - PAM-4', 'FontSize', cfg.title_size, 'FontWeight','bold');
grid on; legend('Location','southeast','FontSize',9);
style_ax(cfg);
save_fig(fig2, figure_dir, 'system_ber_vs_power', cfg.dpi);

fig3 = figure('Color','w','Position',[120,120,1600,1000],'Name','PAM-4 Level Histogram');
histogram(samples*1e6, 120, 'FaceColor',[0.5 0.5 0.5],'EdgeColor','none');
hold on;
for tv = thr, xline(tv*1e6,'k--','LineWidth',1.5); end
hold off;
xlabel('Matched Filter Output (\muA)', 'FontSize', cfg.label_size, 'FontWeight','bold');
ylabel('Count',                         'FontSize', cfg.label_size, 'FontWeight','bold');
title(sprintf('PAM-4 Decision Histogram - SNR = %.1f dB', SNR_dB), ...
    'FontSize', cfg.title_size, 'FontWeight','bold');
grid on; style_ax(cfg);
save_fig(fig3, figure_dir, 'system_pam4_histogram', cfg.dpi);

fig4 = figure('Color','w','Position',[140,140,1600,1000],'Name','INTERCONNECT Model');
yyaxis left;
semilogx(model.f_GHz, model.zt_VW, 'k-', 'LineWidth', cfg.line_width);
ylabel('|Z_t| (V/W)', 'FontSize', cfg.label_size, 'FontWeight','bold');
yyaxis right;
semilogx(model.f_GHz, model.norm_dB, 'k--', 'LineWidth', cfg.line_width);
ylabel('Normalised Response (dB)', 'FontSize', cfg.label_size, 'FontWeight','bold');
xlabel('Frequency (GHz)', 'FontSize', cfg.label_size, 'FontWeight','bold');
xline(model.f_rc/1e9,  'k:',  sprintf('f_{RC}=%.0f GHz',  model.f_rc/1e9),  'LineWidth',1.5);
xline(model.f_pkg/1e9, 'k-.', sprintf('f_{pkg}=%.0f GHz', model.f_pkg/1e9), 'LineWidth',1.5);
title('INTERCONNECT Compact Model - Electro-optic Response', ...
    'FontSize', cfg.title_size, 'FontWeight','bold');
legend({'|Z_t|','Norm. EO','f_{RC}','f_{pkg}'},'Location','southwest');
grid on; style_ax(cfg);
save_fig(fig4, figure_dir, 'system_interconnect_eo_response', cfg.dpi);

P_sense_W  = 1e-3 * 10.^(P_sw_dBm/10);
NEP_sw     = sqrt(2*q*Id_A*bw_eff + 4*kB*T_K*bw_eff/R_load) / R_AW;
Pmin_sw    = NEP_sw * sqrt(bw_eff);
fig5 = figure('Color','w','Position',[160,160,1600,1000],'Name','Sensitivity Summary');
bar([1 2 3 4], [P_avg_dBm, Psen_dBm, 10*log10(Pmin_sw/1e-3), -Inf], 0.5, ...
    'FaceColor',[0.6 0.6 0.6],'EdgeColor','k');
set(gca,'XTick',[1 2 3 4],'XTickLabel',{'P_{avg}','P_{sens} @BER1e-9','P_{min} (NEP)','-'});
ylabel('Power (dBm)', 'FontSize', cfg.label_size, 'FontWeight','bold');
title('Sensitivity Summary - PAM-4 DR4', 'FontSize', cfg.title_size, 'FontWeight','bold');
grid on; style_ax(cfg);
save_fig(fig5, figure_dir, 'system_sensitivity_summary', cfg.dpi);

fprintf('\nFigures saved to %s\n', figure_dir);

function style_ax(cfg)
set(gca, 'FontSize', cfg.font_size, 'FontName', cfg.font_name, 'LineWidth', 1.5, ...
    'GridAlpha', cfg.grid_alpha, 'MinorGridAlpha', 0.08, 'TickDir', 'out', ...
    'XMinorGrid', 'on', 'YMinorGrid', 'on');
end

function save_fig(fig, outDir, baseName, dpi)
if ~exist(outDir, 'dir'), mkdir(outDir); end
set(fig, 'Color','w','InvertHardcopy','off','Renderer','painters');
drawnow;
exportgraphics(fig, fullfile(outDir, [baseName,'.png']), 'Resolution', dpi, 'BackgroundColor','white');
fprintf('  Saved %s\n', fullfile(outDir, [baseName,'.png']));
end
