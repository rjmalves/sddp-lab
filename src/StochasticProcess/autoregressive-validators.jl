
# AR PARAMETERS VALIDATORS -----------------------------------------------------------------

function __validate_ar_parameters_keys_types!(d, e)
    keys = ["season", "coefficients", "residual_variance", "scale_parameters"]
    types = [Int, Vector{Float64}, Float64, Vector{Float64}]
    
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_types
end

function __validate_ar_parameters_season(d, e)
    season = d["season"]
    valid = season > 0
    if !valid
        push!(e, AssertionError("AutoRegressive model must have positive season value"))
    end
    return valid
end

function __validate_ar_parameters_residual_variance(d, e)
    res_var = d["residual_variance"]
    valid = res_var > 0
    if !valid
        push!(e, AssertionError("AutoRegressive model must have positive residual variance value"))
    end
    return valid
end

function __validate_ar_parameters_coefficients(d, e)
    # eventualmente pode ser interessante testar estacionariedade, mas por enquanto
    # fica so um dummy valid
    return true
end

function __validate_ar_parameters_keys_content(d, e)
    valid = __validate_ar_parameters_season(d, e) &
        __validate_ar_parameters_residual_variance(d, e) &
        __validate_ar_parameters_coefficients(d, e)
    
    return valid
end

function __validate_ar_parameters_dict!(d, e)
    valid = __validate_ar_parameters_keys_types!(d, e) &&
        __validate_ar_parameters_keys_content(d, e)

    return valid
end

# UNIVARIATE AR VALIDATORS -----------------------------------------------------------------

function __validate_univariateautoregressive_keys_types!(d, e)
    keys = ["id", "initial_values", "models"]
    types = [Int, Vector{Float64}, Vector{Dict{String,Any}}]
    
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_types
end

function __validate_univariateautoregressive_season(d, e)
    id = d["id"]
    valid = id > 0
    if !valid
        push!(e, AssertionError("AutoRegressive model must have positive id value"))
    end
    return valid
end

function __validate_univariateautoregressive_dict!(d, e)
    valid =  __validate_univariateautoregressive_keys_types!(d, e) &&
        __validate_univariateautoregressive_season(d, e)
    
    return valid
end