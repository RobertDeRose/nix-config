{ user, ... }:
{
  home.homeDirectory = "/home/${user.username}";
  xdg.enable = true;
}
