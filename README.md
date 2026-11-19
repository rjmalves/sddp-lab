# SDDPlab.jl

A Julia laboratory for experimenting with SDDP algorithm variations in hydrothermal dispatch.

[![CI](https://github.com/rjmalves/sddp-lab/workflows/CI/badge.svg)](https://github.com/rjmalves/sddp-lab/actions)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://rjmalves.github.io/sddp-lab/)
[![codecov](https://codecov.io/gh/rjmalves/sddp-lab/graph/badge.svg)](https://codecov.io/gh/rjmalves/sddp-lab)

SDDPlab.jl provides a configuration-driven pipeline for building, training, and simulating
multi-stage stochastic optimization models of power systems. It is built on top of
[SDDP.jl](https://sddp.dev/stable/) and [JuMP.jl](https://jump.dev/), and is designed to make
it easy to compare algorithmic variants (risk measures, stopping criteria, parallelism strategies)
without modifying Julia source code.

## Installation

SDDPlab.jl is not registered in the Julia General registry. Install it directly from GitHub:

```julia
julia> ]
pkg> add https://github.com/rjmalves/sddp-lab.git
```

Julia 1.10 or higher is required.

## Compiled App

Pre-built application bundles are available on the
[GitHub Releases](https://github.com/rjmalves/sddp-lab/releases) page. No Julia installation
is required to run the compiled app.

Download the tarball for your platform, extract it, and run:

```bash
tar -xzf sddp-lab-v3.0.0-linux-x86_64.tar.gz
SDDPLabApp/bin/SDDPlab <study-path>
```

## Quick Start

```julia
using SDDPlab

study = read_study("path/to/case")
model = build(study)
train(study, model)
simulate(study, model)
```

Results are saved to `<study-path>/data/` by default in Parquet format.

## CLI Usage

The compiled app exposes a CLI with the following interface:

```
SDDPlab [OPTIONS] <study-path>

Arguments:
  <study-path>          Path to directory containing main.jsonc

Task selection:
  --policy-only         Train policy and exit (skip simulation)
  --simulate-only       Load policy from disk and simulate (skip training)

Policy source:
  --policy-path <dir>   Directory to load policy from (default: output dir)
                        Only used with --simulate-only

Output control:
  -o, --output <dir>    Output directory (default: <study-path>/data/)
  -f, --format <fmt>    Output format: "parquet" (default) or "csv"
  --no-save-policy      Skip saving policy artifacts after training
  --no-save-simulation  Skip saving simulation results

General:
  -h, --help            Print this help message
  -V, --version         Print version information
```

By default both training and simulation run. Common workflows:

```bash
# Train only, save policy to custom directory
SDDPlab --policy-only -o results/ my_study/

# Simulate using a previously trained policy
SDDPlab --simulate-only --policy-path results/ my_study/

# Full pipeline without saving intermediate policy
SDDPlab --no-save-policy my_study/
```

## Building from Source

To build the compiled app from source, PackageCompiler.jl is required:

```bash
julia --project=build build/build_app.jl
build/package_tarball.sh
```

The tarball is written to `build/sddp-lab-v{version}-{os}-{arch}.tar.gz`.

## Documentation

Full documentation, including configuration reference and tutorials, is available at:

https://rjmalves.github.io/sddp-lab/

## License

[MIT](LICENSE)
