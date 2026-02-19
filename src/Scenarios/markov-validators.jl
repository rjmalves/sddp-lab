const MARKOV_CHAIN_KEYS = ["transition_matrices"]
const MARKOV_CHAIN_KEY_TYPES = [Vector{Any}]

function __validate_markov_chain_keys_types!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_keys = __validate_keys!(d, MARKOV_CHAIN_KEYS, e)
    valid_types = valid_keys && __validate_key_types!(d, MARKOV_CHAIN_KEYS, MARKOV_CHAIN_KEY_TYPES, e)
    return valid_types
end

function __validate_transition_matrices!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    raw_matrices = d["transition_matrices"]

    if isempty(raw_matrices)
        push!(e, AssertionError("transition_matrices must have at least one matrix"))
        return false
    end

    valid = true
    matrices = Matrix{Float64}[]

    for (i, raw_mat) in enumerate(raw_matrices)
        if !(raw_mat isa Vector)
            push!(e, AssertionError("transition_matrices[$i] must be a matrix (Vector of rows), got $(typeof(raw_mat))"))
            valid = false
            continue
        end

        nrows = length(raw_mat)
        if nrows == 0
            push!(e, AssertionError("transition_matrices[$i] must have at least one row"))
            valid = false
            continue
        end

        row_valid = true
        ncols = nothing
        for (j, row) in enumerate(raw_mat)
            if !(row isa Vector)
                push!(e, AssertionError("transition_matrices[$i] row $j must be a Vector, got $(typeof(row))"))
                row_valid = false
                continue
            end
            if ncols === nothing
                ncols = length(row)
            elseif length(row) != ncols
                push!(e, AssertionError("transition_matrices[$i] row $j has $(length(row)) columns, expected $ncols"))
                row_valid = false
            end
            for (k, val) in enumerate(row)
                if !(val isa Real)
                    push!(e, AssertionError("transition_matrices[$i][$j][$k] must be a Real, got $(typeof(val))"))
                    row_valid = false
                end
            end
        end

        if !row_valid
            valid = false
            continue
        end

        mat = Matrix{Float64}(undef, nrows, ncols)
        for (j, row) in enumerate(raw_mat)
            for (k, val) in enumerate(row)
                mat[j, k] = Float64(val)
            end
        end

        push!(matrices, mat)
    end

    if !valid
        return false
    end

    if size(matrices[1], 1) != 1
        push!(e, AssertionError(
            "First transition matrix must have 1 row (root -> states), got $(size(matrices[1], 1)) rows"
        ))
        valid = false
    end

    for i in 1:(length(matrices) - 1)
        ncols_prev = size(matrices[i], 2)
        nrows_next = size(matrices[i + 1], 1)
        if nrows_next != ncols_prev
            push!(e, AssertionError(
                "transition_matrices[$(i + 1)] has $nrows_next rows but transition_matrices[$i] has $ncols_prev columns (must match)"
            ))
            valid = false
        end
    end

    for i in 2:length(matrices)
        nrows = size(matrices[i], 1)
        ncols = size(matrices[i], 2)
        if nrows != ncols
            push!(e, AssertionError(
                "transition_matrices[$i] must be square ($nrows x $ncols)"
            ))
            valid = false
        end
    end

    for (i, mat) in enumerate(matrices)
        for j in 1:size(mat, 1)
            for k in 1:size(mat, 2)
                if mat[j, k] < 0.0
                    push!(e, AssertionError(
                        "transition_matrices[$i][$j][$k] = $(mat[j, k]) is negative"
                    ))
                    valid = false
                end
            end
            row_sum = sum(mat[j, :])
            if abs(row_sum - 1.0) > 1e-6
                push!(e, AssertionError(
                    "transition_matrices[$i] row $j sums to $row_sum, expected 1.0"
                ))
                valid = false
            end
        end
    end

    if valid
        d["transition_matrices"] = matrices
    end

    return valid
end
