%% EV_BMS_Main.m
%  EV Battery Management System with SOC estimation (Coulomb counting)
%  Main script: Stage A (synthetic signals) + Stage B (battery model) scenarios.
%
%  Run:  >> EV_BMS_Main
%  Needs only base MATLAB (no toolboxes). All files must be in the same folder.
%  Sign convention: current > 0 = discharge, current < 0 = charge.

clear; clc; close all;

%% ----------------------------- user options -------------------------------
SHOW_PLOTS   = true;        % false for a fast, text-only run
PLOT_IDS     = [3 9];       % scenarios to plot in detail (1..11)
SAVE_FIGURES = false;       % true: save PNGs into ./results
SOC_TOL      = 0.05;        % % tolerance for the analytic SOC check

P = bms_params();           % <- change battery/threshold values in bms_params.m

fprintf('=== EV BMS: %g V, %g Ah pack | V %g..%g V | |I| <= %g A | T <= %g C ===\n', ...
        P.V_nom, P.Q_Ah, P.V_min, P.V_max, P.I_max, P.T_max);
fprintf('Thresholds are ILLUSTRATIVE; use the cell datasheet for a real pack.\n\n');

%% ------------------------- STAGE A: synthetic signals ---------------------
fprintf('--- Stage A: synthetic V/I/T signals ---\n');
S = bms_stageA_signals(P);
[A.OV, A.UV, A.OC, A.OT, A.any_fault] = bms_fault_detection( ...
    S.V, S.I, S.T, P.V_max, P.V_min, P.I_max, P.T_max);
A.SOC_est = coulomb_counting(S.I, P.dt, P.Q_Ah, P.SOC_init);
A.SOC_true = A.SOC_est;  A.t = S.t;  A.V = S.V;  A.I_meas = S.I;  A.T = S.T;
A.contactor_closed = true(size(S.t));  A.name = 'Stage A synthetic signals';  A.P = P;

names = {'OV', 'UV', 'OC', 'OT'};
stageA_ok = true;
for n = 1:4
    w = S.expected_windows.(names{n});
    expected = false(size(S.t));
    for r = 1:size(w, 1), expected = expected | (S.t >= w(r,1) & S.t < w(r,2)); end
    ok = isequal(A.(names{n}), expected);
    stageA_ok = stageA_ok && ok;
    fprintf('  %-2s flag matches expected windows : %s\n', names{n}, passfail(ok));
end
fprintf('  Stage A overall: %s\n\n', passfail(stageA_ok));
if SHOW_PLOTS, plot_bms_results(A, 'Stage A: synthetic signals'); end

%% ------------------------- STAGE B: scenarios 1..11 -----------------------
fprintf('--- Stage B: battery model scenarios ---\n');
hdr = sprintf('%-3s %-32s %-4s %-4s %-4s %-4s %8s %7s %7s %7s  %s', ...
    '#', 'Scenario', 'OV', 'UV', 'OC', 'OT', 'SOC_end', 'Vmin', 'Vmax', 'Tmax', 'Result');
fprintf('%s\n%s\n', hdr, repmat('-', 1, numel(hdr)));

all_ok = stageA_ok;
results = cell(1, 11);
for id = 1:11
    sc = bms_scenarios(id, P);
    R  = simulate_bms(P, sc);
    results{id} = R;

    got = [any(R.OV) any(R.UV) any(R.OC) any(R.OT)];
    exp_ = [sc.expect.OV sc.expect.UV sc.expect.OC sc.expect.OT];
    ok = isequal(got, exp_);
    if ~isnan(sc.SOC_final_expected)
        ok = ok && abs(R.SOC_true(end) - sc.SOC_final_expected) <= SOC_TOL ...
                && abs(R.SOC_est(end)  - sc.SOC_final_expected) <= SOC_TOL;
    end
    if sc.protection      % contactor must have opened and stayed open
        ok = ok && ~R.contactor_closed(end) && R.I(end) == 0;
    end
    all_ok = all_ok && ok;

    fprintf('%-3d %-32s %-4d %-4d %-4d %-4d %7.2f%% %7.2f %7.2f %7.2f  %s\n', ...
        id, sc.name, got(1), got(2), got(3), got(4), R.SOC_true(end), ...
        min(R.V), max(R.V), max(R.T), passfail(ok));

    if SHOW_PLOTS && any(id == PLOT_IDS)
        f = plot_bms_results(R, sprintf('Scenario %d: %s', id, sc.name));
        if SAVE_FIGURES
            if ~exist('results', 'dir'), mkdir('results'); end
            saveas(f, fullfile('results', sprintf('scenario_%02d.png', id)));
        end
    end
end

%% --------------------- first-trip times (useful for the viva) -------------
fprintf('\nFirst assertion time of each fault flag (s):\n');
for id = 4:11
    R = results{id};
    fprintf('  Scenario %2d (%s):', id, R.name);
    for n = 1:4
        idx = find(R.(names{n}), 1, 'first');
        if isempty(idx), fprintf('  %s=--', names{n});
        else,            fprintf('  %s=%g', names{n}, R.t(idx)); end
    end
    fprintf('\n');
end

%% ---------------- manual SOC check (matches the guide, section 10) --------
R1 = results{1};
manual = P.SOC_init - 20 * 1800 / (3600 * P.Q_Ah) * 100;
fprintf('\nManual check, scenario 1: 80 - (20 A x 1800 s)/(3600 x 50 Ah) x 100 = %.2f %%\n', manual);
fprintf('Code result: %.2f %%\n', R1.SOC_est(end));

%% ------------- effect of a 2 A current-sensor offset (drift demo) ---------
P2 = P;  P2.I_offset = 2;                       % BMS sees 2 A too much
R_off = simulate_bms(P2, bms_scenarios(1, P2));
fprintf('\nSensor-offset demo (scenario 1, +2 A offset): true SOC %.2f %%, estimated %.2f %%, error %.2f %%\n', ...
        R_off.SOC_true(end), R_off.SOC_est(end), R_off.SOC_est(end) - R_off.SOC_true(end));

fprintf('\n=== OVERALL: %s ===\n', passfail(all_ok));

function s = passfail(ok)
    if ok, s = 'PASS'; else, s = 'FAIL'; end
end
