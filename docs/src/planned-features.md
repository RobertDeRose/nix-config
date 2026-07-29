
# Planned features

This page is the human-readable roadmap. Beads is authoritative for live status, dependencies, claims, and ready-work
selection.

## Project direction

- Purpose: Maison is a two-layer macOS and Linux configuration system that uses Nix/Lix for privileged system state and mise for user tools, packages, applications, preferences, and dotfiles.
- Current scope: Maison manages Apple Silicon macOS, aarch64 Linux, and x86&#95;64 Linux host configuration; local system activation; remote Linux deployment; user-environment convergence; inventory validation; package/tool/app authoring commands; recovery; and project documentation.
- Boundaries: Maison does not support Intel macOS, Home Manager, arbitrary unmanaged package ownership, strict offline byte-for-byte reproduction, or storing private infrastructure identity and trusted access material in the public control plane.

## Roadmap conventions

- Directory names use `<slug>`.
- Detailed intent belongs in each feature's `design.md`.
- Each feature is one Beads epic/molecule; lifecycle and implementation work are tasks beneath it.
- Human workflow references use `<slug>` or the feature name. Root hashes are retained only for audit.
- Live execution state is queried through Beads.
- Completed features move into [Implemented features](features/index.md).

## Feature map

| Feature                   | Beads root | Roadmap state | Dependencies | Design |
|---------------------------|------------|---------------|--------------|--------|
| _No features planned yet_ | —          | —             | —            | —      |
