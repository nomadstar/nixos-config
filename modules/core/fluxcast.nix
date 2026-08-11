{ pkgs, fluxcast, ... }:

# FluxCast (https://github.com/IlyaP358/fluxcast) isn't in nixpkgs, and one
# of its dependencies (upnpclient) isn't either, so both are built here.
#
# Runtime notes:
# - The WFD/Miracast media path shells out to wf-recorder + ffmpeg (wlroots
#   screen capture) and gst-launch-1.0/gst-inspect-1.0 (the actual WFD RTP
#   mux/transport), so those need to be on PATH - wrapProgram below handles
#   that instead of adding them to environment.systemPackages.
# - P2P/WFD group formation goes through NetworkManager, but fluxcast also
#   probes wpa_supplicant's own D-Bus interface directly (WFDIE support,
#   P2P capability checks) - NixOS's default dbus policy for
#   fi.w1.wpa_supplicant1 only allows root, so the `networkmanager` group
#   (nanixtus is already in it, see modules/core/users.nix) gets read access
#   below. Method calls beyond property reads and `own` stay root-only.
# - This only installs the `fluxcast` command; nothing here auto-starts it
#   or touches firewall/network config. Run `fluxcast --doctor` first to
#   check what's actually available on a given machine.
{
  # services.dbus.packages (not environment.etc) is how NixOS merges extra
  # policy fragments into /etc/dbus-1/system.d - environment.etc."dbus-1"
  # is already claimed whole by the dbus module itself, so a nested
  # environment.etc."dbus-1/system.d/..." entry fails to build.
  services.dbus.packages = [
    (pkgs.writeTextDir "share/dbus-1/system.d/wpa_supplicant-fluxcast.conf" ''
      <!DOCTYPE busconfig PUBLIC
       "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
       "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
      <busconfig>
        <policy group="networkmanager">
          <allow send_destination="fi.w1.wpa_supplicant1"/>
          <allow receive_sender="fi.w1.wpa_supplicant1" receive_type="signal"/>
        </policy>
      </busconfig>
    '')
  ];

  nixpkgs.overlays = [
    (final: prev:
      let
        upnpclient = prev.python3Packages.buildPythonPackage rec {
          pname = "upnpclient";
          version = "2.0.3";
          format = "wheel";
          src = prev.fetchurl {
            url = "https://files.pythonhosted.org/packages/d1/85/a96e21ceca5d612852d0f319a689da827f7be93b26b39faf3224d02847d1/upnpclient-2.0.3-py3-none-any.whl";
            sha256 = "01b5930a16799f5ca2096b520207fa0ae85ecd2627529fc7f96a8e02c4d0e656";
          };
          propagatedBuildInputs = with prev.python3Packages; [
            ifaddr
            lxml
            python-dateutil
            requests
          ];
          doCheck = false;
          meta.description = "Python 3 library for accessing uPnP devices";
        };
      in
      {
        fluxcast = prev.python3Packages.buildPythonApplication {
          pname = "fluxcast";
          version = "0.2.2";
          pyproject = true;
          src = fluxcast;

          build-system = [ prev.python3Packages.hatchling ];

          dependencies = with prev.python3Packages; [
            upnpclient
            pychromecast
            dbus-next
            pillow
            pystray
            pygobject3
          ];

          nativeBuildInputs = [ prev.makeWrapper ];
          postFixup =
            let
              gstPlugins = with prev.gst_all_1; [
                gst-plugins-base
                gst-plugins-good
                gst-plugins-bad
                gst-plugins-ugly
              ];
            in
            ''
              wrapProgram $out/bin/fluxcast \
                --prefix PATH : ${prev.lib.makeBinPath ([
                  prev.wf-recorder
                  prev.ffmpeg
                  prev.gst_all_1.gstreamer
                  prev.iproute2
                  prev.pulseaudio # pactl
                  prev.xorg.xrandr
                  prev.dnsmasq
                  prev.iw
                ] ++ gstPlugins)} \
                --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${prev.lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins}
            '';

          doCheck = false;

          meta = with prev.lib; {
            description = "Wireless display casting for Linux via Miracast/WFD, DLNA, or Chromecast";
            homepage = "https://github.com/IlyaP358/fluxcast";
            license = licenses.gpl3Only;
            mainProgram = "fluxcast";
          };
        };
      })
  ];
}
