# ticket-056 Add GitHub Actions Release Workflow for create_app Builds

> **[OUTLINE]** This ticket requires refinement before execution.
> It will be refined with learnings from earlier epics.

## Objective

Create a GitHub Actions workflow (`.github/workflows/release.yml`) that triggers on release tags (`v*`), builds the SDDPlab application using PackageCompiler's `create_app` via `build/build_app.jl` (from ticket-055), packages it as a tarball, validates the bundle size is under 2GB (GitHub's per-artifact limit), and publishes the tarball as a GitHub Release artifact using `gh` or `actions/upload-release-asset`.

## Anticipated Scope

- **Files likely to be modified**: `.github/workflows/release.yml` (new), possibly `.github/workflows/main.yml` (add build step to CI for validation)
- **Key decisions needed**:
  - Whether to build on `ubuntu-latest` or a specific runner with more memory/disk (create_app needs 4-8 GB RAM and 5+ GB disk)
  - Whether to add a size-check step that fails the build if the tarball exceeds a threshold (e.g., 1.5 GB warning, 2 GB hard fail)
  - Whether to cache the Julia depot across builds to speed up dependency resolution
  - Whether to run a smoke test (execute the built app on the 1dtoy example) in CI before publishing
  - How to handle the build timeout (create_app may take 20-40 minutes; GitHub Actions has a 6-hour default)
- **Open questions**:
  - What Julia version should the release workflow use? Latest stable, or pin to a specific version for reproducibility?
  - Should the workflow also build a sysimage (not just create_app) for users who have Julia installed?
  - How to version the tarball name: from `Project.toml` version, or from the git tag?

## Dependencies

- **Blocked By**: ticket-055-create-build-app-script-tarball.md
- **Blocks**: ticket-057-update-readme-docs-distribution-guide.md

## Effort Estimate

**Points**: 3
**Confidence**: Low (will be re-estimated during refinement)
