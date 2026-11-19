"""
    InputModule

Abstract base type for all input sub-modules (e.g., `SystemData`,
`ScenariosData`). Every module that can be read from disk and composed
into a `Study` must subtype `InputModule`.
"""
abstract type InputModule end

"""
    Engine

Abstract base type for algorithm engines. Concrete subtypes (e.g.,
`SDDPEngine`) carry all configuration needed to build, train, and
simulate a policy.
"""
abstract type Engine end

"""
    Model

Abstract base type for built optimization models. Concrete subtypes hold the
solver-ready representation (e.g., `SDDP.PolicyGraph`) returned by `build`.
"""
abstract type Model end

"""
    PolicyTaskDefinition

Abstract base type for policy training task definitions. Concrete subtypes
(e.g., `SDDPPolicyTaskDefinition`) specify convergence criteria,
risk measures, and parallelism options for the training phase.
"""
abstract type PolicyTaskDefinition end

"""
    PolicyTaskArtifact

Abstract base type for the result of a completed training run. Concrete
subtypes hold the trained policy graph and any training logs or diagnostics
produced during training.
"""
abstract type PolicyTaskArtifact end

"""
    SimulationTaskDefinition

Abstract base type for simulation task definitions. Concrete subtypes specify
the number of simulated series and the parallel scheme to use during simulation.
"""
abstract type SimulationTaskDefinition end

"""
    SimulationTaskArtifact

Abstract base type for the result of a completed simulation run. Concrete
subtypes hold the raw simulation trajectories and any metadata needed for
post-processing.
"""
abstract type SimulationTaskArtifact end

"""
    TaskResultsFormat

Abstract base type for output format selectors. Subtypes control how results
are serialized to disk. Use [`CSVFormat`](@ref) for human-readable CSV files or
[`ParquetFormat`](@ref) for columnar binary storage.

See also: [`CSVFormat`](@ref), [`ParquetFormat`](@ref), [`AnyFormat`](@ref)
"""
abstract type TaskResultsFormat end

"""
    AnyFormat <: TaskResultsFormat

A no-op output format that produces no files. Useful for dry-run testing or
when the caller manages output independently.

See also: [`CSVFormat`](@ref), [`ParquetFormat`](@ref)
"""
struct AnyFormat <: TaskResultsFormat end

"""
    CSVFormat <: TaskResultsFormat

Output format that writes results as comma-separated values (`.csv`) files.
This is the default recommended format for inspection and interoperability.

# Example

```julia
save_simulation(study, artifact, "/path/to/output", CSVFormat())
```

See also: [`ParquetFormat`](@ref), [`AnyFormat`](@ref)
"""
struct CSVFormat <: TaskResultsFormat end

"""
    ParquetFormat <: TaskResultsFormat

Output format that writes results as Apache Parquet (`.parquet`) columnar binary
files. Preferred for large result sets where CSV I/O is a bottleneck.

# Example

```julia
save_simulation(study, artifact, "/path/to/output", ParquetFormat())
```

See also: [`CSVFormat`](@ref), [`AnyFormat`](@ref)
"""
struct ParquetFormat <: TaskResultsFormat end
