function SOC = coulomb_counting(I, dt, Q_Ah, SOC0)
%COULOMB_COUNTING  SOC estimation by current integration.
%
%   SOC(k) = SOC(k-1) - ( I(k) * dt / (3600 * Q_Ah) ) * 100
%
%   Inputs
%     I     current in A, positive = discharge, negative = charge
%           - vector (N samples): returns the whole SOC history
%           - scalar            : single-step update, SOC0 is the PREVIOUS SOC
%     dt    sampling time in s            (scalar > 0)
%     Q_Ah  battery capacity in Ah        (scalar > 0)
%     SOC0  initial SOC in %, 0..100      (scalar)
%
%   Output
%     SOC   in %, saturated to [0, 100].
%           Vector mode: SOC(1) = SOC0 (the state at t = 0), then
%           SOC(k) is computed with I(k) for k = 2..N.
%
%   Unit check: A * s / (3600 s/h) = Ah.  Ah / Q_Ah = fraction.  x100 = %.

    % ---------------- input validation --------------------------------------
    if ~isnumeric(I) || ~isreal(I) || isempty(I) || any(~isfinite(I(:)))
        error('coulomb_counting:badCurrent', ...
              'I must be a non-empty, real, finite numeric array (A).');
    end
    if ~isscalar(dt) || ~isnumeric(dt) || ~isfinite(dt) || dt <= 0
        error('coulomb_counting:badDt', 'dt must be a positive scalar (s).');
    end
    if ~isscalar(Q_Ah) || ~isnumeric(Q_Ah) || ~isfinite(Q_Ah) || Q_Ah <= 0
        error('coulomb_counting:badCapacity', ...
              'Q_Ah must be a positive scalar (Ah).');
    end
    if ~isscalar(SOC0) || ~isnumeric(SOC0) || ~isfinite(SOC0) ...
            || SOC0 < 0 || SOC0 > 100
        error('coulomb_counting:badSOC0', ...
              'SOC0 must be a scalar between 0 and 100 (%%).');
    end

    k_gain = dt / (3600 * Q_Ah) * 100;      % % of SOC per ampere of current

    % ---------------- single-step mode --------------------------------------
    if isscalar(I)
        SOC = min(max(SOC0 - I * k_gain, 0), 100);
        return;
    end

    % ---------------- vector mode -------------------------------------------
    I   = I(:);
    N   = numel(I);
    SOC = zeros(N, 1);
    SOC(1) = SOC0;
    for k = 2:N
        SOC(k) = SOC(k-1) - I(k) * k_gain;
        SOC(k) = min(max(SOC(k), 0), 100);   % saturation 0..100 %
    end
end
