###############################################################################
# dynamic2d_aux_multi_region_B/L.i
# 2D dynamic solid with two elastic regions: Base (B) and Lesion (L)
# Poisson = 0.49, rho = 1000 kg/m^3
# Base (B): mu_B = 25 kPa  -> E_B = 74_500 Pa, c_p,B ≈ 35.7071 m/s
# Lesion (L): mu_L =100 kPa -> E_L = 298_000 Pa, c_p,L ≈ 71.4143 m/s
# Dashpot K uses the slower wave speed (base): dashpot_K = rho * c_p,B ≈ 35707.14
###############################################################################

[GlobalParams]
  displacements = 'disp_x disp_y'
  # Material / pulse params
  nu = 0.49
  rho = 1000.0
  # Base (B)
  mu_B = 25000.0
  E_B = 74500.0
  # Lesion (L)
  mu_L = 100000.0
  E_L = 298000.0
  # impulse
  F0 = 1.0e7
  t_imp = 1.0e-4
  # Newmark
  newmark_beta = 0.25
  newmark_gamma = 0.5
  # Dashpot K (based on base compressional speed)
  dashpot_K = 35707.14
[]

[Mesh]
  file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Cubit/EllipInclu.e"
  # MOOSE will import Exodus element blocks, side sets, and node sets (you can use names or IDs).
[]

[Physics/TensorMechanics/Dynamic]
  [all]
    add_variables = true
    strain = SMALL
    time_integration = NEWMARK
    generate_output = 'stress_xx stress_yy stress_xy total_strain_xx total_strain_yy total_strain_xy'
  []
[]

[Variables]
  # only displacements are primary variables (created by action)
[]

[AuxVariables]
  [./vel_x]
    order = FIRST
    initial_condition = 0.0
  []
  [./vel_y]
    order = FIRST
    initial_condition = 0.0
  []
  [./accel_x]
    order = FIRST
    initial_condition = 0.0
  []
  [./accel_y]
    order = FIRST
    initial_condition = 0.0
  []
[]

[AuxKernels]
  [./accel_x]
    type = NewmarkAccelAux
    variable = accel_x
    displacement = disp_x
    beta = ${GlobalParams:newmark_beta}
    gamma = ${GlobalParams:newmark_gamma}
    execute_on = timestep_end
  []
  [./accel_y]
    type = NewmarkAccelAux
    variable = accel_y
    displacement = disp_y
    beta = ${GlobalParams:newmark_beta}
    gamma = ${GlobalParams:newmark_gamma}
    execute_on = timestep_end
  []
  [./vel_x]
    type = NewmarkVelAux
    variable = vel_x
    acceleration = accel_x
    gamma = ${GlobalParams:newmark_gamma}
    execute_on = timestep_end
  []
  [./vel_y]
    type = NewmarkVelAux
    variable = vel_y
    acceleration = accel_y
    gamma = ${GlobalParams:newmark_gamma}
    execute_on = timestep_end
  []
[]

[Materials]
  # Base region (block=1) - softer (mu_B = 25 kPa)
  [./elasticity_B]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${GlobalParams:E_B}
    poissons_ratio = ${GlobalParams:nu}
    block = 1
  []
  [./stress_B]
    type = ComputeLinearElasticStress
    block = 1
  []
  [./density_B]
    type = Density
    density = ${GlobalParams:rho}
    block = 1
  []

  # Lesion region (block=2) - stiffer (mu_L = 100 kPa)
  [./elasticity_L]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${GlobalParams:E_L}
    poissons_ratio = ${GlobalParams:nu}
    block = 2
  []
  [./stress_L]
    type = ComputeLinearElasticStress
    block = 2
  []
  [./density_L]
    type = Density
    density = ${GlobalParams:rho}
    block = 2
  []
[]

[Kernels]
  # TensorMechanics Dynamic action adds stress-divergence kernels automatically.
  # Inertial kernels that read accel auxvars:
  [./inertia_x]
    type = InertialForce
    variable = disp_x
    acceleration = accel_x
    gamma = ${GlobalParams:newmark_gamma}
    alpha = 0.0
    execute_on = timestep_end
  []
  [./inertia_y]
    type = InertialForce
    variable = disp_y
    acceleration = accel_y
    gamma = ${GlobalParams:newmark_gamma}
    alpha = 0.0
    execute_on = timestep_end
  []
[]

[Functions]
  [./half_sine_impulse]
    type = ParsedFunction
    value = 't <= t_imp ? F0 * sin(pi * t / t_imp) : 0.0'
    args = 't F0 t_imp'
  []
[]

[BCs]
  # Left boundary: time-dependent traction (Neumann) in x-direction
  [./left_impulse_x]
    type = NeumannBC
    boundary = 1      # <- REPLACE with left sideset ID or name from your Exodus file
    variable = disp_x
    value_function = half_sine_impulse
  []

  # Dashpot absorbing BCs on other boundaries (both components), using base-based K
  [./dashpot_top_x]
    type = DashpotBC
    boundary = 2      # <- REPLACE with top sideset ID
    variable = disp_x
    K = ${GlobalParams:dashpot_K}
  []
  [./dashpot_top_y]
    type = DashpotBC
    boundary = 2
    variable = disp_y
    K = ${GlobalParams:dashpot_K}
  []
  [./dashpot_right_x]
    type = DashpotBC
    boundary = 3      # <- REPLACE with right sideset ID
    variable = disp_x
    K = ${GlobalParams:dashpot_K}
  []
  [./dashpot_right_y]
    type = DashpotBC
    boundary = 3
    variable = disp_y
    K = ${GlobalParams:dashpot_K}
  []
  [./dashpot_bottom_x]
    type = DashpotBC
    boundary = 4      # <- REPLACE with bottom sideset ID
    variable = disp_x
    K = ${GlobalParams:dashpot_K}
  []
  [./dashpot_bottom_y]
    type = DashpotBC
    boundary = 4
    variable = disp_y
    K = ${GlobalParams:dashpot_K}
  []

  # Minimal Dirichlet constraints (small nodesets / points) to remove rigid bodies
  [./fix_corner_x]
    type = PresetDisplacement
    boundary = 5      # <- REPLACE with small corner nodeset/point ID
    variable = disp_x
    value = 0.0
  []
  [./fix_corner_y]
    type = PresetDisplacement
    boundary = 5
    variable = disp_y
    value = 0.0
  []
  [./fix_one_dof_y]
    type = PresetDisplacement
    boundary = 6      # <- REPLACE with another small nodeset to prevent rotation
    variable = disp_y
    value = 0.0
  []
[]

[Executioner]
  type = Transient
  start_time = 0.0
  end_time = 0.01
  dt = 1.0e-6
  solve_type = 'nonlinear'
[]

[Postprocessors]
  [./nodal_vel_x_node10]
    type = NodalVariableValue
    nodeid = 10
    variable = vel_x
  []
  [./nodal_accel_x_node10]
    type = NodalVariableValue
    nodeid = 10
    variable = accel_x
  []
[]

[Outputs]
  exodus = true
  console = true
[]
