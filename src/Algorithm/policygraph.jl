# CLASS RegularPolicyGraph -----------------------------------------------------------------------

struct RegularPolicyGraph <: PolicyGraph
    discount_rate::Real
end

function RegularPolicyGraph(d::Dict{String,Any}, e::CompositeException)
    valid_keys_types = __validate_regular_policy_graph_keys_types!(d, e)
    valid_content =
        valid_keys_types ? __validate_regular_policy_graph_content!(d, e) : false
    valid = valid_keys_types && valid_content

    return valid ? RegularPolicyGraph(d["discount_rate"]) : nothing
end

# HELPERS -------------------------------------------------------------------------------------

function __build_policy_graph!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_policy_graph_key = __validate_keys!(d, ["policy_graph"], e)
    valid_policy_graph_type =
        valid_policy_graph_key &&
        __validate_key_types!(d, ["policy_graph"], [Dict{String,Any}], e)
    if !valid_policy_graph_type
        return false
    end

    policy_graph_d = d["policy_graph"]
    keys = ["kind", "params"]
    keys_types = [String, Dict{String,Any}]
    valid_keys = __validate_keys!(policy_graph_d, keys, e)
    valid_types = valid_keys && __validate_key_types!(policy_graph_d, keys, keys_types, e)
    if !valid_types
        return false
    end

    kind = policy_graph_d["kind"]
    params = policy_graph_d["params"]

    supported_kinds = Dict{String,Type{T} where {T<:PolicyGraph}}(
        "RegularPolicyGraph" => RegularPolicyGraph
    )
    supported =
        haskey(supported_kinds, kind) ||
        push!(e, AssertionError("Policy graph kind ($kind) not recognized"))

    policy_graph_obj = supported ? supported_kinds[kind](params, e) : nothing
    d["policy_graph"] = policy_graph_obj

    return policy_graph_obj !== nothing
end