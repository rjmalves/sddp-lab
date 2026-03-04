# Epic 15: CI Release Pipeline

## Goal

Automate the PackageCompiler `create_app` build and publish distributable tarballs as GitHub Release artifacts when release tags are pushed. Assess bundle size to confirm feasibility within GitHub's 2GB per-artifact limit.

## Scope

- GitHub Actions workflow triggered by release tags
- Build the `create_app` bundle on ubuntu-latest
- Publish tarball as release artifact
- Bundle size validation step

## Non-Goals

- Multi-architecture builds (aarch64 deferred)
- macOS / Windows builds
- Nightly / pre-release builds

## Tickets

| Ticket     | Title                                                     | Agent               | Points |
| ---------- | --------------------------------------------------------- | ------------------- | ------ |
| ticket-056 | Add GitHub Actions release workflow for create_app builds | hpc-julia-developer | 3      |

## Dependencies

- Depends on: Epic 14 (build_app.jl must exist and work)
- Blocks: Epic 16 (docs reference the release artifacts)
