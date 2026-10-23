function [OV, UV, OC, OT, any_fault] = bms_fault_detection(V, I, T, V_max, V_min, I_max, T_max)
%BMS_FAULT_DETECTION  Threshold-based protection flags (logical outputs).
%
%   OV        = V       > V_max      overvoltage
%   UV        = V       < V_min      undervoltage
%   OC        = abs(I)  > I_max      overcurrent (discharge AND charge)
%   OT        = T       > T_max      overtemperature
%   any_fault = OV | UV | OC | OT    combined fault
%
%   Inputs may be scalars or arrays of the same size (V in volts, I in
%   amperes, T in degC). Thresholds are scalars.
%
%   NOTE: the thresholds are illustrative. Real limits come from the cell
%   datasheet. Production BMS code also uses debounce timers and hysteresis
%   so one noisy sample does not trip a fault; that is left out here for
%   clarity (see "Future scope").

    args = {V, I, T};
    for n = 1:3
        if ~isnumeric(args{n}) || any(~isreal(args{n}(:)))
            error('bms_fault_detection:badInput', ...
                  'V, I and T must be real numeric arrays.');
        end
    end
    thr = [V_max, V_min, I_max, T_max];
    if ~isnumeric(thr) || numel(thr) ~= 4 || any(~isfinite(thr))
        error('bms_fault_detection:badThreshold', ...
              'Thresholds must be finite numeric scalars.');
    end
    if V_min >= V_max
        error('bms_fault_detection:badThreshold', 'V_min must be below V_max.');
    end

    OV        = V      > V_max;
    UV        = V      < V_min;
    OC        = abs(I) > I_max;
    OT        = T      > T_max;
    any_fault = OV | UV | OC | OT;
end
