{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.greeter;
  greeterOutput = cfg.output;

  # cage (regreet's default compositor) can only span every output ("-m
  # extend", the default - the greeter gets stretched across both screens as
  # one stitched framebuffer) or pin to whichever output the kernel happens
  # to enumerate last ("-m last") - it has no flag to pick an output by
  # name. Sway does, so it's used here as a throwaway single-purpose
  # compositor: disable every output, re-enable only greeterOutput, run
  # regreet, then quit sway once regreet exits.
  greetdSwayConfig = pkgs.writeText "greetd-sway-config" ''
    output * disable
    output ${greeterOutput} enable
    exec "${lib.getExe config.programs.regreet.package}; swaymsg exit"
  '';
in
{
  options.desktop.greeter.output = lib.mkOption {
    type = lib.types.str;
    default = "DP-1";
    description = ''
      Physical output the greeter should render on. Must match a real
      monitor name for this host (see home/hypr/monitors.conf) - if it
      doesn't exist, sway's `output * disable` leaves every real output
      disabled and the greeter fails to create a session.
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
