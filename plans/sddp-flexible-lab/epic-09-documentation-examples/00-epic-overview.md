# Epic 09: Documentation and Examples

## Goal

Create comprehensive documentation covering the full API, configuration format, tutorials for common workflows, and example cases demonstrating each feature. This makes the package accessible to new users and serves as a reference for advanced usage.

## Primary Agent

Split between both agents:

- `hpc-julia-developer` handles API reference documentation (Documenter.jl setup, docstrings)
- `sddp-specialist` handles configuration reference and tutorial examples (requires domain expertise to write meaningful tutorials)

## Scope

- API documentation for all public types and functions
- Configuration format reference (JSONC schema documentation)
- Tutorials for common workflows
- New example cases demonstrating advanced features
- Contributing guide

## Tickets

| ID         | Title                                          | Estimate | Agent               |
| ---------- | ---------------------------------------------- | -------- | ------------------- |
| ticket-035 | Write API reference documentation              | 3 pts    | hpc-julia-developer |
| ticket-036 | Write configuration format reference           | 3 pts    | sddp-specialist     |
| ticket-037 | Create tutorial examples for advanced features | 4 pts    | sddp-specialist     |

## Dependencies

- Epic 08 must be complete
