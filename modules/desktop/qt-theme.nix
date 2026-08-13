{ config, lib, pkgs, ... }:

# Without this, Qt apps (OpenSnitch's opensnitch-ui, nm-connection-editor,
# ...) render in Qt's plain default style - white background, no dark mode -
# clashing with the dark + green-accent GTK4/libadwaita theme this system
# otherwise uses everywhere (see hosts/*/home.nix's dconf.settings). qgnomeplatform
# reads that same GNOME dconf state (color-scheme/accent-color under
# org/gnome/desktop/interface), so Qt apps pick up dark mode automatically
# instead of needing a separate hardcoded palette.
{
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };
}
