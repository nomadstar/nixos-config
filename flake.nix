{
  description = "nanixtus reproducible NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Rolling/bleeding-edge nixpkgs, kept separate from the stable `nixpkgs`
    # above. The base system stays on 25.11 for reliability; `pkgsUnstable`
    # (below) is for opting individual fast-moving packages into newer
    # versions instead - see the ai devShell's opencode/ollama for the
    # pattern. Not `nixpkgs.follows`-ed to anything, on purpose: it's meant
    # to actually drift from the pinned stable revision.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Curated dotfiles (hypr/alacritty/nwg-displays), also linked in as the
    # home/ git submodule for `git clone --recurse-submodules`. Fetched here
    # as its own flake input so Nix evaluation doesn't depend on the parent
    # repo's git index carrying submodule content (it doesn't).
    dotfiles = {
      url = "github:nomadstar/dotfiles";
      flake = false;
    };

    # Personal Neovim (NvChad-based) config, also linked in as the nvim/ git
    # submodule for `git clone --recurse-submodules` - same reasoning as
    # `dotfiles` above.
    nvimConfig = {
      url = "github:nomadstar/starter";
      flake = false;
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Claude Code CLI, for the ai devShell. Not in nixpkgs.
    claude-code.url = "github:ryoppippi/nix-claude-code";

    # Google Antigravity IDE + `agy` CLI, for the ai/developer devShells. Not
    # in nixpkgs; this flake pins its own nixpkgs with allowUnfree already set.
    antigravity-nix.url = "github:jacopone/antigravity-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, dotfiles, nvimConfig, sops-nix, claude-code, antigravity-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # CUDA packages are unfree; only the pkgs instance used to build the
      # nvidia devShell variant allows it. The system-wide `pkgs` above (and
      # therefore nixosConfigurations) stays unfree-free unless you decide
      # otherwise for the whole system.
      pkgsUnfree = import nixpkgs { inherit system; config.allowUnfree = true; };

      # Deliberately bleeding-edge, for individual packages that are worth
      # tracking closely (see "Package freshness" in the README). Nothing
      # is pulled from here by default - it's opt-in per package, per
      # devShell/module, same spirit as pkgsUnfree above.
      pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};

      # GPU policy for the ai devShell, per host: NVIDIA -> CUDA, AMD -> ROCm,
      # anything else (no dGPU, Intel-only, etc.) -> no GPU packages added.
      mkAiShell = { gpu ? "none" }:
        let
          gpuPackages =
            if gpu == "amd" then
              (with pkgs; [ rocmPackages.rocminfo rocmPackages.rocm-smi ])
            else if gpu == "nvidia" then
              (with pkgsUnfree; [ cudaPackages.cudatoolkit cudaPackages.cuda_nvcc ])
            else
              [ ];
        in
        pkgs.mkShell {
          name = "ai-devshell";
          packages = with pkgs; [
            python3
            python3Packages.pip
            python3Packages.virtualenv
            claude-code.packages.${system}.default
            antigravity-nix.packages.${system}.google-antigravity-cli
          ] ++ (with pkgsUnstable; [
            # These two ship new releases often enough that waiting for
            # them to land in nixos-25.11 means running months-old
            # versions - pulled from pkgsUnstable instead of pkgs on
            # purpose. Everything else in this shell stays on stable.
            ollama
            opencode
          ]) ++ gpuPackages;
        };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit dotfiles pkgsUnstable; };
        modules = [
          ./hosts/desktop/default.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit dotfiles nvimConfig; };
            home-manager.users.nanixtus = import ./hosts/desktop/home.nix;
          }
        ];
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit dotfiles pkgsUnstable; };
        modules = [
          ./hosts/laptop/default.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit dotfiles nvimConfig; };
            home-manager.users.nanixtus = import ./hosts/laptop/home.nix;
          }
        ];
      };

      # Optional, on-demand tool sets: `nix develop .#<name>`. Nothing here
      # is installed into the system config - these are throwaway shells.
      devShells.${system} = {
        # desktop's GPU: AMD Radeon RX 9060 XT (Navi 44), amdgpu driver -> ROCm.
        ai = mkAiShell { gpu = "amd"; };

        # laptop's GPU: NVIDIA GeForce RTX 2050 (Ampere, GA107) -> CUDA.
        ai-laptop = mkAiShell { gpu = "nvidia"; };

        pentest = pkgs.mkShell {
          name = "pentest-devshell";
          packages = with pkgs; [
            # Red
            nmap masscan netcat-gnu socat tcpdump
            bettercap responder mitmproxy proxychains zap wireshark

            # Recon / DNS / OSINT
            dnsutils whois dnsrecon amass theharvester whatweb

            # Web
            gobuster ffuf feroxbuster nikto nuclei sqlmap commix

            # Credenciales (patator reemplazado por alternativas nativas)
            hydra hashcat hashcat-utils john cewl crunch
            medusa ncrack crowbar brutespray

            # Post-explotación / AD
            metasploit netexec evil-winrm enum4linux-ng smbmap

            # Utilidades
            seclists jq ripgrep git curl python3 pipx
          ];
          shellHook = ''
            export PATH="$HOME/.local/bin:$PATH"
            # dumpcap del devshell no tiene CAP_NET_RAW/CAP_NET_ADMIN; anteponer
            # /run/wrappers/bin para que Wireshark use el dumpcap con capabilities
            # que instala programs.wireshark.enable (modules/core/security.nix).
            export PATH="/run/wrappers/bin:$PATH"
            # Fallback: si nixpkgs no trae patator o impacket, pipx los instala
            command -v patator  >/dev/null 2>&1 || pipx install patator  >/dev/null 2>&1 || true
            command -v secretsdump.py >/dev/null 2>&1 || pipx install impacket >/dev/null 2>&1 || true
            echo "pentest-devshell listo: patator=$(command -v patator) secretsdump=$(command -v secretsdump.py)"
          '';
        };

        sdr = pkgs.mkShell {
          name = "sdr-devshell";
          packages = with pkgs; [
            # Drivers / hardware
            rtl-sdr hackrf airspy airspyhf soapysdr uhd

            # GUI
            gqrx cubicsdr sdrpp

            # Análisis / pentesting RF
            urh inspectrum multimon-ng rtl_433 dump1090-fa

            # GNU Radio / DSP
            gnuradio gnuradioPackages.osmosdr python3

            # Modos digitales
            fldigi direwolf wsjtx

            # GPS / satélites (gps-sdr-sim no está en nixpkgs, se cayó del shell)
            gpsd gnss-sdr gpredict

            # Audio / utilidades
            sox ffmpeg audacity pavucontrol
          ];
        };

        # GUI editors/IDEs plus the build/JS toolchain, kept out of the ai
        # devShell (and off the system entirely) since they're heavy/version-
        # sensitive per-project and only needed on demand. vscode is unfree,
        # hence pkgsUnfree instead of pkgs here. nodejs bundles npm.
        developer = pkgs.mkShell {
          name = "developer-devshell";
          packages = [
            pkgsUnfree.vscode
            antigravity-nix.packages.${system}.google-antigravity-ide
          ] ++ (with pkgs; [ gcc cmake nodejs pnpm yarn ]);
        };
      };
    };
}
