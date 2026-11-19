# Design brief: `hpc-julia-developer`

- **Plan:** `plans/remove-system-entities`
- **Stage:** brief (P2 council, `design-council` workflow run `wf_4e3dc635-449`, 2026-11-10)
- **Context read:** `design/intake.md` only (independent brief; this consultant did not see the other seat's brief)
- **Schema:** `DESIGN_BRIEF` per `skills/plan/references/design-brief.md`

## domain

Julia / JuMP / scientific

## meetsAllStated

true

## simplestViable

### description

One epic with two tickets, both on a branch cut from feat/sddp-flexible-lab.

T1 removes all the Julia code and tests for the three entities in one atomic ticket. It must be one ticket for all three entities, and it cannot be split by layer:
- Julia resolves the type annotations in method signatures when the package loads, for example `add_system_elements!(m, ::NonControllables, ...)` and `contracts_entities::Vector{EnergyContract}`. Removing the types before their consumers therefore breaks `using SDDPlab`.
- Removing the consumers first and the types later does not work either, because SystemData's positional 7-argument constructor is shared by the apply-scaling rebuild in scaling.jl and by six test constructions.

T1 covers:
1. Delete the six src/System entity files and the three test/System entity tests.
2. System.jl: remove the six types, the six includes, the exports and the SystemData field docstrings.
3. systemdata.jl: cut the constructor from 7 arguments to 4 and remove the six accessors.
4. systemdata-validators.jl: remove the three `haskey` branches in both the build and the cast paths.
5. SDDPlab.jl: remove both re-export blocks.
6. Lab/variables.jl and Lab/Lab.jl: remove the five symbols.
7. build.jl:
   - Delete the three `add_system_elements!` methods and their calls.
   - Drop `pump_source_map` and `pump_dest_map` from `add_hydro_balance!`, `_parallel!` and `_chronological!`. In `_chronological!`, also drop `source_pump` and `dest_pump`, so it returns `upstream_flow - m[OUTFLOW][n, k]`.
   - Drop five parameters from `__add_load_balance!`.
   - Drop the NC and contract objective branches, plus `num_nc` and `num_contracts`.
   - Drop the nine locals in `__generate_subproblem_builder`, including `hydro_ids`.
8. scaling.jl:
   - Remove the NC and contract splats in `all_gen` and `all_costs`.
   - Remove the three factor keys in both `compute_scaling_factors` and `no_scaling_config`.
   - Remove the three rebuilt collections and pass 4 arguments to `SystemData`.
9. save_simulation.jl: remove the four `elseif` unscale branches at lines 65-71, which the intake inventory missed, and lines 377-379 and 401-405.
10. validate.jl: remove lines 192-194 and 216-220.
11. Shared tests:
   - Use 4-argument SystemData in test-scaling.jl (four places), test-load-blocks.jl:88-92 and test-per-stage-blocks.jl:54-58.
   - Remove the pump maps from the five hydro-balance calls.
   - Remove `nc_bus_map`, `contract_bus_map`, `contracts`, `pumping_bus_map` and `pumping_entities` at test-load-blocks.jl:348-354.
   - Remove the `renewable_contracts` and `pumped_storage` testsets, so that no Julia code under src/ or test/ references the entities.

T2 removes the non-code material:
- Delete the two example directories and the two tutorials.
- Remove the two docs/make.jl entries and the mentions in the shared docs pages.
- Make the CHANGELOG edits from R12.

The package loads and `Pkg.test()` passes after each ticket.

### forgoes

- **Per-entity revert:** one `git revert` cannot restore a single entity, because one commit removes all three.
- **Per-entity bisect:** bisection cannot narrow a problem to one entity's removal.
- **Smaller reviews:** the T1 diff is larger, about 30 files.
- **Refactors not done:** the plan does not reduce future churn from positional SystemData construction in tests, for example with a keyword constructor or a shared test fixture, even though the operator has announced more scope reductions. R7 forbids that refactor.

## mostDurable

### description

One epic with four tickets.

The first three remove one entity each, end to end, in the order non-controllable, then energy contract, then pumping station. Each ticket covers that entity's types, schemas and validators, SystemData field, accessors, exports, Lab symbols, build, scaling, save and validate code, output files, tests and example testset. Each ticket leaves the package loadable and the tests passing.

The fourth ticket removes the examples and docs and makes the CHANGELOG edits.

This gives:
- one commit per entity that `git revert` can restore cleanly, in case the lab later wants an entity back as a methodology prospect;
- clean bisection;
- smaller, reviewable diffs.

### costs

- SystemData's positional arity is edited three times (7 to 6 to 5 to 4). Each edit also touches the six positional test constructions and the apply-scaling rebuild in scaling.jl.
- The `__add_load_balance!` signature is edited three times.
- `all_gen` and `all_costs` in scaling.jl are edited twice.
- The hydro-balance helpers are edited once, but test-load-blocks.jl is revisited in every ticket.
- Three full test and review cycles are needed instead of one.
- It has more tickets than R9's "fewest tickets that keep each atomic".
- The end state of the code is identical to the simplest option. The only lasting gain is commit granularity, and it serves a reinstatement scenario that is speculative, not stated.

## chosen

`simplestViable`

## reversibility

`two-way`

## rationale

The choice is only about how the plan is cut into tickets, and both options leave identical code. The irreversible items, the API, schema and output-file removals, are already decided by R1-R6 and R10. So this is a two-way door, and the two-ticket plan wins on R9's fewest-tickets rule.

## confidence

85

## gaps

- R7's "same output files" cannot be shown by diffing outputs from SDDP.Threaded() runs, because they vary from run to run regardless of this change. Evidence must come from subproblem-level dumps, or from output diffs under the Serial scheme or `--threads=1` with a fixed seed. This does not block the plan; it constrains how verification is done.

## oneWayDoors

- Removal of the exported Julia API, which is breaking for any external caller: 6 types, 6 accessors, 5 Lab symbols and SystemData's positional arity going from 7 to 4. It is accepted with no deprecation path because it never shipped: v3.0.0 is untagged and the branch is unmerged. Already decided by R1-R3, R6 and R10.
- Removal of the three system.jsonc keys and the six output file names. Stale keys are then silently ignored by the generic reader, and no code handles them specifically. Already decided by R4, R6 and R10.

## twoWayDoors

- How the plan is cut into tickets: 2 tickets (code and tests, then examples, docs and CHANGELOG) versus 1 ticket versus 4 per-entity tickets. The end-state code is identical in every case.
- Where the two example testsets in test-examples-tutorial.jl go. T1 is recommended, so the src/ and test/ grep gate is clean after T1. The examples still run after T1 because stale keys are ignored, so placing the testsets in T2 would also pass.
- Edit order inside T1, such as consumers first (engine and Lab) and then the System layer. It affects only how the diff reads, not the final state.
- How R7 is verified: a one-off, uncommitted subproblem dump and diff versus committing an LP-identity regression test. The one-off check is chosen, per R6 and R9.

## contracts

- Final internal signatures after T1: `SystemData(buses::Buses, lines::Lines, hydros::Hydros, thermals::Thermals)`; `add_hydro_balance!(m, hydros::Hydros, block_mode::Symbol, tau_k::Vector{Float64}, num_blocks::Int)`; `add_hydro_balance_parallel!(m, hydros, zeta::Float64, w_k, num_blocks)`; `add_hydro_balance_chronological!(m, hydros, zeta_k, w_k, num_blocks)`; `__add_load_balance!(m, scenarios, node, load_scale, bus_ids, num_blocks, hydro_bus_map, thermal_bus_map, line_target_map, line_source_map)`. `_build_bus_index_map(entities, ids, bus_field)` stays unchanged, because `bus_field` is still used for `:target_bus_id` and `:source_bus_id`.
- Correction to the intake inventory: src/Engines/sddp/save_simulation.jl lines 65-71, the unscale-factor `elseif sym == NC_GENERATION ... PUMP_POWER` chain, must also be removed. It is a runtime trap. The package still loads with the symbols gone, but every symbol that reaches those branches, such as THERMAL_GENERATION_COST, MARGINAL_COST, WATER_VALUE or STAGE_COST, throws UndefVarError during scaled simulation output. The precompile workload does not exercise SDDPlab paths, so precompilation does not catch it.
- Per-ticket gate: in Julia, a successful `using SDDPlab` does not prove a clean removal, because global names inside function bodies are resolved only at call time. Gate T1 on all of: (a) `git grep -n -i -E` over `src/` and `test/` returns no hits, using the intake pattern extended with internal plumbing names. That extended pattern is: `noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage|pump|contract|curtail|\bnc_|num_nc`. (b) `julia --project -e 'using Pkg; Pkg.test()'` passes. (c) JuliaFormatter in Blue style (`.JuliaFormatter.toml`) leaves the touched files unchanged, because CI runs format_check.yml and the shorter signatures will reflow. Gate T2 on the same extended grep over the whole repo, excluding `plans/` and `LICENSE`, plus a docs build. The intake's original pattern misses `pump_source_map`, `pump_dest_map`, `contract_bus_map`, `pumping_bus_map`, `nc_bus_map`, `num_nc`, `num_contracts`, `source_pump` and `dest_pump`, so orphaned parameters could survive it. Leave `hydro_ids` out of the grep: it is legitimately used in hydro-validators.jl. The build.jl local of that name must still be removed.
- R7 identity argument for entity-free systems:
- The NC, contract and pump variables were never created, because each method returned early on an empty collection, so variable creation order is unchanged.
- Empty-generator `sum`s inside `@constraint` contributed no terms through MutableArithmetics.
- The `init = 0.0` pump sums and the `tau_k[k] * 0.0` objective branches only added +0.0 to constants.
- Taken together, LOAD_BALANCE, HYDRO_BALANCE (parallel and chronological) and the stage objective stay bit-identical.
- The scaling inputs `all_gen` and `all_costs` only lose empty splats, so every retained factor is bit-identical.
- `ScalingConfig.factors` loses the keys NC_GENERATION, CONTRACT_DISPATCH and PUMPED_FLOW. This only shortens the `@info \"AutoScaling applied\"` log line. The identity predicate in save_simulation.jl:21 is unchanged, because the removed values duplicated retained ones.
- R7 verification, a one-off check that is not committed (per R6/R9): on the remaining examples that exercise both block modes and Markov (1dtoy, 1dtoy_per_stage_blocks, load_blocks, 4ree, markov_var), dump each node's subproblem before and after T1 with `JuMP.write_to_file(model.nodes[i].subproblem, ...)` and diff the files. If output files are compared, use the Serial parallel scheme or `--threads=1`, because SDDP.Threaded() runs are not deterministic run to run, independently of this change.
- No change to schema.jl, FieldRule or any Utils helper: each helper used by the entity validators either lives in the deleted dedicated files or has other consumers. test/runtests.jl auto-discovers test files and needs no edit.
- No adjacent cleanup (R7): leave the abstract `Integer`/`Real` fields on the remaining entities, the positional SystemData construction in tests and the `_build_bus_index_map` naming untouched.

## questionsForUser

_none_
