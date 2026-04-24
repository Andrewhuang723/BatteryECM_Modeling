%% ── Load OCV Data ────────────────────────────────────────────────────────────
script_dir         = fileparts(mfilename('fullpath'));
data_root          = fileparts(fileparts(script_dir));
charge_ocv_data    = readtable(fullfile(data_root, 'OCV', 'DV4_charge_SOC_OCV.xlsx'));
discharge_ocv_data = readtable(fullfile(data_root, 'OCV', 'DV4_discharge_SOC_OCV.xlsx'));
SOCs          = charge_ocv_data{:, 1}' ./ 100;   % Convert % → decimal
OCVs_charge   = charge_ocv_data{:, 8}';           % Column 8: 45°C
OCVs_discharge = discharge_ocv_data{:, 8}';       % Column 8: 45°C

%% ── OCV Charge vs Discharge ──────────────────────────────────────────────────
figure;
plot(SOCs .* 100, OCVs_charge,    'r-', 'LineWidth', 2); hold on;
plot(SOCs .* 100, OCVs_discharge, 'b-', 'LineWidth', 2);
xlabel('SOC (%)'); ylabel('OCV (V)'); title('OCV Charge and Discharge');
legend('Charge', 'Discharge', 'Location', 'best'); grid on;

%% ── Load Optimised RC Parameters ────────────────────────────────────────────
optim_param = load(fullfile(script_dir, '1C-CCCV-HT', 'BatteryParameterization_spesession.mat'));
optim_data  = optim_param.SDOSessionData.Data.Workspace.LocalWorkspace.EstimatedParams_6.Parameters;

R0_charge      = optim_data(1).Value;
R0_discharge   = optim_data(2).Value;
R1_charge      = optim_data(3).Value;
R1_discharge   = optim_data(4).Value;
R2_charge      = optim_data(5).Value;
R2_discharge   = optim_data(6).Value;
tau1_charge    = optim_data(7).Value;
tau1_discharge = optim_data(8).Value;
tau2_charge    = optim_data(9).Value;
tau2_discharge = optim_data(10).Value;

%% ── SOC Grid for Plotting ────────────────────────────────────────────────────
SOCs_29 = [linspace(0, 0.09, 10), linspace(0.1, 0.9, 9), linspace(0.91, 1, 10)];

%% ── RC Parameter Plots ───────────────────────────────────────────────────────
figure;

subplot(2, 2, 1);
plot(SOCs_29 .* 100, R0_charge, 'r-', 'LineWidth', 2); hold on;
plot(SOCs_29 .* 100, R1_charge, 'b-', 'LineWidth', 2);
plot(SOCs_29 .* 100, R2_charge, 'g-', 'LineWidth', 2);
ylabel('R (\Omega)'); xlabel('SOC (%)'); title('R Charge');
legend('R0', 'R1', 'R2', 'Location', 'best'); grid on;

subplot(2, 2, 2);
plot(SOCs_29 .* 100, R0_discharge, 'r-', 'LineWidth', 2); hold on;
plot(SOCs_29 .* 100, R1_discharge, 'b-', 'LineWidth', 2);
plot(SOCs_29 .* 100, R2_discharge, 'g-', 'LineWidth', 2);
ylabel('R (\Omega)'); xlabel('SOC (%)'); title('R Discharge');
legend('R0', 'R1', 'R2', 'Location', 'best'); grid on;

subplot(2, 2, 3);
plot(SOCs_29 .* 100, tau1_charge, 'b-', 'LineWidth', 2); hold on;
plot(SOCs_29 .* 100, tau2_charge, 'g-', 'LineWidth', 2);
ylabel('\tau (s)'); xlabel('SOC (%)'); title('Tau Charge');
legend('\tau_1', '\tau_2', 'Location', 'best'); grid on;

subplot(2, 2, 4);
plot(SOCs_29 .* 100, tau1_discharge, 'b-', 'LineWidth', 2); hold on;
plot(SOCs_29 .* 100, tau2_discharge, 'g-', 'LineWidth', 2);
ylabel('\tau (s)'); xlabel('SOC (%)'); title('Tau Discharge');
legend('\tau_1', '\tau_2', 'Location', 'best'); grid on;
