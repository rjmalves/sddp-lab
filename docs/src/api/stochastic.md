# Stochastic Processes

The stochastic process module provides the inflow generation models used during
SDDP training. All concrete process types implement [`generate_saa`](@ref) for
generating Sample Average Approximation scenarios.

## Base Type

```@docs
AbstractStochasticProcess
```

## Concrete Process Types

### Naive (Copula-Based)

```@docs
Naive
```

### Autoregressive

```@docs
AutoRegressive
```

## SAA Generation

```@docs
generate_saa
```

## AR Parameter Access

```@docs
get_ar_parameters
get_ar_scale
```
