{
  lib,
  inventory,
}:
let
  validation = import ./validation.nix { inherit lib; };
  fail = message: throw "inventory.toml: ${message}";

  users = lib.mapAttrs (
    name: raw:
    let
      username = raw.username or name;
      fullName = raw.full_name or (fail "user '${name}' is missing field 'full_name'");
      email = raw.email or (fail "user '${name}' is missing field 'email'");
      github = raw.github or (fail "user '${name}' is missing field 'github'");
      allowNonportable = raw.allow_nonportable or false;
    in
    if username == "root" then
      fail "user '${name}' may not use the root account"
    else if !validation.validUsername username && !allowNonportable then
      fail "user '${name}' has invalid username '${username}'; expected a portable non-root account name, or set allow_nonportable = true only for an existing compatibility identity"
    else if !validation.validGithub github then
      fail "user '${name}' has invalid github value '${github}'; expected a 1-39 character GitHub username"
    else if email == "" then
      fail "user '${name}' has an empty email"
    else
      {
        inherit
          username
          fullName
          email
          github
          allowNonportable
          ;
      }
  ) (inventory.users or { });

  hosts = lib.mapAttrs (
    name: raw:
    let
      system = raw.system or (fail "host '${name}' is missing field 'system'");
      userName =
        raw.user or (inventory.defaults.user
          or (fail "host '${name}' is missing field 'user' and defaults.user is unset")
        );
      profileList = raw.profiles or (fail "host '${name}' is missing field 'profiles'");
      unknownProfiles = lib.filter (
        profile: !(builtins.elem profile validation.profileNames)
      ) profileList;
      incompatibleProfiles = lib.filter (
        profile: !validation.compatibleProfile system profile
      ) profileList;
      selectedUser = users.${userName} or null;
      managedUsername = if selectedUser == null then "" else selectedUser.username;
      rawFeatures = raw.features or { };
      features = {
        personalCache = rawFeatures.personal_cache or false;
      };
      rawDeploy = raw.deploy or { };
      deploy = {
        enable = rawDeploy.enable or false;
        hostname = rawDeploy.hostname or name;
        sshUser = rawDeploy.ssh_user or "maison-deploy";
        userSshUser = rawDeploy.user_ssh_user or managedUsername;
        repoPath = rawDeploy.repo_path or "/home/${managedUsername}/.maison";
        remoteBuild = rawDeploy.remote_build or false;
        autoRollback = rawDeploy.auto_rollback or true;
        magicRollback = rawDeploy.magic_rollback or true;
      };
    in
    if !validation.validHostname name then
      fail "host '${name}' has an invalid hostname; expected one DNS label"
    else if !(builtins.elem system validation.supportedSystems) then
      fail "host '${name}' has unsupported system '${system}'; allowed values: ${lib.concatStringsSep ", " validation.supportedSystems}"
    else if !(builtins.hasAttr userName users) then
      fail "host '${name}' references missing user '${userName}'"
    else if selectedUser.allowNonportable && !(lib.hasSuffix "-darwin" system) then
      fail "host '${name}' uses nonportable compatibility user '${selectedUser.username}' on non-Darwin system '${system}'"
    else if !validation.validRemoteHostname deploy.hostname then
      fail "host '${name}' has invalid deploy.hostname '${toString deploy.hostname}'"
    else if !validation.validSshUsername deploy.sshUser then
      fail "host '${name}' has invalid deploy.ssh_user '${toString deploy.sshUser}'"
    else if deploy.sshUser == selectedUser.username then
      fail "host '${name}' deploy.ssh_user must not match managed username '${selectedUser.username}'"
    else if deploy.userSshUser != selectedUser.username then
      fail "host '${name}' deploy.user_ssh_user must match managed username '${selectedUser.username}'"
    else if deploy.enable && !(lib.hasSuffix "-linux" system) then
      fail "host '${name}' enables deployment on non-Linux system '${system}'"
    else if !validation.validDeployRepoPath deploy.userSshUser deploy.repoPath then
      fail "host '${name}' deploy.repo_path must be a normalized path below /home/${deploy.userSshUser}"
    else if profileList == [ ] then
      fail "host '${name}' must select at least one profile"
    else if unknownProfiles != [ ] then
      fail "host '${name}' references unknown profiles: ${lib.concatStringsSep ", " unknownProfiles}; allowed values: ${lib.concatStringsSep ", " validation.profileNames}"
    else if incompatibleProfiles != [ ] then
      fail "host '${name}' uses platform-incompatible profiles for '${system}': ${lib.concatStringsSep ", " incompatibleProfiles}"
    else
      {
        inherit
          name
          system
          profileList
          userName
          features
          deploy
          ;
        profiles = profileList;
        user = selectedUser;
      }
  ) (inventory.hosts or { });
in
if (inventory.schema or null) != 1 then
  fail "unsupported schema '${toString (inventory.schema or "missing")}'; expected schema = 1"
else if users == { } then
  fail "no users are defined"
else if hosts == { } then
  fail "no hosts are defined"
else
  {
    inherit hosts users;
    defaults = inventory.defaults or { };
  }
