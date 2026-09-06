%% PV + Battery + VSI + Grid System — Parameter Script
% Run this script BEFORE opening/simulating the Simulink model.
% Every block should reference these variable names in its dialog boxes
% instead of typed-in numbers. Edit values here, re-run the script,
% then just hit Run in Simulink — no need to touch block dialogs again.
%
% As we build each new subsystem, add its parameters to the matching
% section below and keep using descriptive prefixes (pv_, res_, boost_,
% batt_, vsi_, grid_, load_) so variable names stay unambiguous once
% the model gets big.
%
% CHANGE LOG (this pass): the three Stateflow charts (Charge Controller,
% Boost MPPT, BuckBoost gate driver) previously had their own hardcoded
% copies of several of these numbers, which had drifted out of sync with
% this script. They've been rewired to pull directly from the variables
% below via Stateflow chart parameters, so this file is now the single
% source of truth for all of them. No existing tuned value was changed —
% the additions below (mppt_Vdc_start_clamp, mppt_Vdc_trip, mppt_Dold_init,
% cc_Ib_trim_max, cc_Iff_max) simply expose numbers that were already
% hardcoded in the charts, plus one bug fix (mppt_Dold_init — see note).

%% ---- Solver / Powergui ----
Ts = 1e-6;              % Fixed-step / powergui discrete sample time (s)

%% ---- PV Array (Step 1) ----
pv_Nser = 1;             % Series modules per string
pv_Npar = 1;             % Parallel strings
pv_irradiance = 1000;    % W/m^2 (feeds Constant -> PV Array input 1)
pv_temperature = 25;     % degC  (feeds Constant1 -> PV Array input 2)

% Reference module electrical ratings (1Soltech 1STH-215-P defaults —
% only relevant if you ever rebuild the module from scratch instead of
% using the preset; the PV Array block already stores these internally
% once you pick/keep the module, so this is just for our own reference
% when sizing the test load below)
pv_Vm = 29;               % V, voltage at max power (single module)
pv_Im = 7.35;             % A, current at max power (single module)

%% ---- Cpv: input capacitor at PV array terminals ----
% CRITICAL: required for solver stability whenever an inductor (R1/L1) is
% the load — without this, the discrete solver produces NaN immediately.
pv_Cpv = 1000e-6;           % F

%% ---- Test load (Step 1 resistive load, temporary) ----
% Rough load to sit near the array's operating point.
% R = (pv_Vm * pv_Nser) / (pv_Im * pv_Npar)
res_test_load = (pv_Vm * pv_Nser) / (pv_Im * pv_Npar);

fprintf('pv_system_params loaded.\n');
fprintf('  Array config: %d series x %d parallel\n', pv_Nser, pv_Npar);
fprintf('  Suggested test resistor: %.3f ohm\n', res_test_load);

%% ---- Boost Converter + MPPT (Step 2 — VERIFIED WORKING) ----
boost_R1 = 0.5;            % ohm, series resistance (R1)
boost_L1 = 200e-6;           % H, series inductance (L1)
boost_Cdc = 2200e-6;          % F, DC bus capacitor (plain Capacitor block, not Series RLC)
boost_Fsw = 10000;         % Hz, PWM switching frequency

% MPPT (P&O, direction-based, with low-pass filtering on Vpv/Ipv)
mppt_Ts = 0.1;             % s, MPPT decision update rate (must be >> circuit settling time)
                            % NOW ACTUALLY WIRED: this is set as the boost
                            % MPPT block's own Sample time in its dialog,
                            % so the chart runs its P&O step exactly once
                            % per mppt_Ts — no more internal call-counter.
mppt_dD = 0.001;           % duty step size per decision
mppt_Dold_init = 0.75;     % seed near known MPP (found via manual duty sweep) instead of 0.5,
                            % since P&O struggled to find MPP from a cold start across the
                            % full duty range — this is a coarse-start + fine-P&O approach
                            % BUG FIX: the chart was previously hardcoding Dold = 0.1 and
                            % ignoring this variable entirely — that cold start from the
                            % wrong end of the duty range is the likely cause of the ~2s of
                            % chaotic hunting seen at the start of the V_PV/I_PV scopes.
                            % It now actually seeds from mppt_Dold_init.
mppt_filter_alpha = 0.1;   % EMA filter strength on raw Vpv/Ipv before MPPT judges them
mppt_max_duty_step = 0.02;
% Boost duty-cycle ceiling (protects against Vdc overshoot). Previously
% hardcoded inside the chart as Vdc_start_clamp=175 / Vdc_trip=180 (only
% a 5V-wide ramp — effectively a relay). Same values kept here so nothing
% changes behaviorally yet; widen the gap between these two if you still
% see bang-bang oscillation on Vdc/I_PV after the sync fixes above.
mppt_Vdc_start_clamp = 220;   % V, duty ceiling starts easing down above this
mppt_Vdc_trip = 280;          % V, duty ceiling reaches its 0.1 floor at this
mppt_Vdc_hyst = 15;          % V, hysteresis margin — clamp releases only after
                              % Vdc drops this far below mppt_Vdc_start_clamp
% Temporary DC-bus dump load (stands in for battery/VSI until those are built)
load_Rdc = 100;            % ohm

%% ---- Battery (Step 3 — VERIFIED WORKING) ----
batt_nominal_voltage = 48;    % V
batt_rated_capacity = 100;    % Ah
batt_type = 'Lithium-Ion';    % chemistry
batt_test_load_R = 10;        % ohm, temporary isolation-test load only

%% ---- Bidirectional Buck-Boost / Charge Control (Step 4) ----
%% ---- Bidirectional Buck-Boost / Charge Control (Step 4 — VERIFIED WORKING) ----
bb_R2 = 0.1;              % ohm (same reasoning as boost_R1 — small parasitic value)
bb_L2 = 1e-3;              % H
bb_Cb = 1e-4;              % F, plain Capacitor block at battery-side node
bb_series_R = 0.01;        % ohm, small series resistor fixing the "voltage source parallel with capacitor" error

% Charge controller (PI on Vdc)
%% ---- Charge controller (RETUNED for full-system stability) ----
cc_Kp = 0.002;
cc_Ki = 0.02;
cc_max_duty_step = 0.005;  % NOTE: not yet consumed anywhere in the chart —
                            % there's no duty-rate-limiting logic in the
                            % Charge Controller script currently. Leaving
                            % this here as-is; flag if you want it added.

% Outer-loop (Vdc) trim authority. Previously hardcoded as a flat +/-2 A
% clamp regardless of how large the actual PV power swing was — likely
% too small to hold Vdc against multi-amp PV transients. Same value kept
% here for now so behavior doesn't change yet; this is the first knob to
% raise (try 8-12) if Vdc still drifts/oscillates after the sync fixes.
cc_Ib_trim_max = 0.5;        % A
cc_Iff_max = 1;           % A, feed-forward current bound (was hardcoded +/-10)

%% ---- PWM_DeadTime block (replaces PWM Generator + NOT + Switches) ----
pwm_dt_Fsw = 10000;
pwm_dt_Ts = 1e-6;
pwm_dt_deadtime_frac = 0.02;

%% ---- IGBT1/IGBT2 snubbers (BuckBoost_Battery) ----
bb_snubber_Rs = 500;
bb_snubber_Cs = 250e-9;          % must match MATLAB Function block's Sample time
cc_Vdc_ref = 150;      % V, target DC bus voltage
cc_Ts = 1e-3;          % s, charge controller sample time
%% ---- VSI + Grid Control (Step 5+) ----
% Grid_AC (Step 5a — PLACEHOLDER values, standalone topology test only.
%          Revisit once VSI output voltage is known in 5b/5c.)
grid_Vrms_test = 30.3;   % V, line-line RMS — round test number, not a spec
grid_freq = 60;         % Hz — pick 50 instead if that's your target grid; arbitrary otherwise
grid_Rs1 = 5;         % ohm — kept consistent with R1/R2 elsewhere in the model
grid_Ls1 = 0.05;        % H  — kept consistent with L1/L2 elsewhere in the model
xfmr_ratio_test = 1;     % unity turns ratio for both transformers, for now —
                          % just proving the topology passes power correctly;
                          % real ratio gets set once VSI's line-line output is known

% Transformer (Grid_AC, Step 5a — placeholder, 1:1 pass-through)
xfmr_Sn_test = 5000;   % VA, nominal power (test scale, not a spec)
xfmr_V_test  = grid_Vrms_test;  % V, Ph-Ph — same on both windings for 1:1
xfmr_R_pu    = 0.002;  % pu leakage resistance, typical placeholder
xfmr_L_pu    = 0.08;   % pu leakage reactance, typical placeholder


% vsi_Cdc = ...
% grid_Vm1 = ...
% grid_freq = ...
vsi_freq= 3000;

%% ---- Load (final stage) ----
% load_P01 = ...
% load_Q01 = ...
% load_RL1 = ...