# SCHEMA-BASED VALIDATION -----------------------------------------------------------------

"""
    FieldConstraint(name::String, predicate::Function)

A named predicate that validates a field value after type conversion.

# Fields

  - `name::String`: Human-readable description used in error messages (e.g., "positive", "in [0, 1]").
  - `predicate::Function`: A function `(value) -> Bool` that returns `true` when the value is valid.
"""
struct FieldConstraint
    name::String
    predicate::Function
end

"""
    FieldRule(key::String, type::DataType, required::Bool, constraints::Vector{FieldConstraint})

Declares the expected key name, type, optionality, and constraints for a single dictionary field.

# Fields

  - `key::String`: The dictionary key name.
  - `type::DataType`: The expected Julia type (conversion is attempted via `__parse_as_type!`).
  - `required::Bool`: Whether the key must be present in the dictionary.
  - `constraints::Vector{FieldConstraint}`: Predicates evaluated after successful type conversion.
"""
struct FieldRule
    key::String
    type::DataType
    required::Bool
    constraints::Vector{FieldConstraint}
end

"""
    FieldRule(key::String, type::DataType; required::Bool = true, constraints = FieldConstraint[])

Convenience constructor for `FieldRule` with keyword arguments for `required` and `constraints`.

# Examples

```julia
rule = FieldRule("alpha", Float64; required = true, constraints = [in_range(0, 1)])
```
"""
function FieldRule(
    key::String, type::DataType; required::Bool = true, constraints = FieldConstraint[]
)
    return FieldRule(
        key,
        type,
        required,
        if constraints isa Vector{FieldConstraint}
            constraints
        else
            Vector{FieldConstraint}(constraints)
        end,
    )
end

# PREDICATE FACTORIES ---------------------------------------------------------------------

"""
    positive()

Returns a `FieldConstraint` that checks `v > 0`.

# Examples

```julia
c = positive()
c.predicate(1)   # true
c.predicate(0)   # false
c.predicate(-1)  # false
```
"""
positive() = FieldConstraint("positive", v -> v > 0)

"""
    non_negative()

Returns a `FieldConstraint` that checks `v >= 0`.

# Examples

```julia
c = non_negative()
c.predicate(0)   # true
c.predicate(1)   # true
c.predicate(-1)  # false
```
"""
non_negative() = FieldConstraint("non-negative", v -> v >= 0)

"""
    in_range(lo, hi)

Returns a `FieldConstraint` that checks `lo <= v <= hi`.

# Examples

```julia
c = in_range(0, 1)
c.predicate(0.5)  # true
c.predicate(0)    # true
c.predicate(1.1)  # false
```
"""
in_range(lo, hi) = FieldConstraint("in [$lo, $hi]", v -> lo <= v <= hi)

"""
    in_range_exclusive(lo, hi)

Returns a `FieldConstraint` that checks `lo < v < hi`.

# Examples

```julia
c = in_range_exclusive(0, 1)
c.predicate(0.5)  # true
c.predicate(0)    # false
c.predicate(1)    # false
```
"""
in_range_exclusive(lo, hi) = FieldConstraint("in ($lo, $hi)", v -> lo < v < hi)

"""
    greater_than(n)

Returns a `FieldConstraint` that checks `v > n`.

# Examples

```julia
c = greater_than(5)
c.predicate(6)  # true
c.predicate(5)  # false
```
"""
greater_than(n) = FieldConstraint("greater than $n", v -> v > n)

"""
    less_than(n)

Returns a `FieldConstraint` that checks `v < n`.

# Examples

```julia
c = less_than(5)
c.predicate(4)  # true
c.predicate(5)  # false
```
"""
less_than(n) = FieldConstraint("less than $n", v -> v < n)

"""
    non_empty()

Returns a `FieldConstraint` that checks `length(v) > 0`.

# Examples

```julia
c = non_empty()
c.predicate("abc")  # true
c.predicate("")     # false
```
"""
non_empty() = FieldConstraint("non-empty", v -> length(v) > 0)

"""
    matches(regex::Regex)

Returns a `FieldConstraint` that checks the value fully matches the given regex.

# Examples

```julia
c = matches(r"^[a-z]+\$")
c.predicate("abc")  # true
c.predicate("ABC")  # false
c.predicate("")     # false
```
"""
function matches(regex::Regex)
    return FieldConstraint(
        "matching $(regex.pattern)", v -> begin
            m = match(regex, v)
            return m !== nothing && m.match == v
        end
    )
end

"""
    unique_in(key::String)

Returns a placeholder `FieldConstraint` marking that values in a collection must be unique
for the given key. Actual uniqueness enforcement is performed at the collection level, not
during per-element schema validation. This constraint always returns `true` at the field level.

# Examples

```julia
schema = [FieldRule("id", Integer; constraints = [positive(), unique_in("id")])]
```
"""
unique_in(key::String) = FieldConstraint("unique in $key", _ -> true)

# SCHEMA VALIDATION -----------------------------------------------------------------------

"""
    validate_schema!(d::Dict{String,Any}, schema::Vector{FieldRule}, e::CompositeException; entity_label::String = "")::Bool

Validate a dictionary against a schema of `FieldRule` declarations. For each rule:

 1. **Required check**: if the key is required but missing, pushes an `ErrorException`.
 2. **Type conversion**: attempts `__parse_as_type!(d, key, type)`; on failure pushes the returned exception.
 3. **Constraints**: evaluates each `FieldConstraint` predicate; on failure pushes an `AssertionError`.

Per-field validation short-circuits (missing key skips type check, failed type check skips
constraints), but validation does NOT short-circuit across fields — all rules are always checked.

Returns `true` only if every rule passes all checks.

# Examples

```julia
schema = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule("name", String; constraints = [non_empty()]),
    FieldRule("alpha", Float64; required = false, constraints = [in_range(0, 1)]),
]
d = Dict{String,Any}("id" => 1, "name" => "bus1")
e = CompositeException()
validate_schema!(d, schema, e)  # true
```
"""
function validate_schema!(
    d::Dict{String,Any},
    schema::Vector{FieldRule},
    e::CompositeException;
    entity_label::String = "",
)::Bool
    all_valid = true
    label_prefix = entity_label == "" ? "" : "$entity_label - "

    for rule in schema
        # 1. Check key existence
        has_key = haskey(d, rule.key)
        if !has_key
            if rule.required
                push!(e, ErrorException("Key '$(rule.key)' not found in dictionary"))
                all_valid = false
            end
            continue
        end

        # 2. Attempt type conversion
        parse_result = __parse_as_type!(d, rule.key, rule.type)
        if parse_result isa Exception
            push!(e, parse_result)
            all_valid = false
            continue
        end

        # 3. Evaluate constraints
        value = d[rule.key]
        for constraint in rule.constraints
            if !constraint.predicate(value)
                push!(
                    e,
                    AssertionError(
                        "$(label_prefix)$(rule.key) ($value) must be $(constraint.name)"
                    ),
                )
                all_valid = false
            end
        end
    end

    return all_valid
end

"""
    validate_schema_keys_types!(d::Dict{String,Any}, schema::Vector{FieldRule}, e::CompositeException; entity_label::String = "")::Bool

Validate only key existence and type conversion for a schema, skipping all constraint evaluation.
This is intended for the "before build" phase where only structural validity matters.

Returns `true` only if every required key is present and all present keys convert successfully.

# Examples

```julia
schema = [
    FieldRule("id", Integer; constraints = [positive()]),
    FieldRule("value", Float64; constraints = [in_range(0, 1)]),
]
d = Dict{String,Any}("id" => -5, "value" => 99.0)
e = CompositeException()
validate_schema_keys_types!(d, schema, e)  # true (constraints not checked)
```
"""
function validate_schema_keys_types!(
    d::Dict{String,Any},
    schema::Vector{FieldRule},
    e::CompositeException;
    entity_label::String = "",
)::Bool
    all_valid = true

    for rule in schema
        # 1. Check key existence
        has_key = haskey(d, rule.key)
        if !has_key
            if rule.required
                push!(e, ErrorException("Key '$(rule.key)' not found in dictionary"))
                all_valid = false
            end
            continue
        end

        # 2. Attempt type conversion
        parse_result = __parse_as_type!(d, rule.key, rule.type)
        if parse_result isa Exception
            push!(e, parse_result)
            all_valid = false
        end
    end

    return all_valid
end
