//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html
#include "SHEEPTestApp.h"
#include "SHEEPApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "MooseSyntax.h"

InputParameters
SHEEPTestApp::validParams()
{
  InputParameters params = SHEEPApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  params.set<bool>("use_legacy_initial_residual_evaluation_behavior") = false;
  return params;
}

SHEEPTestApp::SHEEPTestApp(const InputParameters & parameters) : MooseApp(parameters)
{
  SHEEPTestApp::registerAll(
      _factory, _action_factory, _syntax, getParam<bool>("allow_test_objects"));
}

SHEEPTestApp::~SHEEPTestApp() {}

void
SHEEPTestApp::registerAll(Factory & f, ActionFactory & af, Syntax & s, bool use_test_objs)
{
  SHEEPApp::registerAll(f, af, s);
  if (use_test_objs)
  {
    Registry::registerObjectsTo(f, {"SHEEPTestApp"});
    Registry::registerActionsTo(af, {"SHEEPTestApp"});
  }
}

void
SHEEPTestApp::registerApps()
{
  registerApp(SHEEPApp);
  registerApp(SHEEPTestApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
// External entry point for dynamic application loading
extern "C" void
SHEEPTestApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  SHEEPTestApp::registerAll(f, af, s);
}
extern "C" void
SHEEPTestApp__registerApps()
{
  SHEEPTestApp::registerApps();
}
