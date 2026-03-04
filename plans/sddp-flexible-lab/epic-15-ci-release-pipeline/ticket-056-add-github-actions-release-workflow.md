# ticket-056 Add GitHub Actions Release Workflow for create_app Builds

## Context

### Background

Epic 14 produced `build/build_app.jl` (PackageCompiler `create_app` script) and `build/package_tarball.sh` (tarball packaging). This ticket creates a GitHub Actions workflow that automates the build-and-publish process on release tags, making distributable bundles available as GitHub Release artifacts.

### Relation to Epic

This is the sole ticket in Epic 15. It connects the build tooling (Epic 14) to the release pipeline, enabling users to download pre-built SDDPlab bundles from GitHub Releases.

### Current State

- `build/build_app.jl` calls `PackageCompiler.create_app` with correct parameters (ticket-055)
- `build/package_tarball.sh` produces `sddp-lab-v{version}-{os}-{arch}.tar.gz` (ticket-055)
- `build/Project.toml` declares PackageCompiler dependency for the build environment
- Existing CI workflows: `main.yml` (tests), `docs.yml` (documentation), `format_check.yml` (formatting)
- All existing workflows use `julia-actions/setup-julia@v2`, `julia-actions/cache@v2`

### Design Decisions (resolved from outline)

- **Runner**: `ubuntu-latest` (sufficient RAM/disk for create_app)
- **Julia version**: `"1"` (latest stable) for builds — matches the existing CI matrix
- **Bundle size**: Add a size-check step that warns at 1.5 GB, fails at 2 GB (GitHub limit)
- **Smoke test**: Run the built app on `example/1dtoy/` before publishing
- **Timeout**: Set job timeout to 60 minutes (create_app takes 20-40 min)
- **Tarball versioning**: From git tag (stripping `v` prefix), not Project.toml
- **No sysimage build**: Only create_app (sysimage is a local developer concern)
- **Cache**: Use `julia-actions/cache@v2` to speed up dependency resolution

## Specification

### Requirements

1. Create `.github/workflows/release.yml` triggered on published releases (`types: [published]`)
2. The workflow must:
   a. Check out the repository
   b. Set up Julia (latest stable) with `julia-actions/setup-julia@v2`
   c. Cache Julia depot with `julia-actions/cache@v2`
   d. Install build environment: `julia --project=build -e 'using Pkg; Pkg.instantiate()'`
   e. Run `julia --project=build build/build_app.jl`
   f. Run `build/package_tarball.sh`
   g. Check tarball size (warn > 1.5 GB, fail > 2 GB)
   h. Smoke test: run `build/SDDPLabApp/bin/SDDPlab --version` and `build/SDDPLabApp/bin/SDDPlab example/1dtoy/`
   i. Upload tarball to the GitHub Release using `gh release upload`
3. The workflow needs `contents: write` permission for release asset upload
4. Job timeout: 60 minutes

### Outputs/Behavior

- On each published release, a `sddp-lab-v{tag}-linux-x86_64.tar.gz` artifact appears in the release assets
- The workflow fails if the tarball exceeds 2 GB or the smoke test fails

### Error Handling

- Build failure: workflow fails with clear error in the build step
- Size exceeded: workflow fails with size warning before upload
- Smoke test failure: workflow fails before upload, keeping the release clean

## Acceptance Criteria

- [ ] Given `.github/workflows/release.yml`, when inspected, then it triggers on `release: types: [published]`
- [ ] Given the workflow, when inspected, then it installs Julia, instantiates the build environment, runs `build_app.jl`, runs `package_tarball.sh`, checks tarball size, runs a smoke test, and uploads to the release
- [ ] Given the workflow, when inspected, then it has `timeout-minutes: 60` and `permissions: contents: write`
- [ ] Given the workflow, when inspected, then the smoke test step runs `build/SDDPLabApp/bin/SDDPlab --version` and verifies exit code 0

## Implementation Guide

### Suggested Approach

Create `.github/workflows/release.yml`:

```yaml
name: Release Build

on:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  build-and-publish:
    name: Build distributable app
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4

      - uses: julia-actions/setup-julia@v2
        with:
          version: "1"

      - uses: julia-actions/cache@v2

      - name: Install build dependencies
        run: julia --project=build -e 'using Pkg; Pkg.instantiate()'

      - name: Build app with PackageCompiler
        run: julia --project=build build/build_app.jl

      - name: Package tarball
        run: bash build/package_tarball.sh

      - name: Check bundle size
        run: |
          TARBALL=$(ls build/sddp-lab-v*.tar.gz)
          SIZE=$(stat -c%s "$TARBALL")
          SIZE_MB=$((SIZE / 1024 / 1024))
          echo "Tarball size: ${SIZE_MB} MB"
          if [ "$SIZE_MB" -gt 2048 ]; then
            echo "::error::Tarball exceeds 2 GB limit (${SIZE_MB} MB)"
            exit 1
          elif [ "$SIZE_MB" -gt 1536 ]; then
            echo "::warning::Tarball exceeds 1.5 GB (${SIZE_MB} MB)"
          fi

      - name: Smoke test - version
        run: build/SDDPLabApp/bin/SDDPlab --version

      - name: Smoke test - 1dtoy
        run: build/SDDPLabApp/bin/SDDPlab example/1dtoy/

      - name: Upload release asset
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          TARBALL=$(ls build/sddp-lab-v*.tar.gz)
          gh release upload "${{ github.event.release.tag_name }}" "$TARBALL" --clobber
```

### Key Files to Create

- `/home/rogerio/git/sddp-lab/.github/workflows/release.yml`

### Key Files to Modify

- None

### Pitfalls to Avoid

- Do NOT use `actions/upload-release-asset` (deprecated) — use `gh release upload` instead
- Do NOT forget `permissions: contents: write` — needed for `gh release upload`
- Do NOT skip the smoke test — a broken bundle in a release is worse than a failed build
- The `--clobber` flag on `gh release upload` allows re-running the workflow if the first attempt uploaded a partial file

## Testing Requirements

### Unit Tests

- Not applicable (workflow file is YAML, tested by GitHub Actions itself)

### Integration Tests

- Verify YAML syntax: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
- Manual verification: create a draft release on the fork to trigger the workflow (optional, not required for ticket completion)

## Dependencies

- **Blocked By**: ticket-055-create-build-app-script-tarball.md
- **Blocks**: ticket-057-update-readme-docs-distribution-guide.md

## Effort Estimate

**Points**: 2
**Confidence**: High
