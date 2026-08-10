{ pkgs, dotfiles, ... }:

{
  home.username = "nanixtus";
  home.homeDirectory = "/home/nanixtus";

  # Dotfiles come from the `dotfiles` flake input (a separate curated repo,
  # also linked in as the home/ git submodule for human clones). Managed
  # declaratively, but content is unchanged from the working system at
  # migration time - see the dotfiles repo history for details.
  xdg.configFile."hypr/hyprland.conf".source = "${dotfiles}/hypr/hyprland.conf";
  xdg.configFile."hypr/monitors.conf".source = "${dotfiles}/hypr/monitors.conf";
  xdg.configFile."hypr/workspaces.conf".source = "${dotfiles}/hypr/workspaces.conf";
  xdg.configFile."alacritty/alacritty.toml".source = "${dotfiles}/alacritty/alacritty.toml";
  xdg.configFile."nwg-displays/config".source = "${dotfiles}/nwg-displays/config";

  home.stateVersion = "25.11";
}
