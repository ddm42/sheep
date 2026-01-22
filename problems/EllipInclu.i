#
# Initial single block mechanics input
# https://mooseframework.inl.gov/modules/solid_mechanics/tutorials/introduction/step01.html
#

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
    file = "/Users/ddm42/Google Drive/My Drive/1_Work-Duke-Research/Artery_Research/data/artery_OED/Cubit/EllipInclu.e"

    # block_id = '4 2'
    # block_name = 'base inclusion'
[]

[Physics/SolidMechanics/QuasiStatic]
  [all]
    add_variables = true
  []
[]

[Materials]
  [elasticity]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 1e9
    poissons_ratio = 0.3
  []
  [stress]
    type = ComputeLinearElasticStress
  []
[]

[Executioner]
  type = Transient
  end_time = 5
  dt = 1
[]

[Outputs]
  exodus = true
[]