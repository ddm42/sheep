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
# lambda_L = ${fparse (E_L * nu) / ((1.0 + nu) * (1.0 - 2.0 * nu))}

# Wave speeds: c_p = sqrt((lambda + 2*mu) / rho), c_s = sqrt(mu / rho)
c_p_B = ${fparse sqrt( (lambda_B + 2.0 * mu_B) / rho )}
# c_s_B = ${fparse sqrt( mu_B / rho )}

# c_p_L = ${fparse sqrt( (lambda_L + 2.0 * mu_L) / rho )}
# c_s_L = ${fparse sqrt( mu_L / rho )}

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
[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [file]
    type = FileMeshGenerator
    file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Cubit/EllipInclu.e"
  []
  [bottom_left_nodeset]
    type = BoundingBoxNodeSetGenerator
    input = file
    new_boundary = 'bottom_left_corner'
    bottom_left = '-0.001 -0.001 0'     # Small box around bottom-left
    top_right = '0.001 0.001 0'         # Adjust coordinates as needed
  []
  [bottom_right_nodeset]
    type = BoundingBoxNodeSetGenerator
    input = bottom_left_nodeset
    new_boundary = 'bottom_right_corner'
    bottom_left = '0.999 -0.001 0'      # Small box around bottom-right
    top_right = '1.001 0.001 0'         # Adjust coordinates as needed  
  []
  construct_side_list_from_node_list = true
[]

[Physics/SolidMechanics/Dynamic]
  [all]
    add_variables = true
    strain = SMALL
    newmark_beta = ${newmark_beta}
    newmark_gamma = ${newmark_gamma}
    generate_output = 'stress_xx stress_yy stress_xy strain_xx strain_yy strain_xy'
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
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
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
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
    block = 2
  []
[]


[Functions]
  [./half_sine_impulse]
    type = ParsedFunction
    expression = 'if(t <= ${t_imp}, ${F0} * sin(pi * t / ${t_imp}), 0.0)'
  []
[]

[BCs]
  # Aperture boundary: time-dependent Neumann traction (x-component)
  [./left_impulse_x]
    type = FunctionNeumannBC
    boundary = 10      # sideset 10 (aperture)
    variable = disp_x
    function = half_sine_impulse
  []

  # Dashpot absorbing BCs on other boundaries using base K (both components)
  [./dashpot_top_x]
    type = DashpotBC
    boundary = 1       # sideset 1 (top)
    variable = disp_x
    component = 0      # x-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_top_y]
    type = DashpotBC
    boundary = 1       # sideset 1 (top)
    variable = disp_y
    component = 1      # y-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_right_x]
    type = DashpotBC
    boundary = 2       # sideset 2 (right)
    variable = disp_x
    component = 0      # x-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_right_y]
    type = DashpotBC
    boundary = 2       # sideset 2 (right)
    variable = disp_y
    component = 1      # y-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_bottom_x]
    type = DashpotBC
    boundary = 3       # sideset 3 (bottom)
    variable = disp_x
    component = 0      # x-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_bottom_y]
    type = DashpotBC
    boundary = 3       # sideset 3 (bottom)
    variable = disp_y
    component = 1      # y-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_left_x]
    type = DashpotBC
    boundary = 4       # sideset 4 (leftnotaperture)
    variable = disp_x
    component = 0      # x-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []
  [./dashpot_left_y]
    type = DashpotBC
    boundary = 4       # sideset 4 (leftnotaperture)
    variable = disp_y
    component = 1      # y-component
    disp_x = disp_x
    disp_y = disp_y
    coefficient = ${dashpot_K}
  []

  # Prevent rigid body motion: fix one point completely, constrain second point in one direction
  # Fix bottom-left corner completely (prevents translation)
  [./fix_corner_x]
    type = DirichletBC
    boundary = 'bottom_left_corner'
    variable = disp_x
    value = 0.0
  []
  [./fix_corner_y]
    type = DirichletBC
    boundary = 'bottom_left_corner' 
    variable = disp_y
    value = 0.0
  []
  # Fix bottom-right corner in x-direction only (prevents rotation)
  [./fix_rotation_x]
    type = DirichletBC
    boundary = 'bottom_right_corner'
    variable = disp_x
    value = 0.0
  []
[]

[Executioner]
  type = Transient
  start_time = 0.0
  end_time = 3.0e-6  # .01
  dt = 1.0e-6
  solve_type = 'PJFNK'
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
  # AuxVariables (vel_x, vel_y, accel_x, accel_y, stress/strain fields) are output by default
[]
