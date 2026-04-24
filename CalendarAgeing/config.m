function cfg = config()

%% ── Simulink Model ───────────────────────────────────────────────────────────
cfg.model_name = 'CalendarAgeing';

%% ── Storage Condition ────────────────────────────────────────────────────────
cfg.T_storage   = 25;    % Storage temperature (°C)
cfg.SOC_storage = 100;    % Storage SOC (%)
cfg.period      = 365;
cfg.num_steps   = 11;

cfg.CONDITION = sprintf('%d%%SOC_%ddegC', cfg.SOC_storage, cfg.T_storage);
script_dir    = fileparts(mfilename('fullpath'));
cfg.save_dir  = fullfile(script_dir, cfg.CONDITION);

%% ── Battery Nominal Parameters ───────────────────────────────────────────────
cfg.Qnom                = 230;
cfg.C_rate              = 1.0;
cfg.Battery_capacity    = 230;
cfg.CC                  = cfg.Qnom * cfg.C_rate;
cfg.voltage_upper_limit = 3.65;
cfg.voltage_lower_limit = 2.5;
cfg.init_SOC            = 0;
cfg.t_exp               = 50000;
cfg.num_cycles          = 1;
cfg.storage_temp        = cfg.T_storage + 273.15;   % Kelvin
cfg.storage_soc         = cfg.SOC_storage / 100;    % Decimal

%% ── OCV Lookup Table (29-point, temperature-interpolated) ────────────────────
run('../OCV/ocv_config.m');
ocv_interp = @(SOC_query, T) interp2( ...
    SOC_points ./ 100, OCV_temps, OCV_charge, ...
    SOC_query(:)', T, ...
    'linear');

cfg.SOCs = [linspace(0, 0.09, 10), linspace(0.1, 0.9, 9), linspace(0.91, 1, 10)];
cfg.OCVs = ocv_interp(cfg.SOCs, cfg.T_storage);

% RC values
RC_FILE = load('../BOL_parameterization/1C-CCCV-25/ECMParams.mat');
RC_PARAM_VALUES = RC_FILE.SDOSessionData.Data.Workspace.LocalWorkspace.EstimatedParams_1.Parameters;
cfg.R0_charge      = RC_PARAM_VALUES(1).Value;
cfg.R0_discharge   = RC_PARAM_VALUES(2).Value;
cfg.R1_charge      = RC_PARAM_VALUES(3).Value;
cfg.R1_discharge   = RC_PARAM_VALUES(4).Value;
cfg.R2_charge      = RC_PARAM_VALUES(5).Value;
cfg.R2_discharge   = RC_PARAM_VALUES(6).Value;
cfg.tau1_charge    = RC_PARAM_VALUES(7).Value;
cfg.tau1_discharge = RC_PARAM_VALUES(8).Value;
cfg.tau2_charge    = RC_PARAM_VALUES(9).Value;
cfg.tau2_discharge = RC_PARAM_VALUES(10).Value;

%% ── Cycle Ageing Parameters ──────────────────────────────────────────────────
CYCLE_FILE = load('../CycleLifePrediction/CycleAgeingParams.mat');
CYCLE_PARAM_VALUES = CYCLE_FILE.CycleAgeingParams;
cfg.N    = CYCLE_PARAM_VALUES(1);
cfg.dOCV = CYCLE_PARAM_VALUES(2);
cfg.dR0  = CYCLE_PARAM_VALUES(3);
cfg.dR1  = CYCLE_PARAM_VALUES(4);
cfg.dR2  = CYCLE_PARAM_VALUES(5);
cfg.dQ   = CYCLE_PARAM_VALUES(6);   % 25 degC capacity fade rate (%/cycle)


%% ── Calendar Ageing Coefficients ─────────────────────────────────────────────
CALENDAR_FILE = load('CalendarAgeingParams.mat');
CALENDAR_PARAM_VALUES = CALENDAR_FILE.CalendarAgeingParams;
cfg.bR = CALENDAR_PARAM_VALUES.bR;
cfg.cR = CALENDAR_PARAM_VALUES.cR;
cfg.dR = CALENDAR_PARAM_VALUES.dR;
cfg.aR = CALENDAR_PARAM_VALUES.aR;
cfg.bC = CALENDAR_PARAM_VALUES.bC;
cfg.cC = CALENDAR_PARAM_VALUES.cC;
cfg.dC = CALENDAR_PARAM_VALUES.dC;
cfg.aC = CALENDAR_PARAM_VALUES.aC;

cfg.Q_E = 1.602176634e-19;
cfg.K_B = 1.380649e-23;

%% ── Monte Carlo Settings ─────────────────────────────────────────────────────
cfg.num_simulations = 25;

cfg.mc = struct( ...
    'N',    struct('std', 0,                'lo', 1,           'hi', cfg.N),    ...
    'dOCV', struct('std', 0,                'lo', 0,           'hi', cfg.dOCV), ...
    'dR0',  struct('std', 0,                'lo', 0,           'hi', cfg.dR0),  ...
    'dQ',   struct('std', 0,                'lo', cfg.dQ,      'hi', 0),        ...
    'dR1',  struct('std', 0,                'lo', 0,           'hi', cfg.dR1),  ...
    'dR2',  struct('std', 0,                'lo', 0,           'hi', cfg.dR2),  ...
    'bR',   struct('std', 0,                'lo', cfg.bR/2,    'hi', cfg.bR*2), ...
    'cR',   struct('std', 0,                'lo', 0,           'hi', cfg.cR*2), ...
    'dR',   struct('std', 0,                'lo', cfg.dR/2,    'hi', cfg.dR*2), ...
    'aR',   struct('std', cfg.aR * 0.01,    'lo', cfg.aR/2,    'hi', cfg.aR*2), ...
    'bC',   struct('std', cfg.bC * 0.05,    'lo', cfg.bC/2,    'hi', cfg.bC*2), ...
    'cC',   struct('std', cfg.cC * 0.05,    'lo', cfg.cC/2,    'hi', cfg.cC*2), ...
    'dC',   struct('std', 0,                'lo', cfg.dC/2,    'hi', cfg.dC*2), ...
    'aC',   struct('std', cfg.aC * 0.01,    'lo', cfg.aC/2,    'hi', cfg.aC*2)  ...
);

end
