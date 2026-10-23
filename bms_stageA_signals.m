function S = bms_stageA_signals(P)
%BMS_STAGEA_SIGNALS  Stage A: synthetic voltage/current/temperature signals.
%
%   Each fault is created in its own time window, so you can see every flag
%   rise and fall independently. Used by EV_BMS_Main.m and by the Simulink
%   model (From Workspace blocks) when stage_select = 0.
%
%   Windows (seconds):  0-99 normal | 100-149 OV | 200-249 UV |
%     300-349 OC discharge | 400-449 OC charge | 500-549 OT | 560-599 all four-ish
%   (the last window raises OV + OC + OT together).

    if nargin < 1, P = bms_params(); end
    t = (0:P.dt:600).';
    V = 48 + 0 * t;   I = 20 + 0 * t;   T = 30 + 0 * t;

    V(t >= 100 & t < 150) = P.V_max + 1.5;        % overvoltage
    V(t >= 200 & t < 250) = P.V_min - 2.0;        % undervoltage
    I(t >= 300 & t < 350) = P.I_max + 20;         % discharge overcurrent
    I(t >= 400 & t < 450) = -(P.I_max + 20);      % charge overcurrent
    T(t >= 500 & t < 550) = P.T_max + 5;          % overtemperature
    V(t >= 560 & t < 600) = P.V_max + 1.5;        % multiple faults
    I(t >= 560 & t < 600) = P.I_max + 20;
    T(t >= 560 & t < 600) = P.T_max + 5;

    S.t = t;  S.V = V;  S.I = I;  S.T = T;
    S.expected_windows = struct( ...
        'OV', [100 150; 560 600], 'UV', [200 250], ...
        'OC', [300 350; 400 450; 560 600], 'OT', [500 550; 560 600]);
end
