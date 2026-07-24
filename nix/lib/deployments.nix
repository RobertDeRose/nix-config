{
  inputs,
  lib,
  inventoryData,
  systemConfigs,
}:
let
  linuxHosts = lib.filterAttrs (
    _: host: lib.hasSuffix "-linux" host.system && host.deploy.enable
  ) inventoryData.hosts;

  mkNode =
    name: host:
    let
      deployLib = inputs.deploy-rs.lib.${host.system};
    in
    {
      hostname = host.deploy.hostname;
      sshUser = host.deploy.sshUser;
      remoteBuild = host.deploy.remoteBuild;
      autoRollback = host.deploy.autoRollback;
      magicRollback = host.deploy.magicRollback;

      profiles.system = {
        user = "root";
        profilePath = "/nix/var/nix/profiles/system-manager-profiles/system-manager";
        path = deployLib.activate.custom systemConfigs.${name} ''
          cd /tmp
          "$PROFILE/bin/activate"
        '';
      };
    };
in
{
  nodes = lib.mapAttrs mkNode linuxHosts;
}
