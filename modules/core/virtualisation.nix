{ config, lib, pkgs, ... }:

# VMs (qemu/KVM via libvirtd) and containers (podman), enabled system-wide
# rather than left to a devShell: both need kernel/system-level integration
# that doesn't work well from an isolated shell -
# - libvirtd: /dev/kvm access, the libvirtd group, the virtlogd/virtqemud
#   daemons that actually run the VMs.
# - podman rootless: subuid/subgid ranges assigned to the user, which NixOS
#   handles automatically for normal users but only takes effect through the
#   system module, not a plain package.
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
}
