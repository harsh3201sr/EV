function P = bms_params()
%BMS_PARAMS  Central configuration for the EV BMS / SOC project.
%
%   P = bms_params() returns a struct with every configurable parameter.
%   All other files read their settings from here, so change values HERE.
%
%   SIGN CONVENTION : current > 0 = DISCHARGE, current < 0 = CHARGE.
%   UNITS           : V, A, Ah, ohm, degC, s, J/K, K/W.  SOC is in PERCENT.
%
%   IMPORTANT: every number below is ILLUSTRATIVE. Real protection limits,
%   R0, thermal values and the OCV curve must come from the cell
%   manufacturer's datasheet and from lab tests of your actual cells.

    % ---------------- Pack definition (illustrative 13S NMC pack) -----------
    P.Ns        = 13;      % cells in series  (13 x 3.7 V = 48.1 V nominal)
    P.V_nom     = 48;      % V   nominal pack voltage (documentation only)
    P.Q_Ah      = 50;      % Ah  pack capacity

    % ---------------- Initial conditions ------------------------------------
    P.SOC_init     = 80;   % %    true initial SOC of the battery
    P.SOC_est_init = [];   % %    estimator start value; [] = same as SOC_init
                           %      (set e.g. 60 to see the effect of a wrong start)
    P.T_init       = 25;   % degC initial pack temperature
    P.T_amb        = 25;   % degC ambient temperature

    % ---------------- Protection thresholds (illustrative) ------------------
    P.V_max = 54.6;        % V   = 13 x 4.20 V   overvoltage limit
    P.V_min = 39.0;        % V   = 13 x 3.00 V   undervoltage limit
    P.I_max = 100;         % A   magnitude limit, applies to charge AND discharge
    P.T_max = 60;          % degC overtemperature limit

    % ---------------- Equivalent-circuit model (Stage B) --------------------
    P.R0  = 0.025;         % ohm  pack internal resistance (constant, simplified)
    P.Rth = 0.15;          % K/W  pack-to-ambient thermal resistance
    P.Cth = 8000;          % J/K  pack heat capacity (illustrative, deliberately
                           %      small so thermal effects show up in minutes)

    % ---------------- Sensor / simulation settings --------------------------
    P.I_offset = 0;        % A   current-sensor offset seen ONLY by the BMS
    P.dt       = 1;        % s   sampling time
    P.t_end    = 3600;     % s   default duration (scenarios override this)
    P.protection_enable = true; % simulated contactor logic (scenario may override)

    % ---------------- Illustrative OCV-SOC curve ----------------------------
    % Per-cell open-circuit voltage of a generic NMC cell (NOT measured data).
    % Replace with your own table: rest the cell 1-2 h at each SOC step,
    % record the settled voltage, and paste the numbers here.
    P.SOC_bp    = [0   5    10   20   30   40   50   60   70   80   90   100];
    P.OCV_cell  = [3.00 3.30 3.45 3.57 3.64 3.70 3.77 3.85 3.94 4.04 4.13 4.20];
    P.OCV_pack  = P.Ns * P.OCV_cell;   % pack-level curve used by the model
end
