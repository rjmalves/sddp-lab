# CONTENT VALIDATORS -----------------------------------------------------------------------

function __validate_hydro_id(id::Integer, e::CompositeException)
    id > 0 || push!(e, AssertionError("Hydro id ($id) must be positive"))
    return nothing
end

function __validate_hydro_downstream_id(downstream_id::Integer, e::CompositeException)
    downstream_id >= 0 || push!(
        e, AssertionError("Hydro downstream_id ($downstream_id) must be non-negative")
    )
    return nothing
end

function __validate_hydro_name(name::String, e::CompositeException)
    length(name) > 0 ||
        push!(e, AssertionError("Hydro name ($name) must have at least one character"))
    __valid_name_regex_match(name) || push!(
        e,
        AssertionError(
            "Hydro name ($name) must contain only alphanumeric, '_', '-' or ' ' characters",
        ),
    )
    return nothing
end

function __validate_hydro_bus_id(bus_id::Integer, e::CompositeException)
    bus_id > 0 || push!(e, AssertionError("Hydro bus_id ($bus_id) must be positive"))
    return nothing
end

function __validate_hydro_productivity(productivity::Real, e::CompositeException)
    productivity > 0 ||
        push!(e, AssertionError("Hydro productivity ($productivity) must be non-negative"))
    return nothing
end

function __validate_hydro_storage(
    initial_storage::Real, min_storage::Real, max_storage::Real, e::CompositeException
)
    for (storage, var_name) in zip(
        [initial_storage, min_storage, max_storage],
        ["initial_storage", "min_storage", "max_storage"],
    )
        storage >= 0 ||
            push!(e, AssertionError("Hydro $var_name ($storage) must be non-negative"))
    end
    min_storage <= max_storage || push!(
        e,
        AssertionError(
            "Hydro max_storage ($max_storage) must be >= min_storage ($min_storage)"
        ),
    )
    min_storage <= initial_storage <= max_storage || push!(
        e,
        AssertionError(
            "Hydro initial_storage ($initial_storage) not in [$min_storage, $max_storage]",
        ),
    )
    return nothing
end

function __validate_hydro_generation(
    min_generation::Real, max_generation::Real, e::CompositeException
)
    for (generation, var_name) in
        zip([min_generation, max_generation], ["min_generation", "max_generation"])
        generation >= 0 ||
            push!(e, AssertionError("Hydro $var_name ($generation) must be non-negative"))
    end
    min_generation <= max_generation || push!(
        e,
        AssertionError(
            "Hydro max_generation ($max_generation) must be >= min_generation ($min_generation)",
        ),
    )
    return nothing
end

function __validate_hydro_spillage_penalty(spillage_penalty::Real, e::CompositeException)
    spillage_penalty >= 0 || push!(
        e,
        AssertionError("Hydro spillage_penalty ($spillage_penalty) must be non-negative"),
    )
    return nothing
end

# CONSISTENCY VALIDATORS -------------------------------------------------------------------

function __validate_hydros_unique_ids!(hydros::Vector{Hydro}, e::CompositeException)
    ids = [b.id for b in hydros]
    length(unique(ids)) == length(ids) ||
        push!(e, AssertionError("Hydro ids must be unique"))
    return nothing
end

function __validate_hydros_unique_names!(hydros::Vector{Hydro}, e::CompositeException)
    names = [b.name for b in hydros]
    length(unique(names)) == length(names) ||
        push!(e, AssertionError("Hydro names must be unique"))
    return nothing
end