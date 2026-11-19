# Installation

SDDPlab.jl can be installed as a Julia package, as a pre-built standalone application, or compiled from source.

## As a Julia Package

SDDPlab.jl is not registered in the Julia General registry. Install directly from GitHub:

```julia
julia> ]
pkg> add https://github.com/rjmalves/sddp-lab.git
```

Requires Julia 1.10 or higher. Verify with:

```julia
using SDDPlab
```

## Pre-built Application

Download a pre-built bundle from [GitHub Releases](https://github.com/rjmalves/sddp-lab/releases) (no Julia installation required):

```bash
tar -xzf sddp-lab-v3.0.0-linux-x86_64.tar.gz
SDDPLabApp/bin/SDDPlab <study-path>
```

### CLI Reference

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

### Common Workflows

Train policy only, saving cuts to a custom directory:

```bash
SDDPlab --policy-only -o results/ my_study/
```

Simulate using a previously trained policy:

```bash
SDDPlab --simulate-only --policy-path results/ my_study/
```

Full pipeline without saving the intermediate policy:

```bash
SDDPlab --no-save-policy my_study/
```

## Building from Source

Requires [PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/stable/):

```bash
julia --project=build build/build_app.jl
build/package_tarball.sh
```

The tarball is created at `build/sddp-lab-v{version}-{os}-{arch}.tar.gz`.
