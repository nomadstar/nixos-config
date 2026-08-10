{ config, lib, pkgs, ... }:

{
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.mtr.enable = true;

  # gvfs backs Nemo's trash, network mounts (smb://, sftp://) and
  # removable-media auto-mount.
  services.gvfs.enable = true;

  environment.systemPackages = with pkgs; [
    # Editors
    vim
    neovim
    nano

    # File manager (hyprland.conf's $fileManager, SUPER+W)
    nemo

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
