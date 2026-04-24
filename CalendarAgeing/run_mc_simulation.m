clc; clear;
setenv('TMP', 'D:\MATLAB\temp');
clear tempdir;
fprintf('Temp dir: %s\n', tempdir);

%% ── Load Configuration ───────────────────────────────────────────────────────
cfg = config();

if ~exist(cfg.save_dir, 'dir'), mkdir(cfg.save_dir); end

%% ── Unpack Fixed Parameters for parfor Broadcast ────────────────────────────
model_name           = cfg.model_name;
num_simulations      = cfg.num_simulations;
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

%% ── Generate Monte Carlo Parameter Samples ───────────────────────────────────
fprintf('Generating %d parameter sets...\n', num_simulations);

param_names = {'N','dOCV','dR0','dQ','dR1','dR2','bR','cR','dR','aR','bC','cC','dC','aC'};
param_nominals = [cfg.N, cfg.dOCV, cfg.dR0, cfg.dQ, cfg.dR1, cfg.dR2, ...
                  cfg.bR, cfg.cR,  cfg.dR,  cfg.aR, cfg.bC, cfg.cC, cfg.dC, cfg.aC];

param_samples = struct();
for k = 1:numel(param_names)
    name    = param_names{k};
    nominal = param_nominals(k);
    mc      = cfg.mc.(name);
    if strcmp(name, 'N')
        raw = round(nominal + mc.std * randn(num_simulations, 1));
    else
        raw = nominal + mc.std * randn(num_simulations, 1);
    end
    param_samples.(name) = max(mc.lo, min(mc.hi, raw));
end

% Extract to plain arrays for parfor slicing
sN    = param_samples.N;
sdOCV = param_samples.dOCV;
sdR0  = param_samples.dR0;
sdQ   = param_samples.dQ;
sdR1  = param_samples.dR1;
sdR2  = param_samples.dR2;
sbR   = param_samples.bR;
scR   = param_samples.cR;
sdR   = param_samples.dR;
saR   = param_samples.aR;
sbC   = param_samples.bC;
scC   = param_samples.cC;
sdC   = param_samples.dC;
saC   = param_samples.aC;

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

% Flatten (i_sim, t) pairs into a single job index so all time-steps across
% all samples run concurrently, eliminating the sequential inner loop.
n_jobs        = num_simulations * num_steps;
flat_capacity = nan(n_jobs, 1);
flat_errors   = false(n_jobs, 1);
flat_messages = cell(n_jobs, 1);
flat_times    = zeros(n_jobs, 1);

fprintf('Starting Monte Carlo with %d jobs (%d sims x %d steps)...\n', ...
    n_jobs, num_simulations, num_steps);
fprintf('=========================================\n');
total_tic = tic;

parfor job = 1:n_jobs
    i_sim = ceil(job / num_steps);
    t     = mod(job - 1, num_steps) + 1;
    iter_tic = tic;

    simIn = Simulink.SimulationInput(model_name);

    simIn = simIn.setVariable('N',           sN(i_sim));
    simIn = simIn.setVariable('dOCV',        sdOCV(i_sim));
    simIn = simIn.setVariable('dR0',         sdR0(i_sim));
    simIn = simIn.setVariable('dQ',          sdQ(i_sim));
    simIn = simIn.setVariable('dR1',         sdR1(i_sim));
    simIn = simIn.setVariable('dR2',         sdR2(i_sim));
    simIn = simIn.setVariable('bR',          sbR(i_sim));
    simIn = simIn.setVariable('cR',          scR(i_sim));
    simIn = simIn.setVariable('dR',          sdR(i_sim));
    simIn = simIn.setVariable('aR',          saR(i_sim));
    simIn = simIn.setVariable('bC',          sbC(i_sim));
    simIn = simIn.setVariable('cC',          scC(i_sim));
    simIn = simIn.setVariable('dC',          sdC(i_sim));
    simIn = simIn.setVariable('aC',          saC(i_sim));
    simIn = simIn.setVariable('storage_soc', storage_soc);
    simIn = simIn.setVariable('storage_temp',storage_temp);
    simIn = simIn.setVariable('period',      t * period);

    simIn = simIn.setVariable('CC',                  CC);
    simIn = simIn.setVariable('C_rate',              C_rate);
    simIn = simIn.setVariable('voltage_upper_limit', voltage_upper_limit);
    simIn = simIn.setVariable('voltage_lower_limit', voltage_lower_limit);
    simIn = simIn.setVariable('init_SOC',            init_SOC);
    simIn = simIn.setVariable('t_exp',               t_exp);
    simIn = simIn.setVariable('num_cycles',          num_cycles);
    simIn = simIn.setVariable('Battery_capacity',    Battery_capacity);
    simIn = simIn.setVariable('Qnom',                Qnom);
    simIn = simIn.setVariable('SOCs',                SOCs);
    simIn = simIn.setVariable('OCVs',                OCVs);
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

    try
        sim_out       = sim(simIn);
        capacity_data = sim_out.q_sim.Data;
        zc_discharge  = find(sim_out.discharge_index.Data > 0);
        zc_charge     = find(sim_out.charge_index.Data    > 0);
        n_cycles      = min(length(zc_charge), length(zc_discharge));

        if n_cycles > 0
            flat_capacity(job) = capacity_data(zc_charge(n_cycles));
        else
            flat_capacity(job) = 0;
        end
    catch ME
        fullMsg = ME.message;
        for k = 1:length(ME.cause)
            fullMsg = [fullMsg ' ' ME.cause{k}.message]; %#ok<AGROW>
        end
        if contains(fullMsg, 'Cell capacity after calendar aging must be greater than 0%', 'IgnoreCase', true)
            flat_capacity(job) = 0;
        else
            flat_errors(job)   = true;
            flat_messages{job} = fullMsg;
            flat_capacity(job) = NaN;
        end
    end

    flat_times(job) = toc(iter_tic);
end

total_time = toc(total_tic);

%% ── Aggregate Per-Simulation Trajectories ────────────────────────────────────
for i = 1:num_simulations
    t_idx = (i - 1) * num_steps + (1:num_steps);
    traj  = flat_capacity(t_idx);

    sim_time_results(i) = sum(flat_times(t_idx));

    if any(flat_errors(t_idx))
        first_err         = find(flat_errors(t_idx), 1);
        error_flags(i)    = true;
        error_messages{i} = flat_messages{t_idx(first_err)};
        final_capacity_results(i) = NaN;
        continue;
    end

    capacity_results{i}       = [(1:num_steps)', traj];
    retention_sim             = capacity_results{i};
    retention_sim(:,2)        = retention_sim(:,2) ./ Qnom;
    retention_results{i}      = retention_sim;
    final_capacity_results(i) = traj(end);
end

%% ── Summary ──────────────────────────────────────────────────────────────────
fprintf('=========================================\n');
fprintf('Monte Carlo complete.\n');
fprintf('  Total time    : %.2f s\n', total_time);
fprintf('  Avg per sim   : %.2f s\n', mean(sim_time_results(~error_flags)));
fprintf('  Successful    : %d / %d\n\n', sum(~error_flags), num_simulations);

fprintf('Parameter Statistics:\n');
for k = 1:numel(param_names)
    name = param_names{k};
    fprintf('  %-5s  mean = %12.6g  std = %12.6g\n', name, ...
        mean(param_samples.(name)), std(param_samples.(name)));
end
fprintf('\nFinal Capacity (Ah):\n');
fprintf('  Mean = %.4f  Std = %.4f  Min = %.4f  Max = %.4f\n\n', ...
    mean(final_capacity_results(~error_flags)), std(final_capacity_results(~error_flags)), ...
    min(final_capacity_results(~error_flags)), max(final_capacity_results(~error_flags)));

%% ── Save Results ─────────────────────────────────────────────────────────────
results = struct( ...
    'N',              param_samples.N,    ...
    'dOCV',           param_samples.dOCV, ...
    'dR0',            param_samples.dR0,  ...
    'dQ',             param_samples.dQ,   ...
    'dR1',            param_samples.dR1,  ...
    'dR2',            param_samples.dR2,  ...
    'bR',             param_samples.bR,   ...
    'cR',             param_samples.cR,   ...
    'dR',             param_samples.dR,   ...
    'aR',             param_samples.aR,   ...
    'bC',             param_samples.bC,   ...
    'cC',             param_samples.cC,   ...
    'dC',             param_samples.dC,   ...
    'aC',             param_samples.aC,   ...
    'capacity',       {capacity_results},  ...
    'retention',      {retention_results}, ...
    'final_capacity', final_capacity_results, ...
    'sim_time',       sim_time_results,   ...
    'errors',         error_flags,        ...
    'error_messages', {error_messages}   ...
);

mat_file = fullfile(cfg.save_dir,  sprintf('monte_carlo_parallel_results.mat'));
save(mat_file, 'results', 'cfg', 'num_simulations', 'total_time');

summary_table = table( ...
    results.N, results.dOCV, results.dR0, results.dQ, results.dR1, results.dR2, ...
    results.bR, results.cR,  results.dR,  results.aR, ...
    results.bC, results.cC,  results.dC,  results.aC, ...
    results.final_capacity, results.errors, ...
    'VariableNames', {'N','dOCV','dR0','dQ','dR1','dR2', ...
                      'bR','cR','dR','aR','bC','cC','dC','aC', ...
                      'Final_Capacity','Error'});
csv_file = fullfile(cfg.save_dir, ...
    sprintf('monte_carlo_parallel_summary.csv'));
writetable(summary_table, csv_file);
fprintf('Results saved to: %s\n', cfg.save_dir);

%% ── Performance Summary ──────────────────────────────────────────────────────
poolobj = gcp('nocreate');
n_workers = 0;
if ~isempty(poolobj), n_workers = poolobj.NumWorkers; end
fprintf('\nPerformance:\n');
fprintf('  Workers           : %d\n',    n_workers);
fprintf('  Total time        : %.2f s\n', total_time);
fprintf('  Avg time / sim    : %.2f s\n', mean(sim_time_results(~error_flags)));
fprintf('  Est. sequential   : %.2f s\n', sum(sim_time_results));
fprintf('  Speedup           : %.2fx\n',  sum(sim_time_results) / total_time);
