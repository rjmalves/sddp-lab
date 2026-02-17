module Utils

using CSV
using JSON
using Parquet: Parquet
using DataFrames
using Dates
using JuMP: JuMP

using ..Lab

include("validation-utils.jl")
include("schema.jl")
include("units.jl")
include("variable-units.jl")
include("reading-utils.jl")
include("stochasticprocess-utils.jl")

export __validate_keys!,
    __validate_key_lengths!,
    __validate_key_types!,
    __validate_kind_params_keys!,
    __validate_file_key!,
    __validate_file!,
    __validate_directory!,
    __parse_as_type!,
    __try_conversion!,
    read_jsonc,
    read_csv,
    read_parquet,
    __kind_factory!,
    __single_object_factory,
    __validate_cast_from_jsonc_file!,
    __validate_cast_from_csv_file!,
    __dataframe_to_dict,
    __validate_columns_in_dataframe!,
    __validate_column_types_in_dataframe!,
    __validate_dataframe!,
    __validate_dataframe_content_and_cast!,
    __validate_required_default_values!,
    __get_dataframe_columns_for_default_value_fill,
    __fill_default_values!,
    __node2season,
    __lagged_season,
    FieldRule,
    FieldConstraint,
    validate_schema!,
    validate_schema_keys_types!,
    positive,
    non_negative,
    in_range,
    in_range_exclusive,
    greater_than,
    less_than,
    non_empty,
    matches,
    unique_in,
    # Units and variable units registry
    PhysicalUnit,
    MW,
    MWh,
    HM3,
    M3_PER_S,
    DOLLAR_PER_MWH,
    DOLLAR,
    HOURS,
    DIMENSIONLESS,
    UnitConversion,
    UNIT_CONVERSIONS,
    VariableUnitInfo,
    VARIABLE_UNITS_REGISTRY,
    get_variable_unit,
    get_coefficient_magnitude_report
end