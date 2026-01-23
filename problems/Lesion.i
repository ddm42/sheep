###############################################################################
# dynamic2d_B_L_params.i  -- MOOSE input patched to use top-level params, units,
#                         and computed quantities (E, lambda, c_p, dashpot K).
# - Replace mesh.exo, block and boundary IDs to match your Exodus file (or upload it).
# - This file uses: ${units ...} and ${fparse ...} so keep these assignments at top.
###############################################################################

# -------------------------
# Top-level parameter definitions (evaluated before the rest of the file)
# -------------------------
# Basic material constants (human-friendly input)
nu = 0.49
rho = 1000.0  # kg/m^3

# Shear moduli (convert from kPa to Pa)
mu_B = 25000.0   # Base (B): 25 kPa = 25000 Pa
mu_L = 100000.0  # Lesion (L): 100 kPa = 100000 Pa

# Compute Young's modulus E = 2 * mu * (1 + nu)
E_B = ${fparse 2.0 * mu_B * (1.0 + nu)}
E_L = ${fparse 2.0 * mu_L * (1.0 + nu)}

# Lame's first parameter: lambda = E*nu / ((1+nu)(1-2nu))
lambda_B = ${fparse (E_B * nu) / ((1.0 + nu) * (1.0 - 2.0 * nu))}
lambda_L = ${fparse (E_L * nu) / ((1.0 + nu) * (1.0 - 2.0 * nu))}

# Wave speeds: c_p = sqrt((lambda + 2*mu) / rho), c_s = sqrt(mu / rho)
c_p_B = ${fparse sqrt( (lambda_B + 2.0 * mu_B) / rho )}
c_s_B = ${fparse sqrt( mu_B / rho )}

c_p_L = ${fparse sqrt( (lambda_L + 2.0 * mu_L) / rho )}
c_s_L = ${fparse sqrt( mu_L / rho )}

# Dashpot K: use base/slower c_p_B as you requested
dashpot_K = ${fparse rho * c_p_B}

# Time integration / Newmark defaults
newmark_beta = 0.25
newmark_gamma = 0.5

# Impulse definition (human-friendly units)
F0 = ${units 1e7 N/m^2 -> Pa}       # peak traction magnitude (ex: 1e7 Pa)
t_imp = ${units 1e-4 s -> s}        # impulse duration

# -------------------------
# Mesh and physics
# -------------------------
[Mesh]
  file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Cubit/EllipInclu.e"
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
  # Primary displacement variables are created automatically by add_variables=true
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
    velocity = vel_x
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
  [./accel_y]
    type = NewmarkAccelAux
    variable = accel_y
    displacement = disp_y
    velocity = vel_y
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
  [./vel_x]
    type = NewmarkVelAux
    variable = vel_x
    acceleration = accel_x
    gamma = ${newmark_gamma}
    execute_on = timestep_end
  []
  [./vel_y]
    type = NewmarkVelAux
    variable = vel_y
    acceleration = accel_y
    gamma = ${newmark_gamma}
    execute_on = timestep_end
  []
[]

[Materials]
  # Base (B) - assign to block=1 (placeholder)
  [./elasticity_B]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_B}
    poissons_ratio = ${nu}
    block = 1
  []
  [./stress_B]
    type = ComputeLinearElasticStress
    block = 1
  []
  [./density_B]
    type = Density
    density = ${rho}
    block = 1
  []

  # Lesion (L) - assign to block=2 (placeholder)
  [./elasticity_L]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_L}
    poissons_ratio = ${nu}
    block = 2
  []
  [./stress_L]
    type = ComputeLinearElasticStress
    block = 2
  []
  [./density_L]
    type = Density
    density = ${rho}
    block = 2
  []
[]

[Kernels]
  # Inertial kernels read accel auxvariables (one per component)
  [./inertia_x]
    type = InertialForce
    variable = disp_x
    acceleration = accel_x
    gamma = ${newmark_gamma}
    alpha = 0.0
    execute_on = timestep_end
  []
  [./inertia_y]
    type = InertialForce
    variable = disp_y
    acceleration = accel_y
    gamma = ${newmark_gamma}
    alpha = 0.0
    execute_on = timestep_end
  []
  # Stress divergence kernels are created automatically by the TensorMechanics action.
[]

[Functions]
  [./half_sine_impulse]
    type = ParsedFunction
    value = 't <= ${t_imp} ? ${F0} * sin(pi * t / ${t_imp}) : 0.0'
    args = 't F0 t_imp'
  []
[]

[BCs]
  # Left boundary: time-dependent Neumann traction (x-component)
  [./left_impulse_x]
    type = NeumannBC
    boundary = 1       # <- REPLACE with your left sideset ID or name
    variable = disp_x
    value_function = half_sine_impulse
  []

  # Dashpot absorbing BCs on other boundaries using base K (both components)
  [./dashpot_top_x]
    type = DashpotBC
    boundary = 2       # <- REPLACE with top sideset ID
    variable = disp_x
    K = ${dashpot_K}
  []
  [./dashpot_top_y]
    type = DashpotBC
    boundary = 2
    variable = disp_y
    K = ${dashpot_K}
  []
  [./dashpot_right_x]
    type = DashpotBC
    boundary = 3       # <- REPLACE with right sideset ID
    variable = disp_x
    K = ${dashpot_K}
  []
  [./dashpot_right_y]
    type = DashpotBC
    boundary = 3
    variable = disp_y
    K = ${dashpot_K}
  []
  [./dashpot_bottom_x]
    type = DashpotBC
    boundary = 4       # <- REPLACE with bottom sideset ID
    variable = disp_x
    K = ${dashpot_K}
  []
  [./dashpot_bottom_y]
    type = DashpotBC
    boundary = 4
    variable = disp_y
    K = ${dashpot_K}
  []

  # Minimal Dirichlet constraints (small nodesets / points) to remove rigid bodies
  [./fix_corner_x]
    type = PresetDisplacement
    boundary = 5       # <- small corner nodeset/point ID
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
    boundary = 6       # <- another small nodeset to prevent rotation
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
  # if you want AuxVariables output explicitly, MOOSE outputs system will include
  # nodal/elemental auxfields as configured. See Outputs docs.
[]
