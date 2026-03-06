###############################################################################
# Lesion_TopRight.i -- Soft lesion in top-right corner, conformal TRI6 mesh
# XYDelaunayGenerator with ParsedCurveGenerator for body-fitted ellipse
#
# Domain: x in [-0.04, 0.04], y in [0.0, 0.05]  (80 x 50 mm)
# Uses x-y plane (dim=2).
#
# Lesion: rotated ellipse centered at (x,y) = (15, 20) mm
#         x semi-axis a = 5 mm, y semi-axis b = 2.5 mm, rotated 45 deg CCW
# Materials: mu_B = 25 kPa (background), mu_L = 9 kPa (soft lesion)
# ARF push: x_center = -10 mm (unchanged from other Lesion problems)
#
# Overridable from command line:
#   desired_area - max triangle area (controls element size; default ~ h=0.625mm)
#   n_ellipse    - number of segments on ellipse boundary
#   my_dt    - timestep (s)
#   end_time - simulation end time (s)
#   filename - output file base name
#   suffix   - output filename suffix for convergence runs
###############################################################################

# -------------------------
# Mesh resolution (override from command line)
# -------------------------
# desired_area controls element size: area ~ h^2 * sqrt(3)/4
# h=0.625mm -> area ~ 1.69e-7 m^2
desired_area = 1.7e-7
n_ellipse = 40                         # segments on ellipse boundary

# File naming (can be overridden from command line)
filename = "Lesion_TopRight"

# Output suffix (empty by default; set from CLI for convergence runs)
suffix = ''

# -------------------------
# Material constants
# -------------------------
nu = 0.49
rho = 1000.0  # kg/m^3

# Shear moduli (Pa) - values in SI units
mu_B = 25000.0   # Base (B)
mu_L = 9000.0    # Lesion (L) -- soft lesion

# Compute Young's modulus E = 2 * mu * (1 + nu)
E_B = ${fparse 2.0 * mu_B * (1.0 + nu)}
E_L = ${fparse 2.0 * mu_L * (1.0 + nu)}

# Shear wave speeds: c_s = sqrt(mu / rho)
# c_s_B = 5.0 m/s, c_s_L = 3.0 m/s
# At f_max = 1500 Hz: lambda_min = 2.0 mm (lesion governs -- softer than base)

# Time integration / Newmark defaults
newmark_beta = 0.25
newmark_gamma = 0.5

# Impulse definition (body force - units are N/m^3)
F0 = 400                              # peak body force magnitude (N/m^3)
t_imp = 1.0e-3                        # impulse duration (1 ms)

# Body force spatial profile: Gaussian in x, boxcar in y
sigma_f = 0.003                        # Gaussian std dev in x (m)
x_center = -0.01                       # x-coordinate center of force region (m)
y_min_f = 0.015                        # minimum y-coordinate of force region (m)
y_max_f = 0.035                        # maximum y-coordinate of force region (m)

# Time stepping (overridable from CLI)
my_dt = 0.0625e-3                      # timestep (s) -- sub-percent error at f_max=1500 Hz
end_time = 20e-3                       # simulation end time (s)

# -------------------------
# Mesh: Conformal TRI6 via XYDelaunayGenerator with body-fitted ellipse
# -------------------------
[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  # Rectangular outer boundary (CCW)
  [rect]
    type = PolyLineMeshGenerator
    points = '-0.04  0.0  0.0
              0.04  0.0  0.0
              0.04  0.05 0.0
             -0.04  0.05 0.0'
    loop = true
  []

  # Ellipse boundary as closed curve (rotated 45 deg CCW)
  # cx=15mm, cy=20mm, a=5mm, b=2.5mm, theta=45deg
  # ct = cos(45deg) = 0.7071067811865, st = sin(45deg) = 0.7071067811865
  [ellipse]
    type = ParsedCurveGenerator
    x_formula = '0.015 + 0.005*cos(t)*0.7071067811865 - 0.0025*sin(t)*0.7071067811865'
    y_formula = '0.020 + 0.005*cos(t)*0.7071067811865 + 0.0025*sin(t)*0.7071067811865'
    section_bounding_t_values = '0.0 6.283185307'
    nums_segments = '${n_ellipse}'
    is_closed_loop = true
  []

  # Triangulate the ellipse interior (lesion block)
  [ellipse_tri]
    type = XYDelaunayGenerator
    boundary = 'ellipse'
    desired_area = ${desired_area}
    output_subdomain_name = 'lesion'
    output_boundary = 'ellipse_boundary'
    tri_element_type = TRI6
    smooth_triangulation = true
  []

  # Triangulate the background with ellipse as a stitched hole
  [domain]
    type = XYDelaunayGenerator
    boundary = 'rect'
    holes = 'ellipse_tri'
    stitch_holes = 'true'
    refine_holes = 'false'
    desired_area = ${desired_area}
    output_subdomain_name = 'background'
    output_boundary = 'outer'
    tri_element_type = TRI6
    smooth_triangulation = true
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
  # Base (B) - 'background' block
  [./elasticity_B]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_B}
    poissons_ratio = ${nu}
    block = background
  []
  [./stress_B]
    type = ComputeLinearElasticStress
    block = background
  []
  [./density_B]
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
    block = background
  []

  # Lesion (L) - 'lesion' block
  [./elasticity_L]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_L}
    poissons_ratio = ${nu}
    block = lesion
  []
  [./stress_L]
    type = ComputeLinearElasticStress
    block = lesion
  []
  [./density_L]
    type = GenericConstantMaterial
    prop_names  = 'density'
    prop_values = ${rho}
    block = lesion
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
    order = SECOND
    family = LAGRANGE
  []
  [./vel_y]
    order = SECOND
    family = LAGRANGE
  []
  [./accel_x]
    order = SECOND
    family = LAGRANGE
  []
  [./accel_y]
    order = SECOND
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
  # Homogeneous Dirichlet BCs on all outer edges
  [./fix_outer_x]
    type = DirichletBC
    boundary = outer
    variable = disp_x
    value = 0.0
  []
  [./fix_outer_y]
    type = DirichletBC
    boundary = outer
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

  # Sample disp_y at 4 points in the imaging domain (x in [-20,20]mm, y in [15,35]mm)
  # Source is at x = -10 mm; points at varying distances and positions
  [disp_y_pt1]
    type = PointValue
    variable = disp_y
    point = '-0.005 0.025 0'
  []
  [disp_y_pt2]
    type = PointValue
    variable = disp_y
    point = '0.005 0.025 0'
  []
  [disp_y_pt3]
    type = PointValue
    variable = disp_y
    point = '0.010 0.020 0'
  []
  [disp_y_pt4]
    type = PointValue
    variable = disp_y
    point = '0.010 0.030 0'
  []

  # Average of the 4 sampled displacements
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
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion_TopRight/exodus/${filename}${suffix}"
  []
  [./csv]
    type = CSV
    file_base = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Lesion_TopRight/exodus/${filename}${suffix}"
  []
  console = true
[]
