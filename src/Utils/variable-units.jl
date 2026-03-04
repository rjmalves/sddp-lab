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
    compute_model_magnitudes(policy_graph::SDDP.PolicyGraph) -> Dict{Symbol, VariableUnitInfo}

Extract variable bounds across all nodes and return magnitude information for each registered
variable. Falls back to hardcoded registry values for variables with no finite bounds.
"""
function compute_model_magnitudes(
    policy_graph::SDDP.PolicyGraph
)::Dict{Symbol,VariableUnitInfo}
    result = Dict{Symbol,VariableUnitInfo}()
    global_bounds = Dict{Symbol,Tuple{Vector{Float64},Vector{Float64}}}()

    for (node_key, node) in policy_graph.nodes
        sp = node.subproblem
        for (sym, info) in VARIABLE_UNITS_REGISTRY
            vars = try
                sp[sym]
            catch
                continue
            end

            lb_values, ub_values = _extract_bounds(vars)
            if !haskey(global_bounds, sym)
                global_bounds[sym] = (Float64[], Float64[])
            end
            append!(global_bounds[sym][1], lb_values)
            append!(global_bounds[sym][2], ub_values)
        end
    end

    for (sym, info) in VARIABLE_UNITS_REGISTRY
        if haskey(global_bounds, sym)
            lbs, ubs = global_bounds[sym]
            finite_lbs = filter(isfinite, lbs)
            finite_ubs = filter(isfinite, ubs)

            if isempty(finite_lbs) && isempty(finite_ubs)
                @warn "Variable $sym has no bounds in any subproblem"
                result[sym] = info  # fallback to hardcoded
            else
                if isempty(finite_ubs)
                    @warn "Variable $sym has no upper bound in any subproblem, using fallback max_magnitude"
                end
                min_mag = isempty(finite_lbs) ? 0.0 : minimum(abs.(finite_lbs))
                max_mag = if isempty(finite_ubs)
                    info.max_magnitude
                else
                    maximum(abs.(finite_ubs))
                end
                max_mag = max(
                    max_mag, isempty(finite_lbs) ? 0.0 : maximum(abs.(finite_lbs))
                )
                result[sym] = VariableUnitInfo(sym, info.unit, min_mag, max_mag)
            end
        end
    end

    return result
end

"""
    get_coefficient_magnitude_report(model; magnitudes) -> DataFrame

Report actual vs. expected magnitude ranges for registered variables. Uses model-derived
values when provided, otherwise defaults to hardcoded registry constants.
"""
function get_coefficient_magnitude_report(
    model::JuMP.Model; magnitudes::Dict{Symbol,VariableUnitInfo} = VARIABLE_UNITS_REGISTRY
)::DataFrame
    variable_col = String[]
    unit_col = String[]
    actual_lb_col = Float64[]
    actual_ub_col = Float64[]
    expected_min_col = Float64[]
    expected_max_col = Float64[]
    ratio_col = Float64[]

    for (sym, info) in magnitudes
        vars = try
            model[sym]
        catch
            continue
        end

        lb_values, ub_values = _extract_bounds(vars)
        actual_lb = isempty(lb_values) ? NaN : minimum(lb_values)
        actual_ub = isempty(ub_values) ? NaN : maximum(ub_values)

        ratio = _compute_magnitude_ratio(actual_lb, actual_ub, info.max_magnitude)

        if ratio > 10.0 || (isfinite(ratio) && ratio < 0.01)
            @warn "Variable $sym magnitude ratio is $ratio (threshold: 0.01 - 10.0)"
        end

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
    for v in _collect_variables(vars)
        push!(lb_values, _safe_lower_bound(v))
        push!(ub_values, _safe_upper_bound(v))
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
