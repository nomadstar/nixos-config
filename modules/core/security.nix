{ config, lib, pkgs, ... }:

{
  # Enable Wireshark globally. This creates the wireshark group and installs
  # dumpcap with the cap_net_raw,cap_net_admin=eip capabilities, allowing
  # users in the wireshark group to capture packets without sudo or Wayland GUI issues.
  programs.wireshark.enable = true;
}
