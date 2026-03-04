# Epic 12: Robustness and Reproducibility

## Goal

Harden the system with three independent improvements: (1) validate that all nodes sharing the same stage have identical datetimes, preventing silent data corruption in `stage_datetimes`; (2) replace hardcoded variable magnitude constants with model-derived magnitudes from actual JuMP variable bounds; (3) replace MersenneTwister with Xoshiro RNG and implement composed-seed approach for deterministic, thread-safe SAA generation.

## Primary Agent

`sddp-specialist` for tickets 048 and 049 (domain knowledge of graph validation and LP variable structure). `hpc-julia-developer` for ticket 050 (RNG infrastructure, thread safety, performance).

## Scope

- Same-stage datetime validation in graph validators
- Adaptive model-derived variable magnitudes replacing hardcoded `VARIABLE_UNITS_REGISTRY` max values
- Xoshiro RNG with composed-seed approach for SAA generation
- Removal of deprecated `set_seed!` function

## Tickets

| ID         | Title                                                  | Estimate | Agent               |
| ---------- | ------------------------------------------------------ | -------- | ------------------- |
| ticket-048 | Validate same-stage node datetimes in graph validators | 2 pts    | sddp-specialist     |
| ticket-049 | Adaptive model-derived variable magnitudes             | 3 pts    | sddp-specialist     |
| ticket-050 | Deterministic thread-safe RNG with Xoshiro             | 3 pts    | hpc-julia-developer |

## Dependencies

- All three tickets are independent of each other.
- All three tickets are independent of Epic 11.
- ticket-048 builds on the existing graph validators from Epic 01 (ticket-002).
- ticket-049 builds on the variable units registry from Epic 03 (ticket-017).
- ticket-050 builds on the thread-safe SAA infrastructure from Epic 04 (ticket-022).

## Key Design Decisions

1. **Datetime validation**: Added to the existing `__validate_graph_consistency!` call chain in `graph-validators.jl`, following the established pattern of accumulating errors into `CompositeException`.
2. **Model-derived magnitudes**: Computed once after `build()` completes across all SDDP nodes. The hardcoded registry becomes a fallback for variables without explicit bounds.
3. **Xoshiro RNG**: Julia's default RNG since 1.7. Composed seeds use `hash(user_seed, hash(state_index))` instead of the current `seed + (state-1) * 7919` linear offset.
