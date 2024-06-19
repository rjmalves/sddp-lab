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
    policy_graph_d = d["policy_graph"]
    valid_keys = __validate_keys!(policy_graph_d, ["kind", "params"], e)
    valid_types = __validate_key_types!(
        policy_graph_d, ["kind", "params"], [String, Dict{String,Any}], e
    )
    valid = valid_keys && valid_types
    if !valid
        return false
    end

    kind = policy_graph_d["kind"]
    params = policy_graph_d["params"]

    supported_kinds = Dict{String,Type{T} where {T<:PolicyGraph}}(
        "regular" => RegularPolicyGraph
    )
    supported =
        haskey(supported_kinds, kind) ||
        push!(e, AssertionError("Policy graph kind ($kind) not recognized"))

    policy_graph_obj = supported ? supported_kinds[kind](params, e) : nothing
    d["policy_graph"] = policy_graph_obj

    return policy_graph_obj !== nothing
end