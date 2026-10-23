function R = simulate_bms(P, sc)
%SIMULATE_BMS  Time-stepping simulation: battery plant + BMS + fault logic.
%
%   R = simulate_bms(P, sc)
%     P   parameter struct from bms_params()
%     sc  scenario struct from bms_scenarios()
%
%   Per sample k:
%     1. The commanded current passes through the simulated contactor.
%     2. The "true" battery SOC, voltage and temperature are updated.
%     3. The BMS "measures" current (with optional offset) and estimates SOC
%        by Coulomb counting from the MEASURED current.
%     4. Fault flags are evaluated; if protection is enabled, a fault latches
%        the simulated contactor open for the NEXT sample.
%
%   The simulated contactor is a software signal only. A real BMS drives a
%   hardware contactor / MOSFET driver with redundancy and diagnostics.

    t  = sc.t(:);   N = numel(t);   dt = P.dt;

    SOC_true = zeros(N,1);  SOC_est = zeros(N,1);
    V = zeros(N,1);  I_true = zeros(N,1);  I_meas = zeros(N,1);  T = zeros(N,1);
    OV = false(N,1); UV = false(N,1); OC = false(N,1); OT = false(N,1);
    ANY = false(N,1);  closed_log = true(N,1);

    SOC_true(1) = sc.SOC_init;
    if isempty(P.SOC_est_init), SOC_est(1) = sc.SOC_init;
    else,                       SOC_est(1) = P.SOC_est_init; end
    T(1) = sc.T_init;

    closed  = true;     % contactor state (true = closed, current can flow)
    latched = false;    % fault latch

    for k = 1:N
        closed_log(k) = closed;
        I_true(k) = sc.I_cmd(k) * closed;

        if k > 1
            SOC_true(k) = coulomb_counting(I_true(k), dt, P.Q_Ah, SOC_true(k-1));
            heat = I_true(k)^2 * P.R0;                    % W  (I^2 R)
            loss = (T(k-1) - sc.T_amb(k)) / P.Rth;        % W  to ambient
            T(k) = T(k-1) + dt / P.Cth * (heat - loss);
        end

        V(k) = battery_voltage_model(SOC_true(k), I_true(k), P.R0, ...
                                     P.SOC_bp, P.OCV_pack);

        I_meas(k) = I_true(k) + P.I_offset;               % sensor error
        if k > 1
            SOC_est(k) = coulomb_counting(I_meas(k), dt, P.Q_Ah, SOC_est(k-1));
        end

        [OV(k), UV(k), OC(k), OT(k), ANY(k)] = bms_fault_detection( ...
            V(k), I_meas(k), T(k), P.V_max, P.V_min, P.I_max, P.T_max);

        if sc.protection && ANY(k), latched = true; end
        closed = ~(sc.protection && latched);
    end

    R.t = t;  R.SOC_true = SOC_true;  R.SOC_est = SOC_est;
    R.V = V;  R.I = I_true;  R.I_meas = I_meas;  R.T = T;
    R.OV = OV; R.UV = UV; R.OC = OC; R.OT = OT; R.any_fault = ANY;
    R.contactor_closed = closed_log;
    R.name = sc.name;  R.sc = sc;  R.P = P;
end
