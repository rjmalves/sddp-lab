# Core Pipeline

The core pipeline functions are the primary entry points for using SDDPlab.jl.
They implement the standard workflow: read a study from disk, build the
optimization model, train the policy, and simulate on the trained policy.

## Study Container

The [`Study`](@ref) struct binds validated input data to an engine configuration.
All pipeline functions take a `Study` as their first argument.

```@docs
Study
```

## Core Abstract Types

These abstract types define the extension points for plugging in new engines and
output formats.

```@docs
Engine
Model
PolicyTaskDefinition
PolicyTaskArtifact
SimulationTaskDefinition
SimulationTaskArtifact
InputModule
```

## Pipeline Functions

### Reading a Study

```@docs
read_study
```

### Building the Model

```@docs
build
```

### Training the Policy

```@docs
train
save_policy
load_policy
```

### Simulating

```@docs
simulate
save_simulation
```

### Debugging and Validation

```@docs
debug
validate
save_validation
```
