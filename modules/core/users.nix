{ config, lib, pkgs, ... }:

{
  users.users.nanixtus = {
    isNormalUser = true;
    description = "Ignatus";
    # "input" grants read access to /dev/input/event* (root:input, no
    # uaccess ACL by default) - needed for waybar's keyboard-state module
    # to report caps lock / num lock state.
    # "wireshark" allows capturing packets via dumpcap without sudo.
    # "plugdev" allows access to SDR hardware.
    # "libvirtd" allows managing/using qemu VMs (modules/core/virtualisation.nix)
    # without sudo. podman is rootless and needs no group membership.
    extraGroups = [ "networkmanager" "wheel" "input" "wireshark" "plugdev" "libvirtd" ];
  };
}
