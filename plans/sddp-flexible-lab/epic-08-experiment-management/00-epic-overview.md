# Epic 08: Experiment Management

## Goal

Build experiment management capabilities that allow users to compare multiple algorithm configurations, run automated sensitivity analyses, and ensure reproducibility of results.

## Primary Agent

`hpc-julia-developer` -- These tickets are Julia infrastructure work: multi-process orchestration, configuration management, I/O pipelines, DataFrame aggregation, and reproducibility tooling. The `sddp-specialist` reviews to ensure experiment parameters and comparison metrics are SDDP-meaningful.

## Scope

- Multi-configuration comparison framework
- Automated sensitivity analysis
- Result aggregation and comparison
- Reproducibility (seed management, configuration versioning)

## Tickets

| ID         | Title                                           | Estimate | Agent               |
| ---------- | ----------------------------------------------- | -------- | ------------------- |
| ticket-034 | Implement multi-configuration experiment runner | 4 pts    | hpc-julia-developer |
| ticket-035 | Add automated sensitivity analysis              | 4 pts    | hpc-julia-developer |
| ticket-036 | Add result aggregation and comparison tools     | 3 pts    | hpc-julia-developer |
| ticket-037 | Add reproducibility infrastructure              | 2 pts    | hpc-julia-developer |

## Dependencies

- Epic 07 must be complete
