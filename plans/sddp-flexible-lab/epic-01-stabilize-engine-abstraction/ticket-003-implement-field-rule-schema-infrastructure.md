# ticket-003 Implement FieldRule Schema Infrastructure

## Agent Assignment

- **Primary**: `hpc-julia-developer`
- **Reviewer**: None (pure Julia type system and validation infrastructure -- no SDDP algorithm knowledge needed)

## Context

### Background

The current validation pipeline spans 1900+ lines across 15+ files with massive boilerplate. Every entity type (Bus, Line, Hydro, Thermal, DeterministicLoadValue, IterationLimit, TimeLimit, etc.) requires 5-8 hand-written functions: `__validate_*_keys_types!`, `__validate_*_content!`, `__validate_*_consistency!`, `__build_*_internals_from_dicts!`, plus individual field validators like `__validate_bus_id!`, `__validate_bus_name!`, `__validate_bus_deficit_cost!`. Many of these functions are trivial stubs (`return true`), and the mechanical parts (checking key existence, type conversion, positive/non-negative/range constraints) are identical across entities.

After evaluating five architectural options (macro-based code generation, multiple dispatch protocol, field descriptor tables, separated phases, and a hybrid approach), Option E was selected: a hybrid combining declarative schema tables with the existing build order and protocol pattern. This ticket implements the core `FieldRule` and `validate_schema!` infrastructure in `src/Utils/schema.jl`.

### Relation to Epic

This is the first validation simplification ticket in Epic 01 (third overall after the completed merge and graph validator tickets). It creates the foundation that ticket-004 (migrate System entities) and ticket-005 (migrate Engine/Scenarios entities) will use to replace per-entity boilerplate.

### Current State

**`src/Utils/validation-utils.jl`** (197 lines) contains the core helper functions used by all validators:

- `__validate_keys!(d, keys, e)` -- checks all required keys exist in dict
- `__validate_key_types!(d, keys, types, e)` -- attempts type conversion via `__parse_as_type!`
- `__parse_as_type!(d, k, t)` -- tries `convert(t, d[k])` with special cases for String, DateTime, Matrix
- `__try_conversion!(d, k, t)` -- dispatch-based type conversion (String, DateTime, Date, Matrix specializations)
- `__valid_name_regex_match(name)` -- regex match for entity names

**`src/Utils/Utils.jl`** exports these functions and includes both `validation-utils.jl` and `reading-utils.jl`.

**The 4-step constructor pattern** used by every entity:

```julia
function MyStruct(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_THING_internals_from_dicts!(d, e)
    valid_keys_types = valid_internals && __validate_THING_keys_types!(d, e)
    valid_content = valid_keys_types && __validate_THING_content!(d, e)
    valid_consistency = valid_content && __validate_THING_consistency!(d, e)
    return valid_consistency ? MyStruct(d["field1"], d["field2"], ...) : nothing
end
```

The typical `__validate_*_keys_types!` function looks like:

```julia
function __validate_bus_keys_types!(d::Dict{String,Any}, e::CompositeException)::Bool
    keys = ["id", "name", "deficit_cost"]
    keys_types = [Integer, String, Real]
    valid_keys = __validate_keys!(d, keys, e)
    valid_types = valid_keys && __validate_key_types!(d, keys, keys_types, e)
    return valid_types
end
```

The typical simple content validator:

```julia
function __validate_bus_id!(d::Dict{String,Any}, e::CompositeException)::Bool
    id = d["id"]
    valid = id > 0
    valid || push!(e, AssertionError("Bus id ($id) must be positive"))
    return valid
end
```

**Error type convention**: The codebase uses `AssertionError` (note: this is the project's custom spelling, not Julia's `AssertionError`) for content/consistency violations and `ErrorException` for key/type failures.

## Specification

### Requirements

1. **Create `src/Utils/schema.jl`** containing:

   a. **`FieldConstraint` struct**: Represents a single constraint predicate on a field value.

   ```julia
   struct FieldConstraint
       name::String                              # Human-readable name for error messages (e.g., "positive", "in_range(0,1)")
       predicate::Function                       # (value) -> Bool
   end
   ```

   b. **`FieldRule` struct**: Declares a single field's name, expected type, whether it is required, and a vector of constraints.

   ```julia
   struct FieldRule
       key::String                               # Dict key name (e.g., "id", "name")
       type::Type                                # Expected Julia type (e.g., Integer, String, Real)
       required::Bool                            # Whether the key must be present
       constraints::Vector{FieldConstraint}      # Content constraints applied after type conversion
   end
   ```

   c. **Convenience constructors for `FieldRule`**:

   ```julia
   FieldRule(key::String, type::Type; required::Bool=true, constraints::Vector{FieldConstraint}=FieldConstraint[])
   ```

   d. **Predicate factory functions** returning `FieldConstraint`:
   - `positive()` -- value > 0
   - `non_negative()` -- value >= 0
   - `in_range(lo, hi)` -- lo <= value <= hi
   - `in_range_exclusive(lo, hi)` -- lo < value < hi
   - `greater_than(n)` -- value > n
   - `less_than(n)` -- value < n
   - `non_empty()` -- for strings/collections: `length(value) > 0`
   - `matches(regex::Regex)` -- for strings: `match(regex, value) !== nothing && match(regex, value).match == value`
   - `unique_in(key::String)` -- placeholder constraint name (actual uniqueness is checked at collection level, not field level)

   e. **`validate_schema!(d::Dict{String,Any}, schema::Vector{FieldRule}, e::CompositeException; entity_label::String="")::Bool`**:
   - Iterates over each `FieldRule` in the schema
   - For required fields: checks key existence (pushes `ErrorException` if missing)
   - For present fields: attempts type conversion via `__parse_as_type!(d, rule.key, rule.type)` (pushes error if conversion fails)
   - For successfully typed fields: evaluates each constraint predicate, pushing `AssertionError` with a descriptive message including `entity_label` if any constraint fails
   - Returns `true` only if ALL rules pass
   - Short-circuits per-field: if a key is missing or type conversion fails, constraints are not checked for that field
   - Does NOT short-circuit across fields: all fields are checked so multiple errors can be accumulated

   f. **`validate_schema_keys_types!(d::Dict{String,Any}, schema::Vector{FieldRule}, e::CompositeException)::Bool`**:
   - Like `validate_schema!` but only checks key existence and type conversion, skipping constraint evaluation
   - This is needed for the `before_build` phase where the dict contains raw types (e.g., `Dict{String,Any}` instead of built objects)

2. **Update `src/Utils/Utils.jl`** to include `schema.jl` and export the public API: `FieldRule`, `FieldConstraint`, `validate_schema!`, `validate_schema_keys_types!`, and all predicate factory functions.

3. **Do NOT modify any existing validator files** in this ticket. The schema infrastructure is additive. Migration of existing entities to use schemas happens in tickets 004 and 005.

### Inputs/Props

- `d::Dict{String,Any}` -- the dict being validated (same dict that existing validators operate on)
- `schema::Vector{FieldRule}` -- the declarative field rules
- `e::CompositeException` -- error accumulator (same as existing pattern)
- `entity_label::String` -- optional prefix for error messages (e.g., "Bus 1", "Thermal 3")

### Outputs/Behavior

- `validate_schema!` returns `Bool` -- `true` if all rules pass, `false` otherwise
- Side effects: pushes `ErrorException` (for missing keys, type conversion failures) and `AssertionError` (for constraint violations) to `e`
- Dict mutation: `__parse_as_type!` mutates `d` in place during type conversion (same as existing behavior)

### Error Handling

- Missing required key: `push!(e, ErrorException("Key 'field_name' not found in dictionary"))`
- Type conversion failure: `push!(e, ErrorException("Key 'field_name' (value) can't be converted to Type"))` (delegated to existing `__parse_as_type!`)
- Constraint violation: `push!(e, AssertionError("entity_label - field_name (value) must be constraint_description"))` or `push!(e, AssertionError("field_name (value) must be constraint_description"))` if no entity_label

## Acceptance Criteria

- [ ] Given a dict `{"id" => 1, "name" => "bus1", "deficit_cost" => 100.0}` and a Bus schema with `FieldRule("id", Integer; constraints=[positive()])`, `FieldRule("name", String; constraints=[non_empty(), matches(r"^[\sa-zA-Z0-9_-]*$")])`, `FieldRule("deficit_cost", Real; constraints=[positive()])`, when `validate_schema!` is called, then it returns `true` and `length(e) == 0`
- [ ] Given a dict `{"id" => -1, "name" => "", "deficit_cost" => 100.0}` and the Bus schema, when `validate_schema!` is called with `entity_label="Bus"`, then it returns `false` and `length(e) >= 2` (one for negative id, one for empty name)
- [ ] Given a dict missing the `"id"` key, when `validate_schema!` is called, then it returns `false` and an `ErrorException` about the missing key is pushed
- [ ] Given a dict `{"id" => "not_a_number"}` and a rule `FieldRule("id", Integer)`, when `validate_schema!` is called, then it returns `false` and an `ErrorException` about type conversion is pushed
- [ ] Given a dict `{"alpha" => 0.5}` and a rule with `in_range(0.0, 1.0)`, when `validate_schema!` is called, then it returns `true`
- [ ] Given a dict `{"alpha" => 1.5}` and a rule with `in_range(0.0, 1.0)`, when `validate_schema!` is called, then it returns `false`
- [ ] Given a `FieldRule` with `required=false` and a dict missing that key, when `validate_schema!` is called, then the missing key does not produce an error
- [ ] Given the `validate_schema_keys_types!` function with a schema that has constraints, when called, then constraints are NOT evaluated (only key existence and type conversion are checked)
- [ ] Given the `FieldRule` struct, when inspected with `@code_warntype`, then all fields are concretely typed (no `Any` fields that would cause type instability)

## Implementation Guide

### Suggested Approach

1. **Create `src/Utils/schema.jl`**:

   Start with the struct definitions:

   ```julia
   struct FieldConstraint
       name::String
       predicate::Function
   end

   struct FieldRule
       key::String
       type::Type
       required::Bool
       constraints::Vector{FieldConstraint}
   end

   function FieldRule(key::String, type::Type; required::Bool = true, constraints = FieldConstraint[])
       return FieldRule(key, type, required, constraints isa Vector{FieldConstraint} ? constraints : Vector{FieldConstraint}(constraints))
   end
   ```

   Then the predicate factories:

   ```julia
   positive() = FieldConstraint("positive", v -> v > 0)
   non_negative() = FieldConstraint("non-negative", v -> v >= 0)
   in_range(lo, hi) = FieldConstraint("in [$lo, $hi]", v -> lo <= v <= hi)
   in_range_exclusive(lo, hi) = FieldConstraint("in ($lo, $hi)", v -> lo < v < hi)
   greater_than(n) = FieldConstraint("> $n", v -> v > n)
   less_than(n) = FieldConstraint("< $n", v -> v < n)
   non_empty() = FieldConstraint("non-empty", v -> length(v) > 0)
   matches(regex::Regex) = FieldConstraint("matches $regex", v -> begin
       m = match(regex, v)
       m !== nothing && m.match == v
   end)
   ```

   Then `validate_schema!`:

   ```julia
   function validate_schema!(
       d::Dict{String,Any},
       schema::Vector{FieldRule},
       e::CompositeException;
       entity_label::String = "",
   )::Bool
       valid = true
       label_prefix = isempty(entity_label) ? "" : "$entity_label - "

       for rule in schema
           # Key existence check
           if !haskey(d, rule.key)
               if rule.required
                   push!(e, ErrorException("Key '$(rule.key)' not found in dictionary"))
                   valid = false
               end
               continue
           end

           # Type conversion
           conversion_result = __parse_as_type!(d, rule.key, rule.type)
           if conversion_result isa Exception
               push!(e, conversion_result)
               valid = false
               continue
           end

           # Constraint evaluation
           value = d[rule.key]
           for constraint in rule.constraints
               if !constraint.predicate(value)
                   push!(
                       e,
                       AssertionError(
                           "$(label_prefix)$(rule.key) ($value) must be $(constraint.name)"
                       ),
                   )
                   valid = false
               end
           end
       end

       return valid
   end
   ```

   And `validate_schema_keys_types!`:

   ```julia
   function validate_schema_keys_types!(
       d::Dict{String,Any},
       schema::Vector{FieldRule},
       e::CompositeException,
   )::Bool
       valid = true
       for rule in schema
           if !haskey(d, rule.key)
               if rule.required
                   push!(e, ErrorException("Key '$(rule.key)' not found in dictionary"))
                   valid = false
               end
               continue
           end
           conversion_result = __parse_as_type!(d, rule.key, rule.type)
           if conversion_result isa Exception
               push!(e, conversion_result)
               valid = false
           end
       end
       return valid
   end
   ```

2. **Update `src/Utils/Utils.jl`**:
   - Add `include("schema.jl")` after `include("validation-utils.jl")` (schema.jl depends on `__parse_as_type!` from validation-utils.jl)
   - Add exports: `FieldRule`, `FieldConstraint`, `validate_schema!`, `validate_schema_keys_types!`, `positive`, `non_negative`, `in_range`, `in_range_exclusive`, `greater_than`, `less_than`, `non_empty`, `matches`

3. **Write tests** in `test/Utils/test-schema.jl`:
   - Test each predicate factory
   - Test `validate_schema!` with valid dict
   - Test `validate_schema!` with missing keys
   - Test `validate_schema!` with type conversion failures
   - Test `validate_schema!` with constraint violations
   - Test `validate_schema!` with entity_label
   - Test `validate_schema!` with non-required optional fields
   - Test `validate_schema_keys_types!` skips constraints
   - Test error accumulation (multiple errors from multiple fields)

### Key Files to Modify

- `src/Utils/schema.jl` -- create new (FieldRule, FieldConstraint, validate_schema!, predicates)
- `src/Utils/Utils.jl` -- add include and exports
- `test/Utils/test-schema.jl` -- create new (comprehensive unit tests)
- `test/runtests.jl` -- include new test file (if needed)

### Patterns to Follow

- Follow the existing error message convention: `ErrorException` for key/type failures, `AssertionError` for content/constraint violations
- Follow Blue formatting style (4-space indent, trailing commas in function args)
- The `__parse_as_type!` function from `validation-utils.jl` already handles dict mutation for type conversion -- reuse it, do not reimplement
- Use `const` for any module-level predicate instances if needed for performance

### Pitfalls to Avoid

- Do NOT use `Function` as the predicate type if it causes type instability issues. If `@code_warntype` shows problems, consider using a functor struct pattern instead. However, since predicates are evaluated during input parsing (not in hot loops), `Function` is acceptable here.
- The `__parse_as_type!` function returns `nothing` on success and an `Exception` on failure -- check for `isa Exception`, not `!== nothing` (since `nothing` means success).
- The existing error type in the codebase is spelled `AssertionError` (not `AssertionError`) -- this appears to be a custom type defined somewhere in the project. Use the same spelling.
- Do NOT modify `validation-utils.jl` in this ticket. The schema module is additive.
- Ensure the `matches` predicate handles the case where `match(regex, value)` returns `nothing` (no match at all).

## Testing Requirements

### Unit Tests

Create `test/Utils/test-schema.jl`:

- **Predicate tests**:
  - `positive()` returns true for 1, false for 0, false for -1
  - `non_negative()` returns true for 0, true for 1, false for -1
  - `in_range(0, 1)` returns true for 0, true for 0.5, true for 1, false for -0.1, false for 1.1
  - `non_empty()` returns true for "abc", false for ""
  - `matches(r"^[a-z]+$")` returns true for "abc", false for "ABC", false for "123"

- **Schema validation tests**:
  - Valid dict with all required fields -- returns true, no errors
  - Dict missing one required field -- returns false, one error
  - Dict missing two required fields -- returns false, two errors
  - Dict with wrong type for one field -- returns false, one error
  - Dict with constraint violation -- returns false, one error (AssertionError)
  - Dict with multiple constraint violations across fields -- returns false, multiple errors
  - Dict with optional field missing -- returns true for that field
  - Dict with optional field present but wrong type -- returns false
  - Entity label included in error messages
  - Entity label empty -- no prefix in error messages

- **validate_schema_keys_types! tests**:
  - Validates keys and types but skips constraints
  - Dict with constraint violation but valid keys/types -- returns true

### Integration Tests

- N/A (this is pure infrastructure; integration is tested in tickets 004-005)

### E2E Tests

- N/A

## Dependencies

- **Blocked By**: ticket-001 (merge -- schema.jl needs to be in the merged codebase), ticket-002 (graph validators -- establishes the validation patterns this builds upon)
- **Blocks**: ticket-004 (migrate System entities to schemas), ticket-005 (migrate Engine/Scenarios entities to schemas)

## Effort Estimate

**Points**: 3
**Confidence**: High
