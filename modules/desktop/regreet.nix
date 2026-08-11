{ config, lib, pkgs, ... }:

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
    settings.default_session.command =
      "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe pkgs.sway} --config ${greetdSwayConfig}";
  };

  config.programs.regreet = {
    enable = true;

    settings = {
      GTK = { application_prefer_dark_theme = true; };
      appearance = {
        greeting_msg = "Welcome you wonderful person!";
      };
      widget.clock = { format = "%A, %d %B % %H:%M"; };
    };

    font = {
      name = "Cantarell";
      size = 16;
    };
  };
}
