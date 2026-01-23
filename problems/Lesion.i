###############################################################################
# 2D dynamic solid mechanics with a left-boundary impulse and dashpot absorbing BCs
#
# Replace:
#   - mesh.exo -> your uploaded Exodus file name
#   - boundary IDs (1,2,3,4) -> use the sideset IDs from your mesh
#   - impulse_region (spatial function) if you want the load only on a sub-range
#   - material properties (E, nu, density)
#   - dashpot_coefficient K (suggested formula below)
###############################################################################

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = mesh.exo
  # If your mesh uses named sidesets you can use names instead of integer IDs.
[]

[Physics/TensorMechanics/Master]
  [all]
    add_variables = true
    strain = SMALL            # or FINITE for large deformation
    generate_output = 'stress_xx stress_yy stress_xy total_strain_xx total_strain_yy total_strain_xy'
  []
[]

[Variables]
  # displacement variables created automatically; declare aux variables for Newmark time integrator
  [./vel_x]
    initial_condition = 0.0
  []
  [./vel_y]
    initial_condition = 0.0
  []
  [./accel_x]
    initial_condition = 0.0
  []
  [./accel_y]
    initial_condition = 0.0
  []
[]

[AuxVariables]
  [./vel_x]
    order = FIRST
  []
  [./vel_y]
    order = FIRST
  []
  [./accel_x]
    order = FIRST
  []
  [./accel_y]
    order = FIRST
  []
[]

[AuxKernels]
  # Newmark auxiliary update kernels (implicit Newmark)
  [./accel_x]
    type = NewmarkAccelAux
    variable = accel_x
    displacement = disp_x
    beta = 0.25
    gamma = 0.5
    execute_on = timestep_end
  []
  [./vel_x]
    type = NewmarkVelAux
    variable = vel_x
    acceleration = accel_x
    gamma = 0.5
    execute_on = timestep_end
  []
  [./accel_y]
    type = NewmarkAccelAux
    variable = accel_y
    displacement = disp_y
    beta = 0.25
    gamma = 0.5
    execute_on = timestep_end
  []
  [./vel_y]
    type = NewmarkVelAux
    variable = vel_y
    acceleration = accel_y
    gamma = 0.5
    execute_on = timestep_end
  []
[]

[Materials]
  [./elasticity]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 2.1e11     # example (Pa) — change to your material
    poissons_ratio = 0.3
  []
  [./stress]
    type = ComputeLinearElasticStress
  []
  [./density]
    type = Density
    density = 7850.0            # kg/m^3 (example) — change as needed
  []
  # Optional: regional damping material for PML-like absorbing layer (if you add a thin layer region)
  # You can add Rayleigh damping / viscoelastic material if desired.
[]

[Kernels]
  # Inertial kernels (make inertia explicit)
  [./inertia_x]
    type = InertialForce
    variable = disp_x
    acceleration = accel_x
    gamma = 0.5
    alpha = 0.0
    execute_on = timestep_end
  []
  [./inertia_y]
    type = InertialForce
    variable = disp_y
    acceleration = accel_y
    gamma = 0.5
    alpha = 0.0
    execute_on = timestep_end
  []

  # Note: TensorMechanics master action adds the stress divergence kernels automatically
[]

[Functions]
  # Time history of the impulse applied on left boundary.
  # Example: half-sine pulse from t=0 to t=t_imp with amplitude F0 (traction magnitude)
  [./half_sine_impulse]
    type = ParsedFunction
    value = 't <= t_imp ? F0 * sin(pi * t / t_imp) : 0.0'
    args = 't F0 t_imp'
    # We'll pass parameters via GlobalParams (see below)
  []
  # If you prefer a Gaussian pulse:
  # [./gauss_impulse]
  #   type = ParsedFunction
  #   value = 'F0 * exp(-((t-t0)*(t-t0))/(2*sigma*sigma))'
  #   args = 't F0 t0 sigma'
  # []
[]

[BCs]
  # 1) Left boundary: time-dependent traction (Neumann)
  #    - boundary=1 is a placeholder for the left boundary sideset ID
  #    - direction = 'normal' means traction applied in normal direction; you can specify vector components too
  [./left_impulse]
    type = NeumannBC
    boundary = 1                       # <- REPLACE with actual left sideset ID or name
    variable = disp_x                  # apply in x-direction if your traction is horizontal
    value_function = half_sine_impulse
    # You can also use Vector Neumann forms to apply both components
  []

  # 2) Dashpot absorbing BCs on remaining external boundaries
  #    A DashpotBC applies traction proportional to normal velocity: t = K * (n . v)
  #    Suggested K ~ rho * c, where c is wave speed (use c_p or appropriate wave speed).
  [./dashpot_top]
    type = DashpotBC
    boundary = 2                       # <- REPLACE (top)
    variable = disp_x
    K = 1.0e6                          # <- TUNE: placeholder; suggested compute below
  []
  [./dashpot_top_y]
    type = DashpotBC
    boundary = 2
    variable = disp_y
    K = 1.0e6
  []
  [./dashpot_right]
    type = DashpotBC
    boundary = 3                       # <- REPLACE (right)
    variable = disp_x
    K = 1.0e6
  []
  [./dashpot_right_y]
    type = DashpotBC
    boundary = 3
    variable = disp_y
    K = 1.0e6
  []
  [./dashpot_bottom]
    type = DashpotBC
    boundary = 4                       # <- REPLACE (bottom)
    variable = disp_x
    K = 1.0e6
  []
  [./dashpot_bottom_y]
    type = DashpotBC
    boundary = 4
    variable = disp_y
    K = 1.0e6
  []

  # 3) Minimal Dirichlet constraints to eliminate rigid body motion:
  #    Fix one corner (both x & y) and one additional DOF to avoid rotation.
  #    Replace the boundary or node IDs below to match small sets in your mesh.
  [./fix_corner]
    type = PresetDisplacement
    boundary = 5                       # <- REPLACE with corner node/point sideset id or small nodeset
    variable = disp_x
    value = 0.0
  []
  [./fix_corner_y]
    type = PresetDisplacement
    boundary = 5
    variable = disp_y
    value = 0.0
  []
  # If needed, fix one DOF at another small boundary to remove rigid rotation:
  [./fix_one_dof]
    type = PresetDisplacement
    boundary = 6                       # <- REPLACE
    variable = disp_y
    value = 0.0
  []
[]

[GlobalParams]
  # parameters for the impulse function
  F0 = 1.0e7        # peak traction magnitude (N/m^2) — tune to your case
  t_imp = 1e-4      # impulse duration in seconds (short)
  # wave speed & dashpot suggestions (for reference; not automatically used by BCs)
  E = 2.1e11
  nu = 0.3
  rho = 7850.0
[]

[Executioner]
  type = Transient
  start_time = 0.0
  end_time = 0.01
  dt = 1.0e-6        # time step — choose based on stability and resolution (CFL)
  solve_type = 'nonlinear'   # dynamic problems often need nonlinear solver settings; try 'linear' if small-strain linear
[]

[Postprocessors]
  [./node_disp_sample]
    type = NodalVariableValue
    nodeid = 10                  # example node number to sample; change to a node in your mesh
    variable = disp_x
  []
[]

[Outputs]
  exodus = true
  console = true
  # optionally write CSV/time-series etc.
[]
