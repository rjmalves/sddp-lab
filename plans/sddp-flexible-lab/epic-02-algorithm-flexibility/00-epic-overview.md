# Epic 02: Algorithm Flexibility

## Goal

Expose all SDDP.jl algorithm configuration knobs through the JSONC configuration format. Currently, the SDDPEngine supports a limited set of risk measures (Expectation, WorstCase, AVaR, CVaR), stopping criteria (IterationLimit, TimeLimit, LowerBoundStability), and parallel schemes (Serial, Asynchronous). This epic adds support for all remaining SDDP.jl options: additional risk measures, chained stopping rules, sampling schemes, duality handlers, forward pass strategies, and cut type selection.

## Agent Strategy

This epic benefits from **parallel agent execution**. Tickets 006-011 are mutually independent (each adds a different algorithm knob following the same code pattern). They can be worked on simultaneously:

- **`sddp-specialist`** handles tickets requiring deep SDDP algorithm knowledge: risk measures (006), stopping rules (007), duality handlers (009), forward passes (010), cut types (011). The specialist understands the mathematical semantics of each option and can verify correct SDDP.jl API usage.
- **`hpc-julia-developer`** handles ticket 008 (sampling schemes), which is more infrastructure-heavy (modifying task definition structs, updating both train and simulate pipelines).
- **`hpc-julia-developer`** handles ticket 012 (integration wiring), which requires Julia expertise to properly implement conditional kwargs passing and pipeline integration.

### Parallelization Plan

```
ticket-005 (Epic 01 complete)
     |
     +---> ticket-006 [sddp-specialist]     \
     +---> ticket-007 [sddp-specialist]      \
     +---> ticket-008 [hpc-julia-developer]   |-- All independent, can run in parallel
     +---> ticket-009 [sddp-specialist]      /
     +---> ticket-010 [sddp-specialist]     /
     +---> ticket-011 [sddp-specialist]    /
     |
     v
ticket-012 [hpc-julia-developer] (waits for all 006-011)
```

## Scope

- Add missing risk measures: Entropic, Wasserstein, ModifiedChiSquared, ConvexCombination
- Add missing stopping rules: Statistical, StoppingChain, SimulationStoppingRule, FirstStageStoppingRule
- Add sampling schemes: InSampleMonteCarlo, OutOfSampleMonteCarlo, Historical, PSRSamplingScheme
- Add duality handlers: ContinuousConicDuality, LagrangianDuality, StrengthenedConicDuality, BanditDuality
- Add forward pass strategies: DefaultForwardPass, RevisitingForwardPass, RiskAdjustedForwardPass, AlternativeForwardPass, RegularizedForwardPass
- Add cut type selection: SINGLE_CUT, MULTI_CUT
- Wire all new options through the JSONC config -> SDDPPolicyTaskDefinition -> SDDP.train pipeline
- Add comprehensive tests for each new option

## Tickets

| ID         | Title                                                           | Estimate | Agent               |
| ---------- | --------------------------------------------------------------- | -------- | ------------------- |
| ticket-006 | Add remaining risk measures                                     | 3 pts    | sddp-specialist     |
| ticket-007 | Add chained stopping rules                                      | 3 pts    | sddp-specialist     |
| ticket-008 | Add sampling schemes                                            | 4 pts    | hpc-julia-developer |
| ticket-009 | Add duality handlers                                            | 3 pts    | sddp-specialist     |
| ticket-010 | Add forward pass strategies                                     | 3 pts    | sddp-specialist     |
| ticket-011 | Add cut type selection                                          | 2 pts    | sddp-specialist     |
| ticket-012 | Wire new algorithm options through train and simulate pipelines | 3 pts    | hpc-julia-developer |

## Dependencies

- Epic 01 must be complete (Engine abstraction stabilized, abstract-engine merged into main)

## Deliverables

- Every SDDP.jl algorithm knob is configurable via JSONC
- Each new type has constructor, validators, `generate_*` mapping function, and tests
- The 1dtoy example case can be configured with any combination of these options
- All tests pass with GLPK
