function cfg = config()

%% ── File Paths ───────────────────────────────────────────────────────────────
script_dir     = fileparts(mfilename('fullpath'));        % .../Modeling/CycleLifePrediction
cfg.DATA_ROOT  = fileparts(fileparts(script_dir));        % project root: two levels up

%% ── Simulink Model ───────────────────────────────────────────────────────────
cfg.model_name = 'CyclingAgeing';

%% ── Simulation Temperature ───────────────────────────────────────────────────
cfg.T_sim = 25;  
%% ── Battery Nominal Parameters ───────────────────────────────────────────────
cfg.Qnom      = 230;   % Nominal capacity (Ah)
cfg.C_rate    = 0.33;     % C-rate

cfg.voltage_upper_limit = 3.65;
cfg.voltage_lower_limit = 2.5;
cfg.soc_upper_limit = 1.0;   % Charge cut-off  (relay → discharge)
cfg.soc_lower_limit = 0.0;   % Discharge cut-off (relay → charge)
cfg.init_SOC        = 0.0;   % Start at lower SOC bound

% Sync output directory with target temperature and SOC window
soc_lo_pct = round(cfg.soc_lower_limit * 100);
soc_hi_pct = round(cfg.soc_upper_limit * 100);
c_rate_tag = strrep(sprintf('C%.2f', cfg.C_rate), '.', 'p');
cfg.save_dir = fullfile(script_dir, sprintf('1C-CCCV-%d-SOC%d_%d-%s', cfg.T_sim, soc_lo_pct, soc_hi_pct, c_rate_tag));

%% ── Experimental Cycle Data ──────────────────────────────────────────────────
cfg.t_exp = 6.7434e+07;   % 1 year placeholder
cfg.Battery_capacity = 230;

cfg.CC = cfg.Qnom * cfg.C_rate;   % Charge/discharge current (A)

%% ── OCV Lookup Table (29-point, temperature-interpolated) ────────────────────
run(fullfile(cfg.DATA_ROOT, 'OCV', 'ocv_config.m'));
ocv_interp = @(SOC_query, T) interp2( ...
    SOC_points ./ 100, OCV_temps, OCV_charge, ...
    SOC_query(:)', T, ...
    'linear');

% 29-point SOC grid: denser near 0% and 100% to resolve OCV curvature.
cfg.SOCs = [linspace(0, 0.09, 10), linspace(0.1, 0.9, 9), linspace(0.91, 1, 10)];
cfg.OCVs = ocv_interp(cfg.SOCs, cfg.T_sim);

% RC values
RC_FILE = load('BatteryParameterization_spesession.mat');
RC_PARAM_VALUES = RC_FILE.SDOSessionData.Data.Workspace.LocalWorkspace.EstimatedParams_1.Parameters;
cfg.R0_charge      = RC_PARAM_VALUES(1);
cfg.R0_discharge   = RC_PARAM_VALUES(2);
cfg.R1_charge      = RC_PARAM_VALUES(3);
cfg.R1_discharge   = RC_PARAM_VALUES(4);
cfg.R2_charge      = RC_PARAM_VALUES(5);
cfg.R2_discharge   = RC_PARAM_VALUES(6);
cfg.tau1_charge    = RC_PARAM_VALUES(7);
cfg.tau1_discharge = RC_PARAM_VALUES(8);
cfg.tau2_charge    = RC_PARAM_VALUES(9);
cfg.tau2_discharge = RC_PARAM_VALUES(10);

%% ── Cycle Ageing Parameters ──────────────────────────────────────────────────
CYCLE_FILE  = load(fullfile(script_dir, 'CycleAgeingParams.mat'));
CYCLE_PARAM_VALUES = CYCLE_FILE.CycleAgeingParams;
cfg.N    = CYCLE_PARAM_VALUES(1) / (cfg.soc_upper_limit - cfg.soc_lower_limit);
cfg.dOCV = CYCLE_PARAM_VALUES(2);
cfg.dR0  = CYCLE_PARAM_VALUES(3);
cfg.dR1  = CYCLE_PARAM_VALUES(4);
cfg.dR2  = CYCLE_PARAM_VALUES(5);
cfg.dQ   = CYCLE_PARAM_VALUES(6);   % 25 degC capacity fade rate (%/cycle)
%% ── Monte Carlo Settings ─────────────────────────────────────────────────────
cfg.num_simulations = 20;

cfg.mc = struct( ...
    'N',    struct('std', 0,             'lo', 0,         'hi', cfg.N + 10), ... % fixed: well-constrained by cycle count
    'dOCV', struct('std', cfg.dOCV*0.05, 'lo', 0,         'hi', cfg.dOCV*2), ... % ±5%  OCV drift coefficient
    'dR0',  struct('std', cfg.dR0*0.1,   'lo', 0,         'hi', 20), ...          % ±10% series resistance growth
    'dQ',   struct('std', cfg.dQ*0.1,    'lo', cfg.dQ*2,  'hi', 0), ...           % ±10% capacity fade (dQ<0, so lo<hi when negated)
    'dR1',  struct('std', cfg.dR1*0.1,   'lo', 0,         'hi', 20), ...          % ±10% R1 growth
    'dR2',  struct('std', cfg.dR2*0.1,   'lo', 0,         'hi', 20)  ...          % ±10% R2 growth
);

end
