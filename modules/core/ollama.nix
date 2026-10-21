{ config, lib, pkgs, ... }:

let
  gpuBackend = config.hardwareProfile.gpu.computeBackend; # "rocm" on desktop, "cuda" on laptop
in
{
  services.ollama = {
    enable = lib.mkDefault true;
    host = lib.mkDefault "0.0.0.0";
    port = lib.mkDefault 11434;

    # Dynamically select GPU accelerated package based on host computeBackend:
    # desktop (AMD) -> pkgs.ollama-rocm
    # laptop (NVIDIA) -> pkgs.ollama-cuda
    # other/none -> pkgs.ollama (CPU)
    package = lib.mkDefault (
      if gpuBackend == "rocm" then
        pkgs.ollama-rocm
      else if gpuBackend == "cuda" then
        pkgs.ollama-cuda
      else
        pkgs.ollama
    );

    # For AMD RDNA 4 (Radeon RX 9060 XT, gfx1200 on desktop):
    rocmOverrideGfx = lib.mkIf (gpuBackend == "rocm") (lib.mkDefault "12.0.0");

    environmentVariables = lib.mkMerge [
      (lib.mkIf (gpuBackend == "rocm") {
        HSA_OVERRIDE_GFX_VERSION = "12.0.0";
      })
    ];
  };
}
