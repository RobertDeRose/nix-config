# modules/common/cache.nix
# Shared binary cache endpoints and trusted public keys.
{
  substituters = [
    "https://robertderose.cachix.org"
    "https://cache.numtide.com"
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];

  trustedPublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "robertderose.cachix.org-1:LGSby4A1Kg1W19IC5AoB3oGhLSgfg1x3j2GF0Ve2hKM="
  ];
}
