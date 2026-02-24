###############################################################################
# RectsLR.i -- Left/Right two-block rectangle with Dirichlet BCs on all edges
# Based on HomRect.i: same domain, body force, BCs, and time integration
# Split at x=0 into Left (mu=25kPa, block 1) and Right (mu=21kPa, block 2)
#
# Domain: x in [-0.04, 0.04], y in [0.0, 0.05]  (0.08 x 0.05 m)
# Uses x-y plane (dim=2).
#
# Overridable from command line:
#   nx, ny   - mesh resolution (integers; compute as 0.08/h and 0.05/h)
#   my_dt    - timestep (s)
#   end_time - simulation end time (s)
#   filename - output file base name (include h in name for tracking)
###############################################################################

# -------------------------
# Mesh resolution (override from command line)
# -------------------------
nx = 32                               # elements in x direction (default: h = 2.5 mm)
ny = 20                               # elements in y direction

# Time stepping
my_dt = 0.25e-3                       # timestep (s), default 0.25 ms

# Simulation end time
end_time = 6e-3                       # 6 ms

# Output filename (include h in name; override from CLI)
filename = 'RectsLR_h2.50mm'

# -------------------------
# Material constants
# -------------------------
nu = 0.49
rho = 1000.0                          # kg/m^3

# Shear moduli (Pa)
mu_L = 25000.0                        # Left block - 25 kPa
mu_R = 21000.0                        # Right block - 21 kPa

# Compute Young's modulus E = 2 * mu * (1 + nu)
E_L = ${fparse 2.0 * mu_L * (1.0 + nu)}
E_R = ${fparse 2.0 * mu_R * (1.0 + nu)}

# Newmark time integration
newmark_beta = 0.25
newmark_gamma = 0.5

# -------------------------
# Impulse definition (body force, N/m^3)
# -------------------------
F0 = 400                              # peak body force magnitude
t_imp = 1.0e-3                        # impulse duration (1 ms)

# Body force spatial profile: Gaussian in x, boxcar in y
sigma_f = 0.003                       # Gaussian std dev in x (m)
x_center = -0.01                      # x-coordinate center of force region (m)
y_min_f = 0.015                       # minimum y-coordinate of force region (m)
y_max_f = 0.035                       # maximum y-coordinate of force region (m)

# Domain dimensions
x_min = -0.04
x_max = 0.04
y_min = 0.0
y_max = 0.05

# -------------------------
# Mesh: GeneratedMesh split into Left (block 1) and Right (block 2) at x=0
# -------------------------
[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${nx}
    ny = ${ny}
    xmin = ${x_min}
    xmax = ${x_max}
    ymin = ${y_min}
    ymax = ${y_max}
  []
  [block_left]
    type = SubdomainBoundingBoxGenerator
    input = gen
    bottom_left = '${x_min} ${y_min} 0'
    top_right = '0.0 ${y_max} 0'
    block_id = 1
    block_name = 'left'
  []
  [block_right]
    type = SubdomainBoundingBoxGenerator
    input = block_left
    bottom_left = '0.0 ${y_min} 0'
    top_right = '${x_max} ${y_max} 0'
    block_id = 2
    block_name = 'right'
  []
[]

[Functions]
  [./body_masked_time]
    type = ParsedFunction
    # Gaussian in x, boxcar in y, half-sine in t
    expression = 'if(t <= t_imp, exp(-((x - x_center)^2) / (2 * sigma_f^2)) * if(y >= y_min_f, if(y <= y_max_f, F0 * sin(pi * t / t_imp), 0), 0), 0)'
    symbol_names = 't_imp F0 sigma_f x_center y_min_f y_max_f'
    symbol_values = '${t_imp} ${F0} ${sigma_f} ${x_center} ${y_min_f} ${y_max_f}'
  []
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
  # Left block (block 1) — mu = 25 kPa
  [./elasticity_L]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_L}
    poissons_ratio = ${nu}
    block = 1
  []
  [./stress_L]
    type = ComputeLinearElasticStress
    block = 1
  []
  [./density_L]
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
    block = 1
  []

  # Right block (block 2) — mu = 21 kPa
  [./elasticity_R]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_R}
    poissons_ratio = ${nu}
    block = 2
  []
  [./stress_R]
    type = ComputeLinearElasticStress
    block = 2
  []
  [./density_R]
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
    block = 2
  []

  # Strain energy density material for both blocks
  [./strain_energy_density]
    type = StrainEnergyDensity
    incremental = false
    outputs = exodus
  []
[]

[AuxVariables]
  [./vel_x]
    order = FIRST
    family = LAGRANGE
  []
  [./vel_y]
    order = FIRST
    family = LAGRANGE
  []
  [./accel_x]
    order = FIRST
    family = LAGRANGE
  []
  [./accel_y]
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
  [./vel_y]
    type = NewmarkVelAux
    variable = vel_y
    acceleration = accel_y
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
  [./accel_y]
    type = NewmarkAccelAux
    variable = accel_y
    displacement = disp_y
    velocity = vel_y
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
[]

[Kernels]
  [./body_force_y_masked]
    type = BodyForce
    variable = disp_y
    function = body_masked_time
  []
[]

[BCs]
  # Homogeneous Dirichlet BCs on all edges
  # GeneratedMeshGenerator dim=2 boundaries: bottom, right, top, left

  # bottom (y = y_min)
  [./fix_bottom_x]
    type = DirichletBC
    boundary = bottom
    variable = disp_x
    value = 0.0
  []
  [./fix_bottom_y]
    type = DirichletBC
    boundary = bottom
    variable = disp_y
    value = 0.0
  []

  # right (x = x_max)
  [./fix_right_x]
    type = DirichletBC
    boundary = right
    variable = disp_x
    value = 0.0
  []
  [./fix_right_y]
    type = DirichletBC
    boundary = right
    variable = disp_y
    value = 0.0
  []

  # top (y = y_max)
  [./fix_top_x]
    type = DirichletBC
    boundary = top
    variable = disp_x
    value = 0.0
  []
  [./fix_top_y]
    type = DirichletBC
    boundary = top
    variable = disp_y
    value = 0.0
  []

  # left (x = x_min)
  [./fix_left_x]
    type = DirichletBC
    boundary = left
    variable = disp_x
    value = 0.0
  []
  [./fix_left_y]
    type = DirichletBC
    boundary = left
    variable = disp_y
    value = 0.0
  []
[]

[Executioner]
  type = Transient
  start_time = 0.0
  end_time = ${end_time}
  dt = ${my_dt}
  solve_type = 'PJFNK'
[]

[Postprocessors]
  [strain_energy]
    type = ElementIntegralMaterialProperty
    mat_prop = strain_energy_density
  []

  # Sample disp_y at 4 points evenly spaced in the domain (quarter-points)
  [disp_y_pt1]
    type = PointValue
    variable = disp_y
    point = '-0.02 0.0125 0'
  []
  [disp_y_pt2]
    type = PointValue
    variable = disp_y
    point = '0.02 0.0125 0'
  []
  [disp_y_pt3]
    type = PointValue
    variable = disp_y
    point = '-0.02 0.0375 0'
  []
  [disp_y_pt4]
    type = PointValue
    variable = disp_y
    point = '0.02 0.0375 0'
  []

  # Average of the 4 sampled displacements
  [avg_disp_y]
    type = LinearCombinationPostprocessor
    pp_names = 'disp_y_pt1 disp_y_pt2 disp_y_pt3 disp_y_pt4'
    pp_coefs = '0.25 0.25 0.25 0.25'
  []
[]

[Outputs]
  [./exodus]
    type = Exodus
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/RectsLR/exodus/${filename}"
  []
  [./csv]
    type = CSV
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/RectsLR/exodus/${filename}"
  []
  console = true
[]
