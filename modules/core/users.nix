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
    extraGroups = [ "networkmanager" "wheel" "input" "wireshark" "plugdev" ];
  };
}
