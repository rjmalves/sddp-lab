module Core

include("files.jl")
include("types.jl")
include("variables.jl")

function get_input_module(i::Vector{InputModule}, kind::Type)::InputModule
    index = findfirst(x -> isa(x, kind), i)
    return i[index]
end

export InputModule,
    get_input_module,
    LOAD,
    DEFICIT,
    THERMAL_GENERATION,
    THERMAL_GENERATION_COST,
    STORED_VOLUME,
    HYDRO_GENERATION,
    HYDRO_MIN_GENERATION_SLACK,
    INFLOW,
    TURBINED_FLOW,
    OUTFLOW,
    SPILLAGE,
    ω_INFLOW,
    TOTAL_COST,
    HYDRO_BALANCE,
    LOAD_BALANCE,
    MARGINAL_COST,
    WATER_VALUE,
    STAGE_COST,
    FUTURE_COST,
    DIRECT_EXCHANGE,
    REVERSE_EXCHANGE,
    NET_EXCHANGE,
    POLICY_CUTS_OUTPUT_FILENAME,
    POLICY_CONVERGENCE_OUTPUT_FILENAME

end