{ config, lib, pkgs, ... }:

# VMs (qemu/KVM via libvirtd), containers (podman), and Android apps (waydroid),
# enabled system-wide rather than left to a devShell: all need kernel/system-level
# integration that doesn't work well from an isolated shell -
# - libvirtd: /dev/kvm access, the libvirtd group, the virtlogd/virtqemud
#   daemons that actually run the VMs.
# - podman rootless: subuid/subgid ranges assigned to the user, which NixOS
#   handles automatically for normal users but only takes effect through the
#   system module, not a plain package.
# - waydroid: binder_linux/ashmem_linux kernel modules + the waydroid-container
#   LXC service that must run as root - the same reasoning applies.
# Same reasoning as modules/core/security.nix's programs.wireshark.enable.
{
  # Kernel 6.18+ on this system is compiled without CONFIG_IP_TABLES (legacy
  # iptables), using nftables exclusively. waydroid-net.sh hardcodes
  # LXC_USE_NFT="false" and prefers iptables-legacy, which fails with:
  #   "Module ip_tables not found" / "Table does not exist"
  # Patch the script to flip LXC_USE_NFT="true" and add nft to its PATH.
  nixpkgs.overlays = [
    (final: prev: {
      waydroid = prev.waydroid.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          # Flip the networking backend from legacy iptables to nftables.
          # The waydroid-net.sh-wrapped binary is a compiled C wrapper that
          # prepends a PATH and then exec's the real shell script. The shell
          # script itself is .waydroid-net.sh-wrapped (plain text); patch that.
          local script="$out/lib/waydroid/data/scripts/.waydroid-net.sh-wrapped"

          # 1. Enable nftables mode in the shell script.
          substituteInPlace "$script" \
            --replace-fail 'LXC_USE_NFT="false"' 'LXC_USE_NFT="true"'

          # 2. Rebuild the C wrapper so that nft (from nftables) is on PATH.
          #    The original wrapper was built with makeCWrapper; recreate it
          #    with nftables prepended to the existing PATH prefix.
          local nft_bin="${final.nftables}/bin"
          local orig_wrapper="$out/lib/waydroid/data/scripts/waydroid-net.sh"

          # makeCWrapper is available via the makeBinaryWrapper setup hook.
          rm -f "$orig_wrapper"
          makeCWrapper "$script" "$orig_wrapper" \
            --inherit-argv0 \
            --prefix PATH : "$nft_bin:${final.dnsmasq}/bin:${final.glibc.bin}/bin:${final.iproute2}/bin:${final.iptables}/bin"
        '';
      });
    })
  ];
  virtualisation.libvirtd.enable = true;

  # GUI frontend for libvirtd - create/manage VMs without hand-writing
  # virsh/XML. Pulls in polkit rules so the libvirtd group (users.nix) is
  # enough to use it without sudo.
  programs.virt-manager.enable = true;

  virtualisation.podman = {
    enable = true;
    # docker-compatible CLI/socket, for tooling that still shells out to
    # `docker` instead of `podman`.
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Podman/buildah consult these files even for rootless builds. Declare them
  # explicitly so the NixOS generation always provides policy.json and a
  # deterministic registry for short image names (for example node:20-alpine).
  virtualisation.containers = {
    policy = {
      default = [{ type = "reject"; }];
      transports = {
        docker."docker.io/library" = [{ type = "insecureAcceptAnything"; }];
        docker."docker.io/nvidia" = [{ type = "insecureAcceptAnything"; }];
        docker."nvcr.io/nvidia" = [{ type = "insecureAcceptAnything"; }];
        docker-daemon."" = [{ type = "insecureAcceptAnything"; }];
      };
    };
    registries.search = [ "docker.io" ];
  };

  environment.systemPackages = [ pkgs.podman-compose ];

  # qemu already ships user-mode emulators for every guest arch (qemu-aarch64,
  # qemu-arm, qemu-riscv64, ...) as part of virtualisation.libvirtd's qemu
  # package, but nothing runs them automatically. This registers them with
  # the kernel's binfmt_misc so foreign-arch ELF binaries execute
  # transparently - covers both running a random foreign binary directly and
  # `podman build/run --platform linux/arm64` pulling/running non-x86_64
  # container images without a full VM.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" "riscv64-linux" ];

  # Waydroid: run Android apps natively in a Wayland session.
  # The module handles binder_linux/ashmem_linux kernel modules and the
  # waydroid-container LXC service automatically - no manual modprobe needed.
  # After `nixos-rebuild switch`, run once: sudo waydroid init
  #
  # GPU rendering strategy - driven by hardwareProfile.gpu.displayVendor:
  #   amd / intel → Mesa/gbm works out-of-the-box, no extra flags needed.
  #     desktop:  AMD RX 9060 XT (discrete, displayVendor = "amd")   → mesa
  #     laptop:   Intel iGPU     (hybrid,   displayVendor = "intel")  → mesa
  #       (the NVIDIA dGPU is PRIME-offloaded and never drives the display,
  #        so Waydroid never needs to talk to it)
  #   nvidia (pure discrete, no iGPU) → Waydroid has no official EGL path for
  #     the proprietary NVIDIA driver; fall back to software rendering via
  #     virgl so the container at least starts, at the cost of GPU perf.
  #     Neither host today hits this branch, but it's here for completeness.
  virtualisation.waydroid.enable = true;

  environment.etc."waydroid/waydroid_base.prop" =
    lib.mkIf (config.hardwareProfile.gpu.displayVendor == "nvidia") {
      text = ''
        ro.hardware.gralloc=default
        ro.hardware.egl=swiftshader
      '';
    };
}

