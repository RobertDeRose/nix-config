# Nix toolchain

The existing platform policy is preserved: Intel macOS uses upstream Nix, while Apple Silicon macOS and Linux use Lix. Darwin selection is implemented in `nix/modules/darwin/config.nix`; fresh-machine installation is implemented once in `.mise/lib/bootstrap.sh`.

All command paths enable `nix-command` and `flakes`. Standard NixOS, nix-community, and Numtide caches are configured for normal operation. The personal cache is an explicit host feature and optional acceleration only.

`mise run nix:clean` prunes old system generations, while `mise run nix:gc` performs broader store garbage collection. `mise run doctor` reports daemon and cache state without changing the host.
