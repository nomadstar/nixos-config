{ config, lib, pkgs, ... }:

{
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.mtr.enable = true;

  environment.systemPackages = with pkgs; [
    # Editors
    vim
    neovim
    nano

    # CLI
    git
    wget
    curl
    unzip
    zip
    p7zip
    fastfetch
    bat
    gh

    # Basic monitoring
    htop
    tree
    file
    pciutils
    usbutils

    # Shell utils
    ripgrep
    fd

    # Network diagnostics
    bmon
    iftop
    nload
    nethogs
    tcpdump
    iperf3
  ];
}
