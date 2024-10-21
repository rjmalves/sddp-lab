# CLASS AnyFormat -----------------------------------------------------------------------

function AnyFormat(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_any_format_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_any_format_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_any_format_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_any_format_consistency!(d, e)

    return if valid_consistency
        AnyFormat()
    else
        nothing
    end
end

# CLASS CSVFormat -----------------------------------------------------------------------

function CSVFormat(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_csv_format_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_csv_format_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_csv_format_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_csv_format_consistency!(d, e)

    return if valid_consistency
        CSVFormat()
    else
        nothing
    end
end

# CLASS ParquetFormat -----------------------------------------------------------------------

function ParquetFormat(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_parquet_format_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_parquet_format_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_parquet_format_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_parquet_format_consistency!(d, e)

    return if valid_consistency
        ParquetFormat()
    else
        nothing
    end
end

# SDDP METHODS --------------------------------------------------------------------------

function get_writer(f::AnyFormat)::Function
    no_op(p, df) = nothing
    return no_op
end

function get_extension(f::AnyFormat)::String
    return ""
end

function get_writer(f::CSVFormat)::Function
    return CSV.write
end

function get_extension(f::CSVFormat)::String
    return ".csv"
end

function get_writer(f::ParquetFormat)::Function
    return write_parquet
end

function get_extension(f::ParquetFormat)::String
    return ".parquet"
end

# HELPERS -------------------------------------------------------------------------------------

function __build_results_format!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_task_results_format_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "format", e)
end

function __cast_format_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
