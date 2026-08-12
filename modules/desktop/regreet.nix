{ config, lib, pkgs, dotfiles, ... }:

let
  cfg = config.desktop.greeter;
  greeterOutput = cfg.output;

  # cage (regreet's default compositor) can only span every output ("-m
  # extend", the default - the greeter gets stretched across both screens as
  # one stitched framebuffer) or pin to whichever output the kernel happens
  # to enumerate last ("-m last") - it has no flag to pick an output by
  # name. Sway does, so it's used here as a throwaway single-purpose
  # compositor: disable every output, re-enable only one, run regreet, then
  # quit sway once regreet exits.
  #
  # Which output to enable is picked at runtime rather than baked into a
  # static `output NAME enable` line: prefer greeterOutput, but if it isn't
  # actually connected on this host (wrong name, docked/undocked, hardware
  # swap, ...) fall back to whatever sway does see instead of leaving every
  # output disabled - that's what turned a naming mismatch into a greetd
  # crash-loop before.
  greetdSwaySetupOutput = pkgs.writeShellScript "greetd-sway-setup-output" ''
    set -eu
    chosen=$(${lib.getExe' pkgs.sway "swaymsg"} -t get_outputs -r \
      | ${lib.getExe pkgs.jq} -r --arg pref ${lib.escapeShellArg greeterOutput} \
        '(map(select(.name == $pref)) + .) | .[0].name // empty')
    if [ -z "$chosen" ]; then
      echo "greetd-sway-setup-output: no outputs found" >&2
      exit 1
    fi
    ${lib.getExe' pkgs.sway "swaymsg"} output '*' disable
    ${lib.getExe' pkgs.sway "swaymsg"} output "$chosen" enable
  '';

  greetdSwayConfig = pkgs.writeText "greetd-sway-config" ''
    exec "${greetdSwaySetupOutput}; ${lib.getExe config.programs.regreet.package}; swaymsg exit"
  '';
in
{
  options.desktop.greeter.output = lib.mkOption {
    type = lib.types.str;
    default = "DP-1";
    description = ''
      Physical output the greeter should prefer rendering on (see
      home/hypr/monitors.conf for real monitor names on this host). If it
      isn't actually connected, greetd-sway-setup-output falls back to
      whatever output sway does see, so a stale/wrong name here degrades
      to "some output" instead of crash-looping greetd.
    '';
  };

  config.services.greetd = {
    enable = true;
    # --unsupported-gpu: sway refuses to start at all when it sees the
    # proprietary NVIDIA driver loaded (modules/hardware/nvidia-prime.nix),
    # regardless of which GPU it actually renders on - this is only the
    # greeter's throwaway compositor, not the user's Hyprland session, so
    # sway's "don't report issues" caveat is fine to accept here.
    settings.default_session.command =
      "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe pkgs.sway} --unsupported-gpu --config ${greetdSwayConfig}";
  };

  config.programs.regreet = {
    enable = true;

    settings = {
      GTK = { application_prefer_dark_theme = true; };
      appearance = {
        greeting_msg = "Welcome you wonderful person!";
      };
      widget.clock = { format = "%A, %d %B % %H:%M"; };
      background = {
        path = "${dotfiles}/wallpapers/matrix.png";
        fit = "Cover";
      };
    };

    font = {
      name = "Cantarell";
      size = 16;
    };

    cursorTheme = {
      package = pkgs.matrix-cursors;
      name = "matrix-cursors";
    };

    # Matrix-green-on-black to match the desktop theme instead of stock
    # Adwaita gray. Selectors are the widget names/classes ReGreet's
    # relm4 templates set - see src/gui/templates.rs upstream.
    extraCss = ''
      window {
        background-color: #000000;
      }

      frame.background {
        background-color: rgba(0, 20, 0, 0.8);
        border: 1px solid #00ff41;
        border-radius: 10px;
        color: #00ff41;
      }

      #clock_frame {
        color: #00ff41;
        font-family: monospace;
        font-size: 20px;
        padding: 4px 20px;
      }

      label {
        color: #00ff41;
      }

      entry {
        background-color: #001a00;
        color: #00ff41;
        border: 1px solid #00ff41;
        caret-color: #00ff41;
      }

      entry:focus-within {
        border-color: #66ff9c;
        box-shadow: 0 0 6px #00ff41;
      }

      button {
        color: #00ff41;
        border: 1px solid #00ff41;
        background-color: #001a00;
      }

      button:hover {
        background-color: #00330a;
      }

      #login_button.suggested-action {
        background-color: #00ff41;
        color: #000000;
        font-weight: bold;
      }

      #login_button.suggested-action:hover {
        background-color: #00cc35;
      }

      #reboot_button.destructive-action,
      #poweroff_button.destructive-action {
        color: #ff5555;
        border-color: #ff5555;
        background-color: #1a0000;
      }

      #notif_info {
        background-color: rgba(0, 20, 0, 0.9);
        color: #00ff41;
        border: 1px solid #00ff41;
      }

      #notif_label {
        color: #00ff41;
      }
    '';
  };
}
