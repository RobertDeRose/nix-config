# Nix configuration UX refactor report

## Baseline

- Baseline commit: `7b2c0ecb7ac4c2c0f598e89f1a8a41933ef0512f`
- Recovery tag: `pre-nix-config-ux-refactor`
- Refactor branch: `refactor/nix-config-ux`
- Darwin output: `darwinConfigurations.USMBDEROSER`
- Linux system output: `systemConfigs.dev-som`
- Linux Home Manager output: `homeConfigurations.dev-som`

## Known baseline constraints

The implementation environment used for this refactor does not provide Nix/Lix or mise. Baseline and final Nix builds therefore must be completed by CI or on a configured host. Static shell, TOML, JSON, task-contract, and repository-structure checks are run locally.

The repository initially used easy-hosts for Darwin discovery, a separate filesystem scan for Linux discovery, substantial inline mise task bodies, and a root bootstrap script containing post-mise orchestration. The Linux flake path also contained a default user fallback.

## Phase log

Each refactor phase appends its implementation and validation result here. User-visible behavior is intentionally preserved unless an entry explicitly states otherwise.
