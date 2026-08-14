{ config, lib, pkgs, ... }:

# SUPER+SHIFT+P: fuzzy-search packages installed in the nearest .venv above
# the *currently focused terminal's* actual working directory - not this
# script's own cwd, since a freshly spawned Alacritty always starts in
# $HOME regardless of what directory you were sitting in. Selecting a
# package opens a new terminal, already `cd`'d into the project root with
# that venv activated, showing `pip show` for the package you picked -
# same wofi-picker-into-alacritty shape as devshell-picker.nix.
let
  venvPkgSearch = pkgs.writeShellApplication {
    name = "venv-pkg-search";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
      pkgs.procps
      pkgs.wofi
      pkgs.alacritty
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      # Alacritty's own cwd never changes after launch - the real project
      # directory lives in its foreground shell child's /proc/<pid>/cwd.
      focused_pid=$(hyprctl activewindow -j | jq -r 'select(.class == "Alacritty") | .pid')
      start_dir="$HOME"
      if [ -n "$focused_pid" ]; then
        child_pid=$(pgrep -P "$focused_pid" | head -n1 || true)
        if [ -n "$child_pid" ] && [ -e "/proc/$child_pid/cwd" ]; then
          start_dir=$(readlink -f "/proc/$child_pid/cwd")
        fi
      fi

      dir="$start_dir"
      venv=""
      while [ "$dir" != "/" ]; do
        if [ -d "$dir/.venv" ]; then
          venv="$dir/.venv"
          break
        fi
        dir=$(dirname "$dir")
      done

      if [ -z "$venv" ]; then
        notify-send "venv-pkg-search" "No .venv found above $start_dir"
        exit 0
      fi

      packages=$("$venv/bin/pip" list --format=freeze 2>/dev/null)
      if [ -z "$packages" ]; then
        notify-send "venv-pkg-search" "$venv has no installed packages"
        exit 0
      fi

      choice=$(printf '%s\n' "$packages" | wofi --dmenu --prompt "venv pkg ($dir)" --width 600 --height 400)
      [ -n "$choice" ] || exit 0
      pkg_name=$(printf '%s' "$choice" | cut -d= -f1)

      # Self-deleting temp script instead of `bash -c "..."` string
      # interpolation - keeps quoting/escaping of $venv and $pkg_name
      # (arbitrary paths/package names) unambiguous.
      inner_script=$(mktemp)
      {
        # shellcheck disable=SC2016
        echo 'rm -f -- "$0"'
        printf 'source %q\n' "$venv/bin/activate"
        printf '%q show %q\n' "$venv/bin/pip" "$pkg_name"
        echo
        # shellcheck disable=SC2016
        echo 'exec "$SHELL"'
      } > "$inner_script"
      chmod +x "$inner_script"

      alacritty --title "venv: $pkg_name" --working-directory "$dir" -e bash "$inner_script"
    '';
  };
in
{
  environment.systemPackages = [ venvPkgSearch ];
}
