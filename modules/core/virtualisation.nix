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

