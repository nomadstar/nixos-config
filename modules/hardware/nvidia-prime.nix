{ config, lib, pkgs, ... }:

{
  # nouveau's GSP/Ampere support is still shaky on this GPU (GA107, RTX 2050)
  # - journalctl shows recurring "gsp: mmu fault queued" / "channel killed"
  # a few minutes into every boot. Switch to the proprietary driver instead.
  boot.blacklistedKernelModules = [ "nouveau" ];
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  # hardware.graphics.enable above makes the GPU driver's libcuda.so.1
  # available under /run/opengl-driver, but that's only wired into
  # GL/Vulkan loaders that already know to look there - a pip-installed
  # RAPIDS/PyTorch-style CUDA wheel just dlopen()s libcuda.so.1 via a plain
  # search path and won't find it without this. Paired with
  # modules/core/nix-ld.nix (which lets the wheel's compiled extensions run
  # at all on NixOS in the first place). Laptop-only: the desktop has no
  # NVIDIA GPU, so this would just be dead weight there.
  environment.variables.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # supported (and recommended) for Turing+ GPUs like this one
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Let the dGPU power all the way down when nothing is using it, instead
    # of idling hot - this laptop's desktop session runs entirely on the
    # Intel iGPU day to day.
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload <cmd>`
      };
      # From `lspci`: Intel iGPU at 00:02.0, NVIDIA dGPU at 01:00.0
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
