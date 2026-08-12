{ config, lib, pkgs, ... }:

{
  users.users.nanixtus = {
    isNormalUser = true;
    description = "Ignatus";
    # "input" grants read access to /dev/input/event* (root:input, no
    # uaccess ACL by default) - needed for waybar's keyboard-state module
    # to report caps lock / num lock state.
    extraGroups = [ "networkmanager" "wheel" "input" ];
  };
}
