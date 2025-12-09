#!/bin/bash

if [[ -z "$1" ]]; then
  echo "provide a hostname for this device"
  exit 1
fi

/usr/bin/sed -i '' "s/<<HOSTNAME>>/$1/" Justfile
/usr/bin/sed -i '' "s/<<HOSTNAME>>/$1/" flake.nix
git checkout -b "host/$1"
git add -u

if ! which brew &> /dev/null; then
  echo "Installing Homebrew"; \
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo >> ~/.zprofile
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ ! -e /nix/receipt.json ]; then
  echo "Installing Lix (Nix compatible alternative)"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.lix.systems/lix | sh -s -- install --no-confirm
fi

if [ -e /nix/receipt.json ]; then
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  echo "Nix failed to install"
  exit 1
fi

if nix build ".#darwinConfigurations.$1.system" --extra-experimental-features 'nix-command flakes'; then
  sudo -E ./result/sw/bin/darwin-rebuild switch --flake ".#$1"
  git commit -m "$1 install"
else
  echo "Nix configuration error"
  exit 1
fi
