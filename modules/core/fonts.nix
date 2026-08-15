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

    # Chromium/Electron UI fonts - without these, Chromium-based apps
    # (any browser, and Electron/VSCode-family apps like Antigravity) ask
    # fontconfig for a named font ("Roboto" on most Google sites, "Inter"
    # on VSCode-family UIs) that doesn't resolve to anything installed.
    # The observed symptom isn't a missing-glyph tofu box - it's every
    # word in a line getting stretched apart evenly, which is what
    # happens when the substituted fallback has different (often
    # monospace-ish) glyph-advance metrics than the proportional font the
    # UI was actually laid out for.
    roboto
    inter

    # CJK Fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji

    # Broad-coverage Latin/symbol fallback beyond the CJK/emoji subsets
    # above - fixes the same missing-named-font substitution problem for
    # any other app expecting "Noto Sans" specifically.
    noto-fonts

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
    sansSerif = [ "Roboto" "Inter" "Noto Sans" "Noto Color Emoji" "DejaVu Sans" ];
    serif = [ "DejaVu Serif" ];
    monospace = [ "JetBrains Mono Nerd Font" "DejaVu Sans Mono" ];
  };
}
