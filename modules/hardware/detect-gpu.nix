{ pkgs, ... }:

let
  # gpu-classify.sh is the pure topology-classification logic (no PCI/
  # sysfs access) - concatenated ahead of both the real detector and its
  # test runner below, so the exact same function is what's exercised by
  # `detect-gpu-selftest` and what actually runs on real hardware.
  classifyLib = builtins.readFile ./gpu-classify.sh;

  detectGpu = pkgs.writeShellApplication {
    name = "detect-gpu";
    runtimeInputs = [ pkgs.pciutils pkgs.jq ];
    text = classifyLib + "\n" + builtins.readFile ./detect-gpu.sh;
  };

  detectHardware = pkgs.writeShellApplication {
    name = "detect-hardware";
    runtimeInputs = [ detectGpu pkgs.jq ];
    text = builtins.readFile ./detect-hardware.sh;
  };

  detectGpuSelftest = pkgs.writeShellApplication {
    name = "detect-gpu-selftest";
    text = classifyLib + "\n" + builtins.readFile ./gpu-classify-test.sh;
  };
in
{
  environment.systemPackages = [ detectGpu detectHardware detectGpuSelftest ];
}
