{
  description = "Persistent ComfyUI ROCm environment";
  inputs.comfyui-nix.url = "github:utensils/comfyui-nix";
  outputs = { self, comfyui-nix }:
    let
      system = "x86_64-linux";
      pkgs = import comfyui-nix.inputs.nixpkgs { inherit system; };
      upstream = comfyui-nix.packages.${system}.rocm;
      hardened = pkgs.writeShellApplication {
        name = "comfy-ui";
        text = ''
          # Reject argparse abbreviations as well as full option names.
          for arg in "$@"; do
            option="''${arg%%=*}"
            if [[ "$option" == --* ]]; then
              for forbidden in --enable-manager --whitelist-custom-nodes --enable-cors-header; do
                if [[ "$forbidden" == "$option"* ]]; then
                  echo "Option blocked by the local security profile: $arg" >&2
                  exit 2
                fi
              done
            fi
          done
          export COMFY_SKIP_BUNDLED_NODES=1
          exec ${upstream}/bin/comfy-ui "$@" \
            --disable-all-custom-nodes --listen 127.0.0.1
        '';
        meta.mainProgram = "comfy-ui";
      };
    in {
      packages.${system} = {
        default = hardened;
        rocm = hardened;
      };

      # Import this module from the host configuration to get systemd isolation.
      nixosModules.default = { lib, ... }: {
        imports = [ comfyui-nix.nixosModules.default ];
        services.comfyui = {
          package = hardened;
          gpuSupport = lib.mkDefault "rocm";
          listenAddress = lib.mkDefault "127.0.0.1";
          openFirewall = lib.mkDefault false;
          bundledCustomNodes = lib.mkDefault false;
          enableManager = lib.mkDefault false;
        };
      };
    };
}
