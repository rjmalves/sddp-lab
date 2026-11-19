# Design brief: `sddp-specialist`

- **Plan:** `plans/remove-system-entities`
- **Stage:** brief (P2 council, `design-council` workflow run `wf_4e3dc635-449`, 2026-11-10)
- **Context read:** `design/intake.md` only (independent brief; this consultant did not see the other seat's brief)
- **Schema:** `DESIGN_BRIEF` per `skills/plan/references/design-brief.md`

## domain

SDDP / stochastic optimization

## meetsAllStated

true

## simplestViable

### description

A delete-only edit of the stage subproblem and its scaling. With the index sets J_nc, J_c and J_p gone, remove the following. (i) The three add_system_elements! methods for NonControllables, EnergyContracts and PumpingStations (build.jl:99-134 and 200-218) and the three dispatch calls (build.jl:224-226). (ii) The pump terms: -/+ zeta*sum_k w_k*PUMPED_FLOW in add_hydro_balance_parallel!, and source_pump/dest_pump in _net_flow_expr of add_hydro_balance_chronological!. Also remove the pump_source_map/pump_dest_map parameters from add_hydro_balance!, from both variants and from the call at build.jl:880, together with the hydro_ids local at build.jl:843, which is now dead. (iii) The NC_GENERATION, CONTRACT_DISPATCH and PUMP_POWER terms in __add_load_balance!, its five entity parameters (noncontrollable_bus_map, contract_bus_map, contracts_entities, pumping_bus_map, pumping_entities) and the five bus/hydro map locals that feed them (build.jl:839-853). (iv) The curtailment and contract objective terms and the num_nc/num_contracts locals in add_system_objective!. (v) In scaling.jl: the NC and contract entries of all_gen and all_costs, the NC_GENERATION, CONTRACT_DISPATCH and PUMPED_FLOW keys in both compute_scaling_factors and no_scaling_config, and the three rebuild blocks in apply_scaling. (vi) The branches for the five symbols in _get_variable_unscale_factor (save_simulation.jl:65-72). The intake inventory misses these. The test oracle is the existing suite, which must pass with no retained numeric expectation edited.

### forgoes

A recorded, mechanical proof that the LP is identical, such as a diff of every node subproblem or golden LP fingerprints. R7 rests instead on the structural argument: with J = {} every removed term is an empty sum or tau_k*0.0, and no columns were ever created. It also rests on the existing tests, and every scaling fixture in test-scaling.jl already uses empty entity collections.

## mostDurable

### description

The same delete-only edit, plus a committed regression harness for LP identity. For each remaining example, it fingerprints every node subproblem as sorted (c, A, b, l, u) triplets, compared by value with a ULP tolerance and never as text. It also records a seeded, serial lower-bound trajectory. Both are captured as golden files on feat/sddp-flexible-lab and asserted after the removal. The harness could be reused for the further scope reductions the operator has announced.

### costs

About one extra ticket of test infrastructure and golden files, plus maintenance on every intended formulation change. Golden LP data is brittle across JuMP, MOI and solver upgrades. It also breaches R7 and R9 (work beyond the removal) and goes against the spirit of R6's ban on adding new tests.

## chosen

`simplestViable`

## reversibility

`two-way`

## rationale

The removal leaves the state vector, cut dimension and SDDP cut-file format unchanged, so nothing persisted in this domain is a one-way door. How deeply to verify can be decided again cheaply: a golden-LP harness can be added when a later simplification actually needs it.

## confidence

88

## gaps

- Accepted non-guarantee, outside R7: a cut file trained on a system that used any of the removed entities would still load through SDDP.read_cuts_from_file, because the state names are the same. Its cuts are not guaranteed to be valid lower bounds of the reduced model, though. Removing forced contract dispatch (min_mw > 0) or NC generation changes V_t in either direction, not monotonically. R6 forbids adding a guard, and such policies exist only on the untagged, unmerged branch, so the practical risk is negligible.

## oneWayDoors

_none_

## twoWayDoors

- How deeply to verify: the existing suite as the oracle (chosen). An optional, uncommitted before/after diff of node subproblems can use the existing debug writer (src/Engines/sddp/debug.jl) on one remaining example. A committed golden-LP harness is deferred until a future simplification needs it.
- Ticket granularity for the formulation edits: one ticket for all three entities, or one ticket per entity. Per-entity tickets change the positional arity of SystemData three times (7 to 6 to 5 to 4), which also hits apply_scaling and the six positional SystemData call sites in tests three times. The pump ticket alone also changes the signatures of the three hydro-balance functions and five testsets in test-load-blocks.jl. The implementation consultant should make this call.
- Keep _build_bus_index_map unchanged: its bus_field parameter is still used by the line maps (:target_bus_id and :source_bus_id), so this removal makes nothing in the helper dead.

## contracts

- Invariance proof for R7: when J_nc, J_c and J_p are all empty, every node subproblem has identical (c, A, b, l, u) and identical row and column order before and after the change. The reasons: add_system_elements! returns early without creating columns; every removed load-balance or hydro-balance term is an empty sum; the objective terms add tau_k*0.0; and in the chronological variant the constant becomes 0.0 - 0.0 + 0.0 = +0.0, exactly as today. Load-balance duals (marginal cost) and hydro-balance duals (water value) are therefore unchanged.
- Scaling invariance: max_gen and max_cost are maxima over the hydro, thermal and bus sets united with an empty set, so they are identical. The removed keys NC_GENERATION and CONTRACT_DISPATCH copy the HYDRO_GENERATION value, and PUMPED_FLOW copies STORED_VOLUME, so the set of values in ScalingConfig.factors is unchanged and _is_identity_scaling gives the same result. The only visible change is three fewer entries in the '@info AutoScaling applied' log line, which is not a persisted format.
- State-space and policy invariance: the only SDDP.State variables are STORED_VOLUME and STCHP (build.jl:143, 509, 619), and the entities add only control variables. So n_x, the cut coefficients beta in R^{n_x}, and the JSON from SDDP.write_cuts_to_file / read_cuts_from_file are unchanged. The policy format is not a door in this plan.
- Stochastic invariance: the entity parameters are deterministic (max_generation, min_mw/max_mw, min_m3s/max_m3s), and src/Scenarios and src/StochasticProcess are untouched. Omega, the SAA and how the RNG is consumed are unchanged, so a fixed seed gives the same forward sample paths.
- Load-order constraint for hpc-julia-developer: the add_system_elements! methods dispatch on NonControllables, EnergyContracts and PumpingStations, and __add_load_balance! has parameters typed Vector{EnergyContract} and Vector{PumpingStation}. The build.jl, scaling.jl, save_simulation.jl and validate.jl edits for an entity must therefore land in the same ticket that deletes that entity's types, or the package will not load.
- Acceptance criterion: any change needed to a retained numerical expectation (scaling factors, bounds, simulation values) means R7 has been violated and must be investigated. It must not be fixed by updating the expected value. Compare equivalence by value with ULP or approx tolerance, never by LP text diff, which can differ in signed zero or formatting. Compare bound trajectories from serial runs, because SDDP.Threaded() changes the order cuts are added in, independently of this change.
- Inventory addition: the five-symbol branches of _get_variable_unscale_factor at save_simulation.jl:65-72 must also be deleted under R10. The intake lists only save_simulation.jl:377-379 and 401-405.

## questionsForUser

_none_
