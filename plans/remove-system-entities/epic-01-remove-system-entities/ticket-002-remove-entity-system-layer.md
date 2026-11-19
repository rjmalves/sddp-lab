---
filesToBeCreated: []
filesToBeModified:
  - src/System/System.jl
  - src/System/systemdata.jl
  - src/System/systemdata-validators.jl
  - src/SDDPlab.jl
  - src/Engines/sddp/scaling.jl
  - test/Engines/sddp/test-scaling.jl
  - test/test-load-blocks.jl
  - test/test-per-stage-blocks.jl
  - test/test-examples-tutorial.jl
filesToBeDeleted:
  - src/System/noncontrollable.jl
  - src/System/noncontrollable-validators.jl
  - src/System/energycontract.jl
  - src/System/energycontract-validators.jl
  - src/System/pumpingstation.jl
  - src/System/pumpingstation-validators.jl
  - test/System/test-noncontrollable.jl
  - test/System/test-energycontract.jl
  - test/System/test-pumpingstation.jl
implements: [ADR-001, ADR-002, ADR-005, R1, R2, R3, R4, R5, R6, R7, R11]
hpcFencedPaths: ["src/Engines/sddp/scaling.jl"]
agent: hpc-julia-developer
tier: complex
---

# TICKET-002 Remove the Three Entities from the System Data Layer

## Context

### Background

After ticket-001 nothing in the SDDP model, the Lab symbols or the output writers reads non-controllable, energy contract or pumping station data. What remains is the data layer that parses, validates and stores them (R1-R5, R11):

- six types, three `SystemData` fields and six accessors;
- three schemas with their validators and readers, and the optional-key branches of the `system.jsonc` build and cast paths;
- the re-exports and the `apply_scaling` rebuild of the three collections;
- three dedicated test files, the 7-argument `SystemData` constructions in shared tests, and the two example testsets that exercise the entity examples.

This ticket deletes all of it, leaving `src/` and `test/` with no trace of the entities.

### Relation to Epic

Second of three tickets in `epic-01-remove-system-entities` (ADR-001). It is LP-neutral by construction: it deletes only data that, after ticket-001, no model-building, scaling-factor or output code reads. That claim is checked here, not assumed. Its `apply_scaling` rewrite runs only under `AutoScaling`, which no test compares at the LP level. So AC6 reruns ticket-001's R7 dump, with parameterized subproblems and factors under `NoScaling` and `AutoScaling` plus the perturbed `compute_scaling_factors` case, against ticket-001's saved base dump (ADR-005). The `hpcFencedPaths` fence on `scaling.jl` requires that bit-exact evidence.

The ticket changes `SystemData`'s positional arity from 7 to 4 once, together with every positional call site (`apply_scaling` and six test constructions), which is why those edits cannot move to another ticket. ticket-003 then deletes the example directories, tutorials, docs mentions and CHANGELOG entries. The examples stay readable until then, because the generic reader ignores unknown `system.jsonc` keys.

Door class: **one-way** — it removes exported types and accessors, the `SystemData` field set and positional arity, and the `noncontrollables`/`energycontracts`/`pumpingstations` input keys, all of which a consumer could depend on; accepted with no deprecation path because v3.0.0 is untagged and the branch is unmerged (ADR-002, R6). Structure budget: deletion only; this ticket introduces no type, function, parameter, file, test or abstraction, and depends on no debt ticket.

### Current State

Line numbers are at base `d16b8ee` unless marked "after ticket-001". ticket-001 does not touch `src/System/**`, `test/Engines/sddp/test-scaling.jl`, `test/test-per-stage-blocks.jl` or `test/test-examples-tutorial.jl`, so base numbers hold there. For `src/SDDPlab.jl`, `src/Engines/sddp/scaling.jl` and `test/test-load-blocks.jl` the expected positions after ticket-001 are given; anchor on the quoted content, because the formatter run of ticket-001 can shift lines.

- `src/System/System.jl` (541 lines): `NonControllable`, `EnergyContract`, `PumpingStation` with docstrings (140-228); `NonControllables`, `EnergyContracts`, `PumpingStations` with docstrings (301-345); three `SystemData` field docstring lines (358-360) and fields (369-371); six `include`s (493-501); six type exports (514-519); six accessor exports (529-534).
- `src/System/systemdata.jl` (172 lines): the dict constructor passes `d["noncontrollables"]`, `d["energycontracts"]`, `d["pumpingstations"]` (11-19 is the 7-argument call); six accessors with docstrings (113-172).
- `src/System/systemdata-validators.jl`: `__build_system_internals_from_dicts!` builds or defaults the three optional keys (48-72); `__cast_system_internals_from_files!` casts them (83-105). `CONFIGURATION_KEYS` lists only the four required keys and stays unchanged.
- Six dedicated source files hold the three schemas (`NONCONTROLLABLE_SCHEMA`, `ENERGY_CONTRACT_SCHEMA`, `PUMPING_STATION_SCHEMA`), their validators and readers; every `src/Utils` helper they call has other consumers.
- `src/SDDPlab.jl`: six types in `using .System:` (base 89-94, after ticket-001 84-89) and six accessors (base 104-109, after ticket-001 99-104); the same in the `export SystemData, ...` block (base 291-296 and 308-313, after ticket-001 281-286 and 298-303).
- `src/Engines/sddp/scaling.jl` `apply_scaling`: three rebuild blocks from `scaled_noncontrollables = NonControllable[` to `new_pumpingstations = PumpingStations(scaled_pumpingstations)` plus the blank line after it (base 175-215, after ticket-001 162-202), then a 7-argument `return SystemData(` (base 216-224, after ticket-001 203-211). `apply_scaling` is called only by `_apply_engine_scaling(::AutoScaling, ...)` (`src/Engines/sddp/build.jl`).
- `test/Engines/sddp/test-scaling.jl`: four fixtures, each three empty-entity locals followed by a 7-argument `system = System.SystemData(` call spanning 9 lines: 191-202, 231-242, 282-293, 330-341.
- `test/test-load-blocks.jl` `_make_system`: three empty-entity locals and a 7-argument `return System.SystemData(` (base and after ticket-001 88-93).
- `test/test-per-stage-blocks.jl` fixture: the same shape at 54-59.
- `test/test-examples-tutorial.jl`: the `renewable_contracts` (9-17) and `pumped_storage` (19-27) testsets plus the blank line 28.
- `test/System/test-{noncontrollable,energycontract,pumpingstation}.jl` test only the System layer; `test/runtests.jl` auto-discovers test files, so deleting them needs no runner edit.
- ticket-001 leaves the R7 artifacts outside the repository in `/tmp/sddplab-r7`:
  - `r7-dump.jl` and `r7-compare.jl`;
  - `Manifest.toml`, a copy of the environment used for the dumps;
  - `lp-before/`, the base-commit dump, with `<example>/`, `autoscale/<example>/` and `perturbed/`;
  - `lp-after-001/`.

## Specification

### Requirements

1. Delete the six dedicated source files and the three dedicated test files (R1-R5).
2. Delete the six types, three fields, six accessors, six includes and all their exports and re-exports, with their docstrings and `See also` cross-references (R1-R3, R6).
3. Remove the optional-key handling of `noncontrollables`, `energycontracts` and `pumpingstations` from the build and cast paths, restoring the four-entity bodies given in Technical Details (R4).
4. Make `SystemData` a 4-field struct with the positional constructor `SystemData(buses::Buses, lines::Lines, hydros::Hydros, thermals::Thermals)` and update `apply_scaling` and the six test constructions to it (ADR-002).
5. Delete the `renewable_contracts` and `pumped_storage` testsets of `test/test-examples-tutorial.jl` (R11).
6. Add no handling of stale keys: a `system.jsonc` that still declares a removed key reads with zero errors because the generic reader ignores keys outside `CONFIGURATION_KEYS` (R6).
7. Rerun ticket-001's R7 dump on the edited tree and compare it with the base dump. Accept byte-identical or 4-ULP-equivalent subproblems, and factor files that lose only the three removed keys (R7, ADR-005). Delete `/tmp/sddplab-r7` once that check passes. Commit nothing from it.

### Inputs/Props

`SystemData(d::Dict{String,Any}, e::CompositeException)` and `SystemData(filename::String, e::CompositeException)` keep their signatures and read only `buses`, `lines`, `hydros` and `thermals`. `apply_scaling(system::SystemData, config::ScalingConfig)::SystemData` keeps its signature and scales the four remaining collections exactly as today.

### Outputs/Behavior

- `fieldnames(SystemData) == (:buses, :lines, :hydros, :thermals)`.
- `SDDPlab` no longer defines or exports `NonControllable`, `NonControllables`, `EnergyContract`, `EnergyContracts`, `PumpingStation`, `PumpingStations`, `get_noncontrollables`, `get_noncontrollables_entities`, `get_energycontracts`, `get_energycontracts_entities`, `get_pumpingstations`, `get_pumpingstations_entities`.
- `SDDPlab.read_study` on `example/renewable_contracts` and `example/pumped_storage` (still present until ticket-003) completes with an empty `CompositeException`.
- The LP, scaling factors and output files of every study are unchanged from the base commit, under both `NoScaling` and `AutoScaling`. AC6 verifies this against ticket-001's base dump.

### Error Handling

No error path is added. The removed validators' error messages disappear with them. The following are failures:

- a retained test fails in `Pkg.test()`;
- any `read_study` call in AC2 records an error;
- the R7 rerun's `r7-dump.jl` exits non-zero;
- the first R7 comparison command prints an `R7 VIOLATION` line;
- the second R7 comparison command prints anything.

On any of them, STOP and return `CLARIFICATION REQUIRED` with the failing output. Never edit an expected value, add key handling, edit either R7 script, change the 4-ULP tolerance, or regenerate `lp-before` from the edited tree to make a check pass.

## Acceptance Criteria

- [ ] **AC1 (R1-R5, R6)** Given the edited tree, when `git ls-files` runs on the 9 paths of this ticket's `filesToBeDeleted` and `git grep -n -i -E 'noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage|pump|contract|curtail|\bnc_|num_nc' -- src test` runs, then the first prints nothing and the second exits 1 with no output.
- [ ] **AC2 (ADR-002, R6)** Given the edited tree, when the command of Technical Details "API and stale-key check" runs from the repo root, then it exits 0 (the `SystemData` field tuple is `(:buses, :lines, :hydros, :thermals)` and both entity examples read with `length(e) == 0`).
- [ ] **AC3 (R5, R7)** Given the edited tree, when `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` runs, then it exits 0, and `git diff $(git merge-base HEAD feat/sddp-flexible-lab) -- test/Engines/sddp/test-scaling.jl test/test-load-blocks.jl test/test-per-stage-blocks.jl | grep -E '^[+-][[:space:]]*@test'` prints nothing.
- [ ] **AC4 (R11)** Given the edited `test/test-examples-tutorial.jl`, when `grep -o '@testset "[^"]*"' test/test-examples-tutorial.jl` runs, then it prints exactly four lines, in order: `@testset "tutorial-examples"`, `@testset "load_blocks"`, `@testset "markov_var"`, `@testset "experiment_sweep"`.
- [ ] **AC5 (CI format)** Given the edited tree, when the formatter command of Technical Details "Formatter fixpoint" runs a second time, then it exits 0 and `git status --porcelain -- . ':!plans/'` lists only the 18 paths of this ticket's frontmatter.
- [ ] **AC6 (R7, ADR-005)** Given `/tmp/sddplab-r7/lp-before`, as ticket-001 saved it or as regenerated by Technical Details "R7 rerun", and `/tmp/sddplab-r7/lp-after-002`, dumped from the edited tree by `julia --project=. /tmp/sddplab-r7/r7-dump.jl /tmp/sddplab-r7/lp-after-002`, which exits 0, when the two commands of Technical Details "R7 comparison" run from the repo root with `AFTER=/tmp/sddplab-r7/lp-after-002`, then:
  - the first prints no line starting with `R7 VIOLATION`, covering every subproblem file under `<example>/` and `autoscale/<example>/`;
  - the second prints nothing and exits 1, so every `factors.txt` under `<example>/`, `autoscale/<example>/` and `perturbed/` differs from the base only by deleted `CONTRACT_DISPATCH`, `NC_GENERATION` and `PUMPED_FLOW` lines.

## Implementation Guide

### Suggested Approach

1. Confirm `git rev-parse --abbrev-ref HEAD` prints `feat/remove-system-entities` and that ticket-001's changes are present (`git grep -c NC_GENERATION -- src` exits 1). Run `julia --project=. -e 'using Pkg; Pkg.instantiate()'` if the environment is fresh. Then run the precondition check of Technical Details "R7 rerun". If it prints anything, run its fallback before editing.
2. `git rm` the 9 files of `filesToBeDeleted`.
3. Edit `src/System/System.jl`, `src/System/systemdata.jl` and `src/System/systemdata-validators.jl` bottom-up with the base line numbers below.
4. Edit `src/SDDPlab.jl` and `apply_scaling` in `src/Engines/sddp/scaling.jl`, anchoring on content.
5. Update the six test constructions and delete the two example testsets.
6. Run, in this order:
   - the formatter fixpoint;
   - the removal gate;
   - the API and stale-key check;
   - the suite;
   - the R7 rerun, `julia --project=. /tmp/sddplab-r7/r7-dump.jl /tmp/sddplab-r7/lp-after-002`, which must exit 0;
   - the two commands of Technical Details "R7 comparison" with `AFTER=/tmp/sddplab-r7/lp-after-002`.
7. After AC6 passes and its output is captured for the completion report, run `rm -rf /tmp/sddplab-r7`. If AC6 fails, keep the directory for diagnosis.

### Key Files to Modify

| File | Edit |
| --- | --- |
| 9 files in `filesToBeDeleted` | `git rm`. |
| `src/System/System.jl` | Delete 529-534, 514-519, 493-501, 369-371, 358-360, 301-345, 140-228 (bottom-up). The `SystemData` docstring keeps its four field lines and its `See also` line. |
| `src/System/systemdata.jl` | Delete 113-172 (the file then ends with the `end` of `get_lines_entities` at line 112). Replace the 7-argument call at 11-19 with `SystemData(d["buses"], d["lines"], d["hydros"], d["thermals"])`. |
| `src/System/systemdata-validators.jl` | Replace 48-72 and 83-105 so both helpers match Technical Details. |
| `src/SDDPlab.jl` | Delete the six type lines and six accessor lines from both the `using .System:` list and the `export SystemData, ...` block (24 lines). |
| `src/Engines/sddp/scaling.jl` | In `apply_scaling` only: delete the three rebuild blocks and replace the return with `return SystemData(new_buses, new_lines, new_hydros, new_thermals)`. |
| `test/Engines/sddp/test-scaling.jl` | Replace each of 330-341, 282-293, 231-242, 191-202 with `system = System.SystemData(buses, lines, hydros, thermals)` (8-space indent). |
| `test/test-load-blocks.jl` | Replace 88-93 with `return System.SystemData(buses, lines, hydros, thermals)` (4-space indent). |
| `test/test-per-stage-blocks.jl` | Replace 54-59 with `return System.SystemData(buses, lines, hydros, thermals)`. |
| `test/test-examples-tutorial.jl` | Delete 9-28. |

### Patterns to Follow

- The four-entity bodies of the two validator helpers are exactly the pre-entity bodies in Technical Details; do not reorder the remaining validity flags.
- Delete a docstring together with the definition it documents, and a `See also` reference together with its target.
- Blue style via `.JuliaFormatter.toml`; the formatter decides the final layout of the shortened constructor calls.

### Pitfalls to Avoid

- Do not change `CONFIGURATION_KEYS`, `CONFIGURATION_KEY_TYPES` or any `src/Utils` helper: none of them names an entity, and `FieldRule`, `validate_schema!`, `__validate_keys!`, `non_empty` and `positive` all have other consumers.
- Do not add a check, warning or error for the removed keys; ignoring them is the intended behavior (R6).
- Do not touch the other four rebuild blocks of `apply_scaling` or any line above `function apply_scaling` in `scaling.jl`.
- Do not delete `example/renewable_contracts` or `example/pumped_storage` here: AC2 reads them, and ticket-003 owns them.
- Do not edit `test/runtests.jl`; it discovers test files by walking `test/`.
- Do not take or regenerate `lp-before` from this ticket's working tree. It must come from the base commit: either ticket-001's copy or the detached-worktree fallback.
- Do not skip AC6 on the grounds that the change is LP-neutral: `apply_scaling` runs only on the `AutoScaling` path, and AC6 is the only check that compares that path's LP.
- If the formatter changes a file outside the 18 declared paths, STOP and return `CLARIFICATION REQUIRED`.

### Technical Details

**Validator helpers after the edit** (`src/System/systemdata-validators.jl`):

```julia
function __build_system_internals_from_dicts!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_buses = __build_buses!(d, e)
    valid_lines = valid_buses && __build_lines!(d, d["buses"], e)
    valid_hydros = valid_buses && __build_hydros!(d, d["buses"], e)
    valid_thermals = valid_buses && __build_thermals!(d, d["buses"], e)
    return valid_lines && valid_hydros && valid_thermals
end

function __cast_system_internals_from_files!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_system_keys_types_before_build!(d, e)
    valid_buses = valid_key_types && __cast_buses_internals_from_files!(d, e)
    valid_lines = valid_key_types && __cast_lines_internals_from_files!(d, e)
    valid_hydros = valid_key_types && __cast_hydros_internals_from_files!(d, e)
    valid_thermals = valid_key_types && __cast_thermals_internals_from_files!(d, e)

    return valid_buses && valid_lines && valid_hydros && valid_thermals
end
```

**`SystemData` after the edit** (`src/System/System.jl`):

```julia
struct SystemData <: InputModule
    buses::Buses
    lines::Lines
    hydros::Hydros
    thermals::Thermals
end
```

**`apply_scaling` tail after the edit** (`src/Engines/sddp/scaling.jl`):

```julia
    new_thermals = Thermals(scaled_thermals)

    return SystemData(new_buses, new_lines, new_hydros, new_thermals)
end
```

**Removal gate** (run from the repo root):

```bash
git ls-files src/System/noncontrollable.jl src/System/noncontrollable-validators.jl src/System/energycontract.jl src/System/energycontract-validators.jl src/System/pumpingstation.jl src/System/pumpingstation-validators.jl test/System/test-noncontrollable.jl test/System/test-energycontract.jl test/System/test-pumpingstation.jl
# required: no output

git grep -n -i -E 'noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage|pump|contract|curtail|\bnc_|num_nc' -- src test
# required: no output, exit status 1
```

**API and stale-key check** (one-off, never committed; R6 forbids a test asserting absence):

```bash
julia --project=. -e 'using SDDPlab; @assert fieldnames(SystemData) == (:buses, :lines, :hydros, :thermals); for ex in ("renewable_contracts", "pumped_storage"); e = CompositeException(); SDDPlab.read_study(joinpath(pwd(), "example", ex); e = e); @assert length(e) == 0 ex; end'
# required: exit status 0
```

`read_study` logs errors without throwing, so the check inspects the `CompositeException` it fills.

**R7 rerun** (ADR-005; everything lives in `/tmp/sddplab-r7`, outside the repository, and nothing is committed). First check that ticket-001's artifacts are present and that the package environment is the one they were dumped with:

```bash
R7=/tmp/sddplab-r7
for f in r7-dump.jl r7-compare.jl Manifest.toml; do test -f $R7/$f || echo "MISSING $f"; done
{ test -d $R7/lp-before/autoscale && test -f $R7/lp-before/perturbed/factors.txt; } || echo "MISSING lp-before"
cmp -s Manifest.toml $R7/Manifest.toml || echo "ENVIRONMENT CHANGED"
# no output: reuse /tmp/sddplab-r7 as ticket-001 left it
```

If it prints anything, rebuild the base side before rerunning. This can happen after a reboot, on another machine, or after a fresh `Pkg.instantiate()`.

1. Run `mkdir -p /tmp/sddplab-r7`, then write any missing script verbatim from the two blocks below. They are byte-for-byte the scripts of ticket-001.
2. Regenerate `lp-before` from a detached worktree of the base commit, using the current `Manifest.toml` so that both sides use the same package versions:

```bash
R7=/tmp/sddplab-r7
rm -rf $R7/lp-before $R7/base && git worktree prune
git worktree add --detach $R7/base $(git merge-base HEAD feat/sddp-flexible-lab)
cp Manifest.toml $R7/base/Manifest.toml && cp Manifest.toml $R7/Manifest.toml
(cd $R7/base && julia --project=. -e 'using Pkg; Pkg.instantiate()' && julia --project=. $R7/r7-dump.jl $R7/lp-before)
git worktree remove --force $R7/base
```

Then dump the edited tree with `julia --project=. /tmp/sddplab-r7/r7-dump.jl /tmp/sddplab-r7/lp-after-002` from the repo root; it must exit 0. The script's `rebuild` helper is arity-agnostic, so it works on the 4-field `SystemData`.

`r7-dump.jl` writes three subtrees, each with its sorted `factors.txt`:

- `<example>/` holds the engine as configured, which is `NoScaling`, as parameterized subproblems.
- `autoscale/<example>/` holds the same studies with `AutoScaling`. This is the only path that calls `apply_scaling`.
- `perturbed/` holds `compute_scaling_factors` on a `4ree` variant in which thermal cost and thermal `max_generation` dominate.

```julia
# /tmp/sddplab-r7/r7-dump.jl — never committed. Run from the repo root:
#   julia --project=. /tmp/sddplab-r7/r7-dump.jl <out-dir>
using SDDPlab, SDDP
const Engines = SDDPlab.Engines
const EXAMPLES = ["1dtoy", "1dtoy_per_stage_blocks", "load_blocks", "4ree", "markov_var"]
const EXT = ".lp"

# Copy of `x` with one field replaced; works for any field count (7- or 4-field SystemData).
function rebuild(x, field::Symbol, value)
    T = typeof(x)
    return T((f === field ? value : getfield(x, f) for f in fieldnames(T))...)
end

function write_factors(dir, factors)
    mkpath(dir)
    open(joinpath(dir, "factors.txt"), "w") do io
        for (k, v) in sort(collect(factors); by = first)
            println(io, k, " ", repr(v))
        end
    end
end

function dump_model(dir, model)
    mkpath(dir)
    for (node_id, node) in model.policy_graph.nodes
        # SDDP.jl installs stage objective + theta only here, so the file carries c.
        SDDP.parameterize(node, first(node.noise_terms).term)
        name = replace(string(node_id), r"[^0-9A-Za-z]+" => "_")
        SDDP.write_subproblem_to_file(
            node, joinpath(dir, "subproblem_$(name)$(EXT)"); throw_error = false
        )
    end
    @assert any(endswith(EXT), readdir(dir)) "no subproblem written in $dir"
    write_factors(dir, model.scaling.factors)
end

out = abspath(ARGS[1])
for ex in EXAMPLES
    study = SDDPlab.read_study(joinpath(pwd(), "example", ex))
    @assert study.engine.policy.scaling isa Engines.NoScaling "$ex no longer defaults to NoScaling"
    dump_model(joinpath(out, ex), SDDPlab.build(study))
    policy = rebuild(study.engine.policy, :scaling, Engines.AutoScaling())
    auto = SDDPlab.build(SDDPlab.Study(study.inputs, rebuild(study.engine, :policy, policy)))
    @assert any(!=(1.0), values(auto.scaling.factors)) "AutoScaling not applied for $ex"
    dump_model(joinpath(out, "autoscale", ex), auto)
end

# 4ree variant: thermal max_generation and thermal cost dominate; lines are non-empty.
sys = SDDPlab.get_system(SDDPlab.read_study(joinpath(pwd(), "example", "4ree")).inputs.files)
gen = 2 * maximum(Float64(h.max_generation) for h in SDDPlab.get_hydros_entities(sys))
cost = 2 * maximum(Float64(b.deficit_cost) for b in SDDPlab.get_buses_entities(sys))
ts = SDDPlab.get_thermals_entities(sys)
t1 = rebuild(rebuild(ts[1], :max_generation, gen), :cost, cost)
variant = rebuild(sys, :thermals, SDDPlab.Thermals([t1; ts[2:end]]))
@assert !isempty(SDDPlab.get_lines_entities(variant)) "4ree has no lines"
factors = Engines.compute_scaling_factors(variant).factors
@assert factors[:THERMAL_GENERATION] == gen && factors[:COST_SCALE] == cost "a thermal input no longer reaches compute_scaling_factors"
write_factors(joinpath(out, "perturbed"), factors)
```

```julia
# /tmp/sddplab-r7/r7-compare.jl — never committed. Run from the repo root:
#   julia --project=. /tmp/sddplab-r7/r7-compare.jl <before-file> <after-file>
using JuMP
ulp_close(a, b) = a == b || abs(a - b) <= 4 * eps(max(abs(a), abs(b)))
coefs(f) = Dict(JuMP.name(v) => c for (c, v) in JuMP.linear_terms(f))
setvals(s) = Float64[getfield(s, x) for x in fieldnames(typeof(s))]
function canon(path)
    m = JuMP.read_from_file(path)
    obj = JuMP.objective_function(m, JuMP.AffExpr)
    out = Dict{Any,Tuple{Dict{String,Float64},Vector{Float64}}}(
        (:objective, JuMP.objective_sense(m)) => (coefs(obj), [JuMP.constant(obj)]),
    )
    for (F, S) in JuMP.list_of_constraint_types(m), c in JuMP.all_constraints(m, F, S)
        o = JuMP.constraint_object(c)
        isvar = F == JuMP.VariableRef
        key = (isvar ? JuMP.name(o.func) : JuMP.name(c), S)
        @assert !haskey(out, key) "duplicate key $key in $path"
        out[key] = (isvar ? Dict{String,Float64}() : coefs(o.func), setvals(o.set))
    end
    return out
end
a, b = canon(ARGS[1]), canon(ARGS[2])
same(x, y) = keys(x) == keys(y) && all(ulp_close(x[k], y[k]) for k in keys(x))
ok = keys(a) == keys(b) && all(keys(a)) do k
    (ca, sa), (cb, sb) = a[k], b[k]
    return same(ca, cb) && length(sa) == length(sb) && all(ulp_close.(sa, sb))
end
println(ok ? "ULP-EQUIVALENT " : "DIFFERENT ", ARGS[2])
exit(ok ? 0 : 1)
```

If ticket-001 switched `EXT` to `".mof.json"` (its saved `lp-before` then holds `.mof.json` files), keep that value. The comparison commands exclude both extensions from the factors diff, and `r7-compare.jl` reads both formats.

**R7 comparison** (run from the repo root; the same two commands as ticket-001, with this ticket's dump):

```bash
R7=/tmp/sddplab-r7; AFTER=$R7/lp-after-002
diff -r -q -x factors.txt $R7/lp-before $AFTER | while read -r line; do
  case "$line" in
    "Files "*" differ")
      set -- $line
      julia --project=. $R7/r7-compare.jl "$2" "$4" </dev/null || echo "R7 VIOLATION: $line" ;;
    *) echo "R7 VIOLATION: $line" ;;
  esac
done
# required: no line starting with "R7 VIOLATION". The output is empty when every subproblem file
# under <example>/ and autoscale/<example>/ is byte-identical, plus one "ULP-EQUIVALENT <file>" line
# for each file whose bytes differ but whose objective, rows and bounds agree within 4 ULP.
# An "Only in" line (a file present on one side only) is a violation.

R7=/tmp/sddplab-r7; AFTER=$R7/lp-after-002
diff -r -x '*.lp' -x '*.mof.json' $R7/lp-before $AFTER | grep -v -E '^(diff |[0-9]+(,[0-9]+)?d[0-9]+$|< (CONTRACT_DISPATCH|NC_GENERATION|PUMPED_FLOW) )'
# required: no output, exit status 1. Every factors.txt, under <example>/, autoscale/<example>/
# and perturbed/, differs from the base only by deleted CONTRACT_DISPATCH, NC_GENERATION and
# PUMPED_FLOW lines. Factor values are compared exactly, because repr(::Float64) round-trips.
```

**Formatter fixpoint** (JuliaFormatter v1, the version CI pins; it reads `.JuliaFormatter.toml`, Blue style):

```bash
julia --startup-file=no -e 'using Pkg; Pkg.activate(; temp = true); Pkg.add(Pkg.PackageSpec(; name = "JuliaFormatter", version = "1")); using JuliaFormatter; exit(format(["src", "test", "docs"]) ? 0 : 1)'
```

The first run may exit 1 after rewriting files; the second run must exit 0.

## Testing Requirements

### Unit Tests

No test is added (R6). The three dedicated entity test files are deleted with the code they test. The retained System tests (`test/System/test-{bus,line,hydro,thermal,systemdata}.jl`) and the scaling tests (`test/Engines/sddp/test-scaling.jl`, which call `compute_scaling_factors` and `apply_scaling` on the 4-argument fixtures) must pass with no `@test` line edited.

### Integration Tests

The full suite (`JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'`, matching the CI configuration in `main.yml`) reads, builds, trains and simulates the remaining examples. The suite alone does not prove this ticket LP-neutral, for two reasons:

- The `AutoScaling` end-to-end test (`test/test-main.jl:436-472`) compares only the unscaled lower bound within 1%, and that bound does not change under a change of units.
- The scaling fixtures all have deficit cost above thermal cost and empty lines.

The mandatory R7 rerun (AC6) therefore rebuilds the five examples under both scaling modes and compares their parameterized subproblems and factors with the base-commit dump. `AutoScaling` is the only path that calls the rewritten `apply_scaling`.

### E2E Tests (if applicable)

- The AC2 stale-key check is the end-to-end proof of R6's "ignored like any unrecognized key". It reads the two entity examples, whose `system.jsonc` still declare the removed keys, through the public `read_study` path.
- The AC6 rerun is the end-to-end LP identity check of this ticket. Cite its result in the completion report as the bit-exact evidence `hpcFencedPaths` requires:
  - the number of subproblem files compared in each subtree;
  - every `ULP-EQUIVALENT` line, if any;
  - the `COST_SCALE` and `THERMAL_GENERATION` lines of `perturbed/factors.txt`.

## Out of Scope

- `example/renewable_contracts/`, `example/pumped_storage/`, `docs/`, `CHANGELOG.md` (ticket-003).
- Converting the positional `SystemData` constructor to keyword arguments, sharing a test fixture between the six constructions, and the abstract `Integer`/`Real` fields of `Bus`, `Line`, `Hydro`, `Thermal` (R7: no adjacent refactor).
- `src/Utils/schema.jl` and every other `src/Utils` file, `test/runtests.jl`, and `CONFIGURATION_KEYS`.
- Any guard against loading a cut file trained with the removed entities (accepted non-guarantee in the master plan's Risk Analysis; R6).
- Any test asserting the entities are absent (R6), and `plans/sddp-flexible-lab/**` (R13).
- Committing either R7 script or any dump, and any edit to the scripts, their 4-ULP tolerance or the base dump (ADR-005).

## Dependencies

- **Blocked By**: ticket-001-remove-entity-model-footprint.md
- **Blocks**: ticket-003-remove-entity-traces-outside-package.md
- **Ordering reason**: this ticket needs ticket-001's removal of every engine-side consumer of the entity types and, for AC6, the base dump that ticket-001 saves in `/tmp/sddplab-r7` (regenerable from the base commit). Its AC2 reads `example/renewable_contracts` and `example/pumped_storage`, which ticket-003 deletes. ticket-003 in turn needs the example testsets gone from `test/test-examples-tutorial.jl` before the directories go.

## Effort Estimate

**Points**: 2
**Confidence**: High
Rationale: 9 file deletions and about 21 verbatim edits whose final text is given. One full `Pkg.test()` run and one R7 dump run (ten model builds) dominate the time. The worktree fallback adds one base-commit dump only when ticket-001's artifacts are gone.

## Definition of Done

- AC1-AC6 pass and their command outputs are quoted in the completion report. From AC6, quote the count of compared subproblem files for each subtree, any `ULP-EQUIVALENT` lines, and the `perturbed/factors.txt` values of `COST_SCALE` and `THERMAL_GENERATION`.
- Exactly the 18 paths of the frontmatter changed (9 deleted, 9 modified), and no file was created. `/tmp/sddplab-r7` was deleted after AC6 passed.
- No dead code left behind: no unused include, export, import, docstring, `See also` reference, helper or local tied to the removed entities.
- The work is committed on `feat/remove-system-entities` as a normal commit (for example `refactor: remove entity types from the System data layer`); no force-push, no history rewrite.
