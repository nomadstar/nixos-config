{ config, lib, pkgs, ... }:

{
  users.users.nanixtus = {
    isNormalUser = true;
    description = "Ignatus";
    extraGroups = [ "networkmanager" "wheel" ];
  };
}
