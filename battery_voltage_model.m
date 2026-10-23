function [V_term, OCV] = battery_voltage_model(SOC, I, R0, SOC_bp, OCV_pack)
%BATTERY_VOLTAGE_MODEL  Simplified (R0-only) equivalent-circuit battery.
%
%   V_term = OCV(SOC) - I * R0
%
%   Inputs
%     SOC      state of charge in % (scalar or array, clamped to 0..100)
%     I        current in A, positive = discharge (same size as SOC or scalar)
%     R0       internal resistance in ohm (scalar)
%     SOC_bp   (optional) SOC breakpoints in %,      1xM, increasing
%     OCV_pack (optional) pack OCV at those points in V, 1xM
%              If SOC_bp / OCV_pack are omitted, bms_params() defaults are used.
%
%   Outputs
%     V_term   terminal voltage in V
%     OCV      open-circuit voltage in V
%
%   ASSUMPTIONS
%     1. OCV depends on SOC only (no temperature, no ageing, no hysteresis).
%     2. R0 is constant (in reality it rises at low SOC, low temperature and
%        with ageing).
%     3. No RC (diffusion / polarisation) branch, so the voltage responds
%        instantly to a current step. Real cells relax over seconds-minutes.
%     4. The OCV table is ILLUSTRATIVE, not measured.
%
%   TO USE REAL DATA: replace P.SOC_bp and P.OCV_cell in bms_params.m with a
%   table measured from your cell (rest-and-record at each SOC step), and
%   estimate R0 from the instantaneous voltage step when a current pulse is
%   applied:  R0 = delta_V / delta_I.

    if nargin < 5
        P        = bms_params();
        SOC_bp   = P.SOC_bp;
        OCV_pack = P.OCV_pack;
    end
    if ~isscalar(R0) || ~isnumeric(R0) || R0 < 0
        error('battery_voltage_model:badR0', 'R0 must be a scalar >= 0 (ohm).');
    end
    if numel(SOC_bp) ~= numel(OCV_pack) || any(diff(SOC_bp) <= 0)
        error('battery_voltage_model:badTable', ...
              'SOC_bp must be increasing and the same length as OCV_pack.');
    end

    SOC_clamped = min(max(SOC, SOC_bp(1)), SOC_bp(end));   % no extrapolation
    OCV    = interp1(SOC_bp, OCV_pack, SOC_clamped, 'linear');
    V_term = OCV - I .* R0;
end
