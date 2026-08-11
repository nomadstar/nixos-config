{ pkgs, lib, dotfiles, nvimConfig, ... }:

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
  xdg.configFile."hypr/hyprpaper.conf".source = "${dotfiles}/hypr/hyprpaper.conf";
  xdg.configFile."alacritty/alacritty.toml".source = "${dotfiles}/alacritty/alacritty.toml";
  xdg.configFile."nwg-displays/config".source = "${dotfiles}/nwg-displays/config";
  xdg.configFile."waybar/config.jsonc".source = "${dotfiles}/waybar/config.jsonc";
  xdg.configFile."waybar/style.css".source = "${dotfiles}/waybar/style.css";
  xdg.configFile."wallpapers/matrix.png".source = "${dotfiles}/wallpapers/matrix.png";
  xdg.configFile."wofi/config".source = "${dotfiles}/wofi/config";
  xdg.configFile."wofi/style.css".source = "${dotfiles}/wofi/style.css";

  # Personal Neovim (NvChad-based) config from the `nvimConfig` flake input -
  # whole-directory symlink, same reasoning as the dotfiles entries above.
  xdg.configFile."nvim".source = "${nvimConfig}";

  # Dark theme + green accent for GTK4/libadwaita apps (regreet, nemo, ...).
  # Needs `programs.dconf.enable` at the NixOS level (see modules/core) for
  # the dconf/gsettings backend to exist under Hyprland.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    accent-color = "green";
  };

  # Matrix-green cursor (see modules/desktop/matrix-cursors.nix for how the
  # theme itself is built). gtk/x11 here cover GTK apps and XWayland; the
  # Wayland-native cursor Hyprland itself draws is set via `env =` in
  # hyprland.conf instead, since that's what wlroots actually reads.
  home.pointerCursor = {
    package = pkgs.matrix-cursors;
    name = "matrix-cursors";
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  programs.bash.enable = true;
  programs.oh-my-posh = {
    enable = true;
    enableBashIntegration = true;
    settings = builtins.fromJSON (builtins.readFile ../oh-my-posh-matrix.json);
  };

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
