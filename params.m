%% PV_Grid_System_Parameters.m
% System parameters for 100kW PV grid-tied system with NPC inverter
% All units in SI (V, A, W, H, F, Hz)

clear; clc; close all;

%% ============ PV ARRAY PARAMETERS ============
% Solar cell parameters (typical 250W polycrystalline module)
PV.Voc = 37.5;          % Open circuit voltage per module (V)
PV.Isc = 8.8;           % Short circuit current per module (A)
PV.Vmp = 30.5;          % Voltage at max power point (V)
PV.Imp = 8.2;           % Current at max power point (A)
PV.Pmp = PV.Vmp * PV.Imp; % 250W per module

% Array configuration
PV.Ns = 16;             % Modules in series (produces ~488V)
PV.Np = 26;             % Parallel strings (produces ~213A total, ~100kW)
PV.Ns_total = PV.Ns * PV.Np;
PV.P_total = PV.Pmp * PV.Ns * PV.Np / 1000; % kW

% Environmental conditions
PV.irradiance = 1000;   % W/m² (standard test condition)
PV.temperature = 25;    % °C

fprintf('PV Array Total Power: %.2f kW\n', PV.P_total);

%% ============ BOOST CONVERTER PARAMETERS ============
% Input voltage from PV at MPP: ~Vmp * Ns = 30.5*16 = 488V
% Output voltage to DC bus: 700V (selected for 400V AC grid)

Boost.Vin_nominal = PV.Vmp * PV.Ns;  % ~488V
Boost.Vout_desired = 700;            % DC bus voltage (V)
Boost.D_nominal = 1 - (Boost.Vin_nominal / Boost.Vout_desired); % ~0.303

% Calculate inductor for CCM (Continuous Conduction Mode)
% CCM condition: L > (Vin*D)/(2*fs*Iout)
Boost.fsw = 20000;      % Switching frequency (20 kHz)
Boost.Tsw = 1/Boost.fsw;
Boost.P_out_per_converter = PV.P_total / 4;  % 4 converters
Boost.Iout = Boost.P_out_per_converter / Boost.Vout_desired;
Boost.L_min = (Boost.Vin_nominal * Boost.D_nominal) / ...
              (2 * Boost.fsw * Boost.Iout);

% Use 20% margin on inductance
Boost.L = Boost.L_min * 1.2;        % Inductance (H)
Boost.Cin = 1000e-6;                % Input capacitance (F)
Boost.Cout = 470e-6;                % Output capacitance (F)

fprintf('Boost L_min: %.2f mH, Using: %.2f mH\n', ...
        Boost.L_min*1000, Boost.L*1000);

%% ============ DC LINK PARAMETERS ============
DC.Vdc_ref = 700;       % Desired DC bus voltage (V)
DC.Cdc = 2200e-6;       % DC link capacitance (F)
DC.Rdc = 1000;          % DC link discharge resistor (ohms)

% Split capacitors for NPC (2 capacitors in series)
DC.Cdc1 = DC.Cdc * 2;   % Each cap twice total to maintain capacitance
DC.Cdc2 = DC.Cdc * 2;   
DC.Vdc_half = DC.Vdc_ref / 2;

fprintf('DC Link Vdc: %.1f V, Cdc: %.1f µF\n', ...
        DC.Vdc_ref, DC.Cdc*1e6);

%% ============ NPC INVERTER PARAMETERS ============
Inverter.fsw = 2000;     % Switching frequency (Hz) for IGBTs
Inverter.Tsw = 1/Inverter.fsw;
Inverter.Vdc = DC.Vdc_ref;

% Grid parameters (400V LL, 50Hz)
Grid.Vrms_LL = 400;     % RMS line-to-line voltage (V)
Grid.Vpeak_LL = Grid.Vrms_LL * sqrt(2);  % Peak LL
Grid.Vphase_peak = Grid.Vpeak_LL / sqrt(3);  % Peak phase voltage
Grid.f = 50;            % Frequency (Hz)
Grid.w = 2*pi*Grid.f;   % Angular frequency (rad/s)

%% ============ OUTPUT FILTER PARAMETERS ============
% LC filter for grid connection (common values)
Filter.L = 2e-3;        % Filter inductance (mH)
Filter.C = 10e-6;       % Filter capacitance (µF)
Filter.Rdamp = 2;       % Damping resistor for LCL filter (if used)

% Calculate cutoff frequency (should be 10x grid freq, 1/10th switching)
Filter.fc = 1 / (2*pi*sqrt(Filter.L*Filter.C));
fprintf('Filter Cutoff Frequency: %.1f Hz\n', Filter.fc);

%% ============ CONTROL SYSTEM GAINS ============
% DC Voltage Controller (Outer loop)
Ctrl.Kp_vdc = 0.5;      % Proportional gain
Ctrl.Ki_vdc = 20;       % Integral gain
Ctrl.Vdc_max_limit = 750;
Ctrl.Vdc_min_limit = 650;

% Current Controllers (Inner loop - d and q axis)
Ctrl.Kp_id = 5;         % d-axis current PI gain
Ctrl.Ki_id = 50;        
Ctrl.Kp_iq = 5;         % q-axis current PI gain  
Ctrl.Ki_iq = 50;

% Current limits
Ctrl.Id_max = 150;      % Max d-axis current (A)
Ctrl.Iq_max = 150;      % Max q-axis current (A)

%% ============ MPPT PARAMETERS ============
MPPT.step_size = 0.002;  % Duty cycle perturbation step
MPPT.D_min = 0.1;
MPPT.D_max = 0.9;
MPPT.sampling_time = 0.01;  % MPPT update rate (10ms)

%% ============ SIMULATION PARAMETERS ============
Sim.Ts = 1e-6;          % Simulation time step (1 µs)
Sim.Tstop = 0.5;        % Simulation stop time (seconds) - start small
Sim.solver = 'ode23t';  % Use for stiff systems

%% ============ DISPLAY SUMMARY ============
fprintf('\n========== SYSTEM SUMMARY ==========\n');
fprintf('PV Array Power: %.2f kW\n', PV.P_total);
fprintf('PV Voltage (MPP): %.1f V\n', Boost.Vin_nominal);
fprintf('DC Bus Voltage: %.1f V\n', DC.Vdc_ref);
fprintf('Boost Duty Cycle: %.3f\n', Boost.D_nominal);
fprintf('Grid Voltage: %.1f V (LL-rms)\n', Grid.Vrms_LL);
fprintf('Switching Frequencies: Boost=%.1f kHz, Inverter=%.1f kHz\n', ...
        Boost.fsw/1000, Inverter.fsw/1000);
fprintf('====================================\n');