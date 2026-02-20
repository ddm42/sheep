###############################################################################
# Lesion-Soft-ARFCenter.i  -- Soft lesion with Gaussian ARF body force
# Based on Lesion-DirBC.i: Dirichlet BCs, Cubit file mesh, x-z plane
# Material: mu_B=5kPa, mu_L=19kPa (soft tissue range)
# Body force: Gaussian profile in x (sigma_f=3mm), boxcar in z, half-sine in t
#
# Overridable from command line:
#   filename  - Cubit mesh basename and output filename root
#   refine    - uniform_refine level (0=base mesh, 1=halved, etc.)
#   my_dt     - timestep (s)
#   end_time  - simulation end time (s)
#   suffix    - output filename suffix for convergence runs
###############################################################################

# -------------------------
# Top-level parameter definitions (evaluated before the rest of the file)
# -------------------------
# File naming (can be overridden from command line)
filename = "Lesion_h2.50mm"

# Output suffix (empty by default; set from CLI for convergence runs)
suffix = '_soft'

# Basic material constants (human-friendly input)
nu = 0.49
rho = 1000.0  # kg/m^3

# Shear moduli (Pa) - soft tissue values in SI units
mu_B = 5000.0     # Base (B) - 5 kPa
mu_L = 19000.0    # Lesion (L) - 19 kPa

# Compute Young's modulus E = 2 * mu * (1 + nu)
E_B = ${fparse 2.0 * mu_B * (1.0 + nu)}
E_L = ${fparse 2.0 * mu_L * (1.0 + nu)}

# Time integration / Newmark defaults
newmark_beta = 0.25
newmark_gamma = 0.5

# Impulse definition (body force - units are N/m^3)
F0 = 1                                # peak body force magnitude (N/m^3)
t_imp = 1.0e-3                        # impulse duration (1 ms)

# Body force spatial profile: Gaussian in x, boxcar in z
sigma_f = 0.003                        # Gaussian std dev in x (m)
x_center = 0.0                         # x-coordinate center of force region (m)
z_min = 0.015                          # minimum z-coordinate of force region (m)
z_max = 0.035                          # maximum z-coordinate of force region (m)

# Time stepping (overridable from CLI)
my_dt = 0.125e-3                       # timestep (s) - converged (see dt convergence study)
end_time = 35e-3                       # simulation end time (s) - longer for slower waves

# Default mesh refinement for production (refine=2 on h2.50mm base -> effective h~0.625mm)
refine = 2

# -------------------------
# Mesh and physics
# -------------------------
[GlobalParams]
  displacements = 'disp_x disp_z'
[]

[Mesh]
  [file]
    type = FileMeshGenerator
    file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Cubit/${filename}.e"
  []
  construct_side_list_from_node_list = true
  uniform_refine = ${refine}
[]

[Functions]
  [./body_masked_time]
    type = ParsedFunction
    # Gaussian in x, boxcar in z, half-sine in t
    expression = 'if(t <= t_imp, exp(-((x - x_center)^2) / (2 * sigma_f^2)) * if(z >= z_min, if(z <= z_max, F0 * sin(pi * t / t_imp), 0), 0), 0)'
    symbol_names = 't_imp F0 sigma_f x_center z_min z_max'
    symbol_values = '${t_imp} ${F0} ${sigma_f} ${x_center} ${z_min} ${z_max}'
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
  # Base (B) - assign to block=1
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

  # Lesion (L) - assign to block=2
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
  end_time = ${end_time}
  dt = ${my_dt}
  solve_type = 'PJFNK'
[]

[Postprocessors]
  [strain_energy]
    type = ElementIntegralMaterialProperty
    mat_prop = strain_energy_density
  []
[]

[Outputs]
  [./exodus]
    type = Exodus
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion/exodus/${filename}${suffix}"
  []
  [./csv]
    type = CSV
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion/exodus/${filename}${suffix}"
  []
  console = true
[]
