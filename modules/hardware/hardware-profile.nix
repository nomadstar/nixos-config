{ lib, ... }:

with lib;

let
  # Shared vendor enum, reused below instead of repeating the same string
  # list on every option.
  vendorEnum = types.enum [ "amd" "nvidia" "intel" ];
in
{
  # Single declared source of truth for a host's GPU display/compute
  # topology - written once by `detect-hardware` into
  # hosts/<host>/hardware-gpu.nix (see modules/hardware/detect-gpu.nix),
  # then just plain data from here on. Nothing reads /sys or runs lspci
  # during Nix evaluation.
  #
  # The GPU driving the desktop/display is not necessarily the GPU used
  # for compute (e.g. this repo's laptop: Intel iGPU renders the desktop,
  # NVIDIA dGPU does CUDA via PRIME offload) - `displayVendor` and
  # `computeVendor` are kept as separate fields on purpose, never derived
  # from one another.
  #
  # This iteration only produces the data; hosts/<host>/default.nix still
  # imports modules/hardware/amdgpu.nix / nvidia-prime.nix explicitly by
  # hand, and flake.nix's devShells still pick their GPU toolchain by hand
  # too (mkAiShell/mkDeveloperShell `gpu = "amd"/"nvidia"`) - wiring those
  # to read from hardwareProfile.gpu.* is deliberately left for a later
  # iteration, to avoid mixing two architectural changes at once.
  options.hardwareProfile.gpu = {
    mode = mkOption {
      type = types.enum [ "integrated" "discrete" "hybrid" "unknown" ];
      default = "unknown";
      description = ''
        Overall GPU topology: "integrated" (Intel-only), "discrete" (a
        single non-Intel vendor, no Intel adapter present), "hybrid" (an
        Intel iGPU alongside exactly one discrete vendor), or "unknown"
        (not yet detected, or detect-gpu found more than one non-Intel
        vendor and refused to guess - see modules/hardware/gpu-classify.sh).
      '';
    };

    integratedVendor = mkOption {
      type = types.nullOr vendorEnum;
      default = null;
      description = "Vendor of the integrated GPU, if any (always \"intel\" in this repo today).";
    };

    discreteVendor = mkOption {
      type = types.nullOr vendorEnum;
      default = null;
      description = "Vendor of the discrete GPU, if any.";
    };

    displayVendor = mkOption {
      type = types.nullOr vendorEnum;
      default = null;
      description = "Vendor actually driving the desktop/display - not necessarily the same as computeVendor.";
    };

    computeVendor = mkOption {
      type = types.nullOr vendorEnum;
      default = null;
      description = "Vendor targeted for GPU compute (ROCm/CUDA/...) - not necessarily the same as displayVendor.";
    };

    computeBackend = mkOption {
      type = types.nullOr (types.enum [ "rocm" "cuda" "intel" ]);
      default = null;
      description = "Compute backend matching computeVendor. null when there's no compute story yet (e.g. Intel-only hosts today).";
    };

    offload = mkOption {
      type = types.nullOr (types.enum [ "prime" ]);
      default = null;
      description = ''
        Display-offload mechanism from the integrated to the discrete GPU,
        if any. Only ever "prime" (NVIDIA PRIME, see
        modules/hardware/nvidia-prime.nix) - Mesa/DRI_PRIME for an Intel+
        AMD hybrid is a different mechanism and isn't implemented in this
        repo yet, so that case is left null here rather than reusing
        "prime" for it.
      '';
    };
  };
}
