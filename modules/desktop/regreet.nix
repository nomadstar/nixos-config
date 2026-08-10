{ config, lib, pkgs, ... }:

{
  services.greetd.enable = true;

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
