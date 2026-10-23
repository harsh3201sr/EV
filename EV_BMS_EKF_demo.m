%% EV_BMS_EKF_demo.m   (ADVANCED, OPTIONAL)
%  Compares Coulomb counting vs an EKF when the estimator starts from a WRONG
%  initial SOC (50 % instead of 80 %).
%
%  HONEST CAVEAT: the "true" battery below is a synthetic 1-RC model that is
%  EXACTLY the model the EKF assumes, with simulated noise. Good results here
%  show the algorithm works in a best case; they say nothing about accuracy
%  on a real cell. Validate against reference SOC data before claiming accuracy.

clear; clc; close all;
P = bms_params();
dt = 1;  rng(1);                                   % repeatable noise

% --- synthetic "real" cell with RC dynamics (illustrative values) -----------
R1 = 0.015;  C1 = 2000;  a = exp(-dt / (R1 * C1));
tp = [0 300 600 900 1200 1500 1800 2100 2400 3000 3600];
Ip = [0  40  70  -30   20   60  -20   45   10   30    0];
t = (0:dt:3600).';   I = interp1(tp, Ip, t);

SOC_true = zeros(size(t));  V1 = zeros(size(t));  V = zeros(size(t));
SOC_true(1) = 80;
for k = 1:numel(t)
    if k > 1
        SOC_true(k) = SOC_true(k-1) - I(k) * dt / (3600 * P.Q_Ah) * 100;
        V1(k) = a * V1(k-1) + R1 * (1 - a) * I(k);
    end
    V(k) = battery_voltage_model(SOC_true(k), 0, 0, P.SOC_bp, P.OCV_pack) - V1(k) - P.R0 * I(k);
end
V_meas = V + 0.02 * randn(size(V));                % 20 mV voltage noise
I_meas = I + 0.5  * randn(size(I));                % 0.5 A current noise

% --- Coulomb counting with the wrong start ---------------------------------
SOC_cc = coulomb_counting(I_meas, dt, P.Q_Ah, 50);

% --- EKF with the same wrong start but large initial uncertainty -----------
E = struct('Q_Ah', P.Q_Ah, 'R0', P.R0, 'R1', R1, 'C1', C1, ...
           'SOC_bp', P.SOC_bp, 'OCV_pack', P.OCV_pack, 'SOC0', 50, ...
           'P0', diag([0.3^2, 0.05^2]), 'Qn', diag([1e-9, 1e-6]), 'Rn', 0.05^2);
[SOC_ekf, ~, P_trace] = ekf_soc_estimator(V_meas, I_meas, dt, E);

% --- results ----------------------------------------------------------------
half = t > 1800;
fprintf('RMS SOC error, last 30 min:  Coulomb counting %.2f %%   EKF %.2f %%\n', ...
    sqrt(mean((SOC_cc(half) - SOC_true(half)).^2)), ...
    sqrt(mean((SOC_ekf(half) - SOC_true(half)).^2)));

figure('Name', 'EKF vs Coulomb counting');
subplot(2,1,1);
plot(t/60, SOC_true, 'k', t/60, SOC_cc, 'r--', t/60, SOC_ekf, 'b', 'LineWidth', 1.3);
grid on; ylabel('SOC (%)'); legend('True (synthetic)', 'Coulomb counting, wrong start', 'EKF, wrong start');
title('Recovery from a wrong initial SOC (model-matched synthetic test)');
subplot(2,1,2);
plot(t/60, SOC_ekf - SOC_true, 'b', 'LineWidth', 1.2); grid on;
xlabel('Time (min)'); ylabel('EKF error (%)');
