"""
get_reader(f::TaskResultsFormat)

Gets the reader function that will import the Table data
from the filesystem.
"""
function get_reader(f::TaskResultsFormat)::Function end

"""
get_writer(f::TaskResultsFormat)

Gets the writer function that will export the Table data
to the filesystem.
"""
function get_writer(f::TaskResultsFormat)::Function end

"""
get_extension(f::TaskResultsFormat)::String

Gets the file extension to be used when exporting the data.
"""
function get_extension(f::TaskResultsFormat)::String end

# CLASS AnyFormat --------------------------------------------------------------------------------

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

function get_reader(f::AnyFormat)::Function
    no_op(p, df) = nothing
    return no_op
end

function get_writer(f::AnyFormat)::Function
    no_op(p, df) = nothing
    return no_op
end

function get_extension(f::AnyFormat)::String
    return ""
end

# CLASS CSVFormat --------------------------------------------------------------------------------

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

function get_reader(f::CSVFormat)::Function
    return CSV.read
end

function get_writer(f::CSVFormat)::Function
    return CSV.write
end

function get_extension(f::CSVFormat)::String
    return ".csv"
end

# CLASS ParquetFormat --------------------------------------------------------------------------------

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

function get_reader(f::ParquetFormat)::Function
    return read_parquet
end

function get_writer(f::ParquetFormat)::Function
    return Parquet.write_parquet
end

function get_extension(f::ParquetFormat)::String
    return ".parquet"
end

# CLASS TaskResults --------------------------------------------------------------------------------

function TaskResults(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_results_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_results_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_results_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_results_consistency!(d, e)

    return if valid_consistency
        TaskResults(d["path"], d["save"], d["format"])
    else
        nothing
    end
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

function __build_results!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_results_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    results_d = d["results"]

    valid_key_types = __validate_results_keys_types_before_build!(results_d, e)
    if !valid_key_types
        return false
    end

    d["results"] = TaskResults(results_d, e)
    return d["results"] !== nothing
end

function __cast_results_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
