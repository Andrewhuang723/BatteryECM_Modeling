clc; clear;

%% ── Run Single Simulation + Error Analysis ───────────────────────────────────
%
% Automated alternative to the manual workflow:
%   cycle_ageing_parameters.m  →  CyclingAgeing.slx (UI)  →  error_analysis.m
%
% This script does the same thing end-to-end without manual steps.
% To tune parameters, edit config.m.

%% ── Load Configuration ───────────────────────────────────────────────────────
cfg = config();

%% ── Build Simulation Input ───────────────────────────────────────────────────
simIn = Simulink.SimulationInput(cfg.model_name);

% Ageing parameters
simIn = simIn.setVariable('N',    cfg.N);
simIn = simIn.setVariable('dOCV', cfg.dOCV);
simIn = simIn.setVariable('dR0',  cfg.dR0);
simIn = simIn.setVariable('dQ',   cfg.dQ);
simIn = simIn.setVariable('dR1',  cfg.dR1);
simIn = simIn.setVariable('dR2',  cfg.dR2);

% Battery / simulation parameters
simIn = simIn.setVariable('CC',        cfg.CC);
simIn = simIn.setVariable('C_rate',    cfg.C_rate);
simIn = simIn.setVariable('voltage_upper_limit', cfg.voltage_upper_limit);   % Charge cut-off SOC (DoD 70%)
simIn = simIn.setVariable('voltage_lower_limit', cfg.voltage_lower_limit);   % Discharge cut-off SOC (DoD 70%)
simIn = simIn.setVariable('soc_upper_limit', cfg.soc_upper_limit);   % Charge cut-off SOC (DoD 70%)
simIn = simIn.setVariable('soc_lower_limit', cfg.soc_lower_limit);   % Discharge cut-off SOC (DoD 70%)
simIn = simIn.setVariable('init_SOC',  cfg.init_SOC);
simIn = simIn.setVariable('t_exp',               cfg.t_exp);
simIn = simIn.setVariable('Battery_capacity',    cfg.Battery_capacity);
simIn = simIn.setVariable('Qnom',                cfg.Qnom);
simIn = simIn.setVariable('SOCs_29',             cfg.SOCs_29);
simIn = simIn.setVariable('OCVs_29',             cfg.OCVs_29);

% RC parameters
simIn = simIn.setVariable('R0_charge',           cfg.R0_charge);
simIn = simIn.setVariable('R0_discharge',        cfg.R0_discharge);
simIn = simIn.setVariable('R1_charge',           cfg.R1_charge);
simIn = simIn.setVariable('R1_discharge',        cfg.R1_discharge);
simIn = simIn.setVariable('R2_charge',           cfg.R2_charge);
simIn = simIn.setVariable('R2_discharge',        cfg.R2_discharge);
simIn = simIn.setVariable('tau1_charge',         cfg.tau1_charge);
simIn = simIn.setVariable('tau1_discharge',      cfg.tau1_discharge);
simIn = simIn.setVariable('tau2_charge',         cfg.tau2_charge);
simIn = simIn.setVariable('tau2_discharge',      cfg.tau2_discharge);

%% ── Run Simulation ───────────────────────────────────────────────────────────
fprintf('Running single simulation (T=%d°C)...\n', cfg.T_sim);
tic;
sim_out = sim(simIn);
fprintf('Simulation complete in %.2f s\n\n', toc);

%% ── Extract Per-Cycle Results ────────────────────────────────────────────────
capacity_data = sim_out.q_sim.Data;
zc_charge    = find(sim_out.zeroCrossing_charge.Data    > 0);
zc_discharge = find(sim_out.zeroCrossing_discharge.Data > 0);
n_cycles     = min(length(zc_charge), length(zc_discharge));
zc_charge    = zc_charge(1:n_cycles);
zc_discharge = zc_discharge(1:n_cycles);

cycle_idx       = (0:n_cycles-1)';
q_sim_charge    = [cycle_idx,  capacity_data(zc_charge)];
q_sim_discharge = [cycle_idx,  capacity_data(zc_charge) - capacity_data(zc_discharge)];

retention_sim      = q_sim_charge;
retention_sim(:,1) = retention_sim(:,1) - retention_sim(1,1);
retention_sim(:,2) = retention_sim(:,2) ./ retention_sim(1,2);

%% ── Load Experimental Data ───────────────────────────────────────────────────
cycle_data     = readtable(cfg.CYCLE_FILE, 'VariableNamingRule', 'preserve', 'Encoding', 'UTF-8');
discharge_data = cycle_data(cycle_data{:,'工步種類'} == "CC放電" & cycle_data{:, "工步編號"} >= 10, :);
discharge_data{:,'截止電量(Ah)'} = discharge_data{:,'截止電量(Ah)'};
[~, max_Q_idx] = max(discharge_data{:,'截止電量(Ah)'});
discharge_data = discharge_data(max_Q_idx:end, :);

q_exp         = [(1:height(discharge_data))', discharge_data{:,'截止電量(Ah)'}];
q_exp(:,1)    = q_exp(:,1) - q_exp(1,1);
retention_exp = q_exp;
retention_exp(:,2) = retention_exp(:,2) ./ retention_exp(1,2);

%% ── Error Metrics ────────────────────────────────────────────────────────────
q_sim_interp        = interp1(q_sim_discharge(:,1), q_sim_discharge(:,2), q_exp(:,1),        'linear', 'extrap');
retention_sim_interp = interp1(retention_sim(:,1),  retention_sim(:,2),  retention_exp(:,1), 'linear', 'extrap');

MAE_capacity  = mean(abs(q_exp(:,2)         - q_sim_interp));
MAE_retention = mean(abs(retention_exp(:,2) - retention_sim_interp));

fprintf('Error Analysis\n==============\n');
fprintf('Capacity MAE : %.4f Ah\n', MAE_capacity);
fprintf('Retention MAE: %.4f\n\n',  MAE_retention);

%% ── Plot ─────────────────────────────────────────────────────────────────────
sim_legend = sprintf('Simulation: N=%g  dOCV=%.5f  dQ=%.2f  dR0=%.2f  dR1=%.2f  dR2=%.2f', ...
    cfg.N, cfg.dOCV, cfg.dQ, cfg.dR0, cfg.dR1, cfg.dR2);

figure;

subplot(1,2,1);
plot(q_exp(:,1),           q_exp(:,2),           'b-',  'LineWidth', 2); hold on;
plot(q_sim_discharge(:,1), q_sim_discharge(:,2),  'r--', 'LineWidth', 2);
xlabel('Cycles'); ylabel('Capacity (Ah)');
title(sprintf('Capacity vs Cycles\nMAE = %.4f Ah', MAE_capacity));
legend('Experimental', sim_legend, 'Location', 'best');
grid on;

subplot(1,2,2);
plot(retention_exp(:,1), retention_exp(:,2), 'b-',  'LineWidth', 2); hold on;
plot(retention_sim(:,1), retention_sim(:,2), 'r--', 'LineWidth', 2);
xlabel('Cycles'); ylabel('Capacity Retention');
title(sprintf('Capacity Retention vs Cycles\nMAE = %.4f', MAE_retention));
legend('Experimental', sim_legend, 'Location', 'best');
ylim([0.7, 1]); grid on;
