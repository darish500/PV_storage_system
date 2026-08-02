# PV Storage System

A Simulink/Simscape model of a 100 kW photovoltaic (PV) array coupled with battery storage and a three-level NPC (Neutral Point Clamped) inverter. The repository contains Simulink model files, parameter scripts and calibration data used to simulate PV + battery + power-electronic converters connected to a medium-voltage grid through a transformer.

## Stack
- Language(s): MATLAB (scripts) and Simulink/Simscape models (.slx/.slxc)
- Framework / runtime: MATLAB & Simulink (tested with R2026a project cache present)
- Notable libraries: Simscape, Simscape Electrical / Support Package for Power Systems (SimPowerSystems), Simulink

## Contents
Top-level files and notable entries:

```
PV_Boost_Stage_test.slx           # Simulink model for boost stage testing
PV_Boost_Stage_test.slx.original  # Original/autosave artifacts
PV_Grid_NPC_system.slx            # Alternate model combining PV and NPC inverter
PV_Grid_NPC_system_simscape.slx   # Simscape variant
PV_Params_Stage1.mat              # MATLAB .mat parameters for stage 1
boost_validation_test.slx         # Validation model for boost converter
params.m                          # Main parameter script (MPP, boost, inverter, filters)
pv_storafe_system.slx             # (typo?) older model file
pv_storage_params.asv             # Simulink autosave / variant data
pv_storage_params.m               # Central parameter file for PV + Battery + VSI + Grid
pv_storage_system.slx             # Primary system-level Simulink model
pv_storage_system.slx.autosave    # Autosave file
pv_storage_system.slx.original    # Original autosave artifact
pv_storage_system.slxc             # Compressed representation / xml of the model
```

## How it's organized
- Simulink models (.slx, .slxc) are the runtime artifacts describing the electrical system topology and component instances.
- Parameter scripts (`params.m`, `pv_storage_params.m`) set system parameters (PV array, boost converters, DC link, NPC inverter, battery model and converters, control gains, and simulation settings).
- .mat/.asv files store saved parameter sets or Simulink autosave state.

How it fits together: Load the parameter script to populate the MATLAB base workspace with named parameter variables (Vdc_ref, Batt_AhRated, L1_boost, etc.), then open the primary Simulink model (pv_storage_system.slx) which references those workspace variables and Simscape components (battery, IGBTs, inductors, sensors). The model can be simulated directly from the MATLAB command line or using the Simulink UI.

## Requirements
- MATLAB with Simulink
- Simscape and Simscape Electrical (Support Package for Power Systems / SimPowerSystems)
- Optional: Simulink Coder or other toolboxes if you plan to generate code or run accelerated simulations

Note: The repository contains model cache data referencing R2026a — models may require that or a later MATLAB release for full compatibility.

## Quick start — run the main model
1. Clone the repository and start MATLAB.
2. In the MATLAB Command Window:

```matlab
cd 'path/to/PV_storage_system'
% Load parameters (choose the file you want to use)
run('pv_storage_params.m');    % central parameter set
% or
run('params.m');

% Open and simulate the model
open_system('pv_storage_system.slx');
% Simulate for the default Tsim defined in the parameter file
simOut = sim('pv_storage_system','StopTime',num2str(Tsim));

% Example: run for 2 seconds explicitly
simOut = sim('pv_storage_system','StopTime','2');
```

Troubleshooting tips:
- If a referenced variable is undefined, ensure you've run the correct `.m` parameter script that defines it.
- If Simulink reports missing library blocks (e.g., `ee_lib_for_power_systems`), install or enable the Simscape Electrical / Support Package for Power Systems.

## What you can do with these models
- Run time-domain simulations of PV + battery + NPC inverter interacting with a grid
- Validate boost converter design and MPPT schemes (see PV_Boost_Stage_test.slx, boost_validation_test.slx)
- Study battery charge/discharge behavior and battery-side bidirectional converter
- Tune control gains (files expose Ctrl.* and MPPT.* parameters in `params.m`)

## Licensing
No explicit license file is included. If you plan to reuse or redistribute this work, please add a LICENSE file or contact the repository owner for terms.

## Try asking
- How do I change the PV array size (Ns, Np) and update the model to reflect it?
- Which Simulink blocks require the Support Package for Power Systems, and how can I replace them with basic Simscape equivalents?
- Where are the MPPT implementation details located in the model (which subsystem or script controls the duty update)?
