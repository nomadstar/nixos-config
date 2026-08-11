{ fluxcast, ... }:

# FluxCast (https://github.com/IlyaP358/fluxcast) isn't in nixpkgs, and one
# of its dependencies (upnpclient) isn't either, so both are built here.
#
# Runtime notes:
# - The WFD/Miracast media path shells out to wf-recorder + ffmpeg (wlroots
#   screen capture) and gst-launch-1.0/gst-inspect-1.0 (the actual WFD RTP
#   mux/transport), so those need to be on PATH - wrapProgram below handles
#   that instead of adding them to environment.systemPackages.
# - P2P/WFD group formation goes through NetworkManager over D-Bus
#   (services.networking.networkmanager, already enabled), not raw
#   wpa_supplicant config files - nothing extra to wire up for that.
# - This only installs the `fluxcast` command; nothing here auto-starts it
#   or touches firewall/network config. Run `fluxcast --doctor` first to
#   check what's actually available on a given machine.
{
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
          postFixup = ''
            wrapProgram $out/bin/fluxcast --prefix PATH : ${prev.lib.makeBinPath [
              prev.wf-recorder
              prev.ffmpeg
              prev.gst_all_1.gstreamer
              prev.gst_all_1.gst-plugins-base
              prev.gst_all_1.gst-plugins-good
              prev.gst_all_1.gst-plugins-bad
              prev.gst_all_1.gst-plugins-ugly
              prev.iproute2
            ]}
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
