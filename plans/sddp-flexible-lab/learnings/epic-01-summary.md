# Accumulated Learnings Summary -- Epic 01

## Core Architecture

- All entities construct from `Dict{String,Any}` + `CompositeException` and return `nothing` on failure
- Four-phase constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`, each gating the next via `&&`
- `ErrorException` for structural failures (missing keys, type conversion); `AssertionError` for semantic violations
- Errors accumulate in `CompositeException` -- never thrown, always pushed
- File pair convention: `entity.jl` (constructors, methods) + `entity-validators.jl` (schemas, validators)
- Validators file is included first; entity file calls validator functions

## FieldRule Schema System

- `src/Utils/schema.jl` provides `FieldRule`, `FieldConstraint`, `validate_schema!`, `validate_schema_keys_types!`
- Predicate factories: `positive()`, `non_negative()`, `in_range(lo,hi)`, `in_range_exclusive(lo,hi)`, `greater_than(n)`, `less_than(n)`, `non_empty()`, `matches(regex)`, `unique_in(key)`
- Schema handles key existence, type conversion, and constraints in one call
- Per-field short-circuits (missing -> skip type, bad type -> skip constraints), but cross-field does NOT short-circuit
- `validate_schema_keys_types!` skips constraints -- used for "before build" raw dict validation
- `unique_in()` is a placeholder; actual uniqueness checked in `__validate_*_consistency!` at collection level
- Schema works best for flat-field validation; cross-field (min <= max) and cross-entity (bus_id exists) still need manual validators

## kind_factory! Extension Mechanism

- `__kind_factory!(module, dict, key, e)` resolves `{"kind": "TypeName", "params": {...}}` to Julia objects
- Uses `getfield(module, Symbol(kind))` -- no registry needed; just define the struct and constructor
- Each concrete type must implement `TypeName(d::Dict{String,Any}, e::CompositeException)`
- Handles both single objects and `Vector{Dict{String,Any}}` arrays
- Used for: stopping criteria, risk measures, parallel schemes, load types, inflow models, engine types

## Entity Implementation Guide

- Simple entity (Bus): schema const + `validate_schema!` call + construct or return nothing
- Complex entity (Hydro): schema for flat fields, then manual cross-field/cross-entity validators
- Collection entity (Buses): build child entities first, then validate keys_types, then consistency (unique IDs/names)
- Cross-entity refs (Hydro->Bus, Line->Bus): validate ref exists, store as `Ref{T}`
- Cross-module validation (Load->Graph nodes): place in parent's validator file (scenariosdata-validators.jl)

## Input Format

- `main.jsonc` is entry point; references `data/` files for scenarios, system, constraints
- Graph defined in `graph.jsonc` with nodes (id, stage, start/end datetime) and edges (source, target, probability, discount_rate)
- Load CSV columns: `bus_id`, `node_id`, `value` (node_id references graph nodes, not stage indices)
- Engine config inlined in `main.jsonc` under `"engine"` key with kind/params pattern
- Old files removed: `algorithm.jsonc`, `tasks.jsonc`, `stages.csv`

## Testing Conventions

- Three helpers: `__renew(DICT)` (deep copy + fresh CompositeException), `__modif_key(d, k, v)`, `__remove_key(d, k)`
- Each test file defines a `DICT` constant with known-valid data
- Test pattern: start from valid, mutate one thing, assert `nothing` return + `length(e) > 0`
- Boundary tests (0 vs 1 for positive(), empty string for non_empty()) document exact constraint behavior
- Integration tests in `test/test-main.jl` run full pipeline per example: read -> build -> train -> simulate -> save

## Key Observations for Future Epics

- Adding new SDDP options (Epic 02): define struct, constructor, `generate_*` dispatch, optional schema; kind_factory handles discovery
- Adding system elements (Epic 05): follow Hydro pattern (most complex entity with bus refs + topology)
- New cross-entity constraints: place validators in parent module's validator file
- Schema reduced ~80% boilerplate for simple entities, ~30% for complex entities with cross-field logic
- Graph architecture decouples from sequential stages; load uses node_id for future branching/cyclic support
