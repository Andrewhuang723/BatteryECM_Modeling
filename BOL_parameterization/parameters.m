clc; clear;

%% ── OCV Lookup Table (all temperatures) ─────────────────────────────────────
run('../OCV/ocv_config.m');

ocv_interp = @(SOC_query, T) interp2( ...
    SOC_points ./ 100, OCV_temps, OCV_charge, ...
    SOC_query(:)', T, ...
    'linear');

%% ── Customized data here: ────────────────────────────────────────────────────
T_sim = 35;   % Simulation temperature (°C) — change to any value in [−30, 60]
Qnom = 230;
voltage_upper_limit = 3.65;   % Charge cut-off voltage (V)
voltage_lower_limit = 2.5;    % Discharge cut-off voltage (V)
init_SOC = 0.0;
Battery_capacity = 230;

%% ── Experimental Signals ─────────────────────────────────────────────────────
script_dir = fileparts(mfilename('fullpath'));
bol_csv    = readtable(fullfile(script_dir, 'BOL_data.csv'));
t_exp      = bol_csv.time_s;
i_exp      = bol_csv.current_A;
v_exp      = bol_csv.voltage_V;


%% ── OCV Table (29-point, interpolated at T_sim) ──────────────────────────────
SOCs = [linspace(0, 0.09, 10), linspace(0.1, 0.9, 9), linspace(0.91, 1, 10)];
OCVs = ocv_interp(SOCs, T_sim);

%% ── Initial Guesses for RC Parameters ───────────────────────────────────────
R0_charge      = 1e-4 * ones(size(OCVs));
R0_discharge   = 1e-4 * ones(size(OCVs));
R1_charge      = 1e-4 * ones(size(OCVs));
R1_discharge   = 1e-4 * ones(size(OCVs));
R2_charge      = 1e-4 * ones(size(OCVs));
R2_discharge   = 1e-4 * ones(size(OCVs));
tau1_charge    = 5e2  * ones(size(OCVs));
tau1_discharge = 5e2  * ones(size(OCVs));
tau2_charge    = 5e2  * ones(size(OCVs));
tau2_discharge = 5e2  * ones(size(OCVs));

%% ── Optimiser Bounds ─────────────────────────────────────────────────────────
lb_R   = 1e-5;
ub_R   = 1e1;
lb_tau = 1e-1;
ub_tau = 1e3;
