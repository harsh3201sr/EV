%% verify_simulink_vs_matlab.m
%  Runs EV_BMS_SOC.slx for scenarios 1..11 and compares it with the MATLAB
%  simulation (simulate_bms). Run create_EV_BMS_model first.
%
%  Expected differences (not bugs):
%   * Simulink uses forward-Euler integration, so its SOC at step k uses the
%     current up to step k-1, while coulomb_counting() uses I(k). The final SOC
%     differs by at most one sample of charge: I*dt/(3600*Q)*100 (about 0.04 %
%     for 100 A, 1 s, 50 Ah).
%   * Fault flags may start/stop one sample later in Simulink for the same reason.

clear; clc;
mdl = 'EV_BMS_SOC';
if ~bdIsLoaded(mdl), load_system(mdl); end
P = bms_params();

fprintf('%-3s %-32s %10s %10s %10s  %s\n', '#', 'Scenario', 'SOC_matlab', 'SOC_simulink', 'diff(%)', 'faults match');
for id = 1:11
    assignin('base', 'scenario_id', id);
    assignin('base', 'stage_select', 1);
    evalin('base', 'bms_simulink_init;');
    sc = bms_scenarios(id, P);
    R  = simulate_bms(P, sc);

    out = sim(mdl);
    soc_sl = out.get('log_SOC_est');
    flags_sl = [any(out.get('log_OV')) any(out.get('log_UV')) ...
                any(out.get('log_OC')) any(out.get('log_OT'))];
    flags_ml = [any(R.OV) any(R.UV) any(R.OC) any(R.OT)];
    fprintf('%-3d %-32s %10.2f %10.2f %10.3f  %s\n', id, sc.name, ...
        R.SOC_est(end), soc_sl(end), soc_sl(end) - R.SOC_est(end), ...
        mat2str(isequal(flags_sl, flags_ml)));
end
fprintf('\nIf SOC differs by more than about 0.1 %% or the fault flags do not match, see Troubleshooting.\n');
