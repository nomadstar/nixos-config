{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    # General
    font-awesome

    # Nerd Fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only

    # UI & Terminal
    fira-code
    source-code-pro
    cascadia-code
    hack

    # CJK Fonts
    noto-fonts-cjk
    noto-fonts-emoji

    # Icons
    material-design-icons
    noto-cjk

    # Arabic
    amiri
    # Other common Arabic fonts
    noto-sans-arabic
    tahoma

    # System Fonts
    dejavu_fonts
    liberation_fonts
    freefont

    wps-fonts
  ];

  fonts.fontconfig.enable = true;

  # Optional: Configure fallback fonts
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Noto Color Emoji" "DejaVu Sans" ];
    serif = [ "DejaVu Serif" ];
    monospace = [ "JetBrains Mono Nerd Font" "DejaVu Sans Mono" ];
  };
}
