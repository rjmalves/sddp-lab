# Score Report

**Mode**: Design
**Ticket**: plan directory `/home/carlosribeiro/git/sddp-lab/plans/remove-system-entities`
**Composite Score**: 1.00
**Gate**: PASS (threshold: 0.80)

Independent re-score computed only from on-disk artifacts (master plan frontmatter, tickets, `design/critique/round-1.md`, `design/council/*.brief.md`, `design/signoff.md`) against `rubrics/design.md`. Flags: `--no-council` not set, `--skip-design-review` not set, so all five dimensions apply (divisor 1.00). No clarification is required: every dimension is determinable from the artifacts, so `status` is `complete` and `clarification` is `null`.

## Dimensional Breakdown

| Dimension | Weight | Score | Weighted | Evidence Summary |
| --------- | ------ | ----- | -------- | ---------------- |
| Traceability | 0.25 | 1.00 | 0.2500 | frac_decisions 4/4; frac_tickets 3/3; mean 1.0 |
| Options Considered | 0.15 | 1.00 | 0.1500 | 4/4 accepted non-cross_cutting decisions complete |
| Council Coverage | 0.15 | 1.00 | 0.1500 | frac_briefs 2/2; frac_signoffs 2/2 |
| Durability | 0.25 | 1.00 | 0.2500 | 0 unresolved UNDER (F1-001 resolved via ADR-005) |
| Proportionality | 0.20 | 1.00 | 0.2000 | 0 unresolved OVER (none recorded) |

Composite = 0.2500 + 0.1500 + 0.1500 + 0.2500 + 0.2000 = 1.0000, divisor 1.00 (no dimension N/A).

## Detailed Evidence

### Traceability (1.00)

- **Scoring Rule**: mean(frac_decisions, frac_tickets).
- **Evidence**: Accepted decisions are ADR-001 (R9,R10,R1-R5,R11,R12), ADR-002 (R1,R2,R3,R6,R7,R10), ADR-004 (R8,R13), ADR-005 (R7,R6,R9); ADR-003 is `superseded` and excluded. Every cited id is declared in `requirements:` (R1-R13). Tickets carrying `implements:`: ticket-001 `[ADR-001, ADR-002, ADR-004, ADR-005, R6, R7, R8, R10]`, ticket-002 `[ADR-001, ADR-002, ADR-005, R1-R7, R11]`, ticket-003 `[ADR-001, ADR-004, R11, R12, R13]`; all ids resolve to declared requirement or decision ids. The epic overview carries no `implements:` key and is not a counted ticket.
- **Score Justification**: frac_decisions = 4/4 = 1.0, frac_tickets = 3/3 = 1.0, mean = 1.0.

### Options Considered (1.00)

- **Scoring Rule**: accepted non-cross_cutting decisions with >=2 options AND reversibility AND rework_trigger / accepted non-cross_cutting decisions.
- **Evidence**: No decision carries a `cross_cutting` flag in the frontmatter, so all four accepted decisions are counted (excluding any would not change the fraction). ADR-001: 3 options, `two-way`, rework_trigger "none known". ADR-002: 3 options, `one-way`, "none known". ADR-004: 3 options, `two-way`, "none known". ADR-005: 3 options, `two-way`, rework_trigger naming a future harness plan.
- **Score Justification**: 4/4 = 1.0.

### Council Coverage (1.00)

- **Scoring Rule**: mean(frac_briefs, frac_signoffs).
- **Evidence**: Roster is 2 seats. `design/council/hpc-julia-developer.brief.md` and `design/council/sddp-specialist.brief.md` both exist with full brief sections. `design/signoff.md` records a verdict for both domains (`hpc-julia-developer` APPROVE; `sddp-specialist` OBJECT on ADR-003, resolved as ACCEPTED and carried into the revision).
- **Score Justification**: frac_briefs 2/2, frac_signoffs 2/2, mean 1.0. An OBJECT verdict is still a recorded verdict; the rubric measures presence of artifacts.

### Durability (1.00)

- **Scoring Rule**: 1.0 if n == 0 unresolved UNDER findings; 0.5 if n == 1 non-major; 0.0 if n >= 2 or any major/critical.
- **Evidence**: `design/critique/round-1.md` is the only round file and holds one finding, F1-001 (HIGH, UNDER, major), verdict ACKNOWLEDGED. Its `## Revision Log (round 1)` states "Action: superseded ADR-003 with ADR-005", and ADR-005 is `accepted` with `supersedes: ADR-003` in the master plan frontmatter, and ADR-003 is `superseded`. The SIGNOFF-ADR-003 entry is a sign-off objection (not a critique finding) resolved by the same ADR-005.
- **Score Justification**: ACKNOWLEDGED plus a revision log naming the superseding decision meets the "resolved" definition, so n = 0, score 1.0. Had the revision log not named ADR-005, the major UNDER would have scored 0.0.

### Proportionality (1.00)

- **Scoring Rule**: 1.0 if n == 0 unresolved OVER findings.
- **Evidence**: round-1.md lists a single finding with direction UNDER; no OVER finding is recorded, and no `DISPUTED` or verdict-less finding exists.
- **Score Justification**: n = 0, score 1.0.
