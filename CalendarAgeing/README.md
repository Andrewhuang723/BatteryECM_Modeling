# Calendar Ageing

Simulates capacity fade during storage using a physics-based calendar ageing model. Supports a single deterministic run or a full Monte Carlo pipeline with uncertainty bands across 14 ageing parameters.

## Files

| File | Role |
|------|------|
| `config.m` | Central configuration — storage condition, RC params, ageing params, Monte Carlo bounds |
| `CalendarAgeingParams.mat` | Calendar ageing coefficients: bR, cR, dR, aR, bC, cC, dC, aC |
| `CalendarAgeing.slx` | Simulink model — 2-RC ECM with calendar ageing update at each storage period |
| `run_single_simulation.m` | Single deterministic run; plots capacity retention vs. storage time |
| `run_mc_simulation.m` | 25-sample parallel Monte Carlo; saves trajectories and summary results |

## Configuration (`config.m`)

All parameters are controlled here. Key settings to change before running:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cfg.T_storage` | `25` | Storage temperature (°C) |
| `cfg.SOC_storage` | `100` | Storage state of charge (%) |
| `cfg.period` | `365` | Length of one storage interval (days) |
| `cfg.num_steps` | `11` | Number of intervals (0 – 11 years) |
| `cfg.num_simulations` | `25` | Monte Carlo sample count |

`CONDITION` and `save_dir` are auto-generated from storage condition:
```matlab
cfg.CONDITION = sprintf('%d%%SOC_%ddegC', cfg.SOC_storage, cfg.T_storage);
cfg.save_dir  = fullfile(script_dir, cfg.CONDITION);
```

### Parameter sources loaded by `config.m`

- **RC parameters** — read from `../BOL_parameterization/1C-CCCV-25/ECMParams.mat` (produced by BOL parameterization SDO session)
- **Cycle ageing parameters** — read from `../CycleLifePrediction/CycleAgeingParams.mat` as a struct with fields `N`, `dOCV`, `dR0`, `dR1`, `dR2`, `dQ`
- **Calendar ageing parameters** — read from `CalendarAgeingParams.mat` as a struct with fields `bR`, `cR`, `dR`, `aR`, `bC`, `cC`, `dC`, `aC`
- **OCV table** — interpolated at `T_storage` from `../OCV/ocv_config.m`

## Usage

### Single deterministic run

```matlab
cd CalendarAgeing
run_single_simulation
```

Runs `CalendarAgeing.slx` for each storage period (0 to `num_steps` years) with nominal ageing parameters from `config.m` and plots capacity retention (%) vs. storage time (days).

### Monte Carlo (25 samples)

```matlab
cd CalendarAgeing
run_mc_simulation
```

Samples all 14 ageing parameters as `N(μ, σ)` clipped to `[lo, hi]` bounds defined in `config.m`. All `num_simulations × num_steps` jobs are flattened into a single `parfor` loop for maximum parallelism. Before running, update the temp directory path at the top of the script if needed:

```matlab
setenv('TMP', 'D:\MATLAB\temp');   % change to a valid path on your machine
```

## Output

Results are saved to `cfg.save_dir` (e.g., `100%SOC_25degC/`):

| File | Contents |
|------|----------|
| `monte_carlo_parallel_results.mat` | Per-simulation capacity and retention trajectories, sampled parameters, error flags |
| `monte_carlo_parallel_summary.csv` | Per-simulation final capacity and all 14 parameter values |

## Monte Carlo Uncertainty Bounds

Defined in `config.m` under `cfg.mc`. Each parameter is perturbed independently:

| Parameter | Perturbation | Meaning |
|-----------|-------------|---------|
| `N`, `dOCV`, `dR0`, `dQ`, `dR1`, `dR2` | σ = 0 (fixed) | Cycle ageing params — held at nominal |
| `aR` | σ = ±1% of nominal | Arrhenius pre-factor for resistance growth |
| `bC` | σ = ±5% of nominal | Pre-exponential for capacity fade |
| `cC` | σ = ±5% of nominal | SOC-dependent capacity fade coefficient |
| `aC` | σ = ±1% of nominal | Arrhenius pre-factor for capacity fade |

### Monte Carlo Parameters

![Monte Carlo Parameters](100%25SOC_25degC/MC_params.png)

### Final Capacity vs. Monte Carlo Parameters

![Q vs Monte Carlo Parameters](100%25SOC_25degC/Q_vs_MC_params.png)

## Results

### 100% SOC, 25 °C

![Calendar Ageing Prediction](100%25SOC_25degC/prediction.png)
