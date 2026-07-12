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
      userName = raw.user or (inventory.defaults.user or (fail "host '${name}' is missing field 'user' and defaults.user is unset"));
      profileList = raw.profiles or (fail "host '${name}' is missing field 'profiles'");
      unknownProfiles = lib.filter (profile: !(builtins.elem profile validation.profileNames)) profileList;
      incompatibleProfiles = lib.filter (profile: !validation.compatibleProfile system profile) profileList;
    in
    if !validation.validHostname name then
      fail "host '${name}' has an invalid hostname; expected one DNS label"
    else if !(builtins.elem system validation.supportedSystems) then
      fail "host '${name}' has unsupported system '${system}'; allowed values: ${lib.concatStringsSep ", " validation.supportedSystems}"
    else if !(builtins.hasAttr userName users) then
      fail "host '${name}' references missing user '${userName}'"
    else if users.${userName}.allowNonportable && !(lib.hasSuffix "-darwin" system) then
      fail "host '${name}' uses nonportable compatibility user '${users.${userName}.username}' on non-Darwin system '${system}'"
    else if profileList == [ ] then
      fail "host '${name}' must select at least one profile"
    else if unknownProfiles != [ ] then
      fail "host '${name}' references unknown profiles: ${lib.concatStringsSep ", " unknownProfiles}; allowed values: ${lib.concatStringsSep ", " validation.profileNames}"
    else if incompatibleProfiles != [ ] then
      fail "host '${name}' uses platform-incompatible profiles for '${system}': ${lib.concatStringsSep ", " incompatibleProfiles}"
    else
      {
        inherit name system profileList userName;
        profiles = profileList;
        user = users.${userName};
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
