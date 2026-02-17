###############################################################################
# HomRect-StepTest.i -- Test: original step-function body force on uniform mesh
# Demonstrates that epsilon_f = 0.0001 produces zero displacement on a
# structured mesh because no Gauss quadrature points fall in the 0.2 mm band.
###############################################################################

nx = 16
ny = 10
my_dt = 0.25e-3
end_time = 6e-3
filename = '/tmp/HomRect_StepTest'

nu = 0.49
rho = 1000.0
mu_B = 25000.0
E_B = ${fparse 2.0 * mu_B * (1.0 + nu)}

newmark_beta = 0.25
newmark_gamma = 0.5

F0 = 400
t_imp = 1.0e-3

# Original narrow step function (same as Lesion-DirBC.i)
epsilon_f = 0.0001
x_center = -0.01
y_min_f = 0.015
y_max_f = 0.035

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${nx}
    ny = ${ny}
    xmin = -0.04
    xmax = 0.04
    ymin = 0.0
    ymax = 0.05
  []
[]

[Functions]
  [body_masked_time]
    type = ParsedFunction
    expression = 'if(t <= t_imp, if(x >= (x_center - epsilon_f), if(x <= (x_center + epsilon_f), if(y >= y_min_f, if(y <= y_max_f, F0 * sin(pi * t / t_imp), 0), 0), 0), 0), 0)'
    symbol_names = 't_imp F0 epsilon_f x_center y_min_f y_max_f'
    symbol_values = '${t_imp} ${F0} ${epsilon_f} ${x_center} ${y_min_f} ${y_max_f}'
  []
[]

[Physics/SolidMechanics/Dynamic]
  [all]
    add_variables = true
    strain = SMALL
    newmark_beta = ${newmark_beta}
    newmark_gamma = ${newmark_gamma}
  []
[]

[Materials]
  [elasticity]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = ${E_B}
    poissons_ratio = ${nu}
  []
  [stress]
    type = ComputeLinearElasticStress
  []
  [density]
    type = GenericConstantMaterial
    prop_names = 'density'
    prop_values = ${rho}
  []
[]

[AuxVariables]
  [vel_x][]
  [vel_y][]
  [accel_x][]
  [accel_y][]
[]

[AuxKernels]
  [vel_x]
    type = NewmarkVelAux
    variable = vel_x
    acceleration = accel_x
    gamma = ${newmark_gamma}
    execute_on = timestep_end
  []
  [vel_y]
    type = NewmarkVelAux
    variable = vel_y
    acceleration = accel_y
    gamma = ${newmark_gamma}
    execute_on = timestep_end
  []
  [accel_x]
    type = NewmarkAccelAux
    variable = accel_x
    displacement = disp_x
    velocity = vel_x
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
  [accel_y]
    type = NewmarkAccelAux
    variable = accel_y
    displacement = disp_y
    velocity = vel_y
    beta = ${newmark_beta}
    execute_on = timestep_end
  []
[]

[Kernels]
  [body_force_y]
    type = BodyForce
    variable = disp_y
    function = body_masked_time
  []
[]

[BCs]
  [fix_bottom_x]
    type = DirichletBC
    boundary = bottom
    variable = disp_x
    value = 0.0
  []
  [fix_bottom_y]
    type = DirichletBC
    boundary = bottom
    variable = disp_y
    value = 0.0
  []
  [fix_right_x]
    type = DirichletBC
    boundary = right
    variable = disp_x
    value = 0.0
  []
  [fix_right_y]
    type = DirichletBC
    boundary = right
    variable = disp_y
    value = 0.0
  []
  [fix_top_x]
    type = DirichletBC
    boundary = top
    variable = disp_x
    value = 0.0
  []
  [fix_top_y]
    type = DirichletBC
    boundary = top
    variable = disp_y
    value = 0.0
  []
  [fix_left_x]
    type = DirichletBC
    boundary = left
    variable = disp_x
    value = 0.0
  []
  [fix_left_y]
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
  [disp_y_pt1]
    type = PointValue
    variable = disp_y
    point = '-0.02 0.025 0'
  []
[]

[Outputs]
  csv = true
  console = true
[]
