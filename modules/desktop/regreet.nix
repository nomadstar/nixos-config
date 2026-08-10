{ config, lib, pkgs, ... }:

{
  services.greetd.enable = true;

  programs.regreet = {
    enable = true;

    # cage defaults to "-m extend", which spans the greeter across every
    # connected output as one stitched-together framebuffer. "last" pins it
    # to a single output instead, so on dual-monitor hosts the greeter
    # renders correctly on one screen rather than straddling both.
    cageArgs = [ "-s" "-m" "last" ];

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
