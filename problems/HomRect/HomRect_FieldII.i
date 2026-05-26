###############################################################################
# HomRect_FieldII.i -- HomRect with Field II ARF spatial profile
#
# Replaces the analytical Gaussian-in-x × boxcar-in-y body force with a
# precomputed 2D ARF intensity field from Field II (gen_ARF_field.m),
# multiplied by a 200 us rectangular temporal impulse (Vasconcelos 2021)
# via CompositeFunction.
#
# Spatial field: ${arf_data_dir}/${arf_file} (PiecewiseMultilinear, axes
# AXIS X / AXIS Y in meters, peak normalized to 1).
#
# Overridable from command line:
#   nx, ny       - mesh resolution
#   dt_impulse   - timestep during impulse (s)
#   dt_post      - timestep after t_cutover (s)
#   t_cutover    - time at which dt switches (s)
#   end_time     - simulation end time (s)
#   filename     - output file base name
#   data_dir     - base data directory
#   arf_file     - ARF spatial field filename (in ${arf_data_dir})
###############################################################################

# -------------------------
# Mesh resolution (h = 0.25 mm — refined from 0.625 mm so the element-scale
# shear-wave frequency c_s/h ≈ 20 kHz sits above the 200 us rect pulse's
# broadband content, suppressing element-scale spurious modes)
# -------------------------
nx = 320
ny = 200

# Time stepping — adaptive (FunctionDT below):
#   dt = dt_impulse during [0, t_cutover) to resolve the 200 us rectangular pulse
#   dt = dt_post    after t_cutover (free vibration; matches Lesion_25_9)
dt_impulse = 0.01e-3                    # 10 us  -> 20 samples across the 200 us pulse
dt_post    = 0.0625e-3                  # 62.5 us -> matches Lesion_25_9
t_cutover  = 500e-6                     # 2.5 x pulse duration (200 us pulse + 300 us settling)
end_time   = 20e-3

# Output filename
filename = 'HomRect_FieldII_h0.25mm'
suffix = ''

# Data directory
data_dir = '/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED'
output_dir = '${data_dir}/HomRect_FieldII/exodus'

# ARF spatial field
arf_data_dir = '${data_dir}/ARF'
arf_file     = 'arf_field_x-10mm_FN2_xy.txt'

# -------------------------
# Material constants
# -------------------------
nu = 0.49
rho = 1000.0
mu_B = 25000.0
E_B = ${fparse 2.0 * mu_B * (1.0 + nu)}

newmark_beta = 0.25
newmark_gamma = 0.5

# -------------------------
# Body force: unit peak (spatial field is peak-normalized to 1 in MATLAB)
# -------------------------
F0    = 1.0
t_imp = 200e-6                          # 200 us rectangular pulse (Vasconcelos)

# Domain dimensions
x_min = -0.04
x_max =  0.04
y_min =  0.0
y_max =  0.05

# -------------------------
# Mesh and physics
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
    generate_output = 'stress_xx stress_yy stress_xy strain_xx strain_yy strain_xy'
  []
[]

[Materials]
  [./elasticity]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_B}
    poissons_ratio = ${nu}
  []
  [./stress]
    type = ComputeLinearElasticStress
  []
  [./density]
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
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
  [./body_force_y]
    type = BodyForce
    variable = disp_y
    function = arf_body_force
  []
[]

[BCs]
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

  [avg_disp_y]
    type = LinearCombinationPostprocessor
    pp_names = 'disp_y_pt1 disp_y_pt2 disp_y_pt3 disp_y_pt4'
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
