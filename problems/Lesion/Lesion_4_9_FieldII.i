###############################################################################
# Lesion_4_9_FieldII.i  -- Lesion_4_9 with Field II ARF spatial profile
#
# Replaces the analytical Gaussian-in-x × boxcar-in-z × half-sine-in-t body
# force with a precomputed 2D ARF intensity field from Field II
# (gen_ARF_field.m), multiplied by a 200 us rectangular temporal impulse
# (Vasconcelos 2021) via CompositeFunction.
#
# Materials: mu_B = 4 kPa (c_s_B = 2 m/s), mu_L = 9 kPa (c_s_L = 3 m/s).
# Hard lesion (faster than background).
#
# Spatial ARF: ${arf_data_dir}/${arf_file} (PiecewiseMultilinear, axes
# AXIS X / AXIS Z in meters, peak normalized to 1).
#
# Overridable from command line:
#   mesh_file   - Cubit mesh basename (in ${mesh_dir})
#   filename    - output file base name
#   refine      - uniform_refine level on the Cubit mesh
#   dt_impulse  - timestep during impulse (s)
#   dt_post     - timestep after t_cutover (s)
#   t_cutover   - time at which dt switches (s)
#   end_time    - simulation end time (s)
#   data_dir    - base data directory
#   arf_file    - ARF spatial field filename (in ${arf_data_dir})
###############################################################################

# -------------------------
# Mesh: use the native h=0.25 mm Cubit mesh (uniform_refine on a coarser
# Cubit base does not refit the curved lesion boundary, so it under-resolves
# the interface — always start from a Cubit mesh built at the target h).
# Matches HomRect_FieldII's h = 0.25 mm.
# -------------------------
mesh_file = "Lesion_h.250mm"
refine    = 0

# Time stepping -- adaptive (FunctionDT below):
#   dt = dt_impulse during [0, t_cutover) to resolve the 200 us rectangular pulse
#   dt = dt_post    after t_cutover
dt_impulse = 0.01e-3                    # 10 us  -> 20 samples across the 200 us pulse
dt_post    = 0.0625e-3                  # 62.5 us
t_cutover  = 500e-6                     # 2.5 x pulse duration (200 us pulse + 300 us settling)
end_time   = 30e-3                      # max observation window before x-boundary reflections enter imaging domain at ~25 ms (c_s_B=2 m/s, traversal to x=+20 mm takes ~15 ms)

# Output filename
filename = 'Lesion_4_9_FieldII_h0.25mm'
suffix   = ''

# Data directory
data_dir   = '/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED'
output_dir = '${data_dir}/Lesion_4_9_FieldII/exodus'
mesh_dir   = '${data_dir}/Cubit'

# ARF spatial field (x-z plane for Lesion problems)
arf_data_dir = '${data_dir}/ARF'
arf_file     = 'arf_field_x-10mm_FN2_xz.txt'

# -------------------------
# Material constants
# -------------------------
nu  = 0.49
rho = 1000.0
mu_B = 4000.0
mu_L = 9000.0
E_B  = ${fparse 2.0 * mu_B * (1.0 + nu)}
E_L  = ${fparse 2.0 * mu_L * (1.0 + nu)}

newmark_beta  = 0.25
newmark_gamma = 0.5

# -------------------------
# Body force: unit peak (spatial field is peak-normalized to 1 in MATLAB)
# -------------------------
F0    = 1.0
t_imp = 200e-6                          # 200 us rectangular pulse (Vasconcelos)

# -------------------------
# Mesh and physics
# -------------------------
[GlobalParams]
  displacements = 'disp_x disp_z'
[]

[Mesh]
  [file]
    type = FileMeshGenerator
    file = "${mesh_dir}/${mesh_file}.e"
  []
  construct_side_list_from_node_list = true
  uniform_refine = ${refine}
[]

[Functions]
  [arf_spatial]
    type = PiecewiseMultilinear
    data_file = "${arf_data_dir}/${arf_file}"
  []
  [arf_temporal]
    type = ParsedFunction
    expression = 'if(t <= t_imp, F0, 0)'
    symbol_names  = 't_imp F0'
    symbol_values = '${t_imp} ${F0}'
  []
  [arf_body_force]
    type = CompositeFunction
    functions = 'arf_spatial arf_temporal'
  []
  [dt_function]
    type = PiecewiseConstant
    x = '0             ${t_cutover}'
    y = '${dt_impulse} ${dt_post}'
    direction = left
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
  [./body_force_z]
    type = BodyForce
    variable = disp_z
    function = arf_body_force
  []
[]

[BCs]
  # Homogeneous Dirichlet BCs on all four Cubit sidesets
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
  solve_type = 'PJFNK'
  [TimeStepper]
    type = FunctionDT
    function = dt_function
  []
[]

[Postprocessors]
  [strain_energy]
    type = ElementIntegralMaterialProperty
    mat_prop = strain_energy_density
  []

  [disp_z_pt1]
    type = PointValue
    variable = disp_z
    point = '-0.005 0 0.025'
  []
  [disp_z_pt2]
    type = PointValue
    variable = disp_z
    point = '0.005 0 0.025'
  []
  [disp_z_pt3]
    type = PointValue
    variable = disp_z
    point = '0.010 0 0.020'
  []
  [disp_z_pt4]
    type = PointValue
    variable = disp_z
    point = '0.010 0 0.030'
  []

  [avg_disp_z]
    type = LinearCombinationPostprocessor
    pp_names = 'disp_z_pt1 disp_z_pt2 disp_z_pt3 disp_z_pt4'
    pp_coefs = '0.25 0.25 0.25 0.25'
  []
[]

[Outputs]
  append_date = true
  [./exodus]
    type = Exodus
    file_base = "${output_dir}/${filename}${suffix}"
  []
  [./csv]
    type = CSV
    file_base = "${output_dir}/${filename}${suffix}"
  []
  console = true
[]
