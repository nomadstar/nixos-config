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
    hack-font

    # CJK Fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji

    # Icons
    material-design-icons

    # Arabic
    amiri

    # System Fonts
    dejavu_fonts
    liberation_ttf
    freefont_ttf
  ];

  fonts.fontconfig.enable = true;

  # Optional: Configure fallback fonts
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Noto Color Emoji" "DejaVu Sans" ];
    serif = [ "DejaVu Serif" ];
    monospace = [ "JetBrains Mono Nerd Font" "DejaVu Sans Mono" ];
  };
}
