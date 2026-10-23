function create_EV_BMS_model(run_test)
%CREATE_EV_BMS_MODEL  Programmatically builds and saves EV_BMS_SOC.slx.
%
%   >> create_EV_BMS_model          % build, save, compile-check, short test run
%   >> create_EV_BMS_model(false)   % build and save only
%
%   REQUIRES: MATLAB + Simulink only (all blocks are core Simulink; no
%   Simscape, Stateflow or other toolbox). Keep all project files in one folder.
%
%   STATUS: this script was NOT run inside MATLAB/Simulink by its author (no
%   MATLAB was available). Its block list and connections were checked by a
%   separate structural checker, but you must run it once to confirm it works
%   on your release. See "Troubleshooting" in the guide if a line errors.
%
%   Model structure (top level):
%     ILoad_Profile -> Protection_Control -> Battery_Model -> [Stage switches]
%        -> Battery_Monitoring -> SOC_Estimator
%                              -> Fault_Detection -> Protection_Control (loop)
%        -> Visualization (scopes, displays)  and  To Workspace logging

    if nargin < 1, run_test = true; end
    mdl = 'EV_BMS_SOC';

    % ---- make sure workspace variables exist, start from a clean model ------
    evalin('base', 'bms_simulink_init;');
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    if exist([mdl '.slx'], 'file'), delete([mdl '.slx']); end
    new_system(mdl);
    open_system(mdl);

    % ---- solver configuration: fixed-step Euler, 1 s (= P.dt) --------------
    set_param(mdl, 'SolverType', 'Fixed-step');
    set_param(mdl, 'Solver', 'ode1');
    set_param(mdl, 'FixedStep', 'Ts');
    set_param(mdl, 'StopTime', 'Tstop');
    set_param(mdl, 'InitFcn', 'bms_simulink_init;');
    set_param(mdl, 'SaveTime', 'on');
    set_param(mdl, 'ReturnWorkspaceOutputs', 'on');

    %% =================== SUBSYSTEM 1: Battery_Model ==========================
    % Inputs : I_load (A, + discharge), T_amb (degC)
    % Outputs: V_batt (V), I_batt (A), T_batt (degC), SOC_true (%)
    % V = OCV(SOC) - I*R0 ;  C*dT/dt = I^2*R0 - (T - Tamb)/Rth
    sys = mdl;
    blk(sys, 'Battery_Model', 'built-in/Subsystem', [420 60 560 200]);
    sys = [mdl '/Battery_Model'];
    blk(sys, 'I_load',        'simulink/Sources/In1',                [20 40 50 54],    'Port', '1');
    blk(sys, 'T_amb',         'simulink/Sources/In1',                [20 300 50 314],  'Port', '2');
    blk(sys, 'Gain_SOC',      'simulink/Math Operations/Gain',       [110 20 170 50],  'Gain', 'k_soc');
    blk(sys, 'SOC0_const',    'simulink/Sources/Constant',           [110 80 170 110], 'Value', 'SOC_init');
    blk(sys, 'Int_SOC',       'simulink/Continuous/Integrator',      [220 30 260 100], 'InitialConditionSource', 'external', 'LimitOutput', 'on', 'UpperSaturationLimit', '100', 'LowerSaturationLimit', '0');
    blk(sys, 'OCV_Lookup',    'simulink/Lookup Tables/1-D Lookup Table', [310 30 380 60], 'BreakpointsForDimension1', 'SOC_bp', 'Table', 'OCV_pack');
    blk(sys, 'Gain_R0',       'simulink/Math Operations/Gain',       [110 140 170 170], 'Gain', 'R0');
    blk(sys, 'Sum_V',         'simulink/Math Operations/Sum',        [430 40 460 80],  'Inputs', '+-');
    blk(sys, 'Prod_I2',       'simulink/Math Operations/Product',    [110 220 140 260], 'Inputs', '2');
    blk(sys, 'Gain_Heat',     'simulink/Math Operations/Gain',       [180 225 240 255], 'Gain', 'R0');
    blk(sys, 'Sum_dT',        'simulink/Math Operations/Sum',        [180 290 210 330], 'Inputs', '+-');
    blk(sys, 'Gain_Rth_inv',  'simulink/Math Operations/Gain',       [240 295 300 325], 'Gain', 'inv_Rth');
    blk(sys, 'Sum_Net',       'simulink/Math Operations/Sum',        [340 235 370 275], 'Inputs', '+-');
    blk(sys, 'Gain_Cth_inv',  'simulink/Math Operations/Gain',       [400 240 460 270], 'Gain', 'inv_Cth');
    blk(sys, 'Int_T',         'simulink/Continuous/Integrator',      [500 235 540 275], 'InitialCondition', 'T_init');
    blk(sys, 'V_batt',        'simulink/Sinks/Out1',                 [600 52 630 66],  'Port', '1');
    blk(sys, 'I_batt',        'simulink/Sinks/Out1',                 [600 112 630 126], 'Port', '2');
    blk(sys, 'T_batt',        'simulink/Sinks/Out1',                 [600 245 630 259], 'Port', '3');
    blk(sys, 'SOC_true',      'simulink/Sinks/Out1',                 [600 12 630 26],  'Port', '4');
    ln(sys, 'I_load/1',       'Gain_SOC/1');
    ln(sys, 'Gain_SOC/1',     'Int_SOC/1');
    ln(sys, 'SOC0_const/1',   'Int_SOC/2');
    ln(sys, 'Int_SOC/1',      'OCV_Lookup/1');
    ln(sys, 'Int_SOC/1',      'SOC_true/1');
    ln(sys, 'I_load/1',       'Gain_R0/1');
    ln(sys, 'OCV_Lookup/1',   'Sum_V/1');
    ln(sys, 'Gain_R0/1',      'Sum_V/2');
    ln(sys, 'Sum_V/1',        'V_batt/1');
    ln(sys, 'I_load/1',       'I_batt/1');
    ln(sys, 'I_load/1',       'Prod_I2/1');
    ln(sys, 'I_load/1',       'Prod_I2/2');
    ln(sys, 'Prod_I2/1',      'Gain_Heat/1');
    ln(sys, 'Int_T/1',        'Sum_dT/1');
    ln(sys, 'T_amb/1',        'Sum_dT/2');
    ln(sys, 'Sum_dT/1',       'Gain_Rth_inv/1');
    ln(sys, 'Gain_Heat/1',    'Sum_Net/1');
    ln(sys, 'Gain_Rth_inv/1', 'Sum_Net/2');
    ln(sys, 'Sum_Net/1',      'Gain_Cth_inv/1');
    ln(sys, 'Gain_Cth_inv/1', 'Int_T/1');
    ln(sys, 'Int_T/1',        'T_batt/1');
    % Clip (do not extrapolate) outside the table; parameter name varies by release.
    try, set_param([sys '/OCV_Lookup'], 'ExtrapMethod', 'Clip'); catch, end

    %% =================== SUBSYSTEM 2: SOC_Estimator ==========================
    % SOC(t) = SOC0 + integral( -100/(3600*Q) * I dt ), limited to 0..100 %.
    % Gain = -100/(3600*Q_Ah): A*s -> Ah -> fraction of Q -> percent, minus = discharge.
    sys = mdl;
    blk(sys, 'SOC_Estimator', 'built-in/Subsystem', [980 420 1120 500]);
    sys = [mdl '/SOC_Estimator'];
    blk(sys, 'I_meas',    'simulink/Sources/In1',               [20 40 50 54],   'Port', '1');
    blk(sys, 'Gain_SOC',  'simulink/Math Operations/Gain',      [100 30 160 60], 'Gain', 'k_soc');
    blk(sys, 'SOC_est0',  'simulink/Sources/Constant',          [100 100 160 130], 'Value', 'SOC_est_init');
    blk(sys, 'Int_SOC',   'simulink/Continuous/Integrator',     [210 30 250 130], 'InitialConditionSource', 'external', 'LimitOutput', 'on', 'UpperSaturationLimit', '100', 'LowerSaturationLimit', '0');
    blk(sys, 'Sat_SOC',   'simulink/Discontinuities/Saturation', [300 50 350 80], 'UpperLimit', '100', 'LowerLimit', '0');
    blk(sys, 'SOC_est',   'simulink/Sinks/Out1',                [400 58 430 72], 'Port', '1');
    ln(sys, 'I_meas/1',   'Gain_SOC/1');
    ln(sys, 'Gain_SOC/1', 'Int_SOC/1');
    ln(sys, 'SOC_est0/1', 'Int_SOC/2');
    ln(sys, 'Int_SOC/1',  'Sat_SOC/1');
    ln(sys, 'Sat_SOC/1',  'SOC_est/1');

    %% =================== SUBSYSTEM 3: Battery_Monitoring =====================
    % Measurement layer: passes V, T, SOC and adds a configurable current-sensor
    % offset (Sum block) so you can study drift. Outputs are what the BMS "sees".
    sys = mdl;
    blk(sys, 'Battery_Monitoring', 'built-in/Subsystem', [760 200 900 340]);
    sys = [mdl '/Battery_Monitoring'];
    blk(sys, 'V',              'simulink/Sources/In1', [20 30 50 44],   'Port', '1');
    blk(sys, 'I',              'simulink/Sources/In1', [20 90 50 104],  'Port', '2');
    blk(sys, 'T',              'simulink/Sources/In1', [20 190 50 204], 'Port', '3');
    blk(sys, 'SOC',            'simulink/Sources/In1', [20 250 50 264], 'Port', '4');
    blk(sys, 'I_offset_const', 'simulink/Sources/Constant', [20 130 80 160], 'Value', 'I_offset');
    blk(sys, 'Sum_I_sensor',   'simulink/Math Operations/Sum', [140 90 170 130], 'Inputs', '++');
    blk(sys, 'V_meas',         'simulink/Sinks/Out1',  [260 30 290 44],   'Port', '1');
    blk(sys, 'I_meas',         'simulink/Sinks/Out1',  [260 103 290 117], 'Port', '2');
    blk(sys, 'T_meas',         'simulink/Sinks/Out1',  [260 190 290 204], 'Port', '3');
    blk(sys, 'SOC_mon',        'simulink/Sinks/Out1',  [260 250 290 264], 'Port', '4');
    ln(sys, 'V/1',              'V_meas/1');
    ln(sys, 'I/1',              'Sum_I_sensor/1');
    ln(sys, 'I_offset_const/1', 'Sum_I_sensor/2');
    ln(sys, 'Sum_I_sensor/1',   'I_meas/1');
    ln(sys, 'T/1',              'T_meas/1');
    ln(sys, 'SOC/1',            'SOC_mon/1');

    %% =================== SUBSYSTEM 4: Fault_Detection ========================
    % OV: V > V_max | UV: V < V_min | OC: |I| > I_max | OT: T > T_max | ANY = OR
    sys = mdl;
    blk(sys, 'Fault_Detection', 'built-in/Subsystem', [1000 200 1140 340]);
    sys = [mdl '/Fault_Detection'];
    blk(sys, 'V',        'simulink/Sources/In1', [20 30 50 44],   'Port', '1');
    blk(sys, 'I',        'simulink/Sources/In1', [20 130 50 144], 'Port', '2');
    blk(sys, 'T',        'simulink/Sources/In1', [20 230 50 244], 'Port', '3');
    blk(sys, 'Vmax_const', 'simulink/Sources/Constant', [90 5 150 25],    'Value', 'V_max');
    blk(sys, 'Vmin_const', 'simulink/Sources/Constant', [90 60 150 80],   'Value', 'V_min');
    blk(sys, 'Imax_const', 'simulink/Sources/Constant', [190 150 250 170], 'Value', 'I_max');
    blk(sys, 'Tmax_const', 'simulink/Sources/Constant', [90 255 150 275], 'Value', 'T_max');
    blk(sys, 'Abs_I',    'simulink/Math Operations/Abs', [90 125 130 150]);
    blk(sys, 'Rel_OV',   'simulink/Logic and Bit Operations/Relational Operator', [270 20 310 50],  'Operator', '>');
    blk(sys, 'Rel_UV',   'simulink/Logic and Bit Operations/Relational Operator', [270 80 310 110], 'Operator', '<');
    blk(sys, 'Rel_OC',   'simulink/Logic and Bit Operations/Relational Operator', [270 130 310 160], 'Operator', '>');
    blk(sys, 'Rel_OT',   'simulink/Logic and Bit Operations/Relational Operator', [270 230 310 260], 'Operator', '>');
    blk(sys, 'OR_Any',   'simulink/Logic and Bit Operations/Logical Operator', [400 120 430 200], 'Operator', 'OR', 'Inputs', '4');
    blk(sys, 'OV',       'simulink/Sinks/Out1', [500 28 530 42],   'Port', '1');
    blk(sys, 'UV',       'simulink/Sinks/Out1', [500 88 530 102],  'Port', '2');
    blk(sys, 'OC',       'simulink/Sinks/Out1', [500 138 530 152], 'Port', '3');
    blk(sys, 'OT',       'simulink/Sinks/Out1', [500 238 530 252], 'Port', '4');
    blk(sys, 'ANY',      'simulink/Sinks/Out1', [500 153 530 167], 'Port', '5');
    ln(sys, 'V/1',         'Rel_OV/1');
    ln(sys, 'Vmax_const/1','Rel_OV/2');
    ln(sys, 'V/1',         'Rel_UV/1');
    ln(sys, 'Vmin_const/1','Rel_UV/2');
    ln(sys, 'I/1',         'Abs_I/1');
    ln(sys, 'Abs_I/1',     'Rel_OC/1');
    ln(sys, 'Imax_const/1','Rel_OC/2');
    ln(sys, 'T/1',         'Rel_OT/1');
    ln(sys, 'Tmax_const/1','Rel_OT/2');
    ln(sys, 'Rel_OV/1',    'OR_Any/1');
    ln(sys, 'Rel_UV/1',    'OR_Any/2');
    ln(sys, 'Rel_OC/1',    'OR_Any/3');
    ln(sys, 'Rel_OT/1',    'OR_Any/4');
    ln(sys, 'Rel_OV/1',    'OV/1');
    ln(sys, 'Rel_UV/1',    'UV/1');
    ln(sys, 'Rel_OC/1',    'OC/1');
    ln(sys, 'Rel_OT/1',    'OT/1');
    ln(sys, 'OR_Any/1',    'ANY/1');

    %% =================== Protection_Control (optional) =======================
    % SIMULATED contactor-open command. A fault sets a latch (one-sample delay
    % breaks the algebraic loop); the latch opens the "contactor", i.e. forces
    % the load current to zero. protection_enable = 0 disables it.
    % This is only a signal in a simulation, NOT a hardware disconnection system.
    sys = mdl;
    blk(sys, 'Protection_Control', 'built-in/Subsystem', [240 60 380 160]);
    sys = [mdl '/Protection_Control'];
    blk(sys, 'I_cmd',          'simulink/Sources/In1', [20 40 50 54],    'Port', '1');
    blk(sys, 'Fault_any',      'simulink/Sources/In1', [20 140 50 154],  'Port', '2');
    blk(sys, 'OR_Latch',       'simulink/Logic and Bit Operations/Logical Operator', [100 130 130 170], 'Operator', 'OR', 'Inputs', '2');
    blk(sys, 'Latch_Memory',   'simulink/Discrete/Unit Delay', [170 130 210 170], 'InitialCondition', '0', 'SampleTime', 'Ts');
    blk(sys, 'Prot_enable',    'simulink/Sources/Constant', [170 200 230 230], 'Value', 'logical(protection_enable)', 'OutDataTypeStr', 'boolean');
    blk(sys, 'AND_Enable',     'simulink/Logic and Bit Operations/Logical Operator', [280 140 310 180], 'Operator', 'AND', 'Inputs', '2');
    blk(sys, 'NOT_Trip',       'simulink/Logic and Bit Operations/Logical Operator', [350 145 380 175], 'Operator', 'NOT');
    blk(sys, 'To_Double',      'simulink/Signal Attributes/Data Type Conversion', [420 145 470 175], 'OutDataTypeStr', 'double');
    blk(sys, 'Gate_I',         'simulink/Math Operations/Product', [530 40 560 80], 'Inputs', '2');
    blk(sys, 'I_actual',       'simulink/Sinks/Out1', [620 53 650 67],   'Port', '1');
    blk(sys, 'Contactor_closed', 'simulink/Sinks/Out1', [620 153 650 167], 'Port', '2');
    blk(sys, 'Trip_latched',   'simulink/Sinks/Out1', [620 213 650 227], 'Port', '3');
    ln(sys, 'Fault_any/1',     'OR_Latch/1');
    ln(sys, 'OR_Latch/1',      'Latch_Memory/1');
    ln(sys, 'Latch_Memory/1',  'OR_Latch/2');
    ln(sys, 'Latch_Memory/1',  'AND_Enable/1');
    ln(sys, 'Prot_enable/1',   'AND_Enable/2');
    ln(sys, 'AND_Enable/1',    'NOT_Trip/1');
    ln(sys, 'NOT_Trip/1',      'To_Double/1');
    ln(sys, 'I_cmd/1',         'Gate_I/1');
    ln(sys, 'To_Double/1',     'Gate_I/2');
    ln(sys, 'Gate_I/1',        'I_actual/1');
    ln(sys, 'To_Double/1',     'Contactor_closed/1');
    ln(sys, 'AND_Enable/1',    'Trip_latched/1');

    %% =================== SUBSYSTEM 5: Visualization ==========================
    sys = mdl;
    blk(sys, 'Visualization', 'built-in/Subsystem', [1240 120 1380 420]);
    sys = [mdl '/Visualization'];
    blk(sys, 'SOC_true_in',  'simulink/Sources/In1', [20 20 50 34],    'Port', '1');
    blk(sys, 'SOC_est_in',   'simulink/Sources/In1', [20 70 50 84],    'Port', '2');
    blk(sys, 'V_in',         'simulink/Sources/In1', [20 120 50 134],  'Port', '3');
    blk(sys, 'I_in',         'simulink/Sources/In1', [20 170 50 184],  'Port', '4');
    blk(sys, 'T_in',         'simulink/Sources/In1', [20 220 50 234],  'Port', '5');
    blk(sys, 'OV_in',        'simulink/Sources/In1', [20 270 50 284],  'Port', '6');
    blk(sys, 'UV_in',        'simulink/Sources/In1', [20 300 50 314],  'Port', '7');
    blk(sys, 'OC_in',        'simulink/Sources/In1', [20 330 50 344],  'Port', '8');
    blk(sys, 'OT_in',        'simulink/Sources/In1', [20 360 50 374],  'Port', '9');
    blk(sys, 'ANY_in',       'simulink/Sources/In1', [20 390 50 404],  'Port', '10');
    blk(sys, 'Contactor_in', 'simulink/Sources/In1', [20 440 50 454],  'Port', '11');
    blk(sys, 'Scope_SOC',         'simulink/Sinks/Scope', [200 20 240 90],   'NumInputPorts', '2');
    blk(sys, 'Scope_Voltage',     'simulink/Sinks/Scope', [200 110 240 140]);
    blk(sys, 'Scope_Current',     'simulink/Sinks/Scope', [200 160 240 190]);
    blk(sys, 'Scope_Temperature', 'simulink/Sinks/Scope', [200 210 240 240]);
    blk(sys, 'Scope_Faults',      'simulink/Sinks/Scope', [200 260 240 410], 'NumInputPorts', '5');
    blk(sys, 'Display_SOC',       'simulink/Sinks/Display', [320 60 400 90]);
    blk(sys, 'Display_Fault_Any', 'simulink/Sinks/Display', [320 380 400 410]);
    blk(sys, 'Display_Contactor', 'simulink/Sinks/Display', [320 430 400 460]);
    ln(sys, 'SOC_true_in/1',  'Scope_SOC/1');
    ln(sys, 'SOC_est_in/1',   'Scope_SOC/2');
    ln(sys, 'SOC_est_in/1',   'Display_SOC/1');
    ln(sys, 'V_in/1',         'Scope_Voltage/1');
    ln(sys, 'I_in/1',         'Scope_Current/1');
    ln(sys, 'T_in/1',         'Scope_Temperature/1');
    ln(sys, 'OV_in/1',        'Scope_Faults/1');
    ln(sys, 'UV_in/1',        'Scope_Faults/2');
    ln(sys, 'OC_in/1',        'Scope_Faults/3');
    ln(sys, 'OT_in/1',        'Scope_Faults/4');
    ln(sys, 'ANY_in/1',       'Scope_Faults/5');
    ln(sys, 'ANY_in/1',       'Display_Fault_Any/1');
    ln(sys, 'Contactor_in/1', 'Display_Contactor/1');

    %% =================== TOP LEVEL: sources, stage switch, wiring ============
    sys = mdl;
    blk(sys, 'ILoad_Profile', 'simulink/Sources/From Workspace', [40 60 130 90],   'VariableName', 'I_load_data', 'SampleTime', '0', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    blk(sys, 'Tamb_Profile',  'simulink/Sources/From Workspace', [40 180 130 210], 'VariableName', 'Tamb_data',   'SampleTime', '0', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    blk(sys, 'V_Synthetic',   'simulink/Sources/From Workspace', [420 260 510 290], 'VariableName', 'V_sig_data', 'SampleTime', '0', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    blk(sys, 'I_Synthetic',   'simulink/Sources/From Workspace', [420 320 510 350], 'VariableName', 'I_sig_data', 'SampleTime', '0', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    blk(sys, 'T_Synthetic',   'simulink/Sources/From Workspace', [420 380 510 410], 'VariableName', 'T_sig_data', 'SampleTime', '0', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value');
    blk(sys, 'Stage_Select',  'simulink/Sources/Constant',       [420 450 510 480], 'Value', 'stage_select');
    blk(sys, 'Switch_V', 'simulink/Signal Routing/Switch', [620 90 660 130],  'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
    blk(sys, 'Switch_I', 'simulink/Signal Routing/Switch', [620 190 660 230], 'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
    blk(sys, 'Switch_T', 'simulink/Signal Routing/Switch', [620 290 660 330], 'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');
    ln(sys, 'ILoad_Profile/1',     'Protection_Control/1');
    ln(sys, 'Protection_Control/1','Battery_Model/1');
    ln(sys, 'Tamb_Profile/1',      'Battery_Model/2');
    ln(sys, 'Battery_Model/1',     'Switch_V/1');
    ln(sys, 'V_Synthetic/1',       'Switch_V/3');
    ln(sys, 'Stage_Select/1',      'Switch_V/2');
    ln(sys, 'Battery_Model/2',     'Switch_I/1');
    ln(sys, 'I_Synthetic/1',       'Switch_I/3');
    ln(sys, 'Stage_Select/1',      'Switch_I/2');
    ln(sys, 'Battery_Model/3',     'Switch_T/1');
    ln(sys, 'T_Synthetic/1',       'Switch_T/3');
    ln(sys, 'Stage_Select/1',      'Switch_T/2');
    ln(sys, 'Switch_V/1',          'Battery_Monitoring/1');
    ln(sys, 'Switch_I/1',          'Battery_Monitoring/2');
    ln(sys, 'Switch_T/1',          'Battery_Monitoring/3');
    ln(sys, 'SOC_Estimator/1',     'Battery_Monitoring/4');
    ln(sys, 'Battery_Monitoring/2','SOC_Estimator/1');
    ln(sys, 'Battery_Monitoring/1','Fault_Detection/1');
    ln(sys, 'Battery_Monitoring/2','Fault_Detection/2');
    ln(sys, 'Battery_Monitoring/3','Fault_Detection/3');
    ln(sys, 'Fault_Detection/5',   'Protection_Control/2');
    ln(sys, 'Battery_Model/4',     'Visualization/1');
    ln(sys, 'Battery_Monitoring/4','Visualization/2');
    ln(sys, 'Battery_Monitoring/1','Visualization/3');
    ln(sys, 'Battery_Monitoring/2','Visualization/4');
    ln(sys, 'Battery_Monitoring/3','Visualization/5');
    ln(sys, 'Fault_Detection/1',   'Visualization/6');
    ln(sys, 'Fault_Detection/2',   'Visualization/7');
    ln(sys, 'Fault_Detection/3',   'Visualization/8');
    ln(sys, 'Fault_Detection/4',   'Visualization/9');
    ln(sys, 'Fault_Detection/5',   'Visualization/10');
    ln(sys, 'Protection_Control/2','Visualization/11');

    %% =================== Logging to workspace (for post-processing) ==========
    blk(sys, 'log_SOC_true', 'simulink/Sinks/To Workspace', [1440 20 1520 40],  'VariableName', 'log_SOC_true', 'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_SOC_est',  'simulink/Sinks/To Workspace', [1440 60 1520 80],  'VariableName', 'log_SOC_est',  'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_V',        'simulink/Sinks/To Workspace', [1440 100 1520 120], 'VariableName', 'log_V',       'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_I',        'simulink/Sinks/To Workspace', [1440 140 1520 160], 'VariableName', 'log_I',       'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_T',        'simulink/Sinks/To Workspace', [1440 180 1520 200], 'VariableName', 'log_T',       'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_OV',       'simulink/Sinks/To Workspace', [1440 220 1520 240], 'VariableName', 'log_OV',      'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_UV',       'simulink/Sinks/To Workspace', [1440 260 1520 280], 'VariableName', 'log_UV',      'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_OC',       'simulink/Sinks/To Workspace', [1440 300 1520 320], 'VariableName', 'log_OC',      'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_OT',       'simulink/Sinks/To Workspace', [1440 340 1520 360], 'VariableName', 'log_OT',      'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_ANY',      'simulink/Sinks/To Workspace', [1440 380 1520 400], 'VariableName', 'log_ANY',     'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    blk(sys, 'log_Contactor','simulink/Sinks/To Workspace', [1440 420 1520 440], 'VariableName', 'log_Contactor', 'SaveFormat', 'Array', 'MaxDataPoints', 'inf');
    ln(sys, 'Battery_Model/4',     'log_SOC_true/1');
    ln(sys, 'Battery_Monitoring/4','log_SOC_est/1');
    ln(sys, 'Battery_Monitoring/1','log_V/1');
    ln(sys, 'Battery_Monitoring/2','log_I/1');
    ln(sys, 'Battery_Monitoring/3','log_T/1');
    ln(sys, 'Fault_Detection/1',   'log_OV/1');
    ln(sys, 'Fault_Detection/2',   'log_UV/1');
    ln(sys, 'Fault_Detection/3',   'log_OC/1');
    ln(sys, 'Fault_Detection/4',   'log_OT/1');
    ln(sys, 'Fault_Detection/5',   'log_ANY/1');
    ln(sys, 'Protection_Control/2','log_Contactor/1');

    %% =================== Save, compile-check, optional test run ==============
    save_system(mdl, [mdl '.slx']);
    fprintf('Saved %s.slx\n', mdl);

    try
        set_param(mdl, 'SimulationCommand', 'update');      % compile check
        fprintf('Model diagram update (compile check): OK\n');
    catch ME
        fprintf(2, 'Compile check FAILED:\n%s\n', ME.message);
        fprintf(2, 'See the troubleshooting section of the guide.\n');
        return;
    end

    if run_test
        try
            out = sim(mdl);
            soc = out.get('log_SOC_est');
            fprintf('Test run OK. Final estimated SOC = %.2f %% (scenario %d).\n', ...
                    soc(end), evalin('base', 'scenario_id'));
        catch ME
            fprintf(2, 'Test run FAILED:\n%s\n', ME.message);
        end
    end
    save_system(mdl);
end

% ---------------------------------------------------------------------------
function blk(sys, name, lib, pos, varargin)
%BLK  add_block wrapper: library path, name, [x1 y1 x2 y2] position, params.
    add_block(lib, [sys '/' name], 'Position', pos, varargin{:});
end

function ln(sys, src, dst)
%LN  add_line wrapper: 'Block/port' -> 'Block/port'.
    add_line(sys, src, dst, 'autorouting', 'on');
end
