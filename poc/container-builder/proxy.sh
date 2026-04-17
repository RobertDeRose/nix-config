#!/bin/bash
exec /opt/homebrew/bin/container exec -i nix-builder bash -c 'exec 3<>/dev/tcp/127.0.0.1/22; cat <&3 & cat >&3; kill %1 2>/dev/null'
