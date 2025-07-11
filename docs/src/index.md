# SDDPlab.jl

Welcome to the SDDPlab.jl documentation!

This page aims to provide all the necessary information and guides for using and extending `SDDPlab.jl`'s functionality

## What is SDDPlab.jl?

As the name implies, this package is meant to be a small scale laboratory for development of new methodologies related to Stochastic Dynamic Dual Programming, focused on hydrothermal optimal dispatch problems. To this end, `SDDPlab.jl` standardizes and automates all the definition and building of the power system and uncertainties' stochastic processes.

This package has [`SDDP.jl`](https://sddp.dev/stable/) as its main backend, for running the actual SDDP algorithm, i.e. the actual execution of the cutting plane approximation once the linear program at each node is built. This means that `SDDPlab.jl` is focused not on the actual solving of the MSLP, buy on how to best model challenging aspects of the long-term planning problem.

It is built with extensibility in mind, so that new system elements, statistical models and any other representation within the problem can be implemented fairly easily, without large scale modifications to the overall structure of the package.

## Found a bug and/or error?

Please report all unexpected behavior by [opening an issue](https://github.com/rjmalves/sddp-lab/issues)

## Package Manual

```@contents
Pages = ["man/getting_started.md"]
Depth = 2
```
