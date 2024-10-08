# CLASS Serial -----------------------------------------------------------------------

function Serial(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_serial_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_serial_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_serial_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_serial_consistency!(d, e)

    return valid_consistency ? Serial() : nothing
end

# CLASS Asynchronous -----------------------------------------------------------------------

function Asynchronous(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_asynchronous_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_asynchronous_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_asynchronous_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_asynchronous_consistency!(d, e)

    return valid_consistency ? Asynchronous() : nothing
end

# SDDP METHODS --------------------------------------------------------------------------

function generate_parallel_scheme(p::Serial)::SDDP.AbstractParallelScheme
    return SDDP.Serial()
end

function generate_parallel_scheme(p::Asynchronous)::SDDP.AbstractParallelScheme
    return SDDP.Asynchronous()
end

function setup_parallel_scheme(p::Serial) end

function setup_parallel_scheme(p::Asynchronous) end

function clean_parallel_scheme(p::Serial) end

function clean_parallel_scheme(p::Asynchronous) end

# HELPERS -------------------------------------------------------------------------------------

function __build_parallel_scheme!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_parallel_scheme_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "parallel_scheme", e)
end

function __cast_parallel_scheme_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    return true
end
