[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  large_kinematics = true # used in NeoHookean among others
[]

[AuxVariables]
  [pressure]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Mesh]
  file = /home/ddm42/projects/frog/mesh/sphericalOctant-mm.msh
[]

[Modules/TensorMechanics/Master]
  [all]
    strain = FINITE # ComputeLagrangianStrain
    #displacements = 'disp_x disp_y disp_z' exists because of GlobalParams
    add_variables = true # adds displacement variables
    new_system = true # UpdatedLagrangianStressDivergence kernels are "new"
    formulation = UPDATED # UpdatedLagrangianStressDivergence kernel
    volumetric_locking_correction = true
    generate_output = 'l2norm_pk2_stress l2norm_cauchy_stress l2norm_strain'
    # 80% sure l2norm_strain is true strain (read docs best I could)
  []
[]

[BCs]
  [bottom_x]
    type = DirichletBC
    variable = disp_x
    boundary = 75
    value = 0 # meters
    preset = false # true = value of BC is applied before solve begins
  []
  [bottom_y]
    type = DirichletBC
    variable = disp_y
    boundary = 74
    value = 0 # meters
    preset = false
  []
  [bottom_z]
    type = DirichletBC
    variable = disp_z
    boundary = 67
    value = 0
    preset = false
  []
  [Pressure]
    [right]
      boundary = 65
      function = 4.3*t # 14.5 kPa = 148.1 cm. H2O
      use_automatic_differentiation = true
    []
  []
[]

[AuxKernels]
  [pressure]
    type = FunctionAux
    variable = pressure
    function = '4.3*t'
    boundary = 65
    execute_on = TIMESTEP_END
  []
[]

[Materials]
  [stress]
    type = ComputeMooneyRivlinStress
    c1 = -550 # kPa
    c2 = 700 # kPa
    # Beta = 10^5 * max(C1,C2)
    # p_0 = 2*c2 - c1
    use_displaced_mesh = true # helps with stability?
  []
[]

[Preconditioning]
  [SMP] # for user-defined preconditioners
    type = SMP # Single Matrix Preconditioner
    full = true
  []
[]

[Functions]
  [timestepper]
      type = PiecewiseConstant
      x = '0 0.09 1' # time_t
      y = '0.001 0.0001' # time_dt
      direction = LEFT
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  end_time = 1 # <--- failing at .1655
  #dt = .005
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_package'
  petsc_options_value = 'lu superlu_dist'
  nl_abs_tol = 1e-5
  # line_search = l2

  # [Adaptivity]
  #   interval = 1
  #   refine_fraction = 0.1
  #   coarsen_fraction = 0.1
  #   max_h_level = 3
  #   start_time = .09
  # []

  [TimeStepper]
    type = FunctionDT
    function = timestepper
  []
[]

[Outputs]
  exodus = true
  print_linear_residuals = false
[]
