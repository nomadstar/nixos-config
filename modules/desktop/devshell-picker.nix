{ config, lib, pkgs, ... }:

# Waybar button that lists this flake's devShells (see README.md's
# "Optional devShells" section) and opens one in a terminal, instead of
# having to remember the exact `nix develop ~/nixos-config#whatever`
# invocation and shell name.
let
  # Same fixed clone location assumed by nixos-install/README.md; not
  # derived from $PWD since this runs from a waybar click, not a shell in
  # the repo.
  repoPath = "/home/nanixtus/nixos-config";

  devshellPicker = pkgs.writeShellApplication {
    name = "devshell-picker";
    runtimeInputs = [ pkgs.nix pkgs.jq pkgs.wofi pkgs.alacritty pkgs.libnotify ];
    text = ''
      # flake.nix hardcodes `system = "x86_64-linux"` for every output
      # (including devShells), so no need to detect it here.
      shells=$(nix flake show --json "${repoPath}" 2>/dev/null \
        | jq -r '.devShells["x86_64-linux"] // {} | keys[]')

      if [ -z "$shells" ]; then
        notify-send "nix develop" "No se encontraron devShells en ${repoPath}"
        exit 0
      fi

      choice=$(printf '%s\n' "$shells" | wofi --dmenu --prompt "nix develop" --width 480 --height 300)
      [ -n "$choice" ] || exit 0

      alacritty --title "nix develop .#$choice" --working-directory "${repoPath}" -e nix develop "${repoPath}#$choice"
    '';
  };
in
{
  environment.systemPackages = [ devshellPicker ];
}
