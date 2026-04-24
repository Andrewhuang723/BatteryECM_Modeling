clc; clear;

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
simIn = simIn.setVariable('SOCs',             cfg.SOCs);
simIn = simIn.setVariable('OCVs',             cfg.OCVs);

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

%% ── Plot ─────────────────────────────────────────────────────────────────────
figure;
plot(retention_sim(:,1), retention_sim(:,2) * 100, '-', 'LineWidth', 2);
xlabel('Cycle Number');
ylabel('Capacity Retention (%)');
title(sprintf('Cycle Life Prediction (T=%d°C)', cfg.T_sim));
grid on;