module Lab

import MathOptInterface as MOI
using CSV
using Parquet

include("files.jl")
include("types.jl")
include("tasks.jl")
include("variables.jl")
include("io.jl")

function get_input_module(i::Vector{InputModule}, kind::Type)::InputModule
    index = findfirst(x -> isa(x, kind), i)
    index === nothing && error("Required InputModule of type $kind not found in inputs")
    return i[index]
end

export
    # Domain problem variables
    LOAD,
    DEFICIT,
    THERMAL_GENERATION,
    THERMAL_GENERATION_COST,
    NC_GENERATION,
    NC_CURTAILMENT,
    CONTRACT_DISPATCH,
    PUMPED_FLOW,
    PUMP_POWER,
    BLOCK_STORAGE,
    INFLOW_SLACK,
    NOISE_ADJUSTMENT_SLACK,
    STORED_VOLUME,
    HYDRO_GENERATION,
    HYDRO_MIN_GENERATION_SLACK,
    INFLOW,
    TURBINED_FLOW,
    OUTFLOW,
    SPILLAGE,
    ω_INFLOW,
    STCHP,
    TOTAL_COST,
    HYDRO_BALANCE,
    LOAD_BALANCE,
    MARGINAL_COST,
    WATER_VALUE,
    STAGE_COST,
    FUTURE_COST,
    VERTEX_COVERAGE_DISTANCE,
    DIRECT_EXCHANGE,
    REVERSE_EXCHANGE,
    NET_EXCHANGE,
    # Core definitions
    Engine,
    Model,
    PolicyTaskDefinition,
    PolicyTaskArtifact,
    SimulationTaskDefinition,
    SimulationTaskArtifact,
    TaskResultsFormat,
    AnyFormat,
    CSVFormat,
    ParquetFormat,
    get_reader,
    get_writer,
    get_extension,
    InputModule,
    get_input_module,
    # Core tasks
    build,
    train,
    diagnose,
    debug,
    save_policy,
    load_policy,
    simulate,
    save_simulation,
    validate,
    save_validation,
    # Global constants
    POLICY_CUTS_OUTPUT_FILENAME,
    POLICY_CUTS_OUTPUT_INTERCEPT_NAME,
    POLICY_CONVERGENCE_OUTPUT_FILENAME,
    POLICY_TRAINING_LOG_OUTPUT_FILENAME,
    POLICY_CONVERGENCE_ANALYSIS_OUTPUT_FILENAME,
    POLICY_CONVERGENCE_REPORT_OUTPUT_FILENAME

end