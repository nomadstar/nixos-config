{ config, lib, pkgs, ... }:

{
  # amdgpu is in-tree and loads automatically for this GPU (desktop's AMD
  # Radeon RX 9060 XT, Navi 44/gfx1200) - no blacklist/driver selection
  # needed like nvidia-prime.nix's nouveau workaround. This module only
  # covers permanent host-level AMD/ROCm support: Vulkan/OpenGL and basic
  # admin/monitoring tools, so GPU state is checkable without `nix develop`.
  #
  # The actual ROCm/HIP compile+run toolchain (clr, hipcc, ...) lives in
  # flake.nix's `developer` devShell instead, on purpose - it's
  # version/target-arch-sensitive per project and not something every
  # process on the system needs linked in.
  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs.rocmPackages; [
    # rocminfo lists the detected GPU/agents, rocm-smi shows
    # utilization/temp/power like nvidia-smi - both useful standalone,
    # independent of any devShell.
    rocminfo
    rocm-smi
  ];
}
