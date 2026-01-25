# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**NOTE: This is the application-specific CLAUDE.md for the SHEEP project. Always read this file when working within the sheep/ directory for the most current project-specific guidance.**

## Repository Overview

SHEEP is a MOOSE-based application for multiphysics simulations. It's built on the Multiphysics Object-Oriented Simulation Environment (MOOSE) framework and focuses on solid mechanics problems.

## Application Architecture

### Core Components
- `src/base/SHEEPApp.C` - Main application class that registers MOOSE modules and custom objects
- `include/base/SHEEPApp.h` - Application header
- `test/` - Test infrastructure with separate test application (`SHEEPTestApp`)
- `problems/` - Input files for simulations (`.i` files)

### MOOSE Integration
- Only the `SOLID_MECHANICS` module is enabled (see Makefile:49)
- Uses MOOSE framework's factory pattern for object registration
- Inherits from `MooseApp` and registers with `ModulesApp`

## Common Development Commands

**IMPORTANT: Before running any commands, activate the moose conda environment:**

**Conda Environment Setup for Claude Code:**
Claude Code requires conda initialization to access the conda shell functions. Use this command pattern:
```bash
source ~/miniforge/etc/profile.d/conda.sh && conda activate moose
```

Or for individual commands:
```bash
source ~/miniforge/etc/profile.d/conda.sh && conda activate moose && make -j8
```

**Standard usage (if conda is already initialized in your shell):**
```bash
conda activate moose
```

### Building
```bash
conda activate moose        # Ensure moose environment is active
make -j8                    # Build optimized version (default)
METHOD=dbg make -j8         # Build debug version
METHOD=oprof make -j8       # Build with profiling
```

### Testing
```bash
conda activate moose        # Ensure moose environment is active
./run_tests                 # Run all tests
./run_tests -j 8           # Run tests with 8 parallel jobs
./run_tests -i test_name   # Run specific test by name
./run_tests --re "pattern" # Run tests matching regex pattern
./run_tests --failed-tests # Re-run only failed tests
```

### Code Formatting
```bash
conda activate moose        # Ensure moose environment is active
clang-format -i src/**/*.C include/**/*.h  # Format C++ code using .clang-format
```

## Configuration Files

### `sheep.yaml`
Application configuration:
- `DMETHOD: opt` - Default build method
- `compiler_type: clang` - Preferred compiler
- `documentation: true` - Documentation generation enabled
- `registered_apps` - Lists WASPAPP, SHEEPAPP, SHEEPAPP

### `Makefile`
- `SOLID_MECHANICS := yes` - Only solid mechanics module enabled
- All other MOOSE modules set to `no`
- Application name: `sheep`

## MOOSE Documentation and Source Code Search

### Online Documentation
- **Syntax Reference**: Search `mooseframework.inl.gov/syntax/` for specific actions, kernels, materials
- **Module Documentation**: Use `mooseframework.inl.gov/modules/solid_mechanics/` for mechanics-specific docs
- **Physics System**: Modern syntax uses `[Physics/SolidMechanics/Dynamic]` instead of deprecated `[Physics/TensorMechanics]`

### Source Code Navigation
**Key directories in `../moose/`:**
- `modules/solid_mechanics/` - Solid mechanics module implementation
- `modules/solid_mechanics/include/actions/` - Action class headers
- `modules/solid_mechanics/src/actions/` - Action implementations
- `modules/solid_mechanics/test/tests/dynamics/` - Dynamic analysis examples
- `modules/solid_mechanics/doc/content/syntax/` - Documentation source

**Search patterns for solving issues:**
```bash
# Find specific actions or classes
grep -r "DynamicSolidMechanicsPhysics" ../moose/modules/solid_mechanics/
# Find example input files
grep -r "Physics.*SolidMechanics.*Dynamic" ../moose/modules/solid_mechanics/test/
# Find documentation
find ../moose/modules/solid_mechanics/doc -name "*.md" | xargs grep -l "Dynamic"
```

**Working examples in MOOSE source:**
- `../moose/modules/solid_mechanics/test/tests/dynamics/dynamic_physics/dynamic_physics_2d_planar.i`
- Uses correct `[Physics/SolidMechanics/Dynamic]` syntax
- Shows proper Newmark time integration setup

## Test Framework

Tests use MOOSE's TestHarness system:
- Test specifications in `tests` files
- Example: `test/tests/kernels/simple_diffusion/tests`
- Supports Exodiff comparisons for simulation output
- Gold files stored in `gold/` directories
- Test results cached in `.previous_test_results.json`

## Input Files and Problems

Simulation input files (`.i` format) in `problems/`:
- `Lesion.i` - Currently modified lesion simulation
- `EllipInclu.i` - Elliptical inclusion problem  
- `ramp_octant-8.i` - Ramp octant geometry

## Build Artifacts

- `sheep-opt` - Main executable (optimized build)
- `lib/` - Compiled libraries
- `build/` - Intermediate build files
- `.libs/` - Additional library files