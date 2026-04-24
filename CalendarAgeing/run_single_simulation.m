clc; clear;

%% ── Load Configuration ───────────────────────────────────────────────────────
cfg = config();

%% ── Unpack Parameters ────────────────────────────────────────────────────────
model_name           = cfg.model_name;
num_steps            = cfg.num_steps;
period               = cfg.period;
Battery_capacity     = cfg.Battery_capacity;
Qnom                 = cfg.Qnom;
CC                   = cfg.CC;
C_rate               = cfg.C_rate;
voltage_upper_limit  = cfg.voltage_upper_limit;
voltage_lower_limit  = cfg.voltage_lower_limit;
init_SOC             = cfg.init_SOC;
t_exp                = cfg.t_exp;
num_cycles           = cfg.num_cycles;
SOCs                 = cfg.SOCs;
OCVs                 = cfg.OCVs;
R0_charge            = cfg.R0_charge;
R0_discharge         = cfg.R0_discharge;
R1_charge            = cfg.R1_charge;
R1_discharge         = cfg.R1_discharge;
R2_charge            = cfg.R2_charge;
R2_discharge         = cfg.R2_discharge;
tau1_charge          = cfg.tau1_charge;
tau1_discharge       = cfg.tau1_discharge;
tau2_charge          = cfg.tau2_charge;
tau2_discharge       = cfg.tau2_discharge;
storage_soc          = cfg.storage_soc;
storage_temp         = cfg.storage_temp;
N                    = cfg.N;
dOCV                 = cfg.dOCV;
dR0                  = cfg.dR0;
dQ                   = cfg.dQ;
dR1                  = cfg.dR1;
dR2                  = cfg.dR2;
bR                   = cfg.bR;
cR                   = cfg.cR;
dR                   = cfg.dR;
aR                   = cfg.aR;
bC                   = cfg.bC;
cC                   = cfg.cC;
dC                   = cfg.dC;
aC                   = cfg.aC;

%% ── Storage Simulation Loop ──────────────────────────────────────────────────
total_storage_periods  = num_steps + 1;
Battery_capacity_data  = zeros(total_storage_periods, 1);
Battery_retention_data = zeros(total_storage_periods, 1);

for i = 0:total_storage_periods-1
    simIn = Simulink.SimulationInput(model_name);

    simIn = simIn.setVariable('dOCV',        dOCV);
    simIn = simIn.setVariable('dR0',         dR0);
    simIn = simIn.setVariable('dQ',          dQ);
    simIn = simIn.setVariable('dR1',         dR1);
    simIn = simIn.setVariable('dR2',         dR2);
    simIn = simIn.setVariable('bR',          bR);
    simIn = simIn.setVariable('cR',          cR);
    simIn = simIn.setVariable('dR',          dR);
    simIn = simIn.setVariable('aR',          aR);
    simIn = simIn.setVariable('bC',          bC);
    simIn = simIn.setVariable('cC',          cC);
    simIn = simIn.setVariable('dC',          dC);
    simIn = simIn.setVariable('aC',          aC);
    simIn = simIn.setVariable('storage_soc', storage_soc);
    simIn = simIn.setVariable('storage_temp',storage_temp);
    simIn = simIn.setVariable('period',      i * period);

    simIn = simIn.setVariable('CC',                  CC);
    simIn = simIn.setVariable('C_rate',              C_rate);
    simIn = simIn.setVariable('voltage_upper_limit', voltage_upper_limit);
    simIn = simIn.setVariable('voltage_lower_limit', voltage_lower_limit);
    simIn = simIn.setVariable('init_SOC',            init_SOC);
    simIn = simIn.setVariable('t_exp',               t_exp);
    simIn = simIn.setVariable('num_cycles',          num_cycles);
    simIn = simIn.setVariable('Battery_capacity',    Battery_capacity);
    simIn = simIn.setVariable('Qnom',                Qnom);
    simIn = simIn.setVariable('SOCs',             SOCs);
    simIn = simIn.setVariable('OCVs',             OCVs);
    simIn = simIn.setVariable('R0_charge',           R0_charge);
    simIn = simIn.setVariable('R0_discharge',        R0_discharge);
    simIn = simIn.setVariable('R1_charge',           R1_charge);
    simIn = simIn.setVariable('R1_discharge',        R1_discharge);
    simIn = simIn.setVariable('R2_charge',           R2_charge);
    simIn = simIn.setVariable('R2_discharge',        R2_discharge);
    simIn = simIn.setVariable('tau1_charge',         tau1_charge);
    simIn = simIn.setVariable('tau1_discharge',      tau1_discharge);
    simIn = simIn.setVariable('tau2_charge',         tau2_charge);
    simIn = simIn.setVariable('tau2_discharge',      tau2_discharge);

    sim_out      = sim(simIn);
    capacity_data = sim_out.q_sim.Data;

    zc_discharge  = find(sim_out.discharge_index.Data > 0);
    zc_charge     = find(sim_out.charge_index.Data    > 0);
    cycle_num_sim = min(length(zc_charge), length(zc_discharge));
    if cycle_num_sim == 0, break; end

    q_charge    = capacity_data(zc_charge(1:cycle_num_sim));
    q_discharge = q_charge - capacity_data(zc_discharge(1:cycle_num_sim));

    Battery_capacity_data(i+1)  = q_charge(end);
    Battery_retention_data(i+1) = q_charge(end) / Battery_capacity_data(1) * 100;
    fprintf('Iteration %d finished: Retention = %.4f%%\n', i, Battery_retention_data(i+1));
end

%% ── Plot ─────────────────────────────────────────────────────────────────────
sim_days = (0:total_storage_periods-1) * period;

figure;
plot(sim_days, Battery_retention_data, '-o', 'LineWidth', 2);
xlabel('Time (days)');
ylabel('Capacity Retention (%)');
title(sprintf('Calendar Ageing: %s', cfg.CONDITION));
grid on;

