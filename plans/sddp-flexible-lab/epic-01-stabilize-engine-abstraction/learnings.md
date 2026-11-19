# Epic 01 Learnings: Stabilize Engine Abstraction

**Date**: 2026-02-17
**Scope**: Tickets 001-009
**Net change**: +1694 / -3005 lines across 58 files

---

## Patterns Established

### 1. FieldRule Declarative Schema Pattern

Every entity that is constructed from a `Dict{String,Any}` declares a `const` schema vector at the top of its `*-validators.jl` file. The schema replaces per-field manual key checks, type conversions, and simple constraint assertions with a single `validate_schema!` call. The canonical example is `BUS_SCHEMA` in `/home/rogerio/git/sddp-lab/src/System/bus-validators.jl` (lines 3-11). Predicate factories (`positive()`, `non_negative()`, `in_range()`, `matches()`, etc.) are defined in `/home/rogerio/git/sddp-lab/src/Utils/schema.jl` and compose declaratively. The schema engine handles three phases in order: required-key check, type conversion via `__parse_as_type!`, then constraint evaluation. Per-field validation short-circuits (missing key skips type check, failed type skips constraints), but cross-field validation does NOT short-circuit -- all fields are always checked so multiple errors accumulate.

### 2. Four-Phase Entity Constructor Pattern

Every entity follows a strict constructor pipeline: `build_internals -> validate_keys_types -> validate_content -> validate_consistency`. Each phase gates the next via `&&` chaining. Simple entities (Bus, DeterministicLoadValue) collapse to a single `validate_schema!` call that covers the first three phases, then return `nothing` on failure. Collection entities (Buses, Hydros, Lines, Thermals, DeterministicLoad) always go through all four phases because they must build child entities before validating cross-entity consistency. The canonical collection constructor is `Buses()` in `/home/rogerio/git/sddp-lab/src/System/bus.jl` (lines 10-16).

### 3. CompositeException Error Accumulation Pattern

All validation functions accept an `e::CompositeException` parameter and push errors into it rather than throwing. Two error types are used: `ErrorException` for structural failures (missing keys, type conversion failures) and `AssertionError` (custom project spelling) for content/semantic violations. This allows the system to report all validation errors in a single pass rather than stopping at the first one. The pattern is used consistently across all 15+ validator files.

### 4. kind_factory! Polymorphic Construction Pattern

The `__kind_factory!` function in `/home/rogerio/git/sddp-lab/src/Utils/reading-utils.jl` (lines 97-119) resolves `{"kind": "TypeName", "params": {...}}` JSON structures into Julia objects at runtime via `getfield(module, Symbol(kind))`. This is the primary extension mechanism for adding new stopping criteria, risk measures, parallel schemes, load types, inflow models, and engine types. Each concrete type must implement a `TypeName(d::Dict{String,Any}, e::CompositeException)` constructor. The factory handles both single objects and vectors of objects.

### 5. File-Pair Convention: entity.jl + entity-validators.jl

Every domain entity has its code split across two files: `entity.jl` contains the constructor, general methods, and helpers; `entity-validators.jl` contains the schema constant, key/type validators, content validators, consistency validators, and internal-build helpers. The module file (e.g., `Scenarios.jl`, `System/System.jl`) includes the validators file first, then the entity file, since the entity constructor calls validator functions. Observed in: `bus.jl`/`bus-validators.jl`, `hydro.jl`/`hydro-validators.jl`, `line.jl`/`line-validators.jl`, `thermal.jl`/`thermal-validators.jl`, `load.jl`/`load-validators.jl`, `graph.jl`/`graph-validators.jl`, `scenariosdata.jl`/`scenariosdata-validators.jl`.

### 6. Cross-Entity Validation via Ref Pattern

Entities that reference other entities (Hydro -> Bus, Thermal -> Bus, Line -> Bus, DeterministicLoad -> Graph nodes) validate the reference exists during construction and store a `Ref{T}` to the referenced entity. The validation happens in `__validate_*_content!` functions that return the `Ref` or `nothing`. See `/home/rogerio/git/sddp-lab/src/System/hydro-validators.jl` (lines 52-62) for the Hydro-to-Bus pattern, and `/home/rogerio/git/sddp-lab/src/Scenarios/scenariosdata-validators.jl` (lines 44-76) for the Load-to-Graph cross-validation.

---

## Architectural Decisions

### D1: Hybrid schema + manual validators (chosen) vs. full macro code generation (rejected)

The FieldRule system replaces only the mechanical parts of validation (key existence, type conversion, simple predicates). Cross-field validators (e.g., `min_storage <= initial_storage <= max_storage` in Hydro), cross-entity validators (e.g., bus_id exists in Buses), and consistency validators (e.g., unique IDs, DAG topology) remain as hand-written functions. This was chosen because the cross-entity/cross-field validators have complex logic that does not reduce to single-field predicates, and a macro approach would have been harder to debug. The decision is visible by comparing `HYDRO_SCHEMA` (11 simple field rules, `/home/rogerio/git/sddp-lab/src/System/hydro-validators.jl` lines 3-19) against the hand-written `__validate_hydro_storage` and `__validate_hydro_generation` functions in the same file.

### D2: node_id field in DeterministicLoadValue (chosen) vs. stage_index (rejected)

The load representation was refactored from `stage_index::Integer` to `node_id::Integer` to decouple load data from the assumption of sequential stages. The node_id references the graph's `Node.id` directly, enabling future support for cyclic/branching graphs. The CSV column was renamed from `stage_index` to `node_id`. A cross-validation in `__validate_deterministic_load_node_references!` (`/home/rogerio/git/sddp-lab/src/Scenarios/scenariosdata-validators.jl` lines 44-76) ensures all node_ids in load data exist in the graph.

### D3: validate_schema_keys_types! (two-pass validation) vs. single validate_schema!

A separate `validate_schema_keys_types!` function was created that runs only key-existence and type-conversion, skipping constraint evaluation. This is needed for the "before build" phase where raw `Dict{String,Any}` structures are validated before being converted to typed objects. Without this separation, constraint evaluation would fail on unconverted values. See `/home/rogerio/git/sddp-lab/src/Utils/schema.jl` lines 293-321.

---

## Files and Structures Created

- `/home/rogerio/git/sddp-lab/src/Utils/schema.jl` -- FieldRule/FieldConstraint types, predicate factories, validate_schema! and validate_schema_keys_types! functions (322 lines)
- `/home/rogerio/git/sddp-lab/test/Utils/test-schema.jl` -- Comprehensive unit tests for schema infrastructure (241 lines)
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-sddp-mappings.jl` -- Tests for SDDP.jl type mappings (stopping rules, risk measures, parallel schemes) (80 lines)
- `/home/rogerio/git/sddp-lab/test/Engines/sddp/test-convergence.jl` -- Tests for Convergence construction and validation (77 lines)
- `/home/rogerio/git/sddp-lab/example/1dsin/data/graph.jsonc` -- Graph definition for 1dsin example (24 nodes, 23 edges)
- `/home/rogerio/git/sddp-lab/example/1dsin_ar/data/graph.jsonc` -- Graph definition for 1dsin_ar example
- `/home/rogerio/git/sddp-lab/example/4ree/data/graph.jsonc` -- Graph definition for 4ree example

---

## Conventions Adopted

### C1: Entity name regex

All entity names (Bus, Hydro, Thermal, Line) must match `r"^[\sa-zA-Z0-9_-]*$"` -- alphanumeric characters, spaces, hyphens, and underscores only. This is enforced via the `matches()` predicate in each entity schema.

### C2: Error type distinction

`ErrorException` is used for structural failures (missing keys, type conversion failures). `AssertionError` (project-specific spelling, not Julia's `AssertionError`) is used for semantic/content violations. This distinction is critical: schema.jl uses `ErrorException` for missing keys and type failures, `AssertionError` for constraint violations.

### C3: Private function naming

All internal functions use double-underscore prefix (`__build_*`, `__validate_*`, `__cast_*`, `__get_*`). Public API functions have no prefix. Collection builders follow the pattern `__build_ENTITY_entities!` for building individual items, and `__build_ENTITYs!` (or `__build_ENTITY_PLURAL!`) for the top-level builder called from the parent module.

### C4: Test helper trio

Tests use three helpers defined in `runtests.jl`: `__renew(dict)` returns a deep copy of the dict and a fresh `CompositeException`; `__modif_key(dict, key, value)` returns a copy with one key modified; `__remove_key(dict, key)` returns a copy with one key removed. Every test starts from a known-valid `DICT` constant and mutates one thing. See `/home/rogerio/git/sddp-lab/test/System/test-bus.jl` for the canonical example.

### C5: Input file format convention

The `main.jsonc` file is the entry point; it references relative paths under `data/` for scenarios, system, and constraints. Scenarios reference `graph.jsonc` via `{"params": {"file": "graph.jsonc"}}`. Load data comes from CSV with columns `bus_id`, `node_id`, `value`. JSONC (JSON with comments) is used throughout to allow inline documentation. Engine configuration (convergence, risk measures, parallel schemes) is inlined in `main.jsonc` under the `"engine"` key.

### C6: Deleted files from old architecture

The following file categories were removed as part of the abstract-engine merge: `data/algorithm.jsonc`, `data/tasks.jsonc`, `data/stages.csv` from all example directories. These were replaced by the engine configuration in `main.jsonc` and graph definitions in `graph.jsonc`.

---

## Surprises and Deviations

### S1: Schema did not replace as much boilerplate as expected for complex entities

The ticket plan estimated 40%+ boilerplate reduction. For simple entities (Bus, DeterministicLoadValue, IterationLimit, TimeLimit), the reduction was near 80% -- each needed only a schema constant and a one-line `validate_schema!` call. But for complex entities (Hydro, Thermal, Line), the schema only handles the flat-field validation. Cross-field checks (min_storage <= max_storage, min_generation <= max_generation) and cross-entity checks (bus_id exists in buses) still require hand-written validators. The actual boilerplate reduction for complex entities is closer to 30%. This is visible in `/home/rogerio/git/sddp-lab/src/System/hydro-validators.jl` where the schema (19 lines) replaces about 40 lines of per-field validators, but 70+ lines of cross-field and cross-entity validators remain.

### S2: Load refactor required cross-module consistency validation

The plan assumed the load-graph validation would be simple. In practice, `__validate_deterministic_load_node_references!` needed to be placed in `scenariosdata-validators.jl` (not `load-validators.jl`) because it requires access to both the built `DeterministicLoad` object and the built `Graph` object. This creates a coupling where `scenariosdata-validators.jl` must know about `DeterministicLoad` internals (iterating `.values` and checking `.node_id`). Future cross-module validations should follow this same pattern: place cross-entity validators in the parent's validator file.

### S3: Example migration required graph.jsonc creation

The plan mentioned "migrating" example cases but the graph definitions did not exist as separate files. They had to be created from scratch by inspecting the old `stages.csv` files and constructing the equivalent node/edge graph representation. Each graph needed node IDs, stage numbers, date ranges, edge probabilities, and discount rates. The 4ree example was particularly involved with 12 nodes.

### S4: The `__add_load_balance!` function semantics were already correct

The ticket plan for load refactoring suggested significant changes to `__add_load_balance!`. In practice, the function's `node::Integer` parameter was already being passed the graph node ID from the SDDP.jl subproblem builder closure. The only change needed was removing TODO comments and confirming the `get_load(bus_id, node, scenarios)` call used the correct semantics. The load refactor was primarily a data model and validation change, not a build pipeline change.

---

## Recommendations for Future Epics

### R1: Adding new SDDP algorithm options (Epic 02)

New stopping criteria, risk measures, and parallel schemes only need: (1) a struct definition in the appropriate types file, (2) a constructor following the `TypeName(d::Dict{String,Any}, e::CompositeException)` pattern, (3) a `generate_*` dispatch method mapping to the SDDP.jl equivalent, and (4) a schema constant if the type has parameters. The `__kind_factory!` in `/home/rogerio/git/sddp-lab/src/Utils/reading-utils.jl` will discover and instantiate any new type automatically via `getfield(module, Symbol(kind))`. No factory registration is needed. See `/home/rogerio/git/sddp-lab/src/Engines/sddp/input.jl` lines 63-66 (AVaR constructor) as a minimal example of a parameterized option.

### R2: Adding new system elements (Epic 05)

Follow the Bus/Hydro/Thermal/Line pattern exactly: define the struct in the System module, create `element.jl` + `element-validators.jl`, define a `const ELEMENT_SCHEMA` with FieldRule entries, implement the four-phase constructor, add to `SystemData`, and wire into `add_system_elements!` dispatch in `/home/rogerio/git/sddp-lab/src/Engines/sddp/build.jl`. The Hydro entity at `/home/rogerio/git/sddp-lab/src/System/hydro.jl` is the best reference for entities with cross-entity bus references and topology.

### R3: Extending the validation pipeline

When adding constraints that span multiple entities (e.g., fuel supply constraints spanning thermals), place the cross-entity validator in the parent module's validator file (e.g., `inputsdata-validators.jl` or `scenariosdata-validators.jl`), not in the child entity's validator file. This follows the pattern established in S2 above with load-graph validation.

### R4: Test structure for new entities

Copy the test structure from `/home/rogerio/git/sddp-lab/test/System/test-bus.jl`: define a `DICT` constant with valid data, use `__renew(DICT)` to get a fresh copy per test, systematically test each field with invalid values using `__modif_key` and `__remove_key`, and verify both the return value (nothing) and error accumulation (`length(e) > 0`). Boundary tests (zero vs. one for positive() constraints) are important because they document the exact boundary behavior.

### R5: The unique_in constraint is a placeholder only

The `unique_in(key)` predicate in the schema always returns true at the field level. Actual uniqueness enforcement happens in the `__validate_*_consistency!` functions at the collection level. Do not rely on the schema engine for uniqueness -- it must be checked manually after all entities in a collection are built. See `/home/rogerio/git/sddp-lab/src/System/bus-validators.jl` lines 43-57 for the bus unique ID/name consistency checks.
