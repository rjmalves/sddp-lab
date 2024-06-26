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
