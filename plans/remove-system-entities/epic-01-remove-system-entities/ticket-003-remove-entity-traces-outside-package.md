---
filesToBeCreated: []
filesToBeModified:
  - docs/make.jl
  - docs/src/api/system.md
  - docs/src/api/variables.md
  - docs/src/configuration/system.md
  - docs/src/index.md
  - docs/src/tutorials/load_blocks.md
  - CHANGELOG.md
filesToBeDeleted:
  - example/pumped_storage/data/buses.csv
  - example/pumped_storage/data/constraints.jsonc
  - example/pumped_storage/data/graph.jsonc
  - example/pumped_storage/data/hydros.csv
  - example/pumped_storage/data/inflow_scenarios.jsonc
  - example/pumped_storage/data/lines.csv
  - example/pumped_storage/data/load.csv
  - example/pumped_storage/data/scenarios.jsonc
  - example/pumped_storage/data/system.jsonc
  - example/pumped_storage/data/thermals.csv
  - example/pumped_storage/main.jsonc
  - example/renewable_contracts/data/buses.csv
  - example/renewable_contracts/data/constraints.jsonc
  - example/renewable_contracts/data/graph.jsonc
  - example/renewable_contracts/data/hydros.csv
  - example/renewable_contracts/data/inflow_scenarios.jsonc
  - example/renewable_contracts/data/lines.csv
  - example/renewable_contracts/data/load.csv
  - example/renewable_contracts/data/noncontrollables.csv
  - example/renewable_contracts/data/scenarios.jsonc
  - example/renewable_contracts/data/system.jsonc
  - example/renewable_contracts/data/thermals.csv
  - example/renewable_contracts/main.jsonc
  - docs/src/tutorials/renewable_contracts.md
  - docs/src/tutorials/pumped_storage.md
implements: [ADR-001, ADR-004, R11, R12, R13]
agent: hpc-julia-developer
tier: standard
---

# TICKET-003 Remove Entity Traces Outside the Package Source

## Context

### Background

After ticket-002, `src/` and `test/` contain no trace of the non-controllable, energy contract and pumping station entities. The rest of the repository still documents them: two example studies built around them, two tutorials, their `docs/make.jl` page entries, mentions in five shared documentation pages and four v3.0.0 CHANGELOG entries. The operator extended "as if they never existed" to examples and documentation (R11) and to the CHANGELOG without a "Removed" note (R12). This ticket deletes that material and closes the plan with the whole-repo grep gate.

### Relation to Epic

Third and last ticket of `epic-01-remove-system-entities` (ADR-001). It touches no Julia source under `src/` or `test/`; its only `.jl` edit is `docs/make.jl`. It also performs the plan's R13 closing check: `plans/sddp-flexible-lab/**` unchanged and the branch history intact (ADR-004).

Door class: **two-way** — documentation, example data and changelog text are cheap to change later and nothing consumes them programmatically. Structure budget: deletion only; the only authored text is the three replacement passages fixed verbatim below; no file, page, section or note is added, and no debt ticket is involved.

Agent note: the dispatch table maps `.md` files to `open-source-documentation-writer`; this ticket is assigned to `hpc-julia-developer` because it authors no prose of its own (every replacement is verbatim here), edits `docs/make.jl`, and its gates are Julia commands (docs build, `Pkg.test()`, JuliaFormatter).

### Current State

At base `d16b8ee` (ticket-001 and ticket-002 change none of these files):

- `example/renewable_contracts/` (12 tracked files, including `data/noncontrollables.csv`) and `example/pumped_storage/` (11 tracked files) are runnable studies whose `system.jsonc` declare the removed keys. `example/*/data/` is gitignored, so their data files are force-tracked; generated run outputs (`out*/`) are ignored and may exist locally.
- `docs/src/tutorials/renewable_contracts.md` (114 lines) and `docs/src/tutorials/pumped_storage.md` (101 lines) are listed in `docs/make.jl` lines 36-37 (`"Renewable Generation & Contracts" => ...`, `"Pumped Storage" => ...`).
- `docs/src/api/system.md`: six accessors in the first `@docs` block (25-30), three collections (40-42), three entities (52-54).
- `docs/src/api/variables.md`: sections "Non-Controllable Generation", "Energy Contracts", "Pumping Stations" (31-50).
- `docs/src/configuration/system.md` (501 lines): intro sentence naming the three entities (3-6); top-level example with `"thermals": { ... },` (16) followed by `// Optional sections (omit if not needed)` and the three keys (17-20); sections "Non-Controllable Generation", "Energy Contracts", "Pumping Stations" (226-438); the three keys in the "Complete System Example" (469-499).
- `docs/src/index.md` lines 21-22: the "Rich system model" bullet naming the three entities.
- `docs/src/tutorials/load_blocks.md` line 105 (last line): `- Add a non-controllable (solar) that produces only during shoulder/peak blocks`.
- `CHANGELOG.md`: v3.0.0 feature entries for the three entities (10-12), `- Adds five tutorial examples with runnable configurations` (30), the `EnergyContract.get_params` fix (37).

## Specification

### Requirements

1. Delete the two example directories and the two tutorials, and remove their two `docs/make.jl` entries (R11). The remaining tutorials are `load_blocks`, `markov_var` and `experiment_sweep`.
2. Remove every entity mention from `docs/src/api/system.md`, `docs/src/api/variables.md`, `docs/src/configuration/system.md`, `docs/src/index.md` and `docs/src/tutorials/load_blocks.md`, using the verbatim replacements in Technical Details (R11).
3. In `CHANGELOG.md`, delete lines 10-12 and 37 and change line 30 to `- Adds three tutorial examples with runnable configurations`; add no "Removed" note (R12).
4. Leave `plans/sddp-flexible-lab/**` and the branch history untouched (R13).

### Inputs/Props

None: this ticket changes no API. The docs build consumes the docstrings left by ticket-002.

### Outputs/Behavior

- The docs site has no page, section, `@docs` entry or sentence about the three entities, and the Documenter build log names none of the removed symbols.
- The final whole-repo grep of `00-master-plan.md` prints nothing outside `plans/` and `LICENSE`.

### Error Handling

No code path changes. If the docs build exits non-zero, or its log still names a removed symbol, STOP and return `CLARIFICATION REQUIRED` with the log excerpt; do not silence a Documenter warning.

## Acceptance Criteria

- [ ] **AC1 (R11)** Given the deletions, when `git ls-files example/renewable_contracts example/pumped_storage docs/src/tutorials/renewable_contracts.md docs/src/tutorials/pumped_storage.md`, `test -e example/renewable_contracts || test -e example/pumped_storage` and the final grep of Technical Details run, then the first prints nothing, the second exits 1, and the grep exits 1 with no output.
- [ ] **AC2 (R11, R12)** Given the edited docs and CHANGELOG, when `git diff --numstat $(git merge-base HEAD feat/sddp-flexible-lab) -- CHANGELOG.md docs/src/configuration/system.md docs/src/index.md` runs, then it prints exactly the three tab-separated lines `1 5 CHANGELOG.md`, `3 252 docs/src/configuration/system.md`, `1 2 docs/src/index.md`, and `grep -c -F -- '- Adds three tutorial examples with runnable configurations' CHANGELOG.md` prints `1`.
- [ ] **AC3 (R11)** Given the edited docs, when the docs build of Technical Details runs, then `julia --project=$D docs/make.jl` exits 0, `grep -i -E 'noncontrollable|non-controllable|energycontract|pumpingstation|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage'` on its log exits 1, and `git status --porcelain -- docs/Project.toml` prints nothing.
- [ ] **AC4 (CI)** Given the edited tree, when `JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` and then the formatter command of Technical Details (second run) execute, then both exit 0.
- [ ] **AC5 (R13, R8)** Given the ticket's changes, when `git diff --quiet $(git merge-base HEAD feat/sddp-flexible-lab) -- plans/sddp-flexible-lab`, `git merge-base --is-ancestor feat/sddp-flexible-lab HEAD` and `git rev-parse --abbrev-ref HEAD` run, then the first two exit 0 and the third prints `feat/remove-system-entities`.

## Implementation Guide

### Suggested Approach

1. Confirm `git rev-parse --abbrev-ref HEAD` prints `feat/remove-system-entities` and that ticket-002 is in place (`git ls-files src/System/noncontrollable.jl` prints nothing).
2. `git rm -r -q example/renewable_contracts example/pumped_storage docs/src/tutorials/renewable_contracts.md docs/src/tutorials/pumped_storage.md`, then `rm -rf example/renewable_contracts example/pumped_storage` to clear ignored run outputs of the deleted studies, if any remain.
3. Apply the edits of Key Files bottom-up inside each file, using the verbatim replacements in Technical Details.
4. Run the final grep, the exact-text checks, the docs build, `Pkg.test()` and the formatter fixpoint, then the R13 checks.

### Key Files to Modify

All line numbers are at base `d16b8ee`.

| File | Edit |
| --- | --- |
| 25 files in `filesToBeDeleted` | `git rm` (step 2). |
| `docs/make.jl` | Delete lines 36-37 (the two tutorial page entries). |
| `docs/src/api/system.md` | Delete 52-54, 40-42, 25-30. |
| `docs/src/api/variables.md` | Delete 31-50 (three sections with their `@docs` blocks and trailing blank lines). |
| `docs/src/configuration/system.md` | Delete 469-499, delete 226-438, delete 17-20, replace 16 and replace 3-6 (Technical Details). Keep `// Required sections` (12) and the "Complete System Example" heading and its sentence (439-441). |
| `docs/src/index.md` | Replace 21-22 with the one-line bullet in Technical Details. |
| `docs/src/tutorials/load_blocks.md` | Delete line 105; the file then ends with the `- Increase peak demand to 300 MW ...` line and a newline. |
| `CHANGELOG.md` | Delete 37, replace 30, delete 10-12. |

### Patterns to Follow

- Each removal takes the whole unit it belongs to: a docs section with its heading and examples, a `@docs` entry line, a list bullet, a JSONC key with its value.
- Replacement text is copied byte for byte from Technical Details; no rewording of surviving text.
- Commit with a conventional message, for example `docs: remove entity examples, tutorials and references`.

### Pitfalls to Avoid

- Do not add a "Removed" CHANGELOG entry or any note about the removal (R12, R6).
- Do not touch `LICENSE` (its legal text contains "contract"), `README.md`, `plans/**` or any file under `src/` or `test/`.
- In `docs/src/configuration/system.md`, drop the trailing comma from `"thermals": { ... },` at line 16 (it becomes the last key); in the complete example (469-499) keep the comma after the `thermals` block, which JSONC permits and the surviving examples use.
- Build the docs from a temporary copy of the docs environment (Technical Details), not with `Pkg.develop` inside `docs/`: on recent Julia versions `Pkg.develop` writes a `[sources]` table into the `Project.toml` it targets, which would put an out-of-scope change in `docs/Project.toml`.
- The JuliaFormatter config has no `format_markdown`, so the formatter only touches `docs/make.jl` among this ticket's files; if it changes any other file, STOP and return `CLARIFICATION REQUIRED`.

### Technical Details

**`docs/src/configuration/system.md` lines 3-6 become** (three lines):

```
The system configuration defines the physical power system: buses (load nodes),
transmission lines, hydro plants, and thermal plants. It is specified in
`system.jsonc` within the study's `data/` directory.
```

**`docs/src/configuration/system.md` line 16 becomes** `    "thermals": { ... }` (four-space indent, no trailing comma), and lines 17-20 are deleted, so the top-level block reads:

```jsonc
{
    // Required sections
    "buses": { ... },
    "lines": { ... },
    "hydros": { ... },
    "thermals": { ... }
}
```

**`docs/src/index.md` lines 21-22 become** one line:

```
- **Rich system model**: Hydro cascades, thermals, and transmission lines.
```

**`CHANGELOG.md` line 30 becomes**:

```
- Adds three tutorial examples with runnable configurations
```

**Final grep** (master plan "Final Whole-Repo Grep Gate"):

```bash
git grep -n -i -E 'noncontrollable|non-controllable|energycontract|energy contract|pumpingstation|pumping station|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage|pump|contract|curtail|\bnc_|num_nc' -- . ':!plans/' ':!LICENSE'
# required: no output, exit status 1
```

**Docs build** (same `makedocs` call as `.github/workflows/docs.yml`, in a temporary copy of the docs environment; run `mktemp -d` once and reuse the printed absolute path as `$D`, since shell state does not persist between tool calls):

```bash
cp docs/Project.toml $D/Project.toml
julia --project=$D -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=$D docs/make.jl > $D/docs.log 2>&1; echo "exit=$?"
# required: exit=0
grep -i -E 'noncontrollable|non-controllable|energycontract|pumpingstation|NC_GENERATION|NC_CURTAILMENT|CONTRACT_DISPATCH|PUMPED_FLOW|PUMP_POWER|renewable_contracts|pumped_storage' $D/docs.log
# required: no output, exit status 1
git status --porcelain -- docs/Project.toml
# required: no output
```

`makedocs` resolves its `root` from the location of `docs/make.jl`, so the environment location does not change what is rendered. It runs with `warnonly = true`, so a missing docstring or a dangling `@ref` would not fail the build; the log grep is what catches a leftover reference. `deploydocs` skips deployment outside CI. Remove `$D` after AC3 passes.

**Formatter fixpoint** (JuliaFormatter v1, the version CI pins; Blue style from `.JuliaFormatter.toml`):

```bash
julia --startup-file=no -e 'using Pkg; Pkg.activate(; temp = true); Pkg.add(Pkg.PackageSpec(; name = "JuliaFormatter", version = "1")); using JuliaFormatter; exit(format(["src", "test", "docs"]) ? 0 : 1)'
```

The second run must exit 0.

## Testing Requirements

### Unit Tests

No test is added or changed (R6). `test/test-examples-tutorial.jl` no longer references the deleted examples (ticket-002), so deleting the directories cannot break the suite.

### Integration Tests

`JULIA_NUM_THREADS=4 julia --project=. -e 'using Pkg; Pkg.test()'` must exit 0 after the deletions, confirming no retained test or example reads a deleted file. The docs build (AC3) is the integration check for the documentation: it renders every remaining page and resolves every remaining `@docs` and `@ref` entry against the package after ticket-002.

### E2E Tests (if applicable)

The final whole-repo grep (AC1) is the plan's end-to-end "as if never existed" check over every tracked file outside `plans/` and `LICENSE`.

## Out of Scope

- `LICENSE` (the word "contract" in its legal text), `README.md`, and `plans/**`, including `plans/sddp-flexible-lab/**` (R13).
- Any file under `src/` or `test/` (ticket-001, ticket-002).
- A "Removed" or migration note in `CHANGELOG.md` or the docs, a version bump, and rewording any surviving docs text beyond the three verbatim replacements (R6, R7, R12).
- The docs deployment workflow and `docs/Project.toml` content.
- Rewriting or squashing the history of `feat/sddp-flexible-lab` (R13, ADR-004).

## Dependencies

- **Blocked By**: ticket-002-remove-entity-system-layer.md
- **Blocks**: None
- **Ordering reason**: deleting the example directories before ticket-002 removes their testsets from `test/test-examples-tutorial.jl` would break `Pkg.test()`; removing the `@docs` entries while the symbols are still exported would make `checkdocs = :exports` report them as undocumented; and the final whole-repo grep can only pass once ticket-001 and ticket-002 have cleared `src/` and `test/`.

## Effort Estimate

**Points**: 2
**Confidence**: High
Rationale: 25 file deletions and 7 files of verbatim line deletions or replacements; the docs build and one `Pkg.test()` run dominate the time.

## Definition of Done

- AC1-AC5 pass and their command outputs are quoted in the completion report.
- Exactly the 32 paths of the frontmatter changed (25 deleted, 7 modified); no file created; the temporary `$D` directory removed.
- No orphan left behind: no docs page, `@docs` entry, `make.jl` entry, cross-link or CHANGELOG line pointing at a removed entity, example or tutorial.
- The work is committed on `feat/remove-system-entities` as a normal commit; no force-push, no history rewrite.
