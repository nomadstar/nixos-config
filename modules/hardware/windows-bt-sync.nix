{ config, lib, pkgs, ... }:

let
  # Bundles windows-bt-sync (stdlib-only Python; hivexregedit/systemctl are
  # the only external processes it shells out to, added to its PATH below)
  # as an installable CLI - same self-contained-module pattern
  # malware-check.nix uses for nix-malware-check.
  windowsBtSync = pkgs.python3Packages.buildPythonApplication {
    pname = "windows-bt-sync";
    version = "0.1.0";
    pyproject = true;
    src = ./windows-bt-sync;
    build-system = [ pkgs.python3Packages.hatchling ];
    doCheck = false;
    makeWrapperArgs = [
      "--prefix" "PATH" ":" (lib.makeBinPath [ pkgs.hivex pkgs.systemd ])
    ];
  };
in
{
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  environment.systemPackages = [ windowsBtSync ];

  # Only reads hivexregedit's export of the Windows registry (never writes
  # to the Windows partition, unlike tools that go the other direction via
  # chntpw/reged) and only ever writes into /var/lib/bluetooth - the actual
  # Windows mount (with its host-specific partition UUID) lives in the
  # host's own config, not here; see hosts/laptop/default.nix.
  systemd.services.windows-bt-sync = {
    description = "Sync Bluetooth LE/classic pairing keys from Windows into BlueZ";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    unitConfig.RequiresMountsFor = "/mnt/winC";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${windowsBtSync}/bin/windows-bt-sync";
    };
  };
}
