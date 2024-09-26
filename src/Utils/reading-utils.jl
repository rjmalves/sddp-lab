using JSON
using CSV

# FILE READERS -------------------------------------------------------------------

function read_jsonc(
    filename::String, e::CompositeException
)::Union{Dict{String,Any},Nothing}
    valid_file = __validate_file!(filename, e)
    if valid_file
        open(filename) do io
            lines = readlines(io)
            lines .= replace.(lines, r"(?<!\\)//.*" => "")
            return JSON.parse(join(lines, "\n"))
        end
    else
        return nothing
    end
end

function read_csv(filename::String, e::CompositeException)::Union{DataFrame,Nothing}
    valid_file = __validate_file!(filename, e)
    return if valid_file
        DataFrame(
            CSV.File(
                filename;
                normalizenames = true,
                stripwhitespace = true,
                missingstring = "-",
                stringtype = String,
            ),
        )
    else
        nothing
    end
end

# HELPERS -------------------------------------------------------------------

function __single_object_factory(
    m::Module, factory_d::Dict{String,Any}, e::CompositeException
)
    valid_key_types = __validate_kind_params_keys!(factory_d, e)
    if !valid_key_types
        return nothing
    end

    kind = factory_d["kind"]
    params = factory_d["params"]

    kind_type = nothing
    try
        kind_type = getfield(m, Symbol(kind))
    catch
        push!(e, AssertionError("Kind ($kind) not recognized"))
    end

    kind_obj = nothing
    if kind_type !== nothing
        kind_obj = kind_type(params, e)
    end

    return kind_obj
end

function __kind_factory!(
    m::Module, d::Dict{String,Any}, key::String, e::CompositeException
)::Bool
    factory_d = d[key]

    valid = true
    if typeof(factory_d) === Vector{Dict{String,Any}}
        result = []
        for f in factory_d
            obj = __single_object_factory(m, f, e)
            valid = valid && obj !== nothing
            if valid
                push!(result, obj)
            end
        end
    else
        result = __single_object_factory(m, factory_d, e)
        valid = result !== nothing
    end

    d[key] = result
    return valid
end

function __validate_cast_from_jsonc_file!(d::Dict{String,Any}, e::CompositeException)::Bool
    internal_d = read_jsonc(d["params"]["file"], e)
    valid_file_data = internal_d !== nothing
    if valid_file_data
        merge!(d["params"], internal_d)
    end
    return valid_file_data
end

function __validate_cast_from_csv_file!(
    d::Dict{String,Any}, key::String, e::CompositeException
)::Bool
    df = read_csv(d["params"]["file"], e)
    valid_df = df !== nothing
    internal_d = valid_df ? __dataframe_to_dict(df) : nothing
    valid_file_data = internal_d !== nothing
    if valid_file_data
        d["params"][key] = internal_d
    end
    return valid_file_data
end

function __get_dataframe_columns_for_default_value_fill(
    df::DataFrame
)::Tuple{Vector{String},Vector{DataType}}
    columns_requiring_default_values = Vector{String}()
    columns_data_types = Vector{DataType}()
    for col in names(df)
        col_type = eltype(df[!, col])
        actual_type = nonmissingtype(col_type)
        if col_type !== actual_type
            push!(columns_requiring_default_values, col)
            real_type = actual_type === Union{} ? Any : actual_type
            push!(columns_data_types, real_type)
        end
    end
    return columns_requiring_default_values, columns_data_types
end

function __fill_default_values!(df::DataFrame, default_values::Dict{String,Any})
    for (col, value) in default_values
        df[!, col] = replace(df[!, col], missing => value)
        disallowmissing!(df, col)
    end
end
