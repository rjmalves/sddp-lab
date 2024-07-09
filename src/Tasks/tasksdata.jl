
# CLASS TasksData -----------------------------------------------------------------------

function TasksData(d::Dict{String,Any}, e::CompositeException)

    # Build internal objects
    valid_internals = __build_tasksdata_internals_from_dicts!(d, e)

    # Keys and types validation
    valid_keys_types = valid_internals && __validate_tasksdata_keys_types!(d, e)

    # Content validation
    valid_content = valid_keys_types && __validate_tasksdata_content!(d, e)

    # Consistency validation
    valid_consistency = valid_content && __validate_tasksdata_consistency!(d, e)

    return if valid_consistency
        TasksData(d["tasks"])
    else
        nothing
    end
end

function TasksData(filename::String, e::CompositeException)
    d = read_jsonc(filename, e)
    valid_jsonc = d !== nothing

    # Cast data from files into the dictionary
    valid = valid_jsonc && __cast_tasksdata_internals_from_files!(d, e)

    return valid ? TasksData(d, e) : nothing
end

# GENERAL METHODS --------------------------------------------------------------------------

"""
get_tasks(s::Vector{InputModule})::Vector{TaskDefinition}

Return the task definition objects from files.
"""
function get_tasks(f::Vector{InputModule})::Vector{TaskDefinition}
    return get_input_module(f, TasksData).tasks
end
