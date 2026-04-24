# Cycle Life Prediction

Simulates capacity fade over cycling using a 2-RC ECM with power-law ageing. Supports a single deterministic run or a full Monte Carlo pipeline with 95% confidence intervals.

## Files

| File | Role |
|------|------|
| `config.m` | Central configuration — temperature, SOC window, C-rate, RC params, ageing params, Monte Carlo bounds |
| `ECMParams.mat` | Fitted RC parameters (R0, R1, R2, τ1, τ2) from BOL parameterization |
| `CycleAgeingParams.mat` | Ageing coefficients: N, dOCV, dR0, dR1, dR2, dQ |
| `CyclingAgeing.slx` | Simulink model — 2-RC ECM with per-cycle ageing update |
| `run_single_simulation.m` | Single deterministic run; prints MAE and plots capacity vs experimental |
| `run_mc_simulation.m` | 20-sample parallel Monte Carlo; saves results and 95% CI curves |

## Configuration (`config.m`)

All parameters are controlled here. Key settings to change before running:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cfg.T_sim` | `25` | Simulation temperature (°C) — interpolates RC params between 25 °C and 45 °C fits |
| `cfg.C_rate` | `0.33` | C-rate for charge/discharge current |
| `cfg.soc_lower_limit` | `0.0` | Discharge cut-off SOC |
| `cfg.soc_upper_limit` | `1.0` | Charge cut-off SOC |
| `cfg.num_simulations` | `20` | Monte Carlo sample count |

`cfg.save_dir` is auto-generated from `T_sim`, SOC window, and C-rate (e.g. `1C-CCCV-25-SOC0_100-C0p33/`).

### Parameter sources loaded by `config.m`

- **RC parameters** — read from `ECMParams.mat` (produced by BOL parameterization SDO session)
- **Ageing parameters** — read from `CycleAgeingParams.mat` as a 6-element vector `[N, dOCV, dR0, dR1, dR2, dQ]`
- **OCV table** — interpolated at `T_sim` from `../OCV/ocv_config.m`

## Usage

### Single deterministic run

```matlab
cd CycleLifePrediction
run_single_simulation
```

Runs `CyclingAgeing.slx` once with the nominal ageing parameters from `config.m`, then prints capacity MAE and retention MAE against experimental data and shows a two-panel plot.

### Monte Carlo (20 samples, 95% CI)

```matlab
cd CycleLifePrediction
run_mc_simulation
```

Samples each ageing parameter as `N(μ, σ)` clipped to `[lo, hi]` bounds defined in `config.m`, runs all samples in parallel via `parfor`, then computes 95% confidence intervals. Before running, update the temp directory path at the top of the script if needed:

```matlab
setenv('TMP', 'D:\MATLAB\temp');   % change to a valid path on your machine
```

## Output

Results are saved to `cfg.save_dir`:

| File | Contents |
|------|----------|
| `monte_carlo_parallel_results.mat` | Per-simulation capacity and retention curves, sampled parameters |
| `monte_carlo_parallel_summary.csv` | Per-simulation final capacity and parameter values |
| `confidence_interval_results.mat` | Mean, 2.5th, 97.5th percentile curves |
| `confidence_interval_data.csv` | Same CI data in tabular form |

## Monte Carlo Uncertainty Bounds

Defined in `config.m` under `cfg.mc`. Each ageing parameter is perturbed independently:

| Parameter | Perturbation | Meaning |
|-----------|-------------|---------|
| `N` | σ = 0 (fixed) | Power-law exponent — well-constrained by cycle count |
| `dOCV` | σ = ±5% of nominal | OCV drift coefficient |
| `dR0` | σ = ±10% of nominal | Series resistance growth rate |
| `dQ` | σ = ±10% of nominal | Capacity fade rate per cycle |
| `dR1`, `dR2` | σ = ±10% of nominal | RC resistance growth rates |
