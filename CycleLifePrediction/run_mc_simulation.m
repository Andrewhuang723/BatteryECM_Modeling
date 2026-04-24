clc; clear;

%% ── MATLAB Temp Directory (machine-specific; keep out of config.m) ───────────
setenv('TMP', 'D:\MATLAB\temp');
clear tempdir;   % Force re-evaluation of tempdir after TMP change
fprintf('Temp dir: %s\n', tempdir);

%% ── Load Configuration ───────────────────────────────────────────────────────
cfg = config();

% Ensure output directory exists
if ~exist(cfg.save_dir, 'dir'), mkdir(cfg.save_dir); end

%% ── Unpack Fixed Parameters for parfor Broadcast ────────────────────────────
% All variables used inside parfor must be plain scalars or arrays —
% not struct fields — so the MATLAB parfor classifier can verify them.
model_name          = cfg.model_name;
num_simulations     = cfg.num_simulations;

Battery_capacity = cfg.Battery_capacity;
CC               = cfg.CC;
C_rate           = cfg.C_rate;
voltage_upper_limit = cfg.voltage_upper_limit;   % Charge cut-off SOC  (DoD 70%)
voltage_lower_limit = cfg.voltage_lower_limit;   % Discharge cut-off SOC (DoD 70%)
init_SOC         = cfg.init_SOC;
t_exp               = cfg.t_exp;
Qnom                = cfg.Qnom;
SOCs             = cfg.SOCs;
OCVs             = cfg.OCVs;
R0_charge           = cfg.R0_charge;
R0_discharge        = cfg.R0_discharge;
R1_charge           = cfg.R1_charge;
R1_discharge        = cfg.R1_discharge;
R2_charge           = cfg.R2_charge;
R2_discharge        = cfg.R2_discharge;
tau1_charge         = cfg.tau1_charge;
tau1_discharge      = cfg.tau1_discharge;
tau2_charge         = cfg.tau2_charge;
tau2_discharge      = cfg.tau2_discharge;

%% ── Parameter Variation Configuration ───────────────────────────────────────
param_names   = {'N', 'dOCV', 'dR0', 'dQ', 'dR1', 'dR2'};
param_nominals = [cfg.N, cfg.dOCV, cfg.dR0, cfg.dQ, cfg.dR1, cfg.dR2];

%% ── Generate Monte Carlo Parameter Samples ───────────────────────────────────
fprintf('Generating %d parameter sets...\n', num_simulations);

param_samples = struct();
for k = 1:numel(param_names)
    name    = param_names{k};
    nominal = param_nominals(k);
    mc      = cfg.mc.(name);
    raw     = nominal + mc.std * randn(num_simulations, 1);
    param_samples.(name) = max(mc.lo, min(mc.hi, raw));
end

% Extract sample arrays to plain variables for clean parfor slicing
sN    = param_samples.N;
sdOCV = param_samples.dOCV;
sdR0  = param_samples.dR0;
sdQ   = param_samples.dQ;
sdR1  = param_samples.dR1;
sdR2  = param_samples.dR2;

%% ── Start Parallel Pool ──────────────────────────────────────────────────────
poolobj = gcp('nocreate');
if isempty(poolobj)
    parpool;
    fprintf('Parallel pool started.\n');
else
    fprintf('Parallel pool running with %d workers.\n', poolobj.NumWorkers);
end

%% ── Parallel Monte Carlo Simulation ─────────────────────────────────────────
capacity_results       = cell(num_simulations, 1);
retention_results      = cell(num_simulations, 1);
final_capacity_results = zeros(num_simulations, 1);
sim_time_results       = zeros(num_simulations, 1);
error_flags            = false(num_simulations, 1);
error_messages         = cell(num_simulations, 1);

fprintf('Starting Monte Carlo with %d iterations...\n', num_simulations);
fprintf('=========================================\n');
total_tic = tic;

parfor i = 1:num_simulations
    fprintf('  Running simulation %d / %d\n', i, num_simulations);
    iter_tic = tic;

    % Build SimulationInput with this iteration's sampled ageing parameters
    simIn = Simulink.SimulationInput(model_name);
    simIn = simIn.setVariable('N',    sN(i));
    simIn = simIn.setVariable('dOCV', sdOCV(i));
    simIn = simIn.setVariable('dR0',  sdR0(i));
    simIn = simIn.setVariable('dQ',   sdQ(i));
    simIn = simIn.setVariable('dR1',  sdR1(i));
    simIn = simIn.setVariable('dR2',  sdR2(i));

    % Fixed model parameters (broadcast)
    simIn = simIn.setVariable('CC',        CC);
    simIn = simIn.setVariable('C_rate',    C_rate);
    simIn = simIn.setVariable('voltage_upper_limit', voltage_upper_limit);
    simIn = simIn.setVariable('voltage_lower_limit', voltage_lower_limit);
    simIn = simIn.setVariable('init_SOC',  init_SOC);
    simIn = simIn.setVariable('t_exp',               t_exp);
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

    % Run simulation
    try
        sim_out = sim(simIn);

        % Extract per-cycle capacity at charge/discharge zero-crossing events
        capacity_data = sim_out.q_sim.Data;
        zc_charge    = find(sim_out.zeroCrossing_charge.Data    > 0);
        zc_discharge = find(sim_out.zeroCrossing_discharge.Data > 0);
        n_cycles     = min(length(zc_charge), length(zc_discharge));
        zc_charge    = zc_charge(1:n_cycles);
        zc_discharge = zc_discharge(1:n_cycles);

        cycle_idx    = (0:n_cycles-1)';
        q_sim_charge = [cycle_idx, capacity_data(zc_charge)];

        retention_sim      = q_sim_charge;
        retention_sim(:,2) = retention_sim(:,2) ./ retention_sim(1,2);

        capacity_results{i}       = q_sim_charge;
        retention_results{i}      = retention_sim;
        final_capacity_results(i) = q_sim_charge(end, 2);
    catch ME
        error_flags(i)            = true;
        error_messages{i}         = ME.message;
        final_capacity_results(i) = NaN;
        fprintf('  ERROR in sim %d: %s\n', i, ME.message);
    end
    sim_time_results(i) = toc(iter_tic);
end

total_time = toc(total_tic);

%% ── Monte Carlo Summary ──────────────────────────────────────────────────────
fprintf('=========================================\n');
fprintf('Monte Carlo complete.\n');
fprintf('  Total time    : %.2f s\n', total_time);
fprintf('  Avg per sim   : %.2f s\n', mean(sim_time_results(~error_flags)));
fprintf('  Successful    : %d / %d\n\n', sum(~error_flags), num_simulations);

valid = ~error_flags & ~isnan(final_capacity_results);
fprintf('Parameter Statistics:\n');
for k = 1:numel(param_names)
    name = param_names{k};
    fprintf('  %-5s  mean = %10.6f  std = %10.6f\n', name, ...
        mean(param_samples.(name)), std(param_samples.(name)));
end
fprintf('\nFinal Capacity (Ah):\n');
fprintf('  Mean = %.4f  Std = %.4f  Min = %.4f  Max = %.4f\n\n', ...
    mean(final_capacity_results(valid)), std(final_capacity_results(valid)), ...
    min(final_capacity_results(valid)), max(final_capacity_results(valid)));

%% ── Save Monte Carlo Results ─────────────────────────────────────────────────
results = struct( ...
    'N',              param_samples.N,    ...
    'dOCV',           param_samples.dOCV, ...
    'dR0',            param_samples.dR0,  ...
    'dQ',             param_samples.dQ,   ...
    'dR1',            param_samples.dR1,  ...
    'dR2',            param_samples.dR2,  ...
    'capacity',       {capacity_results},  ...
    'retention',      {retention_results}, ...
    'final_capacity', final_capacity_results, ...
    'sim_time',       sim_time_results,   ...
    'errors',         error_flags,        ...
    'error_messages', {error_messages}    ...
);

save(fullfile(cfg.save_dir, 'monte_carlo_parallel_results.mat'), ...
    'results', 'cfg', 'num_simulations', 'total_time');

summary_table = table( ...
    results.N, results.dOCV, results.dR0, results.dQ, results.dR1, results.dR2, ...
    results.final_capacity, results.errors, ...
    'VariableNames', {'N','dOCV','dR0','dQ','dR1','dR2','Final_Capacity','Error'});
writetable(summary_table, fullfile(cfg.save_dir, 'monte_carlo_parallel_summary.csv'));
fprintf('Monte Carlo results saved to: %s\n\n', cfg.save_dir);

%% ── Performance Summary ──────────────────────────────────────────────────────
poolobj = gcp('nocreate');
n_workers = 0;
if ~isempty(poolobj), n_workers = poolobj.NumWorkers; end
fprintf('Performance:\n');
fprintf('  Workers           : %d\n',    n_workers);
fprintf('  Total time        : %.2f s\n', total_time);
fprintf('  Avg time / sim    : %.2f s\n', mean(sim_time_results(~error_flags)));
fprintf('  Est. sequential   : %.2f s\n', sum(sim_time_results));
fprintf('  Speedup           : %.2fx\n\n', sum(sim_time_results) / total_time);

%% ═══════════════════════════════════════════════════════════════════════════
%  ── Confidence Interval Analysis ──────────────────────────────────────────
%  (Runs immediately after MC; uses results already in memory)
%% ═══════════════════════════════════════════════════════════════════════════

%% ── Build Matrices on Common Cycle Grid ──────────────────────────────────────
valid_cells   = ~cellfun(@isempty, results.retention);
max_cycles    = min(cellfun(@(r) size(r,1), results.retention(valid_cells)));
common_cycles = (0:max_cycles-1)';

retention_matrix = build_matrix(results.retention, num_simulations, common_cycles);
capacity_matrix  = build_matrix(results.capacity,  num_simulations, common_cycles);

%% ── Compute 95% Confidence Intervals ────────────────────────────────────────
[mean_ret, ci_lo_ret, ci_hi_ret] = compute_ci(retention_matrix);
[mean_cap, ci_lo_cap, ci_hi_cap] = compute_ci(capacity_matrix);

%% ── Save CI Results ──────────────────────────────────────────────────────────
ci_data = struct( ...
    'common_cycles',         common_cycles, ...
    'mean_retention',        mean_ret,      ...
    'ci_95_upper_retention', ci_hi_ret,     ...
    'ci_95_lower_retention', ci_lo_ret,     ...
    'mean_capacity',         mean_cap,  ...
    'ci_95_upper_capacity',  ci_hi_cap, ...
    'ci_95_lower_capacity',  ci_lo_cap  ...
);
save(fullfile(cfg.save_dir, 'confidence_interval_results.mat'), 'ci_data');

ci_table = table(common_cycles, mean_ret, ci_lo_ret, ci_hi_ret, ...
                 mean_cap, ci_lo_cap, ci_hi_cap, ...
    'VariableNames', {'Cycle','Mean_Retention','CI95_Lower_Retention','CI95_Upper_Retention', ...
                      'Mean_Capacity','CI95_Lower_Capacity','CI95_Upper_Capacity'});
writetable(ci_table, fullfile(cfg.save_dir, 'confidence_interval_data.csv'));

fprintf('CI results saved to: %s\n', cfg.save_dir);

%% ════════════════════════════════════════════════════════════════════════════
%  Local Functions  (MATLAB requires these after all script code)
%% ════════════════════════════════════════════════════════════════════════════

function mat = build_matrix(data_cells, n_sims, common_cycles)
% Interpolate each simulation's curve onto a common cycle grid.
    mat = nan(length(common_cycles), n_sims);
    for i = 1:n_sims
        d = data_cells{i};
        if ~isempty(d) && ~any(isnan(d(:)))
            mat(:,i) = interp1(d(:,1), d(:,2), common_cycles, 'linear', 'extrap');
        end
    end
end

function [mn, lo, hi] = compute_ci(mat)
% Compute mean and 95% confidence interval across simulation columns.
    mn = mean(mat,    2, 'omitnan');
    lo = prctile(mat, 2.5,  2);
    hi = prctile(mat, 97.5, 2);
end

