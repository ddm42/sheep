#include "SHEEPApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "ModulesApp.h"
#include "MooseSyntax.h"

InputParameters
SHEEPApp::validParams()
{
  InputParameters params = MooseApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  params.set<bool>("use_legacy_initial_residual_evaluation_behavior") = false;
  return params;
}

SHEEPApp::SHEEPApp(const InputParameters & parameters) : MooseApp(parameters)
{
  SHEEPApp::registerAll(_factory, _action_factory, _syntax);
}

SHEEPApp::~SHEEPApp() {}

void
SHEEPApp::registerAll(Factory & f, ActionFactory & af, Syntax & syntax)
{
  ModulesApp::registerAllObjects<SHEEPApp>(f, af, syntax);
  Registry::registerObjectsTo(f, {"SHEEPApp"});
  Registry::registerActionsTo(af, {"SHEEPApp"});

  /* register custom execute flags, action syntax, etc. here */
}

void
SHEEPApp::registerApps()
{
  registerApp(SHEEPApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
extern "C" void
SHEEPApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  SHEEPApp::registerAll(f, af, s);
}
extern "C" void
SHEEPApp__registerApps()
{
  SHEEPApp::registerApps();
}
