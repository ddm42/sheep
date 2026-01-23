# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Building
```bash
make -j8                    # Build optimized version (default)
METHOD=dbg make -j8         # Build debug version
METHOD=oprof make -j8       # Build with profiling
```

### Testing
```bash
./run_tests                 # Run all tests
./run_tests -j 8           # Run tests with 8 parallel jobs
./run_tests -i test_name   # Run specific test by name
./run_tests --re "pattern" # Run tests matching regex pattern
./run_tests --failed-tests # Re-run only failed tests
```

### Code Formatting
```bash
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