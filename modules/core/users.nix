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

  # Enables lingering for nanixtus: the user's systemd instance starts at
  # boot and keeps running after logout, instead of only while logged in.
  # Needed for the antigravity-nix flake.lock auto-update timer (see
  # hosts/*/home.nix) to fire on schedule even when no session is active.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/nanixtus 0644 root root -"
  ];
}
