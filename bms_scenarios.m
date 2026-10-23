function sc = bms_scenarios(id, P)
%BMS_SCENARIOS  Test-scenario definitions (1..11) for the EV BMS project.
%
%   sc = bms_scenarios(id, P) returns a struct with
%     name, t, I_cmd (A, + = discharge), T_amb (degC), SOC_init (%),
%     T_init (degC), protection (logical), expect (struct OV,UV,OC,OT:
%     should this flag be asserted at least once?), SOC_final_expected
%     (% or NaN), description.
%
%   Scenarios 1-10 run with the simulated contactor DISABLED so that every
%   fault flag stays observable for the whole run. Scenario 11 enables it.

    if nargin < 2, P = bms_params(); end
    nan_ = NaN;
    prot = false;
    Tamb = @(t) 25 + 0 * t;
    T0   = 25;
    SOCf = nan_;

    switch id
        case 1
            sc.name = 'Normal discharge';
            t_end = 1800; SOC0 = 80; I = @(t) 20 + 0 * t;
            exp_ = [0 0 0 0]; SOCf = 60;
            sc.description = '20 A constant discharge for 30 min from 80 %.';
        case 2
            sc.name = 'Battery charging';
            t_end = 3600; SOC0 = 30; I = @(t) -25 + 0 * t;
            exp_ = [0 0 0 0]; SOCf = 80;
            sc.description = '25 A constant charge (negative current) for 1 h from 30 %.';
        case 3
            sc.name = 'Variable load current';
            t_end = 3600; SOC0 = 90;
            tp = [0 300 600 900 1200 1500 1800 2100 2400 3000 3600];
            Ip = [0  40  70  -30   20   60  -20   45   10   30    0];
            I = @(t) interp1(tp, Ip, t, 'linear');
            exp_ = [0 0 0 0];
            sc.description = 'Drive-cycle-like profile with regenerative (negative) segments, peak 70 A.';
        case 4
            sc.name = 'Overvoltage';
            t_end = 600; SOC0 = 85; I = @(t) -40 + 0 * t;
            exp_ = [1 0 0 0];
            sc.description = '40 A charge from 85 %: terminal voltage rises above 54.6 V.';
        case 5
            sc.name = 'Undervoltage';
            t_end = 600; SOC0 = 12; I = @(t) 60 + 0 * t;
            exp_ = [0 1 0 0];
            sc.description = '60 A discharge from 12 %: voltage falls below 39 V near empty.';
        case 6
            sc.name = 'Overcurrent (discharge)';
            t_end = 600; SOC0 = 70; I = @(t) 20 + 100 * (t >= 300 & t < 400);
            exp_ = [0 0 1 0];
            sc.description = '20 A load with a 120 A pulse from t = 300 s to 400 s.';
        case 7
            sc.name = 'Excessive charging current';
            t_end = 600; SOC0 = 40; I = @(t) -20 - 100 * (t >= 300 & t < 400);
            exp_ = [0 0 1 0];
            sc.description = '20 A charge with a -120 A pulse from t = 300 s to 400 s.';
        case 8
            sc.name = 'Overtemperature';
            t_end = 1800; SOC0 = 95; T0 = 50; Tamb = @(t) 40 + 0 * t;
            I = @(t) 80 + 0 * t;
            exp_ = [0 0 0 1];
            sc.description = 'Hot start (50 degC), 40 degC ambient, 80 A discharge: I^2*R0 heating.';
        case 9
            sc.name = 'Multiple simultaneous faults';
            t_end = 300; SOC0 = 95; T0 = 58; Tamb = @(t) 45 + 0 * t;
            I = @(t) -130 + 0 * t;
            exp_ = [1 0 1 1];
            sc.description = '130 A charge at 95 % SOC, hot pack: OV + OC at once, OT after about 50 s.';
        case 10
            sc.name = 'SOC approaching lower limit';
            t_end = 1200; SOC0 = 15; I = @(t) 30 + 0 * t;
            exp_ = [0 1 0 0]; SOCf = 0;
            sc.description = '30 A discharge from 15 %: SOC saturates at 0 % near t = 900 s, UV near the end.';
        case 11
            sc.name = 'Protection demo (contactor trip)';
            t_end = 600; SOC0 = 70; I = @(t) 20 + 100 * (t >= 300 & t < 400);
            exp_ = [0 0 1 0]; prot = true;
            sc.description = 'Same as scenario 6 but the simulated contactor opens and latches.';
        otherwise
            error('bms_scenarios:badId', 'Scenario id must be 1..11.');
    end

    t = (0:P.dt:t_end).';
    sc.id         = id;
    sc.t          = t;
    sc.I_cmd      = I(t);
    sc.T_amb      = Tamb(t);
    sc.SOC_init   = SOC0;
    sc.T_init     = T0;
    sc.protection = prot;
    sc.expect     = struct('OV', exp_(1) == 1, 'UV', exp_(2) == 1, ...
                           'OC', exp_(3) == 1, 'OT', exp_(4) == 1);
    sc.SOC_final_expected = SOCf;
end
