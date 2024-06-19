module Utils

using DataFrames

include("validation-utils.jl")
include("reading-utils.jl")

export 
    __validate_keys!,
    __validate_key_lengths!,
    __validate_key_types!,
    __validate_file!,
    __parse_as_type!,
    __try_conversion!,
    __try_conversion!,
    __try_conversion!,
    __valid_name_regex_match,
    read_jsonc,
    read_csv,
    __dataframe_to_dict

end