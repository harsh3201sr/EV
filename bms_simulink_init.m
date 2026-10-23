% bms_simulink_init.m   (script, runs in the BASE workspace)
%  Creates every workspace variable that EV_BMS_SOC.slx uses in its block
%  parameters. The model calls this automatically (InitFcn) before each run.
%
%  Choose before running:
%     scenario_id  = 1..11   (default 1)   which bms_scenarios() case drives the load
%     stage_select = 1       Stage B: battery model produces V, I, T   (default)
%                  = 0       Stage A: synthetic V, I, T signals are used instead

if ~exist('scenario_id', 'var'),  scenario_id  = 1; end %#ok<*NASGU>
if ~exist('stage_select', 'var'), stage_select = 1; end

P_  = bms_params();
sc_ = bms_scenarios(scenario_id, P_);
SA_ = bms_stageA_signals(P_);

% ---- battery / protection parameters (names used in block dialogs) ---------
Q_Ah     = P_.Q_Ah;
SOC_init = sc_.SOC_init;
if isempty(P_.SOC_est_init), SOC_est_init = sc_.SOC_init; else, SOC_est_init = P_.SOC_est_init; end
T_init   = sc_.T_init;
R0       = P_.R0;
inv_Rth  = 1 / P_.Rth;                 % 1/(K/W)
inv_Cth  = 1 / P_.Cth;                 % 1/(J/K)
V_max    = P_.V_max;   V_min = P_.V_min;   I_max = P_.I_max;   T_max = P_.T_max;
I_offset = P_.I_offset;
SOC_bp   = P_.SOC_bp;  OCV_pack = P_.OCV_pack;
protection_enable = double(sc_.protection);

% ---- SOC integrator gain: % per (A*s)  = -100 / (3600 * Q_Ah) ---------------
k_soc    = -100 / (3600 * Q_Ah);       % e.g. 50 Ah -> -5.5556e-4

% ---- time base ---------------------------------------------------------------
Ts = P_.dt;
if stage_select == 1, Tstop = sc_.t(end); else, Tstop = SA_.t(end); end

% ---- From Workspace data: [time, value] matrices ---------------------------
I_load_data = [sc_.t, sc_.I_cmd];
Tamb_data   = [sc_.t, sc_.T_amb];
V_sig_data  = [SA_.t, SA_.V];
I_sig_data  = [SA_.t, SA_.I];
T_sig_data  = [SA_.t, SA_.T];
