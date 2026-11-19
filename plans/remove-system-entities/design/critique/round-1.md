# Design critique — round 1

- **Plan:** `plans/remove-system-entities`
- **Scope:** design (rubric: `skills/assess/references/assessment-rubrics.md` §Design)
- **Mechanism:** `assess` workflow run `wf_11c8ade8-340` (adversarial-attacker → adversarial-defender), 2026-11-10
- **Files in scope:** 10 (master plan, README, `design/intake.md`, both council briefs, `design/signoff.md`, epic overview, tickets 001–003)
- **Attacker signal:** 1 new finding(s)

## Summary

| ID | Severity | Direction | Category | Verdict |
| --- | --- | --- | --- | --- |
| F1-001 | HIGH | UNDER | Design / verification durability (R7) | **ACKNOWLEDGED** |

## F1-001 — Design / verification durability (R7) (HIGH, UNDER)

### Location

plans/remove-system-entities/00-master-plan.md:93-112 (ADR-003), :195, :297; epic-01-remove-system-entities/ticket-001-remove-entity-model-footprint.md:244-266 (R7 dump), :79; ticket-002-remove-entity-system-layer.md:216; design/signoff.md:101 (accepted rerun-after-ticket-002 remedy)

### Attack (adversarial-attacker, in full)

**Evidence.** The ADR-003 dump builds each example with its own engine config: `study = SDDPlab.read_study(...); model = SDDPlab.build(study)` (ticket-001:249-250). No example sets a scaling mode: `git grep -i scal -- example/` only matches inflow `scale_parameters` in 1dsin_ar. `__build_scaling!` falls back to `NoScaling()` when the key is missing (src/Engines/sddp/input.jl:805-807), and docs/src/configuration/overview.md lists the `scaling` default as `NoScaling`. `_apply_engine_scaling(::NoScaling, files)` returns `(no_scaling_config(), files)` (src/Engines/sddp/build.jl:22-26), so neither `compute_scaling_factors` nor `apply_scaling` runs during the dump. factors.txt is therefore the literal `no_scaling_config()` table (all 1.0), and every dumped LP is the unscaled one. Both scaling edits are on the AutoScaling path and nothing in the dump exercises it. ticket-001 deletes 13 lines of `compute_scaling_factors` by line number (scaling.jl 27, 30-31, 36-37, 42-43, 61, 74-75). ticket-002 rewrites `apply_scaling` and says 'The LP is not re-dumped here' (ticket-002:216). The sign-off remedy already accepted (signoff.md:101), 're-run the same uncommitted script after ticket-002 ... as direct evidence that the apply_scaling edit is LP-neutral', uses the same NoScaling engine, so `apply_scaling` is never called. ticket-002 also edits the same file that ticket-001 lists in `hpcFencedPaths`, but its own frontmatter declares no fence, so no bit-exact evidence is required for that edit. The existing tests do not close the gap. All test-scaling.jl fixtures use `System.Lines(System.Line[])`. Bus deficit cost is larger than thermal cost in both cost fixtures (50 vs 10 at lines 153/189, 100 vs 5 at lines 225-228). No test asserts the FLOW_SCALE, OUTFLOW, DIRECT_EXCHANGE or REVERSE_EXCHANGE values that `compute_scaling_factors` produces. The AutoScaling end-to-end test (test/test-main.jl:436-472) compares only the unscaled lower bound within 1%, and that bound does not change under any self-consistent change to the factors.

**Impact.** R7 requires 'same LP model, scaling factors' for entity-free systems, and the codebase has two scaling variants. The plan's only LP-identity evidence covers the NoScaling one. Example: one off-by-one in the line-number edit, such as deleting `[Float64(t.cost) for t in thermals]...,` (scaling.jl:73) together with the adjacent 74-75. COST_SCALE, and with it every scaled objective coefficient, then changes for any AutoScaling study whose highest thermal cost exceeds its highest deficit cost. test-scaling.jl still passes because deficit cost dominates in both fixtures. test-main's 1% unscaled-bound check passes. AC3's byte-identical dump passes. Pkg.test() passes. R7 is silently broken for AutoScaling users. The Success Metric 'factor files that differ only by the three removed keys' (00-master-plan.md:297) is met vacuously. The same blindness applies to ticket-002's `apply_scaling` rewrite, which the plan calls 'LP-neutral by construction' and checks with nothing beyond those fixtures. The fix stays within ADR-003's one-off, uncommitted, low-complexity option: in the dump script, build each example a second time with the engine's scaling replaced by `Engines.AutoScaling()` (the pattern test-main.jl:436-457 already uses via `SDDPlab.Study(original.inputs, autoscale_engine)`), dump those subproblems and `model.scaling.factors`, and repeat that variant after ticket-002.

### Defense (adversarial-defender, in full)

**Verdict:** `ACKNOWLEDGED`

I checked every factual claim against the code at d16b8ee and each one holds.

(1) The dump only ever builds with NoScaling. None of the five dumped examples sets a scaling mode: `git grep -i scaling -- example/` returns nothing, and the only `scal` hits are the `scale_parameters` lines in 1dsin_ar. When the key is missing, `__build_scaling!` sets `d["scaling"] = NoScaling()` (src/Engines/sddp/input.jl:805-807), and docs/src/configuration/overview.md:150 lists `NoScaling` as the default. In src/Engines/sddp/build.jl:22-26, `_apply_engine_scaling(::NoScaling, files)` returns `(no_scaling_config(), files)`. Only the AutoScaling method (lines 28-38) calls `compute_scaling_factors` and `apply_scaling`. The R7 dump script (ticket-001:247-265) calls `SDDPlab.build(study)` on the study exactly as read, so neither function runs. factors.txt is therefore the literal all-1.0 `no_scaling_config()` table (scaling.jl:84-105), and every dumped LP is unscaled.

(2) Both scaling edits sit on the path the dump never takes. ticket-001 deletes scaling.jl lines 27, 30-31, 36-37, 42-43, 61 and 74-75 by line number (ticket-001:112). Line 73 (`[Float64(t.cost) for t in thermals]...,`) is right next to 74-75. ticket-002 rewrites `apply_scaling` and says 'The LP is not re-dumped here' (ticket-002:216). The rerun remedy accepted in signoff.md:101 reuses the same NoScaling script, so `apply_scaling` is still never called. ticket-002's frontmatter (lines 1-25) has no `hpcFencedPaths`, while ticket-001:14 fences scaling.jl.

(3) The existing tests do not close the gap. Every fixture in test/Engines/sddp/test-scaling.jl uses `System.Lines(System.Line[])` (lines 154, 226, 261, 306). Deficit cost is at least the thermal cost in every cost fixture: 50 vs 10 (153/189), 100 vs 5 (225/228), and 50 vs 5/10 (305, 69-70 of the apply test). So dropping the thermal splat from `all_costs` leaves COST_SCALE unchanged in every test. No test asserts DIRECT_EXCHANGE, REVERSE_EXCHANGE, OUTFLOW or FLOW_SCALE from `compute_scaling_factors`. Line 352 reads `:TURBINED_FLOW`, not FLOW_SCALE. test/test-main.jl:436-472 compares only the unscaled bound (`autoscale_bound_scaled * s_cost * s_gen`) within 1%, and a change of units leaves that bound unchanged by construction.

(4) The plan therefore claims more than it proves. ticket-001:79 promises 'ScalingConfig.factors has the same value for every retained key'. ADR-003 and the Success Metric (00-master-plan.md:195, :297) promise factor files that 'differ only by the three removed keys'. With NoScaling this holds automatically, because every value is 1.0. R7 (00-master-plan.md:28) requires 'same LP model, scaling factors' for entity-free systems, and AutoScaling is a documented, supported mode (overview.md:95).

The defense rules require one of two things for an UNDER finding: `reversibility: two-way` together with a cheap, named rework path, or a ticket that schedules the redo. ADR-003 is two-way, but its `rework_trigger` refers to a future plan's harness, not to this gap, and no ticket adds AutoScaling evidence. A COST_SCALE regression merged unnoticed is not cheap to find later. The only code-side mitigation is that ticket-001:221 says in words that `all_costs` keeps the thermal and bus splats, and nothing verifies that. This is the same class of flaw as the accepted ADR-003 sign-off objection (a gate blind to a hand-edited term), which was rated major, so I rate this major too.

One caveat on the attacker's proposed fix. None of the five dumped examples has a max thermal cost above its max deficit cost: 1dtoy 10 vs 50, load_blocks 50 vs 500, 4ree 937 vs 1420.34, markov_var 25 vs 500. An AutoScaling dump of those examples alone would still miss the specific line-73 mutation. It would still exercise `compute_scaling_factors` and `apply_scaling` (lines in 4ree, real max_gen, FLOW_SCALE and spillage/exchange penalty rescaling), but the thermal cost term needs one extra perturbed case.

### Backlog entry

Severity: major. Problem: the R7 evidence in ADR-003 (ticket-001 AC3, the ticket-001:79 factor-identity promise, the Success Metric at 00-master-plan.md:297, and the signoff.md:101 rerun after ticket-002) runs only under NoScaling, the default, because none of the five examples sets `scaling`. As a result, `compute_scaling_factors` (ticket-001 edits) and `apply_scaling` (ticket-002 rewrite) are never executed by any LP-identity check, and factors.txt is all 1.0. Impact: a mistake in the line-number deletions in scaling.jl, for example dropping the thermal-cost splat at line 73 or the thermal max_generation at line 35, or a mistake in the apply_scaling rewrite, silently changes COST_SCALE or other factors and the scaled LP for AutoScaling users. It still passes test-scaling.jl (deficit cost dominates in every fixture; lines are always empty), test-main.jl:436-472 (it compares only the unit-invariant unscaled bound), Pkg.test() and AC3. R7 is then broken for one of the two scaling modes. Resolution direction (stays within ADR-003's one-off, uncommitted, low-complexity option; planner REVISION of ADR-003, ticket-001 Technical Details 'R7 dump' and AC3, and ticket-002 Testing Requirements): (a) In r7-dump.jl, build each example a second time with the engine's policy scaling replaced by `Engines.AutoScaling()`, using the `SDDPlab.Study(original.inputs, engine)` pattern of test/test-main.jl:436-457. Write those subproblems (after the already-accepted `SDDP.parameterize` step) and that `model.scaling.factors` to a separate `autoscale/` subtree, and extend AC3's two diff commands to cover it. (b) None of the five examples has max thermal cost above max deficit cost, so add one in-script, uncommitted call of `compute_scaling_factors` on an in-memory variant of one example's SystemData where each input category dominates its maximum (thermal cost above deficit cost, thermal max_generation above hydro, non-empty lines). Dump the sorted factors before and after. (c) Make the after-ticket-002 rerun mandatory, not optional: an AC of ticket-002 that diffs the AutoScaling subtree against lp-before and accepts only the three removed keys in the factors files. Give ticket-002 the same `hpcFencedPaths: [src/Engines/sddp/scaling.jl]` fence so this bit-exact evidence is required. Estimated effort: low.

## Disputed findings

_none_ — the only finding was ACKNOWLEDGED by the defender, so the `DISPUTED … Your Call` gate had nothing to present. (Standing operator instruction for this run: take the recommended alternative at every gate.)

## Inputs carried into the round-1 REVISION

1. **F1-001 (ACKNOWLEDGED, major, UNDER)** — the R7 evidence must also cover the AutoScaling path: build each dumped example a second time with the engine's scaling replaced by `Engines.AutoScaling()` (the `SDDPlab.Study(original.inputs, autoscale_engine)` pattern of `test/test-main.jl:436-457`), dump those subproblems and `model.scaling.factors`, and repeat that variant after ticket-002; per the defender's caveat, none of the five dumped examples has max thermal cost above max deficit cost, so one extra perturbed case (thermal cost > deficit cost) is needed to exercise the `all_costs` thermal splat next to the deleted `scaling.jl:74-75`. Stays one-off and uncommitted (ADR-003's option, R6/R9).
2. **Sign-off objection on ADR-003 (`sddp-specialist`, major, ACCEPTED in `design/signoff.md`)** — call `SDDP.parameterize(node, first(node.noise_terms).term)` on every node before `SDDP.write_subproblem_to_file`, so the dump carries `c`; on a byte mismatch compare coefficients through MOI with a ULP tolerance before declaring an R7 violation; re-run the script after ticket-002 against the saved `lp-before`.

## Revision Log (round 1)

Applied by `implementation-planner` in REVISION mode on 2026-11-10, in one pass. Both inputs touch the same decision (ADR-003) and the same ticket procedure (ticket-001 "R7 dump" and AC3), so they are applied as one superseding decision, **ADR-005** (`supersedes: ADR-003`; ADR-003 is now `status: superseded`). No ticket changes shape (no SPLIT, MERGE, ADD or REMOVE), so the Scope Change discipline is not triggered. Every `filesToBe*` block, the requirements R1-R13 and ticket-003 are unchanged.

### F1-001 (ACKNOWLEDGED, major, UNDER)

- **Action: `superseded ADR-003 with ADR-005`.** The option class is unchanged: the existing suite plus a one-off, uncommitted dump, with no committed harness (R6, R9). ADR-005 has `requirements: [R7, R6, R9]`, `reversibility: two-way` and the same `rework_trigger` as ADR-003, which names a future plan's harness outside this plan's horizon.
- **Action: `amended ticket-001 R7 dump + AC3`.**
  - `r7-dump.jl` builds each of the five examples a second time with `Engines.AutoScaling()`, using the `SDDPlab.Study(study.inputs, engine)` pattern of `test/test-main.jl:436-457` through an arity-agnostic `rebuild` helper. It writes those subproblems and factors to `autoscale/<example>/`, and asserts both that each example defaults to `NoScaling` and that the AutoScaling factors are not all 1.0.
  - It also calls `compute_scaling_factors` in-script on an in-memory `4ree` variant. The first thermal gets twice the largest hydro `max_generation` and twice the largest deficit cost, and the variant's lines are non-empty. The script asserts that `THERMAL_GENERATION` and `COST_SCALE` equal the two perturbed values and writes `perturbed/factors.txt`, so a lost splat at `scaling.jl:35` or `:73` now fails.
  - AC3's two comparison commands now cover every subproblem file under `<example>/` and `autoscale/<example>/`, and every `factors.txt` including `perturbed/`. The ticket-001 Outputs/Behavior factor-identity promise (former line ~79) is now backed by evidence under both scaling modes.
  - `$R7` moves from `mktemp -d` to the fixed path `/tmp/sddplab-r7`, outside the repository, and is kept for ticket-002 with a `Manifest.toml` snapshot.
  - `implements:` replaces ADR-003 with ADR-005. Requirement 7, Error Handling, Pitfalls, Testing Requirements, Out of Scope, the Effort rationale and the Definition of Done are updated to match.
- **Action: `amended ticket-002 (hpcFencedPaths, rerun AC)`.**
  - Adds `hpcFencedPaths: ["src/Engines/sddp/scaling.jl"]` (tier already `complex`).
  - Adds AC6, the mandatory rerun of `r7-dump.jl` into `lp-after-002`, checked against ticket-001's `lp-before` with the same two comparison commands. Only the three removed keys may disappear from any factors file.
  - Adds a precondition check of `/tmp/sddplab-r7`, with a detached-worktree fallback that regenerates `lp-before` from the base commit using the current `Manifest.toml`. Both scripts are embedded verbatim, byte-identical to ticket-001's, so the ticket can be implemented in a fresh context.
  - Removes the sentence "The LP is not re-dumped here". `implements:` adds ADR-005 and R7, since AC6 is an R7 check. Requirement 7, Outputs/Behavior, Error Handling, Pitfalls, Testing Requirements, Out of Scope, the Dependencies ordering reason, the Effort rationale and the Definition of Done are updated.
- **Action: prose and README updates.**
  - `00-master-plan.md`:
    - Executive Summary ("bit-identical LP" becomes "the same LP under both scaling modes", because the 4-ULP comparison path exists).
    - Non-Goals and the Specialist Chain now cite ADR-005.
    - Key Design Decisions: an ADR-001 note that the rerun checks ticket-002's LP-neutrality, ADR-003 marked superseded, and a new ADR-005 entry explaining (a) to (e).
    - The Per-ticket gate "Extra" row for ticket-001 and ticket-002, the Testing Strategy paragraph, the Phases & Milestones rows 1-2, the Risk Analysis row on LP change, and the Success Metrics bullet on the dump.
  - `epic-01-remove-system-entities/00-epic-overview.md`: the Exit Criteria bullet on the dump, which named only the ticket-001 NoScaling dump.
  - `README.md`: the Decision Records table (ADR-003 `superseded (by ADR-005)`, new ADR-005 row implemented by ticket-001 and ticket-002), the ticket-001 and ticket-002 Execution Order lines, and ticket-002's Readiness cell, 0.96 to 0.94.
- **Rationale:** The ADR-003 dump ran only under the default `NoScaling`. As a result neither `compute_scaling_factors` (ticket-001's line deletions) nor `apply_scaling` (ticket-002's rewrite) ever ran in an LP-identity check, and no example has a thermal cost above its deficit cost.

### SIGNOFF-ADR-003 (`sddp-specialist`, major, ACCEPTED in `design/signoff.md`)

- **Action: `superseded ADR-003 with ADR-005`.** This is the same superseding decision as F1-001, with `council: { recommended_by: [sddp-specialist], objected_by: [] }`, because the parameterize amendment came from that seat.
- **Action: `amended ticket-001 R7 dump + AC3`.**
  - `dump_model` calls `SDDP.parameterize(node, first(node.noise_terms).term)` before every `SDDP.write_subproblem_to_file`, so each file carries `c`, including `theta` and the fixed `omega_INFLOW` values. This is deterministic, because all five examples set `seed`.
  - A new uncommitted `r7-compare.jl` re-reads both files through MOI (`JuMP.read_from_file`) and compares the objective, rows and bounds within 4 ULP.
  - AC3 accepts a byte mismatch only when that comparison prints `ULP-EQUIVALENT`. Any other mismatch, or an "Only in" file, prints `R7 VIOLATION` and routes to STOP / `CLARIFICATION REQUIRED`. Error Handling forbids editing an expectation, either script, the tolerance or `lp-before`.
- **Action: `amended ticket-002 (hpcFencedPaths, rerun AC)`.** The rerun after ticket-002 against the saved `lp-before`, which the sign-off recommended, is now the mandatory AC6, with the same MOI/ULP rule.
- **Rationale:** SDDP.jl installs the stage objective into the JuMP model only inside `parameterize`. The ADR-003 dump therefore carried no objective vector and could not see the hand-edited objective terms at `build.jl:435-453`.

### Planner-authored details (recorded, not new decisions)

- **4-ULP tolerance.** The sign-off asked for "a ULP tolerance" without a value. `r7-compare.jl` uses `a == b || abs(a - b) <= 4 * eps(max(abs(a), abs(b)))`, so signed zeros compare equal. This is a two-way detail of an uncommitted script, and byte identity remains the expected outcome. Factor values are compared exactly, because `repr(::Float64)` round-trips.
- **Fixed path `/tmp/sddplab-r7`.** Replaces `mktemp -d` so that the fresh-context ticket-002 can find ticket-001's base dump. The `Manifest.toml` snapshot and the detached-worktree fallback cover a reboot, another machine or a changed environment. Both fallbacks run `git worktree prune` before `git worktree add`, and copy the Manifest into the worktree, so both dumps use the same package versions.
- **Verification during revision.** `r7-compare.jl` and both comparison commands were exercised on synthetic LP files in a scratch environment (JuMP 1.32.1, MOI 1.54.0), covering byte-identical, ULP-different, value-different, "Only in" and changed-factor cases. `r7-dump.jl` could not be run, because SDDP.jl is not installed locally. Its SDDPlab API uses (`Lab.build` scaling dispatch, `SDDPModel`, `Study`, `SDDPEngine` / `SDDPPolicyTaskDefinition` fields, `get_system`, entity fields, `compute_scaling_factors`) were checked against the source at `d16b8ee`. Its SDDP.jl uses follow the sign-off seat's citations and the existing `src/Engines/sddp/debug.jl` writer call.
- **Left unchanged by dispatch scope.** In `README.md`, the Navigation line ("decisions ADR-001 to ADR-004") and the Specialist Chain block (`...; ADR-003`) still name the synthesis-time ids.

### Readiness re-scores (rubric `rubrics/readiness.md`, gate 0.85)

| Ticket | Structure | Testability | Boundary | Dependency clarity | Atomicity | Composite |
| --- | --- | --- | --- | --- | --- | --- |
| ticket-001 | 1.0 | 1.0 | 1.0 | 1.0 | 0.6 (5 ACs, 8 files) | 0.96 (unchanged) |
| ticket-002 | 1.0 | 1.0 | 1.0 | 1.0 | 0.4 (6 ACs, 18 files) | 0.94 (was 0.96) |
