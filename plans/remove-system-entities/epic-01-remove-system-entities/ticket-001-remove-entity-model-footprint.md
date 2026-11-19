---
filesToBeCreated: []
filesToBeModified:
  - src/Engines/sddp/build.jl
  - src/Engines/sddp/scaling.jl
  - src/Engines/sddp/save_simulation.jl
  - src/Engines/sddp/validate.jl
  - src/Lab/variables.jl
  - src/Lab/Lab.jl
  - src/SDDPlab.jl
  - test/test-load-blocks.jl
filesToBeDeleted: []
implements: [ADR-001, ADR-002, ADR-004, ADR-005, R6, R7, R8, R10]
hpcFencedPaths: ["src/Engines/sddp/build.jl", "src/Engines/sddp/scaling.jl"]
agent: hpc-julia-developer
tier: complex
---

# TICKET-001 Remove the Entity Footprint from the SDDP Model

## Context

### Background

SDDPlab is being reduced in scope. The non-controllable generation, energy contract and pumping station entities must disappear as if they had never been programmed (master plan R1-R13). This ticket removes everything the SDDP engine and the `Lab` module do with them: the LP variables, expressions and terms in `src/Engines/sddp/build.jl`, the five variable symbols `NC_GENERATION`, `NC_CURTAILMENT`, `CONTRACT_DISPATCH`, `PUMPED_FLOW` and `PUMP_POWER` with their exports, their scaling inputs and factor keys, their unscale-factor branches and the six `operation_*`/`validation_operation_*` output files (R10). It also opens the development branch (R8).

The six entity types and the 7-field `SystemData` stay in place in this ticket so the package keeps loading: Julia resolves method-signature type annotations at load time, so the types can only be deleted after every consumer is gone (ticket-002 deletes them).

### Relation to Epic

First of three tickets in `epic-01-remove-system-entities` (ADR-001, consumers-first cut). It is the only ticket that changes the LP builder, so it takes the R7 base dump and runs the first identity check (ADR-005); ticket-002 reruns the same check against the same base dump after rewriting `apply_scaling`. ticket-002 then deletes the System data layer, which no model code reads after this ticket; ticket-003 removes examples, docs and CHANGELOG entries.

Door class: **one-way** — it removes exported symbols (`SDDPlab.NC_GENERATION` and four others) and three output file names a consumer could depend on; accepted with no deprecation path because v3.0.0 is untagged and the branch is unmerged (ADR-002, R6). Structure budget: deletion only; this ticket introduces no type, function, parameter, file, test or abstraction, and depends on no debt ticket.

### Current State

At base commit `d16b8ee` (tip of `feat/sddp-flexible-lab`):

- `src/Engines/sddp/build.jl` (961 lines) has `add_system_elements!` methods for `NonControllables` (lines 99-119), `EnergyContracts` (121-135) and `PumpingStations` (200-219), called at 224-226. The three hydro-balance functions take `pump_source_map`/`pump_dest_map` (234-235, 268-269, 324-325) and add `PUMPED_FLOW` terms (parallel 252-260; chronological `_net_flow_expr` 301-307). `add_system_objective!` reads `noncontrollables`/`contracts` (406-407, 412-413) and adds curtailment and contract terms (435-453). `__generate_subproblem_builder` builds nine entity locals and maps (839-841, 843, 847-853), passes the pump maps at 879-881 and five entity arguments to `__add_load_balance!` (896, 899-902). `__add_load_balance!` (918-961) declares those five parameters (927, 930-933) and adds the NC, contract and pump-power terms (942-949).
- `src/Engines/sddp/scaling.jl`: `compute_scaling_factors` reads NC and contract entities (27, 30-31), splats them into `all_gen` (36-37, right after the hydro and thermal splats at 34-35) and `all_costs` (74-75, right after the thermal splat at 73), and sets `NC_GENERATION`, `CONTRACT_DISPATCH` (42-43) and `PUMPED_FLOW` (61); `no_scaling_config` lists the same three keys (89-90, 99). `apply_scaling` (lines 175-224) rebuilds the three entity collections through field access only; it stays untouched here.
- `src/Engines/sddp/build.jl:1-38`: `Lab.build` picks the scaling from `engine.policy.scaling`. `_apply_engine_scaling(::NoScaling, ...)` returns `no_scaling_config()` (all factors 1.0) and never calls `compute_scaling_factors` or `apply_scaling`; only `_apply_engine_scaling(::AutoScaling, ...)` does. None of the five examples used for R7 sets `scaling`, so they build with `NoScaling`.
- SDDP.jl installs the stage objective (`node.stage_objective + theta`) into a node's JuMP model only inside `SDDP.parameterize(node, noise)`; SDDPlab's builder (`build.jl:906-910`) only stores it. A subproblem written right after `SDDPlab.build` therefore has an empty objective.
- `src/Engines/sddp/save_simulation.jl`: `_get_variable_unscale_factor` branches on the five symbols (65-72); `map_variable_output` lists `operation_noncontrollables`, `operation_contracts`, `operation_pumping` (377-379); `map_variable_entities` maps the five symbols (401-405).
- `src/Engines/sddp/validate.jl`: `validation_operation_noncontrollables`, `validation_operation_contracts`, `validation_operation_pumping` (192-194) and the five entity mappings (216-220).
- `src/Lab/variables.jl` defines the five symbols with docstrings (36-60); `src/Lab/Lab.jl` exports them (25-29); `src/SDDPlab.jl` imports them from `Lab` (32-36) and re-exports them (248-252).
- `test/test-load-blocks.jl`: the `load-balance` testset defines unused entity locals (348, 351-354); five hydro-balance testsets build empty `pump_source_map`/`pump_dest_map` locals and pass them (389-390/394-395, 427-428/432-433, 473-474/478-479, 509-510/514-515, 538-539/543-544).

## Specification

### Requirements

1. Create `feat/remove-system-entities` from `feat/sddp-flexible-lab` and commit this ticket there (R8, ADR-004).
2. Delete the three entity `add_system_elements!` methods and their three calls; the `SystemData` method dispatches to `Buses`, `Lines`, `Thermals`, `Hydros` in that order (R10).
3. Delete the `pump_source_map`/`pump_dest_map` parameters and pump terms from `add_hydro_balance!`, `add_hydro_balance_parallel!` and `add_hydro_balance_chronological!` (R10, ADR-002).
4. Delete the five entity parameters and three terms of `__add_load_balance!`, the curtailment and contract objective terms, and every builder local whose only consumer was an entity, including the `hydro_ids` local in `build.jl` (R6, R10).
5. Delete the five Lab symbols, their docstrings and both export sites; their scaling inputs and keys in `compute_scaling_factors` and `no_scaling_config`; their unscale branches; their six output-file entries and ten entity mappings (R10).
6. Delete the now-unused entity locals and pump-map arguments in `test/test-load-blocks.jl` without changing any `@test` line (R5, R6).
7. Prove R7 with the one-off dump and comparison of ADR-005, taken at the base commit and after the edits: parameterized node subproblems and `ScalingConfig` factors of five examples under `NoScaling` and under `AutoScaling`, plus the perturbed `compute_scaling_factors` case. Commit nothing from it, and leave `/tmp/sddplab-r7` in place for ticket-002's mandatory rerun.

### Inputs/Props

Signatures after this ticket (the chain contracts in `00-master-plan.md`):

```julia
add_hydro_balance!(m::JuMP.Model, hydros::Hydros, block_mode::Symbol,
                   tau_k::Vector{Float64}, num_blocks::Int)
add_hydro_balance_parallel!(m::JuMP.Model, hydros::Hydros, zeta::Float64,
                            w_k::Vector{Float64}, num_blocks::Int)
add_hydro_balance_chronological!(m::JuMP.Model, hydros::Hydros, zeta_k::Vector{Float64},
                                 w_k::Vector{Float64}, num_blocks::Int)
__add_load_balance!(m::JuMP.Model, scenarios::ScenariosData, node::Integer,
                    load_scale::Float64, bus_ids::Vector{<:Integer}, num_blocks::Int,
                    hydro_bus_map::Dict{Int,Vector{Int}}, thermal_bus_map::Dict{Int,Vector{Int}},
                    line_target_map::Dict{Int,Vector{Int}}, line_source_map::Dict{Int,Vector{Int}})
```

`add_system_objective!`, `compute_scaling_factors`, `no_scaling_config`, `_get_variable_unscale_factor` and `_build_bus_index_map` keep their signatures. `SystemData` keeps its 7 fields until ticket-002.

### Outputs/Behavior

- For any system with no entities of the three kinds, under both `NoScaling` and `AutoScaling`, every parameterized node subproblem, objective vector `c` included, is identical to the base commit: byte-identical, or within 4 ULP per coefficient when both files are read back through MOI. `ScalingConfig.factors` has the same value for every retained key and lacks only `NC_GENERATION`, `CONTRACT_DISPATCH` and `PUMPED_FLOW`. The same holds for `compute_scaling_factors` on a system in which thermal cost and thermal `max_generation` dominate (sddp-specialist invariance contract in `00-master-plan.md`; verified by AC3, ADR-005).
- `save_simulation` and `validate` never write `operation_noncontrollables`, `operation_contracts`, `operation_pumping` or their `validation_` counterparts; all other output files are unchanged.
- A study whose `system.jsonc` still declares the three keys (`example/renewable_contracts`, `example/pumped_storage`) still reads, builds, trains and simulates: the System layer still parses the entities until ticket-002, and nothing in the model reads them. This transient state is branch-local.

### Error Handling

No error path is added or removed. `_get_variable_unscale_factor` keeps its final fallback branch unchanged. The following are R7 violations:

- a failure of a retained numerical test;
- a failed assertion in the "after" run of `r7-dump.jl`;
- an `R7 VIOLATION` line from the first comparison command;
- any output from the factors comparison.

On any of them, STOP and return `CLARIFICATION REQUIRED` with the failing output. Never edit an expected value, the dump script, the 4-ULP tolerance or `lp-before`.

## Acceptance Criteria

- [ ] **AC1 (R8)** Given the ticket's changes are made, when `git rev-parse --abbrev-ref HEAD` and `git merge-base --is-ancestor feat/sddp-flexible-lab HEAD` run, then the first prints `feat/remove-system-entities` and the second exits 0.
- [ ] **AC2 (R10, R6)** Given the edited tree, when the four removal-gate commands of Technical Details "Removal gate" run, then the symbol-and-plumbing `git grep` over `src test` and the `git grep -w hydro_ids -- src/Engines` check each exit 1 with no output, the `awk` type-and-accessor loop over `src/Engines` prints nothing, and `git grep -c -E 'NonControllable|EnergyContract|PumpingStation' -- test/test-load-blocks.jl` prints exactly `test/test-load-blocks.jl:3`.
- [ ] **AC3 (R7, ADR-005)** Given `/tmp/sddplab-r7/lp-before` was dumped at the base commit and `/tmp/sddplab-r7/lp-after-001` after the edits, both by `julia --project=. /tmp/sddplab-r7/r7-dump.jl <dir>` from Technical Details "R7 dump" and both runs exited 0, when the two commands of Technical Details "R7 comparison" run from the repo root with `AFTER=/tmp/sddplab-r7/lp-after-001`, then:
  - the first prints no line starting with `R7 VIOLATION`, covering every subproblem file under `<example>/` and `autoscale/<example>/`;
  - the second prints nothing and exits 1, so every `factors.txt` under `<example>/`, `autoscale/<example>/` and `perturbed/` differs from the base only by deleted `CONTRACT_DISPATCH`, `NC_GENERATION` and `PUMPED_FLOW` lines.
- [ ] **AC4 (R7, R5)** Given the edited tree, when `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` runs, then it exits 0, and `git diff $(git merge-base HEAD feat/sddp-flexible-lab) -- test | grep -E '^[+-][[:space:]]*@test'` prints nothing.
- [ ] **AC5 (CI format)** Given the edited tree, when the formatter command of Technical Details "Formatter fixpoint" runs a second time, then it exits 0 and `git status --porcelain -- . ':!plans/'` lists only the 8 paths in this ticket's `filesToBeModified`.

## Implementation Guide

### Suggested Approach

1. **Branch and environment** (R8). Run `git switch -c feat/remove-system-entities feat/sddp-flexible-lab`. If the branch already exists, run `git switch feat/remove-system-entities` and confirm AC1's ancestry check. Then run `julia --project=. -e 'using Pkg; Pkg.instantiate()'`; `Manifest.toml` is gitignored, so the environment may be empty.
2. **R7 base dump, before any source edit** (ADR-005). The dump directory is the fixed path `/tmp/sddplab-r7`, outside the repository. It is written `$R7` below. Shell state does not persist between tool calls, so start every command block with `R7=/tmp/sddplab-r7`.
   - Run `rm -rf $R7 && mkdir -p $R7 && cp Manifest.toml $R7/Manifest.toml`.
   - Write the two scripts of Technical Details "R7 dump" verbatim to `$R7/r7-dump.jl` and `$R7/r7-compare.jl`.
   - From the repo root, run `julia --project=. $R7/r7-dump.jl $R7/lp-before`. It must exit 0 and create `lp-before/<example>/`, `lp-before/autoscale/<example>/` for the five examples, and `lp-before/perturbed/factors.txt`.
3. **Edit bottom-up inside each file** so the base line numbers below stay valid while you work, and anchor every edit on the quoted content: `build.jl`, `scaling.jl` (lines 1-102 only), `save_simulation.jl`, `validate.jl`, `variables.jl`, `Lab.jl`, `SDDPlab.jl` (symbol blocks only), `test/test-load-blocks.jl`.
4. Run, in this order:
   - the formatter fixpoint;
   - the removal gate;
   - the R7 "after" dump, `julia --project=. $R7/r7-dump.jl $R7/lp-after-001`, which must exit 0;
   - the two commands of Technical Details "R7 comparison" with `AFTER=$R7/lp-after-001`;
   - the suite.
5. Leave `$R7` in place; it is outside the repository and never committed. ticket-002 reruns the dump against `$R7/lp-before`, then deletes the directory.

### Key Files to Modify

All line numbers are at base `d16b8ee`.

| File | Edit |
| --- | --- |
| `src/Engines/sddp/build.jl` | Delete 99-135 (NC and contract `add_system_elements!` methods, including the blank after each), 200-219 (pumping method and trailing blank), 224-226 (three calls). Shrink the three hydro-balance functions, `add_system_objective!`, `__generate_subproblem_builder` and `__add_load_balance!` as shown in Technical Details. |
| `src/Engines/sddp/scaling.jl` | Delete 27, 30-31, 36-37, 42-43, 61, 74-75, 89-90, 99 (13 lines). Keep 34-35 and 73 (hydro and thermal splats). Do not touch `apply_scaling` (lines 111-225). |
| `src/Engines/sddp/save_simulation.jl` | Delete 401-405, 377-379, 65-72 (bottom-up). |
| `src/Engines/sddp/validate.jl` | Delete 216-220, 192-194. |
| `src/Lab/variables.jl` | Delete 36-60 (five docstrings, five definitions, one trailing blank line). |
| `src/Lab/Lab.jl` | Delete 25-29 (five export lines). |
| `src/SDDPlab.jl` | Delete 248-252 (export block) and 32-36 (`using .Lab:` block). Leave the System type and accessor lines (89-94, 104-109, 291-296, 308-313) for ticket-002. |
| `test/test-load-blocks.jl` | Delete 543-544, 538-539, 514-515, 509-510, 478-479, 473-474, 432-433, 427-428, 394-395, 389-390 (pump locals and arguments) and 351-354, 348 (`nc_bus_map`, `contract_bus_map`, `contracts`, `pumping_bus_map`, `pumping_entities`). Keep 349-350 (`line_target_map`, `line_source_map`) and the `_make_system` fixture at 88-92. |

### Patterns to Follow

- Each removal leaves the surrounding expression exactly as an entity-free build evaluates it today; the target shapes below are the ones that keep `(c, A, b, l, u)` and row/column order unchanged.
- Blue style via `.JuliaFormatter.toml`; let the formatter choose the final line breaks of shortened signatures and calls.
- Remove the docstring together with the definition it documents; leave no comment that mentions a removed entity.

### Pitfalls to Avoid

- `using SDDPlab` succeeding proves nothing: a leftover `NC_GENERATION` inside a function body (for example the unscale branches at `save_simulation.jl:65-72`) only fails when called. Run the removal gate.
- Do not delete `_build_bus_index_map` or rename its `bus_field` argument: the line maps still use `:target_bus_id` and `:source_bus_id`.
- Do not touch `apply_scaling`, the `SystemData` struct, `src/System/**` or the `System` lines of `src/SDDPlab.jl`: deleting the types here breaks package loading (ticket-002 owns them).
- Do not run the "before" dump after editing; if it was missed, use the worktree fallback in Technical Details.
- Do not drop the `SDDP.parameterize` call or the `AutoScaling` pass from the dump. Without the first, every file minimizes 0 and the objective edit at `build.jl:435-453` goes unchecked. Without the second, no edit in `scaling.jl` runs, because every example builds with `NoScaling`.
- Do not compare `Threaded()` simulation outputs for R7: they vary run to run independently of this change. Compare subproblems.
- Do not delete `$R7` at the end of this ticket: ticket-002's acceptance criteria need `$R7/lp-before`.
- If the formatter changes a file outside the 8 declared paths, STOP and return `CLARIFICATION REQUIRED`; do not commit pre-existing format drift.

### Technical Details

**`add_hydro_balance_parallel!`** — delete parameter lines 234-235 and the two `PUMPED_FLOW` sums (252-260), so the constraint ends with the upstream-outflow sum:

```julia
function add_hydro_balance_parallel!(
    m::JuMP.Model, hydros::Hydros, zeta::Float64, w_k::Vector{Float64}, num_blocks::Int
)
    num_hydros = length(hydros)

    m[HYDRO_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_hydros],
        m[STORED_VOLUME][n].out ==
            m[STORED_VOLUME][n].in + zeta * m[INFLOW][n] -
        zeta * sum(w_k[k] * m[OUTFLOW][n, k] for k in 1:num_blocks) +
        zeta * sum(
            w_k[k] * m[OUTFLOW][j, k] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n] for
            k in 1:num_blocks
        )
    )
    return nothing
end
```

**`add_hydro_balance_chronological!`** — delete parameter lines 268-269; inside `_net_flow_expr` delete `source_pump` and `dest_pump` (301-306) and return the flow balance alone:

```julia
    function _net_flow_expr(n, k)
        upstream_flow = sum(
            m[OUTFLOW][j, k] for j in 1:num_hydros if
            downstream(hydros.entities[j].id, hydros) == hydros.entities[n];
            init = 0.0,
        )
        return upstream_flow - m[OUTFLOW][n, k]
    end
```

**`add_hydro_balance!`** — delete parameter lines 324-325; the two calls become `add_hydro_balance_parallel!(m, hydros, zeta, w_k, num_blocks)` and `add_hydro_balance_chronological!(m, hydros, zeta_k, w_k, num_blocks)`.

**`add_system_objective!`** — delete `noncontrollables = ...`, `contracts = ...` (406-407) and `num_nc = ...`, `num_contracts = ...` (412-413). Delete the two `tau_k[k] * (if ... end)` terms (435-453); the spillage term at 433-434 loses its trailing ` +` and the generator closes on it:

```julia
            tau_k[k] *
            sum(hydros[n].spillage_penalty * m[SPILLAGE][n, k] for n in 1:num_hydros)
            for k in 1:K
        ) + penalty
```

**`__generate_subproblem_builder`** — the locals become:

```julia
    hydros_entities = get_hydros_entities(system)
    thermals_entities = get_thermals_entities(system)
    lines_entities = get_lines_entities(system)
    bus_ids = get_ids(get_buses(system))

    hydro_bus_map = _build_bus_index_map(hydros_entities, bus_ids, :bus_id)
    thermal_bus_map = _build_bus_index_map(thermals_entities, bus_ids, :bus_id)
    line_target_map = _build_bus_index_map(lines_entities, bus_ids, :target_bus_id)
    line_source_map = _build_bus_index_map(lines_entities, bus_ids, :source_bus_id)
```

The hydro-balance call becomes `add_hydro_balance!(m, get_hydros(system), block_mode, tau_k, K)`. The load-balance call passes, in order: `m, scenarios, load_node_id, s_gen, bus_ids, K, hydro_bus_map, thermal_bus_map, line_target_map, line_source_map`.

**`__add_load_balance!`** — delete parameters 927 and 930-933 and constraint lines 942-949 (the NC sum, the contract sum and the `) - sum(m[PUMP_POWER]...) +` line):

```julia
    m[LOAD_BALANCE] = JuMP.@constraint(
        m,
        [n = 1:num_buses, k = 1:num_blocks],
        sum(m[HYDRO_GENERATION][j, k] for j in get(hydro_bus_map, n, Int[])) +
        sum(m[THERMAL_GENERATION][j, k] for j in get(thermal_bus_map, n, Int[])) +
        sum(
            m[DIRECT_EXCHANGE][j, k] - m[REVERSE_EXCHANGE][j, k] for
            j in get(line_target_map, n, Int[])
        ) +
        sum(
            m[REVERSE_EXCHANGE][j, k] - m[DIRECT_EXCHANGE][j, k] for
            j in get(line_source_map, n, Int[])
        ) +
        m[DEFICIT][n, k] == get_load(bus_ids[n], node, k, scenarios) / load_scale
    )
```

**`compute_scaling_factors`** — `all_gen` keeps only the hydro and thermal splats (34-35); `all_costs` keeps only the thermal and bus splats (73, 76); the factor list keeps `HYDRO_GENERATION`, `THERMAL_GENERATION`, `DEFICIT`, `STORED_VOLUME`, `FLOW_SCALE`, `TURBINED_FLOW`, `SPILLAGE`, `OUTFLOW`, `INFLOW`, `DIRECT_EXCHANGE`, `REVERSE_EXCHANGE`, `COST_SCALE`. Also delete the blank line 30 together with `contracts = ...` at 31. The perturbed case of the R7 dump fails its assertion if line 35 or 73 is lost.

**Removal gate** (run from the repo root):

```bash
git grep -n -E 'NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|pump_source_map|pump_dest_map|source_pump|dest_pump|\b(noncontrollable_bus_map|nc_bus_map|contract_bus_map|contracts_entities|pumping_bus_map|pumping_entities|noncontrollable_entities|num_nc|num_contracts)\b|operation_(noncontrollables|contracts|pumping)' -- src test
# required: no output, exit status 1 (the \b word boundaries keep the System-layer names
# get_energycontracts_entities and __build_noncontrollable_entities!, owned by ticket-002, out of the match)

git grep -n -w hydro_ids -- src/Engines
# required: no output, exit status 1 (hydro_ids stays legitimate in src/System/hydro-validators.jl)

for f in $(git ls-files 'src/Engines/*.jl'); do
  awk -v F="$f" '/^function apply_scaling/ && F ~ /scaling\.jl$/ {skip=1}
       !skip && /NonControllable|EnergyContract|PumpingStation|get_(noncontrollables|energycontracts|pumpingstations)/ {print F ":" FNR ": " $0; bad=1}
       END {exit bad}' "$f" || echo "FAIL $f"
done
# required: no output (entity types and accessors survive only inside apply_scaling)

git grep -c -E 'NonControllable|EnergyContract|PumpingStation' -- test/test-load-blocks.jl
# required: exactly "test/test-load-blocks.jl:3" (the _make_system fixture, owned by ticket-002)
```

**R7 dump** (ADR-005; both scripts live in `/tmp/sddplab-r7`, outside the repository, and are never committed). `$R7/r7-dump.jl` writes three subtrees under its output directory:

- `<example>/` holds the engine as configured, which is `NoScaling`.
- `autoscale/<example>/` holds the same study with the policy's scaling replaced by `AutoScaling`.
- `perturbed/` holds `compute_scaling_factors` on a `4ree` variant.

The `rebuild` helper is arity-agnostic, so the same script runs unchanged after ticket-002 shrinks `SystemData` to 4 fields.

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

`$R7/r7-compare.jl` reads two subproblem files through MOI. It compares objective sense and coefficients, every row (keyed by constraint name and set type) and every variable bound (keyed by variable name and set type) within 4 ULP. It prints `ULP-EQUIVALENT <file>` and exits 0, or prints `DIFFERENT <file>` and exits 1. It uses only JuMP, which is a direct dependency of SDDPlab.

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

If the LP writer throws for a node at the base commit, set `EXT` to `".mof.json"` before taking either dump. AC3 and both comparison commands are unchanged, and `r7-compare.jl` reads both formats.

If the "before" dump was not taken before editing, take it from a detached worktree of the base. Copy the current `Manifest.toml` into the worktree so that both dumps use the same package versions:

```bash
R7=/tmp/sddplab-r7
rm -rf $R7/lp-before $R7/base && git worktree prune
git worktree add --detach $R7/base $(git merge-base HEAD feat/sddp-flexible-lab)
cp Manifest.toml $R7/base/Manifest.toml && cp Manifest.toml $R7/Manifest.toml
(cd $R7/base && julia --project=. -e 'using Pkg; Pkg.instantiate()' && julia --project=. $R7/r7-dump.jl $R7/lp-before)
git worktree remove --force $R7/base
```

**R7 comparison** (run from the repo root; ticket-002 runs the same two commands with `AFTER=$R7/lp-after-002`):

```bash
R7=/tmp/sddplab-r7; AFTER=$R7/lp-after-001
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

R7=/tmp/sddplab-r7; AFTER=$R7/lp-after-001
diff -r -x '*.lp' -x '*.mof.json' $R7/lp-before $AFTER | grep -v -E '^(diff |[0-9]+(,[0-9]+)?d[0-9]+$|< (CONTRACT_DISPATCH|NC_GENERATION|PUMPED_FLOW) )'
# required: no output, exit status 1. Every factors.txt, under <example>/, autoscale/<example>/
# and perturbed/, differs only by deleted CONTRACT_DISPATCH, NC_GENERATION and PUMPED_FLOW lines.
# Factor values are compared exactly, because repr(::Float64) round-trips.
```

**Formatter fixpoint** (JuliaFormatter v1, the version CI pins; it reads `.JuliaFormatter.toml`, Blue style):

```bash
julia --startup-file=no -e 'using Pkg; Pkg.activate(; temp = true); Pkg.add(Pkg.PackageSpec(; name = "JuliaFormatter", version = "1")); using JuliaFormatter; exit(format(["src", "test", "docs"]) ? 0 : 1)'
```

The first run may exit 1 after rewriting files; the second run must exit 0.

## Testing Requirements

### Unit Tests

No test is added or deleted (R6). The retained unit tests must pass unedited:

- `test/test-load-blocks.jl`: hydro-balance dimensions in both block modes and load-balance dimensions.
- `test/Engines/sddp/test-scaling.jl`: factor values, the identity predicate, and `_get_variable_unscale_factor` at lines 399-409. The last exercises the shortened `elseif` chain of `_get_variable_unscale_factor` at call time.

These fixtures have deficit cost above thermal cost and empty lines, so they cannot detect a lost thermal splat. The perturbed case of the R7 dump covers that.

### Integration Tests

The full suite (`JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'`, matching the CI configuration in `main.yml`) builds, trains and simulates the remaining examples plus `renewable_contracts` and `pumped_storage`, whose entity keys are now parsed but not modeled. A subset can be iterated with `TEST_FILTER=<substring>`, but AC4 requires the unfiltered run.

### E2E Tests (if applicable)

The R7 dump (AC3) is the end-to-end LP identity check over `1dtoy`, `1dtoy_per_stage_blocks`, `load_blocks`, `4ree` and `markov_var`. It covers both block modes, per-stage blocks, Markov graphs, lines, both scaling modes and the objective vector `c`, and its perturbed case covers the thermal inputs of `compute_scaling_factors`. It is run by hand at the base commit and after the edits, and is not committed (ADR-005).

Cite its result in the completion report as the bit-exact evidence `hpcFencedPaths` requires:

- the number of subproblem files compared in each subtree, `<example>/` and `autoscale/<example>/`;
- every `ULP-EQUIVALENT` line, if any;
- the `COST_SCALE` and `THERMAL_GENERATION` lines of `perturbed/factors.txt`.

ticket-002 reruns the same script against the same `lp-before`.

## Out of Scope

- The six entity types, the `SystemData` fields and arity, the six accessors, the schemas and validators, `apply_scaling`, the `System` lines of `src/SDDPlab.jl`, `test/Engines/sddp/test-scaling.jl`, `test/test-per-stage-blocks.jl`, `test/test-examples-tutorial.jl` and the `_make_system` fixture in `test/test-load-blocks.jl` (ticket-002).
- `example/`, `docs/` and `CHANGELOG.md` (ticket-003).
- The pre-existing unused `line_target_map`/`line_source_map` locals at `test/test-load-blocks.jl:349-350`, the naming of `_build_bus_index_map`, the non-`const` symbol globals in `src/Lab/variables.jl`, and the abstract `Integer`/`Real` fields of the remaining entities (R7: no adjacent refactor).
- A committed golden-LP or subproblem-fingerprint test, any test asserting the symbols are absent, and committing either R7 script (R6, ADR-005).
- The mandatory R7 rerun after the `apply_scaling` rewrite and the deletion of `/tmp/sddplab-r7` (ticket-002).
- `plans/sddp-flexible-lab/**` and git history (R13).

## Dependencies

- **Blocked By**: None
- **Blocks**: ticket-002-remove-entity-system-layer.md
- **Ordering reason**: ticket-002 deletes the entity types and the 7-field `SystemData`; Julia resolves the types in this ticket's method signatures (`::NonControllables`, `::Vector{EnergyContract}`) at load time, so they can only be deleted after this ticket removes those signatures. ticket-002 also reruns the R7 dump against the `lp-before` this ticket saves.

## Effort Estimate

**Points**: 3
**Confidence**: High
Rationale: about 28 verbatim deletions across 8 files with exact before/after shapes. The cost is dominated by the first `Pkg.instantiate()`, two dump runs (ten model builds each, plus one `compute_scaling_factors` call) and one full `Pkg.test()`.

## Definition of Done

- AC1-AC5 pass and their command outputs are quoted in the completion report. From AC3, quote the count of compared subproblem files for each subtree (`<example>/` and `autoscale/<example>/`), any `ULP-EQUIVALENT` lines, and the `perturbed/factors.txt` values of `COST_SCALE` and `THERMAL_GENERATION`.
- Exactly the 8 files in `filesToBeModified` changed, and no file was created or deleted in the repository. `/tmp/sddplab-r7` stays outside the repository for ticket-002, holding `r7-dump.jl`, `r7-compare.jl`, `Manifest.toml`, `lp-before` and `lp-after-001`.
- No dead code left behind: no unused parameter, local, import, export, docstring or comment that referred to a removed symbol or entity map.
- The work is committed on `feat/remove-system-entities` as a normal commit (for example `refactor: remove entity footprint from the SDDP model`); no force-push, no history rewrite.
