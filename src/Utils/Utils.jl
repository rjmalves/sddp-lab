module Utils

using CSV
using JSON
using Parquet: Parquet
using DataFrames
using Dates

include("validation-utils.jl")
include("reading-utils.jl")

export __validate_keys!,
    __validate_key_lengths!,
    __validate_key_types!,
    __validate_kind_params_keys!,
    __validate_file_key!,
    __validate_file!,
    __validate_directory!,
    __parse_as_type!,
    __try_conversion!,
    __try_conversion!,
    __try_conversion!,
    __valid_name_regex_match,
    read_jsonc,
    read_csv,
    read_parquet,
    __kind_factory!,
    __validate_cast_from_jsonc_file!,
    __validate_cast_from_csv_file!,
    __dataframe_to_dict,
    __validate_columns_in_dataframe!,
    __validate_column_types_in_dataframe!,
    __validate_dataframe!,
    __validate_dataframe_content_and_cast!,
    __validate_required_default_values!,
    __get_dataframe_columns_for_default_value_fill,
    __fill_default_values!
end