# ticket-028 Add Stage Time Duration and MW-to-MWh Conversion

## Agent Assignment

- **Primary**: `sddp-specialist`
- **Reviewer**: `hpc-julia-developer` (verify integration with existing build pipeline, scaling system, and variable units registry)

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Make the LP subproblem use proper energy and volume units everywhere. Currently, SDDPlab treats costs in $/MW and water flows in m³/s without converting to energy (MWh) and volume (hm³) units. This ticket computes stage duration from the existing `start_datetime`/`end_datetime` on graph nodes, derives the time conversion parameters (τ, ζ, w_k), and modifies ALL constraint equations and objective terms to use energy (MWh) and volume (hm³) units.

### Design Decisions (resolved by user)

1. **Stage duration is always derived** from the existing `start_datetime` and `end_datetime` fields on graph nodes. No new user input is needed for single-block stages. The duration in hours is `Dates.value(end_datetime - start_datetime) / 3600000`.

2. **Block durations are mandatory when >1 block exists**. If the user defines multiple blocks within a stage, each block MUST have an explicit `duration_hours`. For a single block (default), the block duration equals the full stage duration.

3. **Unit conversion is NOT optional** — the LP always uses proper energy/volume units:
   - Objective function costs: $/MWh × MW × hours = $ (all terms multiplied by τ_k)
   - Water balance: flows converted to hm³ via ζ = 0.0036 × Σ_k τ_k
   - This is a breaking change to how costs are interpreted. Existing example cases will need their cost parameters reviewed (they were effectively in $/MWh already since stages are monthly and the implicit duration was "1 unit").

4. **No backward-compatible "unit time" mode**. Do the right thing from the start.

### Key Changes

**Time parameters** (computed, not user-specified for single-block):

- `τ_k` = duration of block k in hours (for single block: `end_datetime - start_datetime` in hours)
- `w_k = τ_k / Σ_j τ_j` = block weight (fraction of stage)
- `ζ = 0.0036 × Σ_k τ_k` = time conversion factor (m³/s × hours → hm³)

**Objective function** — all MW-unit costs multiplied by τ_k to produce $:

- Thermal: `Σ_k τ_k × Σ_s c^th_{j,s} × g_{j,k,s}`
- Deficit: `Σ_k τ_k × Σ_b Σ_s c^def × δ_{b,k,s}`
- Exchange: `Σ_k τ_k × c^exch_l × (f⁺_{l,k} + f⁻_{l,k})`
- Contracts: `Σ_k τ_k × c^ctr_c × χ_{c,k}`
- Spillage: `Σ_k τ_k × c^spill_h × s_{h,k}` (becomes $/（m³/s·h) × m³/s × h = $)
- Non-controllable curtailment: `Σ_k τ_k × c^curt_r × (A_r - g^nc_{r,k})`

**Water balance** — flow-to-volume conversion always applied:

- `v_h = v̂_h + ζ × [a_h + Σ_k w_k × net_flows_{h,k}]`

### Data Source

Stage duration is computed from the graph nodes that already exist:

```julia
# In the subproblem builder, per-node:
stage_duration_hours = Dates.value(node.end_datetime - node.start_datetime) / 3600000
```

For multiple blocks (ticket-029), block durations would be specified in the scenarios config and become mandatory:

```json
{
  "blocks": [
    { "name": "LEVE", "duration_hours": 200 },
    { "name": "MEDIA", "duration_hours": 300 },
    { "name": "PESADA", "duration_hours": 228 }
  ]
}
```

This ticket implements single-block only (τ = stage duration). Multi-block is ticket-029.

## Anticipated Scope

- **Files likely to be modified**: `src/Engines/sddp/build.jl` (modify all `add_system_elements!` objective terms and `add_hydro_balance!` to use τ and ζ), `src/Scenarios/Scenarios.jl` or `src/Scenarios/graph.jl` (expose stage duration computation), `src/Lab/variables.jl` (no changes expected — variable symbols stay the same, only coefficients change)
- **Key decisions needed during refinement**:
  - How to pass τ and ζ to the subproblem builder (compute per-node in the `SDDP.parameterize` callback, or precompute per-stage)
  - How the scaling system interacts with τ multiplication (scaling modifies cost coefficients; τ changes effective magnitudes)
  - Whether existing example case cost parameters need adjustment (they were implicitly $/MWh-equivalent for monthly stages)
- **Open questions**:
  - How do existing tests adapt? Unit tests that check objective values will need updating since costs now include the time factor
  - Should ζ be available as a named constant in the subproblem for debugging/inspection?

## Dependencies

- **Blocked By**: ticket-027 (Epic 05 complete)
- **Blocks**: ticket-029

## Effort Estimate

**Points**: 4
**Confidence**: Low (will be re-estimated during refinement)
