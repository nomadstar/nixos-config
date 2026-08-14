{ config, pkgs, lib, nvimConfig, ... }:

{
  home.username = "nanixtus";
  home.homeDirectory = "/home/nanixtus";

  # Dotfiles live directly in this repo under home/ (previously a separate
  # `dotfiles` repo, fetched as its own flake input and linked in as a git
  # submodule - unified into a single tree/checkout to cut the edit -> push
  # -> `nix flake update dotfiles` -> rebuild round trip down to just edit ->
  # rebuild). Full history of the old setup is still on GitHub at
  # nomadstar/dotfiles if ever needed.
  xdg.configFile."hypr/hyprland.conf".source = ../../home/hypr/hyprland.conf;
  xdg.configFile."hypr/workspaces.conf".source = ../../home/hypr/workspaces.conf;
  xdg.configFile."hypr/hypremoji.conf".source = ../../home/hypr/hypremoji.conf;
  xdg.configFile."hypr/hyprpaper.conf".source = ../../home/hypr/hyprpaper.conf;
  xdg.configFile."alacritty/alacritty.toml".source = ../../home/alacritty/alacritty.toml;
  xdg.configFile."nwg-displays/config".source = ../../home/nwg-displays/config;
  xdg.configFile."waybar/config.jsonc".source = ../../home/waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ../../home/waybar/style.css;
  xdg.configFile."wallpapers/matrix.png".source = ../../home/wallpapers/matrix.png;
  xdg.configFile."wofi/config".source = ../../home/wofi/config;
  xdg.configFile."wofi/style.css".source = ../../home/wofi/style.css;

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

  # Notion as a Chromium "app window" (own window/taskbar entry, no address
  # bar) instead of an Electron wrapper - see modules/core/packages.nix for
  # why notion-app-enhanced was dropped.
  xdg.desktopEntries.notion = {
    name = "Notion";
    genericName = "Notes";
    exec = "chromium --app=https://www.notion.so --name=Notion --class=Notion";
    terminal = false;
    categories = [ "Office" ];
  };

  # Firefox as the default browser for http(s)/html links, plus the
  # pre-existing manual associations (claude-cli, discord) that lived in an
  # unmanaged ~/.config/mimeapps.list before this - preserved here so this
  # declaration doesn't drop them.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
    };
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
      run install -Dm644 "${../../home/hypr/monitors.conf}" "$target"
    fi
  '';

  home.stateVersion = "25.11";

  # Antigravity IDE ships fast builds and isn't in nixpkgs (see flake.nix's
  # antigravity-nix input), so its pin goes stale between manual `nix flake
  # update` runs. This checks daily, bumps just that input, and commits
  # flake.lock if it changed - lock update only, no rebuild. Review and run
  # `nixos-rebuild switch` yourself when you want the new version applied.
  # Requires the linger tmpfiles rule in modules/core/users.nix so the timer
  # fires even when nanixtus isn't logged in.
  systemd.user.services.flake-lock-update-antigravity = {
    Unit = {
      Description = "Update antigravity-nix flake input and commit flake.lock";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "update-antigravity-lock" ''
        set -euo pipefail
        repo="${config.home.homeDirectory}/nixos-config"
        cd "$repo"

        # Don't touch a repo with pending work - just skip this run.
        if ! ${pkgs.git}/bin/git diff --quiet || ! ${pkgs.git}/bin/git diff --cached --quiet; then
          echo "nixos-config has uncommitted changes, skipping flake.lock update"
          exit 0
        fi

        ${pkgs.nix}/bin/nix flake lock --update-input antigravity-nix

        if ! ${pkgs.git}/bin/git diff --quiet -- flake.lock; then
          ${pkgs.git}/bin/git add flake.lock
          ${pkgs.git}/bin/git commit -m "Update flake.lock (antigravity-nix)"
          echo "flake.lock updated and committed - run nixos-rebuild switch to apply"
        else
          echo "antigravity-nix already up to date"
        fi
      '');
    };
  };

  systemd.user.timers.flake-lock-update-antigravity = {
    Unit.Description = "Daily check for antigravity-nix updates";
    Timer = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
