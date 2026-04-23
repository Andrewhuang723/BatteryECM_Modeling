# 230Ah DV4 Battery Ageing Model

Physics-based RC equivalent circuit model (ECM) for predicting cycle and calendar ageing of a 230Ah lithium-ion cell (DV4). Implements a 2-RC-branch ECM with Monte Carlo uncertainty quantification across multiple temperatures.

## Directory Structure

```
20260127_230Ah/
├── Cycling/                    # Experimental cycling data (CSV)
│   ├── PRE-C RT CYCLE/         # 25°C, 1C-rate, 3500 cycles
│   └── PRE-C HT CYCLE/         # 45°C, 1C-rate, 1200 cycles
├── OCV/                        # OCV vs SOC lookup tables (XLSX, 25°C & 45°C)
├── Storage/                    # Calendar ageing experimental data
└── Modeling/
    ├── BOL_parameterization/   # RC parameter fitting (SDO optimization)
    ├── CycleLifePrediction/    # Cycle ageing simulation + Monte Carlo
    └── CalendarAgeing/         # Storage degradation simulation
```

## Quick Start

### 1. BOL RC Parameterization
Fit R0, R1, R2, τ1, τ2 against beginning-of-life experimental data:
```matlab
cd Modeling/BOL_parameterization
BOL_Preprocess_230Ah        % Extract BOL cycle, set optimizer bounds
% Open BatteryParameterization.slx → run SDO optimization
RC_values_plot              % Visualize fitted parameters vs SOC
voltage_error_analysis      % Compute RMSE/MAE/MAPE
```
Fitted parameters are saved as `BatteryParameterization_spesession.mat` in `1C-CCCV/` (25°C) and `1C-CCCV-HT/` (45°C).

### 2. Cycle Life Prediction
```matlab
cd Modeling/CycleLifePrediction

% Single deterministic run:
run_single_simulation       % Runs CyclingAgeing.slx, prints MAE vs experimental

% Full Monte Carlo (20 samples, 95% CI):
run_monte_carlo             % Parallel runs, saves results + CI plots
```
Results saved to `1C-CCCV-35/` (or whichever `save_dir` is set in `config.m`).

### 3. Calendar (Storage) Ageing
```matlab
cd Modeling/CalendarAgeing
calendar_ageing_parameters  % Load experimental recovery data
run_calendar_ageing         % Iterate storage periods
% OR
monte_carlo_parallel        % MC pipeline for storage conditions
```
Results in `100%SOC_25degC/`, `100%SOC_35degC/`, etc.

## Configuration

All cycle life parameters are controlled by a single file:

**`Modeling/CycleLifePrediction/config.m`**

Key settings to change:
| Parameter | Default | Description |
|-----------|---------|-------------|
| `cfg.T_sim` | 35 | Simulation temperature (°C) — interpolates between 25°C and 45°C fits |
| `cfg.save_dir` | `1C-CCCV-35` | Output directory for results |
| `cfg.N` | 1.50 | Power-law ageing exponent |
| `cfg.dQ` | interpolated | Capacity fade rate (%/cycle) |
| `cfg.dR0/dR1/dR2` | — | Resistance growth rates |
| `cfg.num_simulations` | 20 | Monte Carlo sample count |

## Model Overview

```
Experimental CSV → BOL Parameterization (BatteryParameterization.slx + SDO)
                         ↓
                  RC params (.mat)
                         ↓
                    config.m  ←── OCV tables, ageing rates, MC bounds
                         ↓
                 CyclingAgeing.slx
               (2-RC ECM + ageing model)
                         ↓
            run_single_simulation  OR  run_monte_carlo (parfor)
                         ↓
               MAE metrics + capacity fade plots
               Results: .mat + .csv in save_dir
```

**Ageing variables** updated per cycle: capacity (`dQ`), OCV offset (`dOCV`), series resistance (`dR0`), RC resistances (`dR1`, `dR2`). The power-law exponent `N` controls the shape of the fade curve.

**Temperature interpolation**: all RC parameters and `dQ` are linearly interpolated between the 25°C and 45°C BOL fits using weights `p1` / `p2` derived from `cfg.T_sim`.

## Output Files

| File | Contents |
|------|----------|
| `monte_carlo_parallel_results.mat` | Per-simulation capacity & retention curves, sampled parameters |
| `monte_carlo_parallel_summary.csv` | Per-simulation final capacity + parameter values |
| `confidence_interval_results.mat` | Mean, 2.5th, 97.5th percentile curves vs experimental |
| `confidence_interval_data.csv` | Same data in tabular form |

## Requirements

- MATLAB R2021b or later
- Simulink
- Simulink Design Optimization (BOL parameterization only)
- Parallel Computing Toolbox (`run_monte_carlo.m`)

The parallel temp directory is hardcoded in `run_monte_carlo.m`:
```matlab
setenv('TMP', 'D:\MATLAB\temp');
```
Change this path if running on a different machine.
