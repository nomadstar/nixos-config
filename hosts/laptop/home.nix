{ pkgs, lib, dotfiles, ... }:

{
  home.username = "nanixtus";
  home.homeDirectory = "/home/nanixtus";

  # Dotfiles come from the `dotfiles` flake input (a separate curated repo,
  # also linked in as the home/ git submodule for human clones). Managed
  # declaratively, but content is unchanged from the working system at
  # migration time - see the dotfiles repo history for details.
  xdg.configFile."hypr/hyprland.conf".source = "${dotfiles}/hypr/hyprland.conf";
  xdg.configFile."hypr/workspaces.conf".source = "${dotfiles}/hypr/workspaces.conf";
  xdg.configFile."hypr/hypremoji.conf".source = "${dotfiles}/hypr/hypremoji.conf";
  xdg.configFile."alacritty/alacritty.toml".source = "${dotfiles}/alacritty/alacritty.toml";
  xdg.configFile."nwg-displays/config".source = "${dotfiles}/nwg-displays/config";
  xdg.configFile."waybar/config.jsonc".source = "${dotfiles}/waybar/config.jsonc";
  xdg.configFile."waybar/style.css".source = "${dotfiles}/waybar/style.css";

  # monitors.conf is intentionally *not* managed above: nwg-displays (the
  # Display Settings app) rewrites it in place whenever monitor layout
  # changes, and a home-manager-managed file would be an immutable
  # /nix/store symlink that nwg-displays can't write to and that a rebuild
  # would silently reset. Instead, seed it once from the dotfiles repo's
  # last-known-good layout, then leave it alone so nwg-displays owns it and
  # user changes persist across rebuilds. hyprland.conf always sources it,
  # so whatever is on disk is what Hyprland uses by default.
  home.activation.seedMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.config/hypr/monitors.conf"
    if [ ! -e "$target" ]; then
      run install -Dm644 "${dotfiles}/hypr/monitors.conf" "$target"
    fi
  '';

  home.stateVersion = "25.11";
}
