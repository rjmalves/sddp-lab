module Engines

using ..Lab
using ..StochasticProcess
using ..Scenarios
using ..System
using ..Utils

using Dates
using DataFrames
using Distributed
using Statistics: Statistics
using SDDP: SDDP
using JuMP: JuMP
using JSON
using CSV
import MathOptInterface as MOI

"""
    ScalingConfig

Internal container for variable scaling factors used during model construction
and result un-scaling. Maps each variable [`Symbol`] to a multiplicative factor.

# Fields
- `factors`: Dict mapping variable symbols to their scaling factors.

See also: [`NoScaling`](@ref), [`AutoScaling`](@ref)
"""
struct ScalingConfig
    factors::Dict{Symbol,Float64}
end

"""
    SDDPModel <: Model

Concrete [`Model`](@ref) subtype produced by [`build`](@ref) for SDDP-based
engines. Wraps an `SDDP.PolicyGraph` together with its [`ScalingConfig`](@ref).

# Fields
- `policy_graph`: The `SDDP.PolicyGraph` subproblem tree.
- `scaling`: The [`ScalingConfig`](@ref) used during construction.
"""
struct SDDPModel <: Model
    policy_graph::SDDP.PolicyGraph
    scaling::ScalingConfig
end

"""
    StoppingCriteria

Abstract base type for all SDDP training stopping rules. Concrete subtypes are:
[`IterationLimit`](@ref), [`TimeLimit`](@ref), [`LowerBoundStability`](@ref),
[`Statistical`](@ref), [`SimulationStopping`](@ref),
[`FirstStageStopping`](@ref), [`StoppingChain`](@ref).

See also: [`Convergence`](@ref)
"""
abstract type StoppingCriteria end

"""
    IterationLimit <: StoppingCriteria

Stop training after a fixed number of SDDP iterations.

# Fields
- `num_iterations`: Maximum number of iterations before halting.

See also: [`Convergence`](@ref), [`TimeLimit`](@ref)
"""
struct IterationLimit <: StoppingCriteria
    num_iterations::Integer
end

"""
    TimeLimit <: StoppingCriteria

Stop training when a wall-clock time limit is reached.

# Fields
- `time_seconds`: Maximum wall-clock training time in seconds.

See also: [`Convergence`](@ref), [`IterationLimit`](@ref)
"""
struct TimeLimit <: StoppingCriteria
    time_seconds::Integer
end

"""
    LowerBoundStability <: StoppingCriteria

Stop training when the lower bound (expected cost estimate) has not improved by
more than `threshold` (relative) over the last `num_iterations` iterations.

# Fields
- `threshold`: Relative improvement threshold (e.g., `1e-4`).
- `num_iterations`: Window size (number of past iterations) to check.

See also: [`Convergence`](@ref), [`Statistical`](@ref)
"""
struct LowerBoundStability <: StoppingCriteria
    threshold::Real
    num_iterations::Integer
end

"""
    Statistical <: StoppingCriteria

Stop training using a statistical convergence test. At every
`iteration_period` iterations, `num_replications` simulations are run and a
z-score test is applied to the gap between the lower bound and simulated cost.

# Fields
- `num_replications`: Number of Monte Carlo replications for the test.
- `iteration_period`: Number of iterations between statistical tests.
- `z_score`: Critical z-score (e.g., `1.96` for 95% confidence).

See also: [`Convergence`](@ref), [`SimulationStopping`](@ref)
"""
struct Statistical <: StoppingCriteria
    num_replications::Integer
    iteration_period::Integer
    z_score::Real
end

"""
    SimulationStopping <: StoppingCriteria

Stop training using SDDP.jl's built-in simulation-based stopping criterion.
Runs `replications` simulations every `period` iterations and stops when the
gap is within the statistical tolerance.

# Fields
- `replications`: Number of simulations per statistical check.
- `period`: Iteration period between checks.

See also: [`Statistical`](@ref), [`Convergence`](@ref)
"""
struct SimulationStopping <: StoppingCriteria
    replications::Integer
    period::Integer
end

"""
    FirstStageStopping <: StoppingCriteria

Stop training when the first-stage cost stabilizes to within `atol` absolute
tolerance over the last `iterations` iterations.

# Fields
- `atol`: Absolute tolerance on the first-stage cost change.
- `iterations`: Window size to check stability.

See also: [`Convergence`](@ref), [`LowerBoundStability`](@ref)
"""
struct FirstStageStopping <: StoppingCriteria
    atol::Real
    iterations::Integer
end

"""
    StoppingChain <: StoppingCriteria

A composite stopping criterion that halts training when **any** of its member
rules triggers. Use this to combine multiple stopping rules with OR logic.

# Fields
- `rules`: Vector of [`StoppingCriteria`](@ref) to evaluate at each iteration.

# Example
```julia
# Stop after 200 iterations OR when lower bound is stable
chain = StoppingChain([IterationLimit(200), LowerBoundStability(1e-4, 10)])
```

See also: [`Convergence`](@ref)
"""
struct StoppingChain <: StoppingCriteria
    rules::Vector{StoppingCriteria}
end

"""
    Convergence

Controls the SDDP training loop termination. Enforces a minimum number of
iterations before any stopping rule is evaluated, and an absolute maximum.

# Fields
- `min_iterations`: Minimum iterations to run before evaluating stopping rules.
- `max_iterations`: Hard maximum; training stops regardless of other criteria.
- `stopping_criteria`: Ordered vector of [`StoppingCriteria`](@ref) to evaluate.

See also: [`SDDPPolicyTaskDefinition`](@ref), [`IterationLimit`](@ref),
[`Statistical`](@ref)
"""
struct Convergence
    min_iterations::Integer
    max_iterations::Integer
    stopping_criteria::Vector{StoppingCriteria}
end

"""
    ParallelScheme

Abstract base type for SDDP parallelism strategies. Subtypes:
[`Serial`](@ref), [`Asynchronous`](@ref), [`Threaded`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type ParallelScheme end

"""
    Serial <: ParallelScheme

Run SDDP forward and backward passes sequentially on a single thread.
This is the default and most compatible parallel scheme.

See also: [`Threaded`](@ref), [`Asynchronous`](@ref)
"""
struct Serial <: ParallelScheme end

"""
    Asynchronous <: ParallelScheme

Run SDDP forward passes asynchronously across distributed Julia workers
(`Distributed.jl`). Requires launching Julia with multiple workers or using
`addprocs`.

See also: [`Serial`](@ref), [`Threaded`](@ref)
"""
struct Asynchronous <: ParallelScheme end

"""
    Threaded <: ParallelScheme

Run SDDP forward passes in parallel using Julia threads. Requires a
thread-safe solver (e.g., HiGHS) and starting Julia with
`julia --threads=N`.

See also: [`Serial`](@ref), [`Asynchronous`](@ref)
"""
struct Threaded <: ParallelScheme end

"""
    RiskMeasure

Abstract base type for SDDP risk measures. Subtypes:
[`Expectation`](@ref), [`WorstCase`](@ref), [`AVaR`](@ref),
[`CVaR`](@ref), [`Entropic`](@ref), [`WassersteinRM`](@ref),
[`ModifiedChiSquared`](@ref), [`ConvexCombination`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type RiskMeasure end

"""
    Expectation <: RiskMeasure

Risk-neutral expectation. Minimizes the expected total cost across all
scenarios. This is the classical SDDP objective.

See also: [`CVaR`](@ref), [`RiskMeasure`](@ref)
"""
struct Expectation <: RiskMeasure end

"""
    WorstCase <: RiskMeasure

Worst-case (minimax) risk measure. Minimizes the maximum cost across all
scenarios.

See also: [`AVaR`](@ref), [`RiskMeasure`](@ref)
"""
struct WorstCase <: RiskMeasure end

"""
    AVaR <: RiskMeasure

Average Value-at-Risk (also known as CVaR or Expected Shortfall) at level
`alpha`. Minimizes the expected cost in the worst `(1 - alpha)` fraction of
scenarios.

# Fields
- `alpha`: Confidence level in `(0, 1)`. Smaller `alpha` = more risk-averse.

See also: [`CVaR`](@ref), [`RiskMeasure`](@ref)
"""
struct AVaR <: RiskMeasure
    alpha::Real
end

"""
    CVaR <: RiskMeasure

Convex combination of [`Expectation`](@ref) and [`AVaR`](@ref):
`lambda * E[cost] + (1 - lambda) * AVaR_alpha[cost]`.

# Fields
- `alpha`: Confidence level for the AVaR component (in `(0, 1)`).
- `lambda`: Weight on the expectation component (in `[0, 1]`).

See also: [`AVaR`](@ref), [`RiskMeasure`](@ref)
"""
struct CVaR <: RiskMeasure
    alpha::Real
    lambda::Real
end

"""
    Entropic <: RiskMeasure

Entropic risk measure with parameter `theta`. Higher `theta` yields more
risk-averse behavior.

# Fields
- `theta`: Risk aversion parameter (positive real number).

See also: [`RiskMeasure`](@ref)
"""
struct Entropic <: RiskMeasure
    theta::Real
end

"""
    WassersteinRM <: RiskMeasure

Wasserstein distance-based distributionally robust risk measure.

# Fields
- `alpha`: Radius of the Wasserstein uncertainty ball.

See also: [`RiskMeasure`](@ref)
"""
struct WassersteinRM <: RiskMeasure
    alpha::Real
end

"""
    ModifiedChiSquared <: RiskMeasure

Modified chi-squared distributionally robust risk measure. Constructs a
confidence set around the empirical distribution.

# Fields
- `radius`: Radius of the chi-squared uncertainty set.
- `minimum_std`: Minimum standard deviation floor to avoid degenerate sets.

See also: [`RiskMeasure`](@ref)
"""
struct ModifiedChiSquared <: RiskMeasure
    radius::Real
    minimum_std::Real
end

"""
    ConvexCombination <: RiskMeasure

Weighted convex combination of multiple [`RiskMeasure`](@ref) instances.
The weights must sum to one.

# Fields
- `measures`: Vector of `(weight, RiskMeasure)` tuples defining the combination.

# Example
```julia
rm = ConvexCombination([(0.7, Expectation()), (0.3, AVaR(0.05))])
```

See also: [`CVaR`](@ref), [`RiskMeasure`](@ref)
"""
struct ConvexCombination <: RiskMeasure
    measures::Vector{Tuple{Real,RiskMeasure}}
end

"""
    SamplingScheme

Abstract base type for SDDP forward-pass sampling strategies. Subtypes:
[`DefaultSampling`](@ref), [`InSampleMC`](@ref), [`PSRSampling`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type SamplingScheme end

"""
    DefaultSampling <: SamplingScheme

Use SDDP.jl's default in-sample Monte Carlo sampling strategy.

See also: [`InSampleMC`](@ref), [`PSRSampling`](@ref)
"""
struct DefaultSampling <: SamplingScheme end

"""
    InSampleMC <: SamplingScheme

In-sample Monte Carlo sampling with configurable depth and leaf termination.

# Fields
- `max_depth`: Maximum depth (number of stages) per forward pass sample.
- `terminate_on_dummy_leaf`: Whether to stop sampling at dummy leaf nodes.

See also: [`DefaultSampling`](@ref), [`PSRSampling`](@ref)
"""
struct InSampleMC <: SamplingScheme
    max_depth::Integer
    terminate_on_dummy_leaf::Bool
end

"""
    PSRSampling <: SamplingScheme

PSR-style sampling that draws a fixed number of independent forward trajectories.

# Fields
- `num_samples`: Number of forward-pass sample trajectories per iteration.

See also: [`DefaultSampling`](@ref), [`InSampleMC`](@ref)
"""
struct PSRSampling <: SamplingScheme
    num_samples::Integer
end

"""
    DualityHandler

Abstract base type for SDDP duality handlers. These determine how dual variables
(cut coefficients) are computed at each iteration. Subtypes:
[`DefaultDuality`](@ref), [`ContinuousConicDualityHandler`](@ref),
[`StrengthenedConicDualityHandler`](@ref), [`LagrangianDualityHandler`](@ref),
[`BanditDualityHandler`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type DualityHandler end

"""
    DefaultDuality <: DualityHandler

Use SDDP.jl's default LP duality for cut generation.

See also: [`LagrangianDualityHandler`](@ref), [`DualityHandler`](@ref)
"""
struct DefaultDuality <: DualityHandler end

"""
    ContinuousConicDualityHandler <: DualityHandler

Use continuous conic duality for problems with conic constraints.

See also: [`StrengthenedConicDualityHandler`](@ref), [`DualityHandler`](@ref)
"""
struct ContinuousConicDualityHandler <: DualityHandler end

"""
    StrengthenedConicDualityHandler <: DualityHandler

Use strengthened conic duality (tighter cuts than continuous conic).

See also: [`ContinuousConicDualityHandler`](@ref), [`DualityHandler`](@ref)
"""
struct StrengthenedConicDualityHandler <: DualityHandler end

"""
    LagrangianDualityHandler <: DualityHandler

Use Lagrangian relaxation to compute dual variables. Suitable for problems
where LP duality is unavailable (e.g., integer subproblems).

See also: [`DefaultDuality`](@ref), [`DualityHandler`](@ref)
"""
struct LagrangianDualityHandler <: DualityHandler end

"""
    BanditDualityHandler <: DualityHandler

A multi-armed bandit duality handler that dynamically selects among multiple
duality handlers based on observed cut quality.

# Fields
- `handlers`: Vector of candidate [`DualityHandler`](@ref) instances.

See also: [`DualityHandler`](@ref)
"""
struct BanditDualityHandler <: DualityHandler
    handlers::Vector{DualityHandler}
end

"""
    ForwardPassStrategy

Abstract base type for SDDP forward-pass strategies. Subtypes:
[`DefaultForwardPassStrategy`](@ref), [`RevisitingForwardPassStrategy`](@ref),
[`RiskAdjustedForwardPassStrategy`](@ref),
[`RegularizedForwardPassStrategy`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type ForwardPassStrategy end

"""
    DefaultForwardPassStrategy <: ForwardPassStrategy

Use SDDP.jl's default forward-pass strategy.

See also: [`RevisitingForwardPassStrategy`](@ref), [`ForwardPassStrategy`](@ref)
"""
struct DefaultForwardPassStrategy <: ForwardPassStrategy end

"""
    RevisitingForwardPassStrategy <: ForwardPassStrategy

Revisit previously explored forward-pass trajectories periodically.

# Fields
- `period`: How often (in iterations) to revisit past trajectories.

See also: [`DefaultForwardPassStrategy`](@ref), [`ForwardPassStrategy`](@ref)
"""
struct RevisitingForwardPassStrategy <: ForwardPassStrategy
    period::Integer
end

"""
    RiskAdjustedForwardPassStrategy <: ForwardPassStrategy

Use risk-adjusted forward passes that sample scenarios more aggressively in
the tail of the cost distribution.

See also: [`DefaultForwardPassStrategy`](@ref), [`ForwardPassStrategy`](@ref)
"""
struct RiskAdjustedForwardPassStrategy <: ForwardPassStrategy end

"""
    RegularizedForwardPassStrategy <: ForwardPassStrategy

Regularized forward-pass that adds an L2 penalty to stabilize the cut planes.

# Fields
- `rho`: Regularization parameter (positive real). Larger values = more
  regularization.

See also: [`DefaultForwardPassStrategy`](@ref), [`ForwardPassStrategy`](@ref)
"""
struct RegularizedForwardPassStrategy <: ForwardPassStrategy
    rho::Real
end

"""
    CutType

Abstract base type for SDDP cut generation strategies. Subtypes:
[`SingleCut`](@ref), [`MultiCut`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type CutType end

"""
    SingleCut <: CutType

Generate a single Benders cut per backward pass (classical SDDP).

See also: [`MultiCut`](@ref), [`CutType`](@ref)
"""
struct SingleCut <: CutType end

"""
    MultiCut <: CutType

Generate one cut per realization in the backward pass (multi-cut SDDP).
Produces more cuts per iteration at higher memory cost.

See also: [`SingleCut`](@ref), [`CutType`](@ref)
"""
struct MultiCut <: CutType end

"""
    ScalingMode

Abstract base type for variable scaling strategies applied during model
construction. Subtypes: [`NoScaling`](@ref), [`AutoScaling`](@ref).

See also: [`SDDPPolicyTaskDefinition`](@ref)
"""
abstract type ScalingMode end

"""
    NoScaling <: ScalingMode

Disable variable scaling. All decision variables retain their original units.

See also: [`AutoScaling`](@ref), [`ScalingMode`](@ref)
"""
struct NoScaling <: ScalingMode end

"""
    AutoScaling <: ScalingMode

Automatically scale decision variables to improve LP conditioning. Scaling
factors are computed from system parameter ranges and stored in a
[`ScalingConfig`](@ref).

See also: [`NoScaling`](@ref), [`ScalingMode`](@ref)
"""
struct AutoScaling <: ScalingMode end

"""
    TrainingLogConfig

Configuration for capturing and writing the SDDP training log.

# Fields
- `log_file`: Path to the log file (relative to the output directory).
- `log_frequency`: Number of iterations between log entries.
- `log_every_iteration`: When `true`, log every iteration regardless of
  `log_frequency`.
- `print_level`: Verbosity level for console output (0 = silent, higher = more).

See also: [`TrainingLog`](@ref), [`SDDPPolicyTaskDefinition`](@ref)
"""
struct TrainingLogConfig
    log_file::String
    log_frequency::Int
    log_every_iteration::Bool
    print_level::Int
end

"""
    TrainingLogEntry

A single row in the SDDP training log capturing convergence metrics at one
iteration.

# Fields
- `iteration`: SDDP iteration number.
- `bound`: Current lower bound (expected future cost estimate).
- `simulation_value`: Simulated cost from the forward pass.
- `time`: Cumulative wall-clock time in seconds.
- `total_solves`: Cumulative number of LP subproblem solves.
- `serious_numerical_issue`: `true` if a numerical issue was detected this
  iteration.

See also: [`TrainingLog`](@ref), [`TrainingLogConfig`](@ref)
"""
struct TrainingLogEntry
    iteration::Int
    bound::Float64
    simulation_value::Float64
    time::Float64
    total_solves::Int
    serious_numerical_issue::Bool
end

"""
    TrainingLog

Complete record of an SDDP training run.

# Fields
- `status`: Terminal status symbol (e.g., `:iteration_limit`, `:time_limit`,
  `:statistical`).
- `iterations`: Vector of [`TrainingLogEntry`](@ref), one per logged iteration.

See also: [`TrainingLogEntry`](@ref), [`TrainingLogConfig`](@ref)
"""
struct TrainingLog
    status::Symbol
    iterations::Vector{TrainingLogEntry}
end

"""
    SDDPPolicyTaskDefinition <: PolicyTaskDefinition

Complete specification for the SDDP policy training phase. All algorithmic
choices (convergence, risk measure, parallelism, duality, etc.) are bundled
into this struct and passed to SDDP.jl's `train` function.

# Fields
- `convergence`: [`Convergence`](@ref) — stopping criteria and iteration limits.
- `risk_measure`: [`RiskMeasure`](@ref) — objective risk functional.
- `parallel_scheme`: [`ParallelScheme`](@ref) — forward-pass parallelism.
- `sampling_scheme`: [`SamplingScheme`](@ref) — scenario sampling method.
- `duality_handler`: [`DualityHandler`](@ref) — cut-coefficient computation.
- `forward_pass`: [`ForwardPassStrategy`](@ref) — forward-pass behavior.
- `cut_type`: [`CutType`](@ref) — single or multi-cut generation.
- `scaling`: [`ScalingMode`](@ref) — variable scaling.
- `logging`: [`TrainingLogConfig`](@ref) — log capture and verbosity settings.

See also: [`SDDPEngine`](@ref), [`Convergence`](@ref)
"""
struct SDDPPolicyTaskDefinition <: PolicyTaskDefinition
    convergence::Convergence
    risk_measure::RiskMeasure
    parallel_scheme::ParallelScheme
    sampling_scheme::SamplingScheme
    duality_handler::DualityHandler
    forward_pass::ForwardPassStrategy
    cut_type::CutType
    scaling::ScalingMode
    logging::TrainingLogConfig
end

"""
    SDDPPolicyTaskArtifact <: PolicyTaskArtifact

Artifact returned by [`train`](@ref). Contains the trained policy and an
optional training log.

# Fields
- `policy`: The trained `SDDP.PolicyGraph`.
- `training_log`: [`TrainingLog`](@ref) captured during training, or `nothing`
  when logging is disabled.

See also: [`TrainingLog`](@ref), [`save_policy`](@ref)
"""
struct SDDPPolicyTaskArtifact <: PolicyTaskArtifact
    policy::SDDP.PolicyGraph
    training_log::Union{TrainingLog,Nothing}
end

"""
    SDDPSimulationTaskDefinition <: SimulationTaskDefinition

Specification for the SDDP simulation phase.

# Fields
- `num_simulated_series`: Number of independent Monte Carlo trajectories.
- `parallel_scheme`: [`ParallelScheme`](@ref) for parallel simulation.
- `sampling_scheme`: [`SamplingScheme`](@ref) for scenario sampling.

See also: [`SDDPEngine`](@ref)
"""
struct SDDPSimulationTaskDefinition <: SimulationTaskDefinition
    num_simulated_series::Integer
    parallel_scheme::ParallelScheme
    sampling_scheme::SamplingScheme
end

"""
    SDDPSimulationTaskArtifact <: SimulationTaskArtifact

Artifact returned by `simulate`. Contains the full simulation
trajectory data.

# Fields
- `definition`: The [`SDDPSimulationTaskDefinition`](@ref) used.
- `simulations`: Nested vector of simulation results (series × stages × vars).
- `scaling`: The [`ScalingConfig`](@ref) needed to un-scale variable values.

See also: [`SDDPSimulationTaskDefinition`](@ref), [`ScalingConfig`](@ref)
"""
struct SDDPSimulationTaskArtifact <: SimulationTaskArtifact
    definition::SDDPSimulationTaskDefinition
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    scaling::ScalingConfig
end

"""
    DiagnosticsConfig

Configuration for pre-solve numerical diagnostics.

# Fields
- `run_numerical_report`: When `true`, run SDDP.jl's numerical diagnostics
  before training begins.
- `warn_threshold`: Warn when any numerical metric exceeds this value.
- `halt_threshold`: Abort training when any metric exceeds this value.

See also: [`SDDPEngine`](@ref)
"""
struct DiagnosticsConfig
    run_numerical_report::Bool
    warn_threshold::Float64
    halt_threshold::Float64
end

"""
    SolverConfig

Configuration for the LP/MIP solver used in each SDDP subproblem.

# Fields
- `solver_name`: Name of the solver package (e.g., `"HiGHS"`, `"GLPK"`).
- `attributes`: Dict of solver-specific attribute key-value pairs passed via
  `set_optimizer_attribute`.

# Example
```julia
# HiGHS with a 60-second time limit
SolverConfig("HiGHS", Dict("time_limit" => 60.0))
```

See also: [`SDDPEngine`](@ref)
"""
struct SolverConfig
    solver_name::String
    attributes::Dict{String,Any}
end

"""
    InflowNonNegativity

Abstract base type for inflow non-negativity enforcement strategies.
AR/VAR processes can produce negative inflow samples; these strategies handle
that case. Subtypes: [`InflowNone`](@ref), [`InflowPenalty`](@ref),
[`InflowTruncation`](@ref), [`InflowTruncationWithPenalty`](@ref).

See also: [`SDDPEngine`](@ref)
"""
abstract type InflowNonNegativity end

"""
    InflowNone <: InflowNonNegativity

No enforcement: negative inflow realizations are passed to the model as-is.
Only appropriate when the stochastic process is guaranteed non-negative (e.g.,
log-normal distributions).

See also: [`InflowPenalty`](@ref), [`InflowTruncation`](@ref)
"""
struct InflowNone <: InflowNonNegativity end

"""
    InflowPenalty <: InflowNonNegativity

Add a slack variable with a penalty cost to absorb negative inflow realizations.
Keeps the model feasible without modifying scenario data.

# Fields
- `penalty_cost`: Cost per unit of inflow slack (currency/m³). Should be large
  enough to discourage use in normal conditions.

See also: [`InflowTruncation`](@ref), [`InflowNonNegativity`](@ref)
"""
struct InflowPenalty <: InflowNonNegativity
    penalty_cost::Float64
end

"""
    InflowTruncation <: InflowNonNegativity

Truncate negative inflow realizations to zero before adding them to the
stochastic problem. Modifies the SAA sample directly.

See also: [`InflowPenalty`](@ref), [`InflowTruncationWithPenalty`](@ref)
"""
struct InflowTruncation <: InflowNonNegativity end

"""
    InflowTruncationWithPenalty <: InflowNonNegativity

Truncate negative inflow realizations to zero AND add an inflow slack variable
with a penalty cost for any remaining infeasibility.

# Fields
- `penalty_cost`: Cost per unit of inflow slack (currency/m³).

See also: [`InflowTruncation`](@ref), [`InflowPenalty`](@ref)
"""
struct InflowTruncationWithPenalty <: InflowNonNegativity
    penalty_cost::Float64
end

"""
    OutOfSampleValidation

Configuration for out-of-sample policy validation using a fresh set of
inflow scenarios.

# Fields
- `num_simulations`: Number of out-of-sample trajectories to simulate.
- `seed`: Random seed for generating the validation SAA (must differ from the
  training seed to ensure independence).
- `branchings`: Number of scenario branchings per stage in the validation tree.
- `parallel_scheme`: [`ParallelScheme`](@ref) for parallel validation.

See also: [`SDDPEngine`](@ref), [`ParallelScheme`](@ref)
"""
struct OutOfSampleValidation
    num_simulations::Integer
    seed::Integer
    branchings::Integer
    parallel_scheme::ParallelScheme
end

"""
    SDDPValidationTaskArtifact

Artifact produced by `validate`. Contains out-of-sample simulation
results and pre-computed summary statistics.

# Fields
- `simulations`: Nested vector of simulation results (series × stages × vars).
- `scaling`: The [`ScalingConfig`](@ref) for un-scaling variable values.
- `statistics`: Dict of summary statistics (mean, std, quantiles, CI bounds).
"""
struct SDDPValidationTaskArtifact
    simulations::Vector{Vector{Dict{Symbol,Any}}}
    scaling::ScalingConfig
    statistics::Dict{String,Float64}
end

"""
    DebugConfig

Configuration for writing subproblem model files and optionally solving the
deterministic equivalent for debugging.

# Fields
- `write_subproblems`: When `true`, write each subproblem to a file.
- `subproblem_nodes`: List of node IDs to write (empty = all nodes).
- `subproblem_format`: File format: `"mof"` (default), `"lp"`, or `"mps"`.
- `deterministic_equivalent`: When `true`, solve the full deterministic
  equivalent problem.
- `det_equiv_time_limit`: Time limit in seconds for the deterministic
  equivalent solve.

See also: [`SDDPEngine`](@ref)
"""
struct DebugConfig
    write_subproblems::Bool
    subproblem_nodes::Vector{Any}
    subproblem_format::String
    deterministic_equivalent::Bool
    det_equiv_time_limit::Float64
end

"""
    SDDPEngine <: Engine

Complete configuration for the SDDP algorithm engine. This is the concrete
[`Engine`](@ref) type built from the `engine` section of `main.jsonc`.

# Fields
- `policy`: [`SDDPPolicyTaskDefinition`](@ref) — training algorithm settings.
- `simulation`: [`SDDPSimulationTaskDefinition`](@ref) — simulation settings.
- `diagnostics`: [`DiagnosticsConfig`](@ref) — numerical report settings.
- `solver`: [`SolverConfig`](@ref) — LP solver and attributes.
- `inflow_non_negativity`: [`InflowNonNegativity`](@ref) — negative inflow
  handling strategy.
- `validation`: [`OutOfSampleValidation`](@ref) or `nothing` — optional
  out-of-sample validation settings.
- `debug`: [`DebugConfig`](@ref) — subproblem file export and det-equiv settings.

# Example
```julia
study = read_study("/path/to/my_study")
engine = study.engine  # SDDPEngine
```

See also: [`SDDPPolicyTaskDefinition`](@ref), [`SDDPSimulationTaskDefinition`](@ref)
"""
struct SDDPEngine <: Engine
    policy::SDDPPolicyTaskDefinition
    simulation::SDDPSimulationTaskDefinition
    diagnostics::DiagnosticsConfig
    solver::SolverConfig
    inflow_non_negativity::InflowNonNegativity
    validation::Union{OutOfSampleValidation,Nothing}
    debug::DebugConfig
end

"""
    get_policy_definition(e) -> PolicyTaskDefinition

Return the [`PolicyTaskDefinition`](@ref) from an [`Engine`](@ref).
For [`SDDPEngine`](@ref) this returns the [`SDDPPolicyTaskDefinition`](@ref).

# Arguments
- `e`: Any concrete [`Engine`](@ref).

See also: [`get_simulation_definition`](@ref)
"""
function get_policy_definition(e::Engine)::PolicyTaskDefinition end

"""
    get_simulation_definition(e) -> SimulationTaskDefinition

Return the [`SimulationTaskDefinition`](@ref) from an [`Engine`](@ref).
For [`SDDPEngine`](@ref) this returns the [`SDDPSimulationTaskDefinition`](@ref).

# Arguments
- `e`: Any concrete [`Engine`](@ref).

See also: [`get_policy_definition`](@ref)
"""
function get_simulation_definition(e::Engine)::SimulationTaskDefinition end

include("sddp.jl")
include("input.jl")
include("input-validators.jl")

export SDDPEngine,
    SDDPPolicyTaskDefinition,
    SDDPSimulationTaskDefinition,
    DiagnosticsConfig,
    SolverConfig,
    TrainingLogConfig,
    TrainingLogEntry,
    TrainingLog,
    InflowNonNegativity,
    InflowNone,
    InflowPenalty,
    InflowTruncation,
    InflowTruncationWithPenalty,
    OutOfSampleValidation,
    SDDPValidationTaskArtifact,
    DebugConfig,
    __build_engine!,
    build,
    train,
    save_policy,
    load_policy,
    simulate,
    save_simulation,
    validate,
    save_validation,
    debug,
    get_policy_definition,
    get_simulation_definition,
    get_validation_definition,
    create_optimizer,
    ScalingMode,
    ScalingConfig,
    NoScaling,
    AutoScaling,
    StoppingCriteria,
    IterationLimit,
    TimeLimit,
    LowerBoundStability,
    Statistical,
    SimulationStopping,
    FirstStageStopping,
    StoppingChain,
    Convergence,
    ParallelScheme,
    Serial,
    Asynchronous,
    Threaded,
    RiskMeasure,
    Expectation,
    WorstCase,
    AVaR,
    CVaR,
    Entropic,
    WassersteinRM,
    ModifiedChiSquared,
    ConvexCombination,
    SamplingScheme,
    DefaultSampling,
    InSampleMC,
    PSRSampling,
    DualityHandler,
    DefaultDuality,
    ContinuousConicDualityHandler,
    StrengthenedConicDualityHandler,
    LagrangianDualityHandler,
    BanditDualityHandler,
    ForwardPassStrategy,
    DefaultForwardPassStrategy,
    RevisitingForwardPassStrategy,
    RiskAdjustedForwardPassStrategy,
    RegularizedForwardPassStrategy,
    CutType,
    SingleCut,
    MultiCut,
    compute_gap_trajectory,
    compute_convergence_rate,
    detect_bound_stationarity,
    generate_convergence_report

end