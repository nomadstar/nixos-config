{ config, lib, pkgs, ... }:

let
  gpuBackend = config.hardwareProfile.gpu.computeBackend; # "rocm" on desktop, "cuda" on laptop
  allowedBackends = [ "rocm" "cuda" "intel" ];
  acceleratedPackages = [
    pkgs.ollama-rocm
    pkgs.ollama-cuda
    pkgs.ollama-vulkan
  ];

  # Verify the expected GPU/NPU device nodes exist before starting Ollama.
  requireAccelScript = pkgs.writeShellScript "ollama-require-accel" ''
    set -eu
    case "${toString gpuBackend}" in
      rocm)
        if [ ! -e /dev/kfd ] || ! ls /dev/dri/renderD* >/dev/null 2>&1; then
          echo "ERROR: ROCm GPU device (/dev/kfd or /dev/dri/renderD*) not available. Refusing to start Ollama on CPU." >&2
          exit 1
        fi
        ;;
      cuda)
        if [ ! -e /dev/nvidiactl ] || ! ls /dev/nvidia[0-9]* >/dev/null 2>&1; then
          echo "ERROR: CUDA GPU device (/dev/nvidiactl or /dev/nvidia*) not available. Refusing to start Ollama on CPU." >&2
          exit 1
        fi
        ;;
      intel)
        if ! ls /dev/dri/renderD* >/dev/null 2>&1 && ! ls /dev/accel/accel* >/dev/null 2>&1; then
          echo "ERROR: Intel GPU/NPU device (/dev/dri/renderD* or /dev/accel/accel*) not available. Refusing to start Ollama on CPU." >&2
          exit 1
        fi
        ;;
      *)
        echo "ERROR: No GPU/NPU compute backend configured (${toString gpuBackend}). Refusing to start Ollama on CPU." >&2
        exit 1
        ;;
    esac
  '';

  # Monitor Ollama's startup discovery logs and abort immediately if it falls back to CPU.
  serveGpuOnlyScript = pkgs.writeShellScript "ollama-serve-gpu-only" ''
    set -u
    ollama_bin="${lib.getExe config.services.ollama.package}"

    fifo=$(mktemp -u /tmp/ollama-log.XXXXXX)
    mkfifo "$fifo"
    cleanup() {
      rm -f "$fifo"
    }
    trap cleanup EXIT

    "$ollama_bin" serve >"$fifo" 2>&1 &
    ollama_pid=$!

    forward_sig() {
      kill -TERM "$ollama_pid" 2>/dev/null || true
    }
    trap forward_sig TERM INT

    gpu_ok=0
    while IFS= read -r line <&3; do
      printf '%s\n' "$line" >&2
      case "$line" in
        *'msg="inference compute"'*library=cpu*|*'no compatible GPUs were discovered'*)
          if [ "$gpu_ok" -eq 0 ]; then
            echo "FATAL: Ollama fell back to CPU (no GPU/NPU inference backend active). Aborting." >&2
            kill -TERM "$ollama_pid" 2>/dev/null || true
            wait "$ollama_pid" 2>/dev/null || true
            exit 1
          fi
          ;;
        *'msg="inference compute"'*library=*)
          gpu_ok=1
          ;;
      esac
    done 3<"$fifo"

    wait "$ollama_pid"
  '';
in
{
  assertions = lib.optionals config.services.ollama.enable [
    {
      assertion = gpuBackend != null && builtins.elem gpuBackend allowedBackends;
      message = "services.ollama requires a GPU or NPU compute backend (hardwareProfile.gpu.computeBackend must be \"rocm\", \"cuda\", or \"intel\"); CPU-only execution is forbidden (got: ${toString gpuBackend}).";
    }
    {
      assertion = builtins.elem config.services.ollama.package acceleratedPackages;
      message = "services.ollama.package must be an accelerated GPU/NPU build (ollama-rocm, ollama-cuda, or ollama-vulkan); CPU-only execution is forbidden.";
    }
    {
      assertion = (config.services.ollama.environmentVariables.OLLAMA_LLM_LIBRARY or "") != "cpu";
      message = "services.ollama.environmentVariables.OLLAMA_LLM_LIBRARY cannot be \"cpu\"; CPU-only execution is forbidden.";
    }
  ];

  services.ollama = {
    enable = lib.mkDefault true;
    host = lib.mkDefault "0.0.0.0";
    port = lib.mkDefault 11434;
    # Hermes requires at least 64K context; leave GPU memory allocation to Ollama.
    environmentVariables = { OLLAMA_CONTEXT_LENGTH = "65536"; } // lib.optionalAttrs (gpuBackend == "rocm") {
      HSA_OVERRIDE_GFX_VERSION = "12.0.0";
    };

    # Dynamically select GPU/NPU accelerated package based on host computeBackend:
    # desktop (AMD) -> pkgs.ollama-rocm
    # laptop (NVIDIA) -> pkgs.ollama-cuda
    # intel (GPU/NPU) -> pkgs.ollama-vulkan
    # CPU-only fallback is forbidden and rejected by assertions above.
    package = lib.mkDefault (
      if gpuBackend == "rocm" then
        pkgs.ollama-rocm
      else if gpuBackend == "cuda" then
        pkgs.ollama-cuda
      else if gpuBackend == "intel" then
        pkgs.ollama-vulkan
      else
        pkgs.ollama-cpu
    );

    # For AMD RDNA 4 (Radeon RX 9060 XT, gfx1200 on desktop):
    rocmOverrideGfx = lib.mkIf (gpuBackend == "rocm") (lib.mkDefault "12.0.0");
  };

  systemd.services.ollama.serviceConfig = lib.mkIf config.services.ollama.enable ({
    ExecStartPre = [ "${requireAccelScript}" ];
    ExecStart = lib.mkForce "${serveGpuOnlyScript}";
  } // lib.optionalAttrs (gpuBackend == "intel") {
    DeviceAllow = [ "char-accel" ];
  });
}
