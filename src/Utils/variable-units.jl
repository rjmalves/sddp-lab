struct VariableUnitInfo
    variable::Symbol
    unit::PhysicalUnit
    min_magnitude::Float64
    max_magnitude::Float64
end

const VARIABLE_UNITS_REGISTRY = Dict{Symbol,VariableUnitInfo}(
    STORED_VOLUME => VariableUnitInfo(STORED_VOLUME, HM3, 0.0, 100_000.0),
    HYDRO_GENERATION => VariableUnitInfo(HYDRO_GENERATION, MW, 0.0, 10_000.0),
    THERMAL_GENERATION => VariableUnitInfo(THERMAL_GENERATION, MW, 0.0, 10_000.0),
    TURBINED_FLOW => VariableUnitInfo(TURBINED_FLOW, HM3, 0.0, 10_000.0),
    SPILLAGE => VariableUnitInfo(SPILLAGE, HM3, 0.0, 50_000.0),
    INFLOW => VariableUnitInfo(INFLOW, HM3, 0.0, 10_000.0),
    DEFICIT => VariableUnitInfo(DEFICIT, MW, 0.0, 50_000.0),
    LOAD => VariableUnitInfo(LOAD, MW, 0.0, 50_000.0),
    DIRECT_EXCHANGE => VariableUnitInfo(DIRECT_EXCHANGE, MW, 0.0, 10_000.0),
    REVERSE_EXCHANGE => VariableUnitInfo(REVERSE_EXCHANGE, MW, 0.0, 10_000.0),
)

function get_variable_unit(sym::Symbol)::Union{VariableUnitInfo,Nothing}
    return get(VARIABLE_UNITS_REGISTRY, sym, nothing)
end

"""
    get_coefficient_magnitude_report(model) -> DataFrame

Report actual vs. expected magnitude ranges for registered variables in a JuMP model.
"""
function get_coefficient_magnitude_report(model::JuMP.Model)::DataFrame
    variable_col = String[]
    unit_col = String[]
    actual_lb_col = Float64[]
    actual_ub_col = Float64[]
    expected_min_col = Float64[]
    expected_max_col = Float64[]
    ratio_col = Float64[]

    for (sym, info) in VARIABLE_UNITS_REGISTRY
        vars = try
            model[sym]
        catch
            continue
        end

        lb_values, ub_values = _extract_bounds(vars)
        actual_lb = isempty(lb_values) ? NaN : minimum(lb_values)
        actual_ub = isempty(ub_values) ? NaN : maximum(ub_values)

        ratio = _compute_magnitude_ratio(actual_lb, actual_ub, info.max_magnitude)

        push!(variable_col, String(sym))
        push!(unit_col, info.unit.symbol)
        push!(actual_lb_col, actual_lb)
        push!(actual_ub_col, actual_ub)
        push!(expected_min_col, info.min_magnitude)
        push!(expected_max_col, info.max_magnitude)
        push!(ratio_col, ratio)
    end

    return DataFrame(;
        variable = variable_col,
        unit = unit_col,
        actual_lower_bound = actual_lb_col,
        actual_upper_bound = actual_ub_col,
        expected_min_magnitude = expected_min_col,
        expected_max_magnitude = expected_max_col,
        magnitude_ratio = ratio_col,
    )
end

function _extract_bounds(vars)::Tuple{Vector{Float64},Vector{Float64}}
    lb_values = Float64[]
    ub_values = Float64[]

    var_list = _collect_variables(vars)

    for v in var_list
        lb = _safe_lower_bound(v)
        ub = _safe_upper_bound(v)
        push!(lb_values, lb)
        push!(ub_values, ub)
    end

    return lb_values, ub_values
end

function _collect_variables(vars)::Vector{JuMP.VariableRef}
    result = JuMP.VariableRef[]

    if vars isa JuMP.VariableRef
        push!(result, vars)
    elseif vars isa AbstractArray
        for v in vars
            if v isa JuMP.VariableRef
                push!(result, v)
            elseif _is_state_variable(v)
                push!(result, v.out)
            end
        end
    end

    return result
end

function _is_state_variable(v)::Bool
    return hasproperty(v, :in) && hasproperty(v, :out)
end

function _safe_lower_bound(v::JuMP.VariableRef)::Float64
    try
        return JuMP.has_lower_bound(v) ? JuMP.lower_bound(v) : NaN
    catch
        return NaN
    end
end

function _safe_upper_bound(v::JuMP.VariableRef)::Float64
    try
        return JuMP.has_upper_bound(v) ? JuMP.upper_bound(v) : NaN
    catch
        return NaN
    end
end

function _compute_magnitude_ratio(
    actual_lb::Float64, actual_ub::Float64, expected_max::Float64
)::Float64
    if expected_max == 0.0
        return NaN
    end
    actual_magnitude = max(abs(actual_lb), abs(actual_ub))
    if !isfinite(actual_magnitude)
        return NaN
    end
    return actual_magnitude / expected_max
end
