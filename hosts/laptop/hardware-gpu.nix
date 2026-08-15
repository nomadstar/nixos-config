{
  # Hand-written, not generated: `detect-hardware` can only see the PCI
  # devices of the machine it actually runs on, so this laptop's profile
  # can't be produced from the desktop. Matches modules/hardware/nvidia-
  # prime.nix's existing hybrid Intel iGPU + NVIDIA dGPU setup.
  hardwareProfile.gpu = {
    mode = "hybrid";
    integratedVendor = "intel";
    discreteVendor = "nvidia";
    displayVendor = "intel";
    computeVendor = "nvidia";
    computeBackend = "cuda";
    offload = "prime";
  };
}
