function [SOC_ekf, V1_ekf, P_trace] = ekf_soc_estimator(V_meas, I_meas, dt, E)
%EKF_SOC_ESTIMATOR  ADVANCED, OPTIONAL: Extended Kalman Filter SOC estimator.
%
%   Battery model (1-RC Thevenin):
%       states   x = [SOC (fraction 0..1) ; V1 (V, RC polarisation voltage)]
%       SOC(k) = SOC(k-1) - I(k)*dt/(3600*Q)
%       V1(k)  = a*V1(k-1) + R1*(1-a)*I(k),   a = exp(-dt/(R1*C1))
%       V(k)   = OCV(SOC(k)) - V1(k) - R0*I(k)           (measurement)
%
%   PREDICT :  x- = f(x, I),   P- = F*P*F' + Qn
%   UPDATE  :  H  = [dOCV/dSOC, -1]
%              K  = P- H' / (H P- H' + Rn)
%              x  = x- + K*(V_meas - V_model),  P = (I - K H) P-
%
%   Inputs  V_meas, I_meas : measured terminal voltage (V), current (A, + = discharge)
%           dt             : sampling time (s)
%           E              : struct with fields
%               Q_Ah, R0, R1, C1                    cell/pack parameters
%               SOC_bp, OCV_pack                    OCV-SOC table (SOC in %)
%               SOC0 (%)                            initial guess
%               P0 (2x2)  initial covariance,  Qn (2x2) process noise,
%               Rn (scalar) measurement-noise variance (V^2)
%   Outputs SOC_ekf in %, V1_ekf in V, P_trace = trace of P at each step.
%
%   WHAT YOU NEED FOR A MEANINGFUL EKF: (1) an OCV-SOC table measured from
%   your cell, (2) R0, R1, C1 identified from pulse tests (or HPPC tests) at
%   the relevant temperatures, (3) sensor noise statistics, (4) tuning of
%   Qn / Rn, (5) VALIDATION against reference SOC (e.g. a lab cycler's
%   Ah-count with a precise current sensor). Without (1)-(5) this code
%   only demonstrates the algorithm; it is NOT a validated estimator.

    V_meas = V_meas(:);  I_meas = I_meas(:);  N = numel(V_meas);
    if numel(I_meas) ~= N, error('ekf_soc_estimator:size', 'V and I must match in length.'); end

    a = exp(-dt / (E.R1 * E.C1));
    x = [E.SOC0 / 100; 0];
    Pc = E.P0;
    F = [1 0; 0 a];

    SOC_ekf = zeros(N,1);  V1_ekf = zeros(N,1);  P_trace = zeros(N,1);
    for k = 1:N
        if k > 1                                             % ---- predict
            x = [x(1) - I_meas(k) * dt / (3600 * E.Q_Ah); ...
                 a * x(2) + E.R1 * (1 - a) * I_meas(k)];
            Pc = F * Pc * F' + E.Qn;
        end
        soc_pct = min(max(x(1) * 100, 0), 100);              % ---- update
        ocv   = interp1(E.SOC_bp, E.OCV_pack, soc_pct, 'linear');
        s_hi  = min(soc_pct + 0.5, 100);  s_lo = max(soc_pct - 0.5, 0);
        dOCV  = (interp1(E.SOC_bp, E.OCV_pack, s_hi) - ...
                 interp1(E.SOC_bp, E.OCV_pack, s_lo)) / (s_hi - s_lo);   % V per %
        H     = [dOCV * 100, -1];                            % V per unit fraction
        V_hat = ocv - x(2) - E.R0 * I_meas(k);
        Sk    = H * Pc * H' + E.Rn;
        K     = Pc * H' / Sk;
        x     = x + K * (V_meas(k) - V_hat);
        Pc    = (eye(2) - K * H) * Pc;
        x(1)  = min(max(x(1), 0), 1);

        SOC_ekf(k) = x(1) * 100;  V1_ekf(k) = x(2);  P_trace(k) = trace(Pc);
    end
end
