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

## Compatibility exception: existing Darwin username

The existing macOS account name `DeRoseR` contains uppercase characters and therefore is not portable to Linux. To preserve the active macOS identity without renaming the account, `inventory.toml` marks that existing identity with `allow_nonportable = true`. Validation permits the exception only for Darwin hosts; newly scaffolded users must still use portable lowercase account names.
