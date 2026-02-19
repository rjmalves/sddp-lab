
function __validate_coefficient_matrix_entry_keys_types!(d::Dict{String,Any}, e::CompositeException)
    keys = ["season", "lag", "matrix"]
    types = [Int, Int, Vector{Any}]

    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_types
end

function __validate_coefficient_matrix_entry_content!(d::Dict{String,Any}, e::CompositeException)
    valid = true

    season = d["season"]
    if season <= 0
        push!(e, AssertionError("VectorAutoRegressive coefficient_matrices entry must have positive season value"))
        valid = false
    end

    lag = d["lag"]
    if lag <= 0
        push!(e, AssertionError("VectorAutoRegressive coefficient_matrices entry must have positive lag value"))
        valid = false
    end

    return valid
end

function __validate_coefficient_matrix_entry!(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_coefficient_matrix_entry_keys_types!(d, e) &&
        __validate_coefficient_matrix_entry_content!(d, e)
    return valid
end

function __validate_coefficient_matrix_dimensions!(
    d::Dict{String,Any}, n_elements::Int, e::CompositeException
)
    matrix_raw = d["matrix"]
    valid = true

    if length(matrix_raw) != n_elements
        push!(
            e,
            AssertionError(
                "VectorAutoRegressive coefficient matrix for season=$(d["season"]), lag=$(d["lag"]) " *
                "has $(length(matrix_raw)) rows but expected $n_elements",
            ),
        )
        return false
    end

    for (i, row) in enumerate(matrix_raw)
        if !(row isa Vector)
            push!(
                e,
                AssertionError(
                    "VectorAutoRegressive coefficient matrix row $i is not a vector",
                ),
            )
            valid = false
            continue
        end
        if length(row) != n_elements
            push!(
                e,
                AssertionError(
                    "VectorAutoRegressive coefficient matrix for season=$(d["season"]), lag=$(d["lag"]) " *
                    "row $i has $(length(row)) columns but expected $n_elements",
                ),
            )
            valid = false
        end
    end

    return valid
end

function __validate_var_marginal_model_keys_types!(d::Dict{String,Any}, e::CompositeException)
    keys = ["id", "initial_values", "models"]
    types = [Int, Vector{Float64}, Vector{Dict{String,Any}}]

    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_types
end

function __validate_var_marginal_model_content!(d::Dict{String,Any}, e::CompositeException)
    id = d["id"]
    valid = id > 0
    if !valid
        push!(e, AssertionError("VectorAutoRegressive marginal_model must have positive id value"))
    end
    return valid
end

function __validate_var_marginal_model!(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_var_marginal_model_keys_types!(d, e) &&
        __validate_var_marginal_model_content!(d, e)
    return valid
end

function __validate_var_season_model_keys_types!(d::Dict{String,Any}, e::CompositeException)
    keys = ["season", "residual_variance", "scale_parameters"]
    types = [Int, Float64, Vector{Float64}]

    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_types
end

function __validate_var_season_model_content!(d::Dict{String,Any}, e::CompositeException)
    valid = true

    season = d["season"]
    if season <= 0
        push!(e, AssertionError("VectorAutoRegressive model must have positive season value"))
        valid = false
    end

    res_var = d["residual_variance"]
    if res_var <= 0
        push!(e, AssertionError("VectorAutoRegressive model must have positive residual variance value"))
        valid = false
    end

    scale = d["scale_parameters"]
    if length(scale) != 2
        push!(e, AssertionError("VectorAutoRegressive scale_parameters must have exactly 2 elements [mean, std]"))
        valid = false
    elseif scale[2] <= 0
        push!(e, AssertionError("VectorAutoRegressive scale_parameters std (second element) must be positive"))
        valid = false
    end

    return valid
end

function __validate_var_season_model!(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_var_season_model_keys_types!(d, e) &&
        __validate_var_season_model_content!(d, e)
    return valid
end

function __validate_vectorautoregressive_keys_types!(d::Dict{String,Any}, e::CompositeException)
    keys = ["marginal_models", "copulas", "coefficient_matrices"]
    types = [Vector{Dict{String,Any}}, Vector{Dict{String,Any}}, Vector{Dict{String,Any}}]

    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, types, e)

    return valid_types
end

function __validate_vectorautoregressive_consistency!(
    d::Dict{String,Any}, e::CompositeException
)
    n_elements = length(d["marginal_models"])

    if n_elements == 0
        push!(e, AssertionError("VectorAutoRegressive must have at least one marginal_model"))
        return false
    end

    all_seasons = Set{Int}()
    for mm in d["marginal_models"]
        if haskey(mm, "models")
            for model in mm["models"]
                if haskey(model, "season")
                    push!(all_seasons, model["season"])
                end
            end
        end
    end

    coef_entries = d["coefficient_matrices"]
    if isempty(coef_entries)
        push!(e, AssertionError("VectorAutoRegressive must have at least one coefficient_matrices entry"))
        return false
    end

    coef_season_lags = Dict{Int,Set{Int}}()
    for entry in coef_entries
        if haskey(entry, "season") && haskey(entry, "lag")
            s = entry["season"]
            l = entry["lag"]
            if !haskey(coef_season_lags, s)
                coef_season_lags[s] = Set{Int}()
            end
            push!(coef_season_lags[s], l)
        end
    end

    valid = true
    coef_seasons = Set(keys(coef_season_lags))
    if !isempty(all_seasons) && coef_seasons != all_seasons
        missing_in_coef = setdiff(all_seasons, coef_seasons)
        extra_in_coef = setdiff(coef_seasons, all_seasons)
        if !isempty(missing_in_coef)
            push!(
                e,
                AssertionError(
                    "VectorAutoRegressive coefficient_matrices missing seasons: $(sort(collect(missing_in_coef)))",
                ),
            )
            valid = false
        end
        if !isempty(extra_in_coef)
            push!(
                e,
                AssertionError(
                    "VectorAutoRegressive coefficient_matrices has extra seasons: $(sort(collect(extra_in_coef)))",
                ),
            )
            valid = false
        end
    end

    for (s, lags) in coef_season_lags
        max_lag = maximum(lags)
        expected_lags = Set(1:max_lag)
        if lags != expected_lags
            push!(
                e,
                AssertionError(
                    "VectorAutoRegressive coefficient_matrices for season=$s has lags $(sort(collect(lags))) but expected 1:$max_lag",
                ),
            )
            valid = false
        end
    end

    max_lags_per_season = [maximum(lags) for (_, lags) in coef_season_lags]
    if length(unique(max_lags_per_season)) > 1
        push!(
            e,
            AssertionError(
                "VectorAutoRegressive coefficient_matrices must have the same max lag for all seasons, got: $max_lags_per_season",
            ),
        )
        valid = false
    end

    if valid && !isempty(max_lags_per_season)
        max_lag = first(max_lags_per_season)
        for mm in d["marginal_models"]
            if haskey(mm, "initial_values")
                if length(mm["initial_values"]) != max_lag
                    push!(
                        e,
                        AssertionError(
                            "VectorAutoRegressive marginal_model id=$(get(mm, "id", "?")) has $(length(mm["initial_values"])) initial_values but max_lag=$max_lag",
                        ),
                    )
                    valid = false
                end
            end
        end
    end

    for entry in coef_entries
        if haskey(entry, "matrix")
            valid = __validate_coefficient_matrix_dimensions!(entry, n_elements, e) && valid
        end
    end

    return valid
end

function __validate_vectorautoregressive_dict!(d::Dict{String,Any}, e::CompositeException)
    valid = __validate_vectorautoregressive_keys_types!(d, e)
    if !valid
        return false
    end

    for mm in d["marginal_models"]
        valid = __validate_var_marginal_model!(mm, e) && valid
        if haskey(mm, "models")
            for model in mm["models"]
                valid = __validate_var_season_model!(model, e) && valid
            end
        end
    end

    for entry in d["coefficient_matrices"]
        valid = __validate_coefficient_matrix_entry!(entry, e) && valid
    end

    valid = valid && __validate_vectorautoregressive_consistency!(d, e)

    return valid
end
