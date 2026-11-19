# Design council sign-off

- **Plan:** `plans/remove-system-entities`
- **Stage:** signoff (P3, `design-council` workflow run `wf_f6d88d66-35c`, 2026-11-10)
- **Roster:** `hpc-julia-developer` (Julia / JuMP / scientific), `sddp-specialist` (SDDP / stochastic optimization) — operator-reduced roster, see `design/intake.md` §(c)
- **Routing:** ADR-002 → Julia seat; ADR-003 → SDDP seat; ADR-001 and ADR-004 (cross-cutting) → both seats. Each seat saw only its own domain's decisions plus the chain contracts of both briefs (independence rule, `skills/plan/references/design-brief.md`).
- **Schema:** `SIGN_OFF` per `skills/plan/references/design-brief.md`

## Summary

| Seat | Domain | Verdict | Objections |
| --- | --- | --- | --- |
| `hpc-julia-developer` | Julia / JuMP / scientific | **APPROVE** | none |
| `sddp-specialist` | SDDP / stochastic optimization | **OBJECT** | ADR-003 |

## `hpc-julia-developer` — Julia / JuMP / scientific

### verdict

`APPROVE`

### reasoning

I checked all three decisions against the code at d16b8ee. None of them is wrong for the Julia / JuMP domain.

ADR-001 (three tickets, consumers first). My brief said consumers-first "does not work" because SystemData's 7-argument positional constructor is shared by apply_scaling and six test fixtures. That was too strong. The real constraints are narrower:
1. A type must not be deleted before its signature consumers, because Julia resolves annotations such as `::NonControllables` and `::Vector{EnergyContract}` at load time.
2. The arity must not change in a ticket that leaves any positional call site unchanged.

The chosen cut satisfies both. ticket-001 removes every engine-side consumer and leaves apply_scaling and the 7-field struct alone. ticket-002 changes the arity together with apply_scaling (scaling.jl:216) and all six fixtures: test-scaling.jl at 4 sites, test-load-blocks.jl:91 and test-per-stage-blocks.jl:57. git grep shows no other positional SystemData call in src or test. Only the 2-argument Dict and filename constructors exist elsewhere, and they do not conflict with the 4-field default constructor.

I also checked for the trap that matters most in Julia, an undefined global inside a function body that fails only when called:
- apply_scaling (scaling.jl:117-225) reads only STORED_VOLUME, HYDRO_GENERATION, THERMAL_GENERATION, FLOW_SCALE, DIRECT_EXCHANGE and COST_SCALE. It reaches the entity collections only through field access, so removing the five Lab symbols in ticket-001 leaves no UndefVarError path.
- Outside the four engine files, Lab.jl, variables.jl and SDDPlab.jl, the only reference to the five symbols (case-insensitive search) is the `curtailment_cost` field in System.jl, which is a field name, not a symbol use, and is deleted in ticket-002.
- The three dedicated System tests use no engine code or Lab symbols, so they still pass after ticket-001.
- The symbol exports in SDDPlab.jl and Lab.jl sit mid-list, so deleting those lines cannot leave a dangling comma.
- The tutorial testsets for renewable_contracts and pumped_storage only assert `@test true`. Both models stay feasible after ticket-001: the pump has min_m3s 0 and buses have deficit. AC4 runs the full Pkg.test() anyway.

The edits really are disjoint: scaling.jl 1-102 vs 117-225, the Lab vs System blocks of SDDPlab.jl, and test-load-blocks.jl 348-544 vs 88-92. Keeping the whole LP diff inside ticket-001 makes the hpcFencedPaths byte-identical subproblem check cleaner than the two-ticket option would. This is a two-way door with no rework, so I accept the departure from my brief.

ADR-002 (delete parameters and fields outright, positional arity 4). This is correct for Julia:
- Empty-default parameters would be dead, entity-shaped signature surface that R6 forbids.
- A keyword constructor is an adjacent refactor that R7 forbids.
- Nothing persists SystemData to disk. I found no Serialization, JLD2 or BSON use. hash_config covers the raw engine params dict, not the system dict, so reproducibility metadata hashes are unaffected.
- With the outer 2-argument constructors, the 4-argument default constructor creates no method ambiguity.
- The final signatures match my chain contract.

ADR-004 (new branch from feat/sddp-flexible-lab, normal commits). This raises no Julia-domain concern. It satisfies R8 and R13, and the untracked plans/remove-system-entities/ directory carries over when the branch is created.

One transient state is acceptable. Between ticket-001 and ticket-003, docs/src/api/variables.md still has @docs entries for the removed symbols. With `warnonly = true` this only produces Documenter warnings, it exists only on the branch, and ticket-003 clears it.

Relevant files: /home/carlosribeiro/git/sddp-lab/plans/remove-system-entities/00-master-plan.md, /home/carlosribeiro/git/sddp-lab/plans/remove-system-entities/epic-01-remove-system-entities/ticket-001-remove-entity-model-footprint.md, /home/carlosribeiro/git/sddp-lab/plans/remove-system-entities/epic-01-remove-system-entities/ticket-002-remove-entity-system-layer.md, /home/carlosribeiro/git/sddp-lab/src/Engines/sddp/scaling.jl, /home/carlosribeiro/git/sddp-lab/src/System/systemdata.jl.

### objections

_none_

## `sddp-specialist` — SDDP / stochastic optimization

### verdict

`OBJECT`

### reasoning

I approve ADR-001 and ADR-004. I object to ADR-003. The decision itself is right: use the existing suite plus a one-off, uncommitted before/after dump instead of a committed harness. But the dump as specified leaves out the objective vector c, which is the one part of the LP that ticket-001 rewrites by hand.

ADR-001 (three tickets, consumers first) is sound for SDDP. Every LP-affecting edit lands in ticket-001, which is where the R7 check runs. I confirmed that the transient branch-local state cannot break anything. apply_scaling (scaling.jl:117-224) reads the entities only through field access and never references any of the five Lab symbols, so deleting the symbols in ticket-001 does not create a runtime failure when apply_scaling is called. The renewable_contracts and pumped_storage testsets in test/test-examples-tutorial.jl contain only `@test true`, so the transient "parsed but not modeled" commit can neither fail them nor hide a failure. Ticket-002 is LP-neutral by construction. If its 7-to-4 SystemData call in apply_scaling were misordered, the typed fields would make it fail at construction.

ADR-004 (new branch from feat/sddp-flexible-lab, no history rewrite) does not affect the formulation, and I approve it.

ADR-003 has an SDDP.jl-specific gap. The ticket-001 script calls SDDPlab.build(study) and then SDDP.write_subproblem_to_file(node, ...) right away. Two facts mean the written subproblem has no objective:
- In SDDPlab, add_system_objective! runs inside the builder (build.jl:910), and its SDDP.@stageobjective call only stores the expression via set_stage_objective. That sets node.stage_objective and stage_objective_set=false; it does not put the expression into the JuMP model.
- SDDP.jl installs `stage_objective + theta` into the JuMP model only in parameterize(node, noise) -> set_objective(node) (SDDP.jl algorithm.jl:217-238, 305-308). The PolicyGraph constructor only sets the objective sense and calls the builder (user_interface.jl:997-998).

So every dumped LP minimizes 0, and AC3 checks A, b, l, u and the row/column order but not c. The only c-changing edit in this plan is deleting build.jl:435-453 and closing the generator on the spillage term before `) + penalty`, and nothing else checks it either. No test asserts an SDDPlab stage objective or a trained bound: the example testsets are `@test true`, and test-scaling.jl:408 checks only an unscale factor. If that edit dropped the spillage term or moved `penalty` inside the k-sum, the package would still load, Pkg.test() would still pass, and AC3 would still be byte-identical. That would silently break R7's "same LP model".

The fix keeps ADR-003's option and cost (one-off, uncommitted, low complexity): in the dump script, call SDDP.parameterize(node, first(node.noise_terms).term) on each node before SDDP.write_subproblem_to_file. This is deterministic, because the SAA is seeded through generate_saa(..., scenarios.seed) with hash(seed, hash(state)) in build.jl:712-719, and before and after run on the same machine and Julia version. Each file then contains the full (c, A, b, l, u), including theta and the fixed omega_INFLOW values.

Two non-blocking notes:
1. A byte-identical diff is stricter than the value-based comparison in my chain contract. That is acceptable, because a mismatch routes to STOP/CLARIFICATION and can never cause an expected value to be edited. If a mismatch appears, re-read both files through MOI and compare coefficients with a ULP tolerance before declaring an R7 violation, since signed zeros or formatting can differ.
2. Rerunning the same uncommitted script after ticket-002 against the saved lp-before costs nothing, and gives direct evidence that ticket-002's apply_scaling edit is LP-neutral.

The rest of the formulation contracts hold:
- The only state variables are STORED_VOLUME and STCHP, so the cut format and beta in R^{n_x} are unchanged.
- The removed scaling keys copy the HYDRO_GENERATION or STORED_VOLUME values, so _is_identity_scaling (save_simulation.jl:20-21, an all() over the values) gives the same result.
- The empty-collection early returns and the +0.0 constants keep the LP identical for entity-free systems.

Source files checked: /home/carlosribeiro/git/sddp-lab/src/Engines/sddp/build.jl, /home/carlosribeiro/git/sddp-lab/src/Engines/sddp/scaling.jl, /home/carlosribeiro/git/sddp-lab/plans/remove-system-entities/epic-01-remove-system-entities/ticket-001-remove-entity-model-footprint.md, and the upstream SDDP.jl src/algorithm.jl and src/user_interface.jl.

### objections

- **ADR-003** — The R7 dump writes each node right after SDDPlab.build(study), before any SDDP.parameterize call. SDDP.jl installs the stage objective (node.stage_objective + theta) into the JuMP model only in parameterize(node, noise) -> set_objective(node). In SDDPlab, add_system_objective! calls @stageobjective inside the builder (build.jl:910), which only stores node.stage_objective. So every dumped .lp file has an empty objective, and AC3 never compares c. The only c-changing edit in this plan is deleting the curtailment and contract terms at build.jl:435-453 and closing the generator on the spillage term before `) + penalty`. No test covers it either: the example testsets are `@test true`, and no test asserts an SDDPlab stage objective or bound. A broken edit, such as a dropped spillage term or `penalty` moved inside the k-sum, would pass Pkg.test() and a byte-identical AC3, silently violating R7. Required amendment, keeping the same one-off and uncommitted scope: in the dump script, call SDDP.parameterize(node, first(node.noise_terms).term) on each node before SDDP.write_subproblem_to_file. This is deterministic because the SAA is seeded via generate_saa(..., scenarios.seed). Each file then carries the full (c, A, b, l, u), including theta and the fixed omega_INFLOW values. Also recommended: on any byte mismatch, compare coefficient values with a ULP tolerance before declaring an R7 violation, and rerun the same script after ticket-002 against the saved lp-before.

## Resolution (orchestrator, 2026-11-10)

The operator's standing instruction for this run is to take the recommended alternative at every gate. The single objection is resolved as follows:

| Objection | Severity | Resolution |
| --- | --- | --- |
| `sddp-specialist` on **ADR-003**: the ticket-001 R7 dump writes each node's subproblem before any `SDDP.parameterize` call, so the written LP carries no objective vector `c`, and AC3 cannot detect a broken edit of the stage objective (the one hand-rewritten `c`-affecting edit in this plan, `build.jl:435-453`). | **major** — it blinds the R7 gate on exactly the term ticket-001 rewrites by hand. | **ACCEPTED.** The decision's chosen option (one-off, uncommitted dump; no committed harness) stands; the amendment is to the dump procedure: call `SDDP.parameterize(node, first(node.noise_terms).term)` on every node before `SDDP.write_subproblem_to_file`, so each file carries the full `(c, A, b, l, u)` including `theta` and the fixed `omega_INFLOW` values (deterministic: the SAA is seeded through `generate_saa(..., scenarios.seed)`). Also adopted, as recommended: on a byte mismatch, re-read both files through MOI and compare coefficients with a ULP tolerance before declaring an R7 violation; and re-run the same uncommitted script after ticket-002 against the saved `lp-before` as direct evidence that the `apply_scaling` edit is LP-neutral. Carried into the P4 round-1 planner REVISION as a `major` sign-off objection (ADR-003 is superseded or amended there, per the ADR authoring rules), together with the round's acknowledged critique findings. |

Both `APPROVE` verdicts on ADR-001 (the three-ticket consumers-first cut that departs from both briefs), ADR-002 and ADR-004 are recorded as-is. The `hpc-julia-developer` seat explicitly withdrew its brief's claim that the removal "cannot be split by layer" after checking the code at `d16b8ee`.
