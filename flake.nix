{
  description = "nanixtus reproducible NixOS configuration";

  # ============================================================================
  # 1. INPUTS
  # ============================================================================
  inputs = {
    # Base system nixpkgs (stable 25.11)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Rolling/bleeding-edge nixpkgs, kept separate from the stable `nixpkgs`
    # above. The base system stays on 25.11 for reliability; `pkgsUnstable`
    # is for opting individual fast-moving packages into newer versions instead
    # (see opencode, ollama, codex, yt-dlp, etc.). Not `nixpkgs.follows`-ed to
    # anything, on purpose: it's meant to drift from the pinned stable revision.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # User environment manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Secret management with age / sops
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Personal Neovim (NvChad-based) config, linked as submodule in nvim/
    # Fetched as its own input so Nix evaluation doesn't depend on the parent
    # repo's git index carrying submodule content.
    nvimConfig = {
      url = "github:nomadstar/starter";
      flake = false;
    };

    # Claude Code CLI, for the ai devShell. Not in nixpkgs.
    claude-code.url = "github:ryoppippi/nix-claude-code";

    # Google Antigravity IDE + `agy` CLI, for the ai/developer devShells.
    # Pinned with allowUnfree already configured in its own flake.
    antigravity-nix.url = "github:jacopone/antigravity-nix";

    # codebase-memory-mcp: MCP code-intelligence server (see codebaseMemoryMcp
    # below, modules/core/codebase-memory-mcp.nix, and repo-root .mcp.json).
    # Pinned to a release tag. `flake = false` to build from source with UI.
    codebase-memory-mcp = {
      url = "github:DeusData/codebase-memory-mcp/v0.10.5";
      flake = false;
    };

    # SONE: native Linux client for TIDAL (lossless, bit-perfect streaming).
    sone = {
      url = "github:lullabyX/sone";
      flake = false;
    };
  };

  # ============================================================================
  # 2. OUTPUTS
  # ============================================================================
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nvimConfig,
      sops-nix,
      claude-code,
      antigravity-nix,
      codebase-memory-mcp,
      sone,
      ...
    }:
    let
      system = "x86_64-linux";

      # Base nixpkgs set (stable 25.11, unfree-free by default)
      pkgs = nixpkgs.legacyPackages.${system};

      # Opt-in unfree package set (for CUDA, VSCode, etc.)
      pkgsUnfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Deliberately bleeding-edge package set for fast-moving tools
      pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};

      # ------------------------------------------------------------------------
      # Custom Packages & Derivations
      # ------------------------------------------------------------------------

      # codebase-memory-mcp: built from source with graph UI embedded
      # (`make -f Makefile.cbm cbm-with-ui`).
      codebaseMemoryMcp = pkgs.stdenv.mkDerivation {
        pname = "codebase-memory-mcp";
        version = "0.10.5";
        src = codebase-memory-mcp;

        nativeBuildInputs = [
          pkgs.gnumake
          pkgs.nodejs
          pkgs.npmHooks.npmConfigHook
        ];
        buildInputs = [ pkgs.zlib ];

        npmRoot = "graph-ui";
        npmDeps = pkgs.fetchNpmDeps {
          name = "codebase-memory-mcp-graph-ui-npm-deps";
          src = "${codebase-memory-mcp}/graph-ui";
          hash = "sha256-cDwGJi8M/t7eTHVKu6TzW7L9OUAQgB+0c+fiTgPn7cE=";
        };

        buildPhase = ''
          runHook preBuild

          ( cd graph-ui
            npm ci
            # npm's own .bin shims use `#!/usr/bin/env node`, which doesn't
            # resolve on NixOS (/usr/bin/env doesn't exist)
            patchShebangs node_modules
            npm run build
          )

          bash scripts/embed-frontend.sh graph-ui/dist build/c/embedded
          make -j$NIX_BUILD_CORES -f Makefile.cbm -o frontend -o embed cbm-with-ui

          runHook postBuild
        '';

        installPhase = ''
          install -Dm755 build/c/codebase-memory-mcp $out/bin/codebase-memory-mcp
        '';

        meta = {
          description = "MCP server that builds and queries a semantic graph of your codebase, with the graph UI embedded";
          homepage = "https://github.com/DeusData/codebase-memory-mcp";
          license = pkgs.lib.licenses.mit;
          mainProgram = "codebase-memory-mcp";
          platforms = [ "x86_64-linux" ];
        };
      };

      # SONE: native Linux client for TIDAL (lossless, bit-perfect).
      # Built from source with nixpkgs-unstable (for pnpm_11 / cargo-tauri /
      # webkitgtk_4_1). Upstream package.nix has a stale pnpmDeps hash in
      # the latest commit, overridden here with the valid fixed-output hash.
      sonePkg = (pkgsUnstable.callPackage "${sone}/nix/package.nix" { src = sone; }).overrideAttrs (_old: {
        pnpmDeps = pkgsUnstable.fetchPnpmDeps {
          pname = "sone";
          version = (builtins.fromJSON (builtins.readFile "${sone}/src-tauri/tauri.conf.json")).version;
          src = sone;
          pnpm = pkgsUnstable.pnpm_11;
          fetcherVersion = 4;
          hash = "sha256-hT9CJTGRoDPV5BAlXTfR3wO4QNpq3Pag6Fvqag29w5c=";
        };
      });

      # cvbrowser: Shared browser-automation endpoint for AI coding agents
      # (Claude Code, Antigravity/agy, Codex) driving Playwright Firefox via MCP HTTP.
      cvbrowser = pkgs.writeShellApplication {
        name = "cvbrowser";
        runtimeInputs = [
          pkgs.playwright-mcp
          pkgs.procps
          pkgs.curl
        ];
        text = ''
          RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/tmp}/cvbrowser"
          DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/cvbrowser"
          PROFILE_DIR="''${CVBROWSER_PROFILE_DIR:-$DATA_DIR/firefox-profile-playwright}"
          PIDFILE="$RUNTIME_DIR/mcp.pid"
          LOGFILE="$RUNTIME_DIR/mcp.log"
          HOST=127.0.0.1
          PORT=8931

          mkdir -p "$RUNTIME_DIR" "$DATA_DIR" "$PROFILE_DIR"
          chmod 700 "$RUNTIME_DIR" "$DATA_DIR" "$PROFILE_DIR"
          export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
          # nixpkgs' mcp-server-playwright wrapper does
          # `export PLAYWRIGHT_MCP_BROWSER=''${PLAYWRIGHT_MCP_BROWSER-'chromium'}`
          # unconditionally, and the underlying server reads that env
          # var to pick the browser - setting it here selects Firefox.
          export PLAYWRIGHT_MCP_BROWSER=firefox

          is_running() {
            [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
          }

          challenge_protocol() {
            echo "CHALLENGE PROTOCOL: if a Cloudflare Turnstile / CAPTCHA / \"verify you are human\" wall appears (an iframe from challenges.cloudflare.com is the usual tell - seen on Indeed and Fiverr, not LinkedIn) - STOP."
            echo "Do not retry the action and do not try to click/solve it yourself. Tell the user and wait: this browser is headed, so they solve it directly in the visible window; resume only once they confirm it's done."
          }

          cmd="status"
          if [ "$#" -gt 0 ]; then
            cmd="$1"
            shift
          fi

          case "$cmd" in
            start)
              if is_running; then
                echo "already running (pid $(cat "$PIDFILE")): http://$HOST:$PORT/mcp"
                exit 0
              fi
              if curl --silent --output /dev/null --connect-timeout 0.2 "http://$HOST:$PORT/mcp"; then
                echo "cannot start: $HOST:$PORT is already served by another process" >&2
                echo "stop that process before running cvbrowser start" >&2
                exit 1
              fi
              extra_args=()
              if [ "''${CVBROWSER_HEADLESS:-0}" = "1" ]; then
                extra_args+=(--headless)
              fi
              if [ "''${CVBROWSER_ISOLATED:-0}" = "1" ]; then
                extra_args+=(--isolated)
                profile_description="ephemeral in-memory profile"
              else
                extra_args+=(--user-data-dir "$PROFILE_DIR")
                profile_description="dedicated profile: $PROFILE_DIR"
              fi
              extra_args+=("$@")
              nohup mcp-server-playwright --browser firefox --host "$HOST" --port "$PORT" "''${extra_args[@]}" \
                < /dev/null \
                > "$LOGFILE" 2>&1 &
              echo $! > "$PIDFILE"
              ready=0
              for _ in $(seq 1 50); do
                if ! is_running; then
                  break
                fi
                if curl --silent --output /dev/null "http://$HOST:$PORT/mcp" && is_running; then
                  ready=1
                  break
                fi
                sleep 0.1
              done
              if [ "$ready" = "1" ]; then
                echo "started (pid $(cat "$PIDFILE")): http://$HOST:$PORT/mcp  (legacy SSE: http://$HOST:$PORT/sse)"
                echo "$profile_description"
                challenge_protocol
              else
                echo "failed to start - see $LOGFILE" >&2
                rm -f "$PIDFILE"
                exit 1
              fi
              ;;
            stop)
              if is_running; then
                kill -TERM "$(cat "$PIDFILE")"
                echo "sent SIGTERM to $(cat "$PIDFILE")"
              else
                echo "not running"
              fi
              rm -f "$PIDFILE"
              ;;
            kill)
              if is_running; then
                pid="$(cat "$PIDFILE")"
                pkill -KILL -P "$pid" 2>/dev/null || true
                kill -KILL "$pid" 2>/dev/null || true
                echo "killed $pid and its children"
              else
                echo "not running"
              fi
              rm -f "$PIDFILE"
              ;;
            status)
              if is_running; then
                echo "running (pid $(cat "$PIDFILE")): http://$HOST:$PORT/mcp"
              else
                echo "not running"
              fi
              ;;
            logs)
              tail -n 50 -f "$LOGFILE"
              ;;
            login)
              if is_running; then
                echo "stop cvbrowser before opening its profile for manual login" >&2
                exit 1
              fi
              firefox_bins=("$PLAYWRIGHT_BROWSERS_PATH"/firefox-*/firefox/firefox)
              if [ "''${#firefox_bins[@]}" -ne 1 ] || [ ! -x "''${firefox_bins[0]}" ]; then
                echo "cannot locate the Playwright-pinned Firefox executable" >&2
                exit 1
              fi
              echo "opening dedicated profile for manual login: $PROFILE_DIR"
              echo "close Firefox completely before running cvbrowser start"
              exec "''${firefox_bins[0]}" --no-remote --profile "$PROFILE_DIR"
              ;;
            profile)
              echo "$PROFILE_DIR"
              ;;
            protocol)
              challenge_protocol
              ;;
            *)
              echo "usage: cvbrowser {start|stop|kill|status|logs|login|profile|protocol}" >&2
              exit 1
              ;;
          esac
        '';
      };

      # ------------------------------------------------------------------------
      # Development Shell Builders
      # ------------------------------------------------------------------------

      # GPU policy for AI devShell: AMD -> ROCm, NVIDIA -> CUDA, none -> CPU only
      mkAiShell =
        {
          gpu ? "none",
          extraShells ? [ ],
        }:
        let
          gpuPackages =
            if gpu == "amd" then
              (with pkgs; [
                rocmPackages.rocminfo
                rocmPackages.rocm-smi
              ])
            else if gpu == "nvidia" then
              (with pkgsUnfree; [
                cudaPackages.cudatoolkit
                cudaPackages.cuda_nvcc
              ])
            else
              [ ];
        in
        pkgs.mkShell {
          name = "ai-devshell";
          inputsFrom = extraShells;
          packages =
            (with pkgs; [
              python311
              python3Packages.pip
              python3Packages.virtualenv
              uv
              claude-code.packages.${system}.default
              antigravity-nix.packages.${system}.google-antigravity-cli
              nodejs
              yarn
              bun
              pnpm
            ])
            ++ (with pkgsUnstable; [
              ollama
              opencode
              codex
            ])
            ++ gpuPackages;

          shellHook = ''
            export CAMOUFOX_TOOL_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/uv/tools/camoufox-browser-0.1.1"
            export CAMOUFOX_BIN_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/uv/bin/camoufox-browser-0.1.1"
            export PATH="$CAMOUFOX_BIN_DIR:$PATH"

            if [ ! -x "$CAMOUFOX_BIN_DIR/camoufox-mcp" ] || [ ! -x "$CAMOUFOX_BIN_DIR/camoufox-browser" ]; then
              mkdir -p "$CAMOUFOX_BIN_DIR"
              UV_TOOL_DIR="$CAMOUFOX_TOOL_DIR" \
                UV_TOOL_BIN_DIR="$CAMOUFOX_BIN_DIR" \
                uv tool install \
                  --python ${pkgs.python311}/bin/python3.11 \
                  'camoufox-browser[mcp]==0.1.1'
            fi
          '';
        };
    in
    {
      # ========================================================================
      # 3. STANDALONE PACKAGES
      # ========================================================================
      packages.${system} = {
        sone = sonePkg;
        default = sonePkg;
      };

      # ========================================================================
      # 4. NIXOS SYSTEM CONFIGURATIONS
      # ========================================================================
      nixosConfigurations = {
        # Desktop (AMD Ryzen / AMD Radeon RX 9060 XT)
        desktop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit pkgsUnstable codebaseMemoryMcp;
            sone = sonePkg;
          };
          modules = [
            ./hosts/desktop/default.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit nvimConfig; };
              home-manager.users.nanixtus = import ./hosts/desktop/home.nix;
            }
          ];
        };

        # Laptop (Intel / NVIDIA GeForce RTX 2050 Prime)
        laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit pkgsUnstable codebaseMemoryMcp;
            sone = sonePkg;
          };
          modules = [
            ./hosts/laptop/default.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit nvimConfig; };
              home-manager.users.nanixtus = import ./hosts/laptop/home.nix;
            }
          ];
        };
      };

      # Optional, on-demand tool sets: `nix develop .#<name>`. Nothing here
      # is installed into the system config - these are throwaway shells.
      devShells.${system} = rec {
        # Keep the browser/Node toolchain as the default `nix develop`
        # environment; named shells only add to it through inputsFrom.
        default = browserAgent;

        # desktop's GPU: AMD Radeon RX 9060 XT (Navi 44), amdgpu driver -> ROCm.
        # extraShells = [ browserAgent camoufox ] fuses cvbrowser/playwright-mcp/curl
        # and camoufox (Firefox anti-detect engine + Qt GUI) into this same shell
        # instance (see mkAiShell's inputsFrom comment above) - `rec` makes this
        # a valid forward reference to `browserAgent` and `camoufox`, defined
        # further down in this same attrset; Nix attrsets are lazily bound so
        # definition order here doesn't matter.
        ai = mkAiShell { gpu = "amd"; extraShells = [ browserAgent camoufox ]; };

        # laptop's GPU: NVIDIA GeForce RTX 2050 (Ampere, GA107) -> CUDA.
        ai-laptop = mkAiShell { gpu = "nvidia"; extraShells = [ browserAgent camoufox ]; };

        pentest =
          let
            # python3Packages.scapy/scrapy on their own wouldn't be
            # importable - separate packages in `packages` just add their
            # own store paths to PATH, they don't get merged into a bare
            # `python3`'s sys.path. withPackages builds one interpreter
            # with both baked into its site-packages instead.
            pythonWithScapyScrapy = pkgs.python3.withPackages (ps: [ ps.scapy ps.scrapy ]);
          in
          pkgs.mkShell {
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
              # NB: the cracker is `thc-hydra`, NOT `hydra` - nixpkgs' plain
              # `hydra` attribute is NixOS's own Nix-based continuous build
              # system, a completely unrelated package. That name collision
              # is why `hydra` silently "didn't work" here before: it did
              # install, just not the tool anyone in this shell wants.
              thc-hydra hashcat hashcat-utils john cewl crunch
              medusa ncrack crowbar brutespray

              # Post-explotación / AD
              metasploit netexec evil-winrm enum4linux-ng smbmap

              # Utilidades
              seclists jq ripgrep git curl pipx
              pythonWithScapyScrapy
              nodejs yarn bun pnpm
            ];
            shellHook = ''
              # netexec (and possibly others here) exports its own PYTHONPATH
              # - its whole python3.12 dependency closure - into this shell's
              # environment. That leaks into any other python3 invocation,
              # including pythonWithScapyScrapy's python3.13 (mismatched
              # compiled-extension ABI, e.g. lxml failing to import etree).
              # Each tool's own wrapper script sets its PYTHONPATH again right
              # before running itself, so this is safe to drop.
              unset PYTHONPATH
              export PATH="$HOME/.local/bin:$PATH"
              # dumpcap del devshell no tiene CAP_NET_RAW/CAP_NET_ADMIN; anteponer
              # /run/wrappers/bin para que Wireshark use el dumpcap con capabilities
              # que instala programs.wireshark.enable (modules/core/security.nix).
              export PATH="/run/wrappers/bin:$PATH"
              # bettercap/responder/mitmproxy/etc. all drag their own plain
              # python3 into this shell's PATH as a runtime dependency, ahead
              # of pythonWithScapyScrapy above (packages list order doesn't
              # control PATH priority - closure order does), so a bare
              # `python3` here would silently resolve to one *without* scapy
              # or scrapy. Force it back to the front explicitly.
              export PATH="${pythonWithScapyScrapy}/bin:$PATH"
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
            nodejs yarn bun pnpm
          ];
        };

        # RAPIDS (cuDF/cuML/...) has no real nixpkgs packaging - it ships as
        # prebuilt manylinux pip wheels. Their compiled extensions hardcode
        # a standard-distro dynamic linker path that doesn't exist on
        # NixOS - modules/core/packages.nix's nix-ld fixes that system-wide, and
        # modules/hardware/nvidia-prime.nix (laptop-only) exports
        # LD_LIBRARY_PATH so they can also find the actual GPU driver's
        # libcuda.so.1. With both in place a plain venv + pip install just
        # works, no FHS/chroot layer needed here (an earlier buildFHSEnv
        # version of this shell hit real problems: `.env` skips the actual
        # sandbox, and the alternative - `exec`ing into the wrapper's own
        # bash - breaks `nix develop -c CMD`; not needed once nix-ld covers
        # the same problem at the system level instead).
        #
        # NVIDIA-only (laptop's RTX 2050, Ampere/GA107) - there's no ROCm
        # equivalent to RAPIDS, so unlike `ai`/`ai-laptop` there's just one
        # variant, and it does nothing useful run from the desktop (no
        # NVIDIA GPU there, so no libcuda.so to find - nix-ld itself is
        # host-agnostic, but that half alone isn't enough).
        #
        # First use, inside `nix develop .#rapids`:
        #   python3 -m venv ~/.venvs/rapids && source ~/.venvs/rapids/bin/activate
        #   pip install --extra-index-url=https://pypi.nvidia.com cudf-cu12 cuml-cu12 ipykernel
        #   python -m ipykernel install --user --name rapids --display-name "RAPIDS (CUDA 12.8)"
        #   jupyter lab   # then pick the "RAPIDS" kernel in the notebook
        # cu12 matches this nixpkgs' cudaPackages.cudatoolkit (12.8) - if a
        # future `nix flake update` bumps that to a cu13 release, the pip
        # install line needs to follow. ~/.venvs/rapids persists across
        # shell entries (auto-activated below if already there) - only the
        # devShell itself is throwaway, same as everywhere else in this
        # flake. jupyterlab comes from nixpkgs (fast, no multi-minute
        # download) rather than the venv - it doesn't need CUDA itself,
        # just to be able to spawn the registered "rapids" kernel.
        rapids = pkgs.mkShell {
          name = "rapids-devshell";
          packages = with pkgs; [
            python3
            python3Packages.pip
            python3Packages.virtualenv
            python3Packages.jupyterlab
            nodejs
            yarn
            bun
            pnpm
          ] ++ (with pkgsUnfree; [
            cudaPackages.cudatoolkit
            cudaPackages.cuda_nvcc
          ]);
          shellHook = ''
            # nix-ld (modules/core/packages.nix) only covers a pip-installed
            # wheel's *own* initial dynamic loading. RAPIDS' native libs
            # then dlopen() several more .so's themselves from already-
            # running Python (ctypes), which uses plain LD_LIBRARY_PATH
            # instead - confirmed live: `import cudf` got past process
            # startup fine, then failed with "libstdc++.so.6: cannot open
            # shared object file" from inside libcufile's own dlopen call.
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              pkgs.openssl
              pkgs.curl
              pkgs.ncurses
              pkgs.icu
            ]}:/run/opengl-driver/lib"
            venv="$HOME/.venvs/rapids"
            if [ -d "$venv" ]; then
              # shellcheck disable=SC1091
              source "$venv/bin/activate"
            else
              echo "No RAPIDS venv yet at $venv - first-time setup:"
              echo "  python3 -m venv $venv && source $venv/bin/activate"
              echo "  pip install --extra-index-url=https://pypi.nvidia.com cudf-cu12 cuml-cu12 ipykernel"
              echo '  python -m ipykernel install --user --name rapids --display-name "RAPIDS (CUDA 12.8)"'
            fi
          '';
        };

        # GUI editors/IDEs plus the build/JS toolchain, kept out of the ai
        # devShell (and off the system entirely) since they're heavy/version-
        # sensitive per-project and only needed on demand. vscode is unfree,
        # hence pkgsUnfree instead of pkgs here. nodejs bundles npm.
        #
        # inputsFrom pulls rapids in too (packages + its shellHook, which
        # mkShell concatenates from every inputsFrom entry) - both are dev
        # tool sets, and `nix develop .#developer && ..#rapids` doesn't
        # combine environments (the second only starts once you exit the
        # first), so this is the one-shell way to get both VSCode/build
        # tooling and RAPIDS/CUDA in the same session. rapids itself stays
        # around unchanged for a lighter, faster shell when the editors
        # aren't needed.
        #
        # Also carries desktop's AMD HIP/ROCm compile toolchain (clr,
        # hipcc) alongside rapids' CUDA packages - the two vendors' tool-
        # chains don't collide (distinct package names/paths), so one
        # shell covers both compiling HIP kernels for the desktop's RX
        # 9060 XT (gfx1200) and running RAPIDS against the laptop's NVIDIA
        # dGPU, whichever host you're actually on.
        developer = pkgs.mkShell {
          name = "developer-devshell";
          inputsFrom = [ rapids ];
          packages = [
            pkgsUnfree.vscode
            antigravity-nix.packages.${system}.google-antigravity-ide
          ] ++ (with pkgs; [ gcc cmake ninja pkg-config nodejs yarn bun pnpm ]) ++ (with pkgs.rocmPackages; [
            # Minimal HIP compile+run toolchain for desktop's AMD Radeon RX
            # 9060 XT (gfx1200) - `clr` is the HIP runtime/ROCclr (also
            # installs the HIP headers and its own patched clang toolchain
            # under $out/llvm) and `hipcc` is the compiler driver that
            # invokes it. rocminfo/rocm-smi are already on PATH system-wide
            # via modules/hardware/amdgpu.nix on desktop - listed again
            # here too since they're tiny and this shell should be usable
            # to validate them on its own. Deliberately not pulling in
            # rocBLAS/MIOpen/rccl/etc - those are per-framework libraries
            # (PyTorch-ROCm et al. pull their own), not needed just to
            # build and run a HIP kernel.
            clr
            hipcc
            rocminfo
            rocm-smi
          ]);
          shellHook = ''
            # Pin every hipcc invocation to gfx1200 (desktop's RX 9060 XT)
            # instead of relying on hipcc's runtime `amdgpu-arch` autodetect
            # - keeps builds reproducible (same output regardless of GPU
            # state/permissions at compile time) and avoids accidentally
            # compiling fat multi-arch binaries. Harmless on the laptop -
            # it just never invokes hipcc there.
            export HIP_PLATFORM=amd
            export HIPCC_COMPILE_FLAGS_APPEND="--offload-arch=gfx1200"
          '';
        };

        # LaTeX editing/compiling, plus the Python (Jinja2/PyYAML) toolchain
        # that data-driven LaTeX generators (e.g. CVmaker's scripts/build.py)
        # need to render templates before compiling. texlive.combine here
        # instead of a plain `texlive.combined.scheme-*` package: scheme-full
        # is a multi-GB download, and scheme-medium alone turned out to be
        # missing titlesec and enumitem (both in collection-latexextra, not
        # pulled in by scheme-medium - confirmed by an actual failed compile:
        # scheme-medium alone still 404'd on enumitem.sty) plus Spanish
        # hyphenation patterns (collection-langspanish) - all used by
        # CVmaker's templates (\usepackage{titlesec}, \usepackage{enumitem},
        # \usepackage[spanish]{babel}). Combining scheme-medium with just
        # those keeps the closure far smaller than scheme-full while still
        # covering every package currently `\usepackage`'d anywhere in that
        # repo (fontenc/inputenc/geometry/hyperref/babel are already in
        # scheme-medium). Add more collections/packages here if a future
        # template pulls in something outside this set.
        latexedit = pkgs.mkShell {
          name = "latexedit-devshell";
          packages = with pkgs; [
            (texlive.combine {
              inherit (texlive) scheme-medium latexmk titlesec enumitem collection-langspanish;
            })
            texlivePackages.chktex
            python3
            python3Packages.pip
            python3Packages.virtualenv
            python3Packages.jinja2
            python3Packages.pyyaml
            nodejs
            yarn
            bun
            pnpm
          ];
        };

        # Camoufox: anti-detect browser (custom C++-patched Firefox engine +
        # Playwright stealth wrapper and PySide6/Qt GUI manager).
        # Installed via venv + pip with full native library linkages (GTK3,
        # NSS, NSPR, Wayland, X11, OpenGL, ALSA) supplied via LD_LIBRARY_PATH
        # and nix-ld so both `camoufox fetch` (downloaded Firefox binary) and
        # `camoufox gui` (PySide6 Qt GUI) run out-of-the-box on NixOS.
        camoufox = pkgs.mkShell {
          name = "camoufox-devshell";
          packages = with pkgs; [
            python3
            python3Packages.pip
            python3Packages.virtualenv
            curl
            procps
            nodejs
            yarn
            bun
            pnpm
          ];
          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (with pkgs; [
              stdenv.cc.cc.lib
              zlib
              zstd
              brotli
              bzip2
              expat
              harfbuzz
              krb5
              libpulseaudio
              speechd
              openssl
              curl
              glib
              gtk3
              pango
              cairo
              gdk-pixbuf
              atk
              at-spi2-atk
              at-spi2-core
              dbus
              libxkbcommon
              xorg.libX11
              xorg.libXcomposite
              xorg.libXdamage
              xorg.libXext
              xorg.libXfixes
              xorg.libXrandr
              xorg.libxcb
              xorg.libXcursor
              xorg.libXi
              xorg.libXrender
              xorg.libXtst
              xorg.libxkbfile
              xorg.xcbutil
              xorg.xcbutilcursor
              xorg.xcbutilimage
              xorg.xcbutilkeysyms
              xorg.xcbutilrenderutil
              xorg.xcbutilwm
              mesa
              libglvnd
              libGL
              alsa-lib
              nspr
              nss
              cups
              fontconfig
              freetype
              ffmpeg
              systemd
              libdrm
              wayland
            ])}:''${LD_LIBRARY_PATH:-}"

            # PySide6 / Qt6 platform plugin configuration
            export QT_QPA_PLATFORM="wayland;xcb"

            venv="$HOME/.venvs/camoufox"
            if [ -d "$venv" ]; then
              # shellcheck disable=SC1091
              source "$venv/bin/activate"
            else
              echo "==> Entorno Camoufox no encontrado en $venv. Configuración inicial:"
              echo "    Creando virtualenv e instalando Camoufox con soporte GUI y GeoIP..."
              python3 -m venv "$venv"
              # shellcheck disable=SC1091
              source "$venv/bin/activate"
              pip install --upgrade pip
              pip install "camoufox[gui,geoip]"
              echo ""
              echo "==> ¡Camoufox configurado con éxito!"
              echo "    - Para abrir el gestor gráfico: camoufox gui"
              echo "    - Para instalar/actualizar el motor manualmente: camoufox fetch"
              echo "    - Para usar en Python:           from camoufox.sync_api import Camoufox"
            fi
          '';
        };

        # Shared browser-automation endpoint for AI coding agents (Claude
        # Code, Antigravity/agy, Codex) to drive a real Firefox via MCP tool
        # calls, instead of each paying for its own browser-use API. A single
        # `mcp-server-playwright --port` process serves MCP over HTTP at
        # 127.0.0.1:8931/mcp; every tool just gets an MCP *client* entry
        # pointing at that URL (see the `cvbrowser` script's own --help and
        # the three config snippets below) - no per-tool browser/API cost.
        #
        # Both `playwright-mcp` (Microsoft's official MCP server) and its
        # Firefox build come straight from nixpkgs (confirmed via
        # `nix build`: every path copied from cache.nixos.org, nothing
        # fetched live from Microsoft's own playwright.dev/Azure CDN the way
        # a plain `npx @playwright/mcp` or `playwright install firefox`
        # would) - this is what "quitar el acceso a Microsoft" turns into in
        # practice: the browser binary is a Nix derivation, not a live
        # download, and `mcp-server-playwright --help` has no
        # telemetry/analytics flag to begin with (there's nothing to opt out
        # of - confirmed by reading the full --help output, not assumed).
        # PLAYWRIGHT_BROWSERS_PATH below points the server at that Nix-built
        # Firefox instead of letting it try to fetch its own.
        #
        # Isolation is process-level, not a container (podman is available
        # system-wide - modules/core/virtualisation.nix - but a plain nix-
        # shell process was the explicit choice here): `cvbrowser start` runs
        # detached with its PID recorded in $XDG_RUNTIME_DIR/cvbrowser/, and
        # `cvbrowser kill` SIGKILLs that PID plus its children (the actual
        # Firefox process tree) the instant anything looks wrong - the whole
        # point of the exercise. The browser uses its own persistent profile
        # under $XDG_DATA_HOME/cvbrowser/firefox-profile-playwright so a human
        # can log in once without exposing or reusing their everyday Firefox
        # profile. `cvbrowser login` launches the exact Playwright-pinned
        # Firefox build without automation for providers that reject automated
        # OAuth browsers; using the system Firefox here can upgrade the profile
        # and make the pinned build refuse to open it afterwards.
        # CVBROWSER_ISOLATED=1 opts back into an in-memory throwaway profile.
        # It is headed by default so the user can watch every agent action
        # (CVBROWSER_HEADLESS=1 for headless instead).
        #
        # Client wiring (run once per tool, after `cvbrowser start`):
        #   Claude Code: claude mcp add --transport http --scope user \
        #     playwright-browser http://127.0.0.1:8931/mcp
        #   Codex (~/.codex/config.toml):
        #     [mcp_servers.playwright]
        #     url = "http://127.0.0.1:8931/mcp"
        #   Antigravity/agy (~/.gemini/config/mcp_config.json or
        #   <workspace>/.agents/mcp_config.json - note the key is
        #   `serverUrl`, NOT `url`; Antigravity's docs say legacy `url`/
        #   `httpUrl` fields are not supported):
        #     { "mcpServers": { "playwright": {
        #         "serverUrl": "http://127.0.0.1:8931/mcp" } } }
        #
        # Fused into `ai`/`ai-laptop` above via inputsFrom (mkAiShell's
        # `extraShells` argument), so `nix develop .#ai` alone already has
        # `cvbrowser` on PATH next to codex/claude-code/agy - no separate
        # `nix develop .#browserAgent` shell needed for normal use. Kept as
        # its own standalone attribute too (same reasoning as `rapids`
        # staying separate from `developer`): a lighter shell for headless/
        browserAgent = pkgs.mkShell {
          name = "browser-agent-devshell";
          packages = [
            cvbrowser
            pkgs.playwright-mcp
            pkgs.curl
            pkgs.nodejs
            pkgs.yarn
            pkgs.bun
            pkgs.pnpm
          ];
        };
      };

      # ========================================================================
      # 6. CHECKS & TESTS (`nix flake check`)
      # ========================================================================
      checks.${system}.gpu-classify =
        pkgs.runCommand "gpu-classify-tests" { } ''
          ${pkgs.writeShellApplication {
            name = "detect-gpu-selftest";
            text =
              builtins.readFile ./modules/hardware/gpu-classify.sh
              + "\n"
              + builtins.readFile ./modules/hardware/gpu-classify-test.sh;
          }}/bin/detect-gpu-selftest
          touch $out
        '';
    };
}
