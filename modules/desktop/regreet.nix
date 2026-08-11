{ config, lib, pkgs, ... }:

let
  # Physical output the greeter should render on. Must match a monitor name
  # from home/hypr/monitors.conf (DP-1 is the primary 1920x1080 panel).
  greeterOutput = "DP-1";

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
  services.greetd = {
    enable = true;
    settings.default_session.command =
      "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe pkgs.sway} --config ${greetdSwayConfig}";
  };

  programs.regreet = {
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
