# Engine Configuration

The engine module contains all types used to configure the SDDP algorithm.
The top-level type is [`SDDPEngine`](@ref), which is built from the `engine`
section of your `main.jsonc` file.

## Top-Level Engine

```@docs
SDDPEngine
```

## Task Definitions

```@docs
SDDPPolicyTaskDefinition
SDDPSimulationTaskDefinition
```

## Convergence Configuration

```@docs
Convergence
```

### Stopping Criteria

```@docs
StoppingCriteria
IterationLimit
TimeLimit
LowerBoundStability
Statistical
SimulationStopping
FirstStageStopping
StoppingChain
```

## Risk Measures

```@docs
RiskMeasure
Expectation
WorstCase
AVaR
CVaR
Entropic
WassersteinRM
ModifiedChiSquared
ConvexCombination
```

## Parallelism

```@docs
ParallelScheme
Serial
Asynchronous
Threaded
```

## Sampling Schemes

```@docs
SamplingScheme
DefaultSampling
InSampleMC
PSRSampling
```

## Duality Handlers

```@docs
DualityHandler
DefaultDuality
ContinuousConicDualityHandler
StrengthenedConicDualityHandler
LagrangianDualityHandler
BanditDualityHandler
```

## Forward Pass Strategies

```@docs
ForwardPassStrategy
DefaultForwardPassStrategy
RevisitingForwardPassStrategy
RiskAdjustedForwardPassStrategy
RegularizedForwardPassStrategy
```

## Cut Types

```@docs
CutType
SingleCut
MultiCut
```

## Variable Scaling

```@docs
ScalingMode
NoScaling
AutoScaling
ScalingConfig
```

## Solver Configuration

```@docs
SolverConfig
```

## Diagnostics Configuration

```@docs
DiagnosticsConfig
```

## Inflow Non-Negativity

```@docs
InflowNonNegativity
InflowNone
InflowPenalty
InflowTruncation
InflowTruncationWithPenalty
```

## Out-of-Sample Validation

```@docs
OutOfSampleValidation
SDDPValidationTaskArtifact
```

## Debug Configuration

```@docs
DebugConfig
```

## Training Log Types

```@docs
TrainingLogConfig
TrainingLog
TrainingLogEntry
```

## Engine Accessor Functions

```@docs
get_policy_definition
get_simulation_definition
```
