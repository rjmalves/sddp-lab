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

### Vector Autoregressive

```@docs
VectorAutoRegressive
```

## SAA Generation

```@docs
generate_saa
```

## AR/VAR Parameter Access

```@docs
get_ar_parameters
get_ar_scale
get_var_season_parameters
get_var_coefficient_matrix
get_var_scales
```
