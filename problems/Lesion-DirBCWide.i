###############################################################################
# Lesion2.i  -- MOOSE input with homogeneous Dirichlet BCs on all edges
# Based on Lesion.i but with fixed boundaries instead of dashpot absorbing BCs
###############################################################################

# -------------------------
# Top-level parameter definitions (evaluated before the rest of the file)
# -------------------------
# Basic material constants (human-friendly input)
nu = 0.49
rho = 1000.0  # kg/m^3

# Shear moduli (Pa) - values in SI units
mu_B = 4000.0   # Base (B)
mu_L = 25000.0  # Lesion (L)

# Compute Young's modulus E = 2 * mu * (1 + nu)
E_B = ${fparse 2.0 * mu_B * (1.0 + nu)}
E_L = ${fparse 2.0 * mu_L * (1.0 + nu)}

# Lame's first parameter: lambda = E*nu / ((1+nu)(1-2nu))
# lambda_B = ${fparse (E_B * nu) / ((1.0 + nu) * (1.0 - 2.0 * nu))}
# lambda_L = ${fparse (E_L * nu) / ((1.0 + nu) * (1.0 - 2.0 * nu))}

# Wave speeds: c_p = sqrt((lambda + 2*mu) / rho), c_s = sqrt(mu / rho)
# c_p_B = ${fparse sqrt( (lambda_B + 2.0 * mu_B) / rho )}
# c_s_B = ${fparse sqrt( mu_B / rho )}

# c_p_L = ${fparse sqrt( (lambda_L + 2.0 * mu_L) / rho )}
# c_s_L = ${fparse sqrt( mu_L / rho )}

# Time integration / Newmark defaults
newmark_beta = 0.25
newmark_gamma = 0.5

# Impulse definition (body force - units are N/m^3)
F0 = 400                          # peak body force magnitude (N/m^3) - line source impulse - Peak shear stress should be << μ for small strain
t_imp = 1.0e-3                      # impulse duration (1 ms) - short pulse for S-waves

# Body force region definition
epsilon_f = 0.0001                     # half-width of body force region (m)
x_center = 0                      # x-coordinate center of force region (m)
z_min = 0.02                          # minimum z-coordinate of force region (m)
z_max = 0.03                          # maximum z-coordinate of force region (m)

# -------------------------
# Mesh and physics
# -------------------------
[GlobalParams]
  displacements = 'disp_x disp_z'
[]

[Mesh]
  [file]
    type = FileMeshGenerator
    file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Cubit/EllipInclu-wide.e"
  []
  construct_side_list_from_node_list = true
[]

[Functions]
  [./body_masked_time]
    type = ParsedFunction
    # Body force applied in parametric region
    expression = 'if(t <= t_imp, if(x >= (x_center - epsilon_f), if(x <= (x_center + epsilon_f), if(z >= z_min, if(z <= z_max, F0 * sin(pi * t / t_imp), 0), 0), 0), 0), 0)'
    symbol_names = 't_imp F0 epsilon_f x_center z_min z_max'
    symbol_values = '${t_imp} ${F0} ${epsilon_f} ${x_center} ${z_min} ${z_max}'
  []
[]

[Physics/SolidMechanics/Dynamic]
  [all]
    add_variables = true
    strain = SMALL
    newmark_beta = ${newmark_beta}
    newmark_gamma = ${newmark_gamma}
    generate_output = 'stress_xx stress_zz stress_xz strain_xx strain_zz strain_xz'
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

[AuxVariables]
  [./vel_x]
    order = FIRST
    family = LAGRANGE
  []
  [./vel_z]
    order = FIRST
    family = LAGRANGE
  []
  [./accel_x]
    order = FIRST
    family = LAGRANGE
  []
  [./accel_z]
    order = FIRST
    family = LAGRANGE
  []
[]

[AuxKernels]
  [./vel_x]
    type = NewmarkVelAux
    variable = vel_x
    acceleration = accel_x
    gamma = ${newmark_gamma}
    execute_on = timestep_end
  []
  [./vel_z]
    type = NewmarkVelAux
    variable = vel_z
    acceleration = accel_z
    gamma = ${newmark_gamma}
    execute_on = timestep_end
  []
  [./accel_x]
    type = NewmarkAccelAux
    variable = accel_x
    displacement = disp_x
    velocity = vel_x
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
  [./accel_z]
    type = NewmarkAccelAux
    variable = accel_z
    displacement = disp_z
    velocity = vel_z
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
[]

[Kernels]
  [./body_force_z_masked]
    type = BodyForce
    variable = disp_z
    function = body_masked_time
  []
[]

[BCs]
  # Homogeneous Dirichlet BCs (fixed boundaries) on all edges
  
  # minz side (boundary 1) - fix both x and z displacements
  [./fix_minz_side_x]
    type = DirichletBC
    boundary = 1
    variable = disp_x
    value = 0.0
  []
  [./fix_minz_side_z]
    type = DirichletBC
    boundary = 1
    variable = disp_z
    value = 0.0
  []
  
  # maxx side (boundary 2) - fix both x and z displacements
  [./fix_maxx_side_x]
    type = DirichletBC
    boundary = 2
    variable = disp_x
    value = 0.0
  []
  [./fix_maxx_side_z]
    type = DirichletBC
    boundary = 2
    variable = disp_z
    value = 0.0
  []
  
  # maxz side (boundary 3) - fix both x and z displacements
  [./fix_maxz_side_x]
    type = DirichletBC
    boundary = 3
    variable = disp_x
    value = 0.0
  []
  [./fix_maxz_side_z]
    type = DirichletBC
    boundary = 3
    variable = disp_z
    value = 0.0
  []
  
  # minx side (boundary 4) - fix both x and z displacements
  [./fix_minx_side_x]
    type = DirichletBC
    boundary = 4
    variable = disp_x
    value = 0.0
  []
  [./fix_minx_side_z]
    type = DirichletBC
    boundary = 4
    variable = disp_z
    value = 0.0
  []
[]

[Executioner]
  type = Transient
  start_time = 0.0
  end_time = 15e-3                # 15e-3 ; time to reach edge of imaging region 
  dt = .25e-3                       # .25e-3 ; chosen so f_s = 4*f_max ; f_max=1000 Hz <- max frequency of interest
  solve_type = 'PJFNK'
[]


[Outputs]
  [./exodus]
    type = Exodus
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion/exodus/lesion2"
    show = 'disp_x disp_z vel_x vel_z accel_x accel_z stress_xx stress_zz stress_xz strain_xx strain_zz strain_xz'
    execute_on = 'timestep_end'
  []
  console = true
  append_date = true
  # AuxVariables explicitly included in output for ParaView visualization
[]