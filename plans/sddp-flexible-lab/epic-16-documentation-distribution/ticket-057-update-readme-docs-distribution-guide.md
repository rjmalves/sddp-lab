# ticket-057 Update README and Docs with Distribution and Precompilation Guide

## Context

### Background

Epics 13-15 added PrecompileTools workload (TTFX elimination), PackageCompiler `create_app` (distributable bundles), `julia_main` CLI entry point, and a GitHub Actions release workflow. Users need documentation to discover and use these capabilities. The current README is in Portuguese and very minimal. This ticket updates it to a proper English README for an open-source project and adds a distribution/installation guide to the Documenter.jl docs.

### Current State

- `README.md` is a short Portuguese-language file with basic usage instructions
- `docs/make.jl` defines pages: Introduction, User Guide, Configuration Reference, Tutorials, API Reference
- No documentation about precompilation, compiled app installation, or CLI usage
- The `julia_main` function with `--help`, `--version`, `--output`, `--format` flags exists (ticket-054)
- `build/build_app.jl` and `build/package_tarball.sh` exist (ticket-055)
- Release workflow publishes tarballs as GitHub Release artifacts (ticket-056)

## Specification

### Requirements

1. Rewrite `/home/rogerio/git/sddp-lab/README.md` in English with:
   - Project title and one-line description
   - Badge for CI status, docs, and codecov (standard Julia package badges)
   - **Installation** section: `Pkg.add(url="...")` for Julia users
   - **Compiled App** section: download from GitHub Releases, extract, run `SDDPlab <study-path>`
   - **Quick Start** section: basic usage with `read_study`, `build`, `train`, `simulate`
   - **CLI Usage** section: `julia_main` flags (`--help`, `--version`, `--output`, `--format`)
   - **Building from Source** section: custom sysimage build instructions using `build/build_app.jl`
   - **Documentation** link to the Documenter.jl site
   - **License** section

2. Create `/home/rogerio/git/sddp-lab/docs/src/man/installation.md` with detailed installation guide:
   - Installing as a Julia package
   - Downloading the compiled app from releases
   - Building a custom sysimage for development
   - Precompilation benefits (PrecompileTools)

3. Update `/home/rogerio/git/sddp-lab/docs/make.jl` to include the new installation page in the User Guide section

## Acceptance Criteria

- [ ] Given `README.md`, when inspected, then it is in English and contains sections: Installation, Compiled App, Quick Start, CLI Usage, Building from Source, Documentation, License
- [ ] Given `docs/src/man/installation.md`, when inspected, then it documents: Julia package install, compiled app download, custom sysimage build, PrecompileTools benefits
- [ ] Given `docs/make.jl`, when inspected, then "Installation" page appears in the User Guide section
- [ ] Given the docs build, when `julia --project=docs -e 'include("docs/make.jl")'` is run, then it completes without errors

## Implementation Guide

### Key Files to Create

- `/home/rogerio/git/sddp-lab/docs/src/man/installation.md`

### Key Files to Modify

- `/home/rogerio/git/sddp-lab/README.md`
- `/home/rogerio/git/sddp-lab/docs/make.jl`

### Pitfalls to Avoid

- Do NOT remove existing docs pages — only add the new installation page
- Keep the README concise — detailed instructions go in the docs
- Use the actual GitHub repo URL: `github.com/rjmalves/sddp-lab`

## Dependencies

- **Blocked By**: ticket-056-add-github-actions-release-workflow.md
- **Blocks**: None

## Effort Estimate

**Points**: 2
**Confidence**: High
