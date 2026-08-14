{ pkgs, ... }:

{
  # Lets prebuilt (non-nixpkgs-packaged) Linux binaries run unmodified -
  # RAPIDS'/PyTorch's pip wheels (compiled extensions), VSCode extensions'
  # native bits, etc. Their ELF headers hardcode a standard-distro dynamic
  # linker path (/lib64/ld-linux-x86-64.so.2) that doesn't exist on NixOS
  # without this - the actual reason RAPIDS' cudf/cuml wheels couldn't even
  # start before this, independent of finding the CUDA/GPU libs themselves
  # (see modules/hardware/nvidia-prime.nix's LD_LIBRARY_PATH for that half).
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    curl
    ncurses
    icu
  ];
}
