# Calendar Ageing

Physics-based calendar (storage) ageing simulation for the 230 Ah DV4 lithium-ion cell. A Simulink model runs repeated charge/discharge cycles after an adjustable storage period, and a Monte Carlo wrapper propagates parameter uncertainty into capacity-retention predictions.

---

## Files

### `config.m`

Single source of truth for all simulation parameters.

| Setting | Value | Description |
|---------|-------|-------------|
| `T_storage` | 25 °C | Storage temperature |
| `SOC_storage` | 100 % | Storage state of charge |
| `period` | 365 days | Length of one storage interval |
| `num_steps` | 11 | Number of intervals (0 – 11 years) |
| `num_simulations` | 25 | Monte Carlo sample count |

`CONDITION` and `save_dir` are derived automatically:
```matlab
cfg.CONDITION = sprintf('%d%%SOC_%ddegC', cfg.SOC_storage, cfg.T_storage);
cfg.save_dir  = fullfile(script_dir, cfg.CONDITION);
```

**External parameter files loaded by `config.m`:**

| File | Contents |
|------|----------|
| `../CycleLifePrediction/CycleAgeingParams.mat` | Cycle ageing coefficients: `N`, `dOCV`, `dR0`, `dR1`, `dR2`, `dQ` |
| `CalendarAgeingParams.mat` | Calendar ageing coefficients: `bR`, `cR`, `dR`, `aR`, `bC`, `cC`, `dC`, `aC` |
| `../BOL_parameterization/1C-CCCV-25/ECMParams.mat` | Fitted RC parameters (R0, R1, R2, τ1, τ2 — charge & discharge) |

Monte Carlo bounds (`cfg.mc`) are defined as `struct('std', ..., 'lo', ..., 'hi', ...)` for each of the 14 sampled parameters.

---

### `run_single_simulation.m`

Deterministic single-trajectory simulation.

**What it does:**
1. Loads all parameters from `config.m`.
2. Loops over `num_steps + 1` storage periods (0 to 11 years).
3. For each period, builds a `Simulink.SimulationInput` with all 22 workspace variables injected via `setVariable()` — the `.slx` model file is never modified.
4. Extracts discharged capacity from `q_sim` at the last charge zero-crossing.
5. Plots capacity retention (%) vs. storage time (days).

**Output plot:** capacity retention (%) on the y-axis, time in days on the x-axis, titled with `cfg.CONDITION`.

---

### `run_mc_simulation.m`

Parallel Monte Carlo simulation over 25 parameter sets × 11 storage steps = 275 Simulink jobs.

**Sampled parameters (14 total):**

| Group | Parameters |
|-------|-----------|
| Cycle ageing | `N`, `dOCV`, `dR0`, `dQ`, `dR1`, `dR2` |
| Calendar resistance | `bR`, `cR`, `dR`, `aR` |
| Calendar capacity | `bC`, `cC`, `dC`, `aC` |

Samples are drawn as `nominal + std × randn`, clipped to `[lo, hi]`. Parameters with `std = 0` are fixed at their nominal value.

**Execution:**
```matlab
% Jobs are flattened: job = (i_sim-1)*num_steps + t
parfor job = 1:n_jobs
    i_sim = ceil(job / num_steps);
    t     = mod(job - 1, num_steps) + 1;
    % ... build SimulationInput, run sim, extract capacity
end
```

A parallel pool is started automatically via `gcp()`. The MATLAB temp directory is redirected to `D:\MATLAB\temp` to avoid worker conflicts.

**Outputs saved to `100%SOC_25degC/`:**
- `monte_carlo_parallel_results.mat` — full trajectories, per-parameter samples, error flags
- `monte_carlo_parallel_summary.csv` — one row per simulation: all 14 parameters + `Final_Capacity` + `Error`

---

## Results — `100%SOC_25degC/`

Storage condition: **100% SOC, 25 °C**, 25 Monte Carlo simulations over 11 yearly intervals.

### `monte_carlo_parallel_summary.csv`

One row per simulation. Columns: `N`, `dOCV`, `dR0`, `dQ`, `dR1`, `dR2`, `bR`, `cR`, `dR`, `aR`, `bC`, `cC`, `dC`, `aC`, `Final_Capacity` (Ah after 11 years), `Error` (0 = success).

### `monte_carlo_parallel_results.mat`

MATLAB struct `results` containing:
- Per-parameter sample arrays (`N`, `dOCV`, … `aC`)
- `capacity` — cell array of `[step, Ah]` trajectories
- `retention` — cell array of `[step, fraction]` trajectories
- `final_capacity` — vector of end-of-life capacity (Ah)
- `sim_time`, `errors`, `error_messages`

---

## Plots

`results.ipynb`

### Monte Carlo Parameters

![Monte Carlo Parameters](100%25SOC_25degC/MC_params.png)

### Final Capacity vs. Monte Carlo Parameters

![Q vs Monte Carlo Parameters](100%25SOC_25degC/Q_vs_MC_params.png)

### Prediction

![Calendar Ageing Prediction](100%25SOC_25degC/prediction.png)
