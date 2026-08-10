# nixos-config

This is the source code of my computing environment: a reproducible, modular
NixOS configuration built on flakes. It's not a dotfiles dump — the goal is
that this repository, plus its [`home`](https://github.com/nomadstar/dotfiles)
submodule, is enough to rebuild the machine it describes from a NixOS Live
ISO.

Base: NixOS 25.11 (stable). Desktop: [Hyprland](https://hyprland.org/) on
Wayland, with an i3-inspired keybinding layout.

## Architecture

```
nixos-config/
├── flake.nix / flake.lock   Entry point. Inputs: nixpkgs (25.11), home-manager,
│                             sops-nix, the dotfiles repo, and claude-code
│                             (Claude Code CLI, for the ai devShell).
├── hosts/
│   ├── desktop/               Host-specific: hostname, timezone, locale, hardware
│   │   ├── default.nix        (disk UUIDs), and the home-manager wiring for this host.
│   │   ├── hardware-configuration.nix
│   │   └── home.nix
│   └── laptop/                 Same shape as desktop/.
├── modules/
│   ├── core/                 Shared across all hosts.
│   │   ├── nix.nix           experimental-features (flakes, nix-command)
│   │   ├── boot.nix          GRUB / UEFI / os-prober
│   │   ├── networking.nix    NetworkManager, sshd
│   │   ├── users.nix         user account
│   │   ├── packages.nix      base CLI + diagnostics tools (incl. nemo, gvfs)
│   │   ├── fonts.nix         Nerd Fonts (JetBrainsMono + symbols-only)
│   │   └── secrets.nix       sops-nix wiring
│   └── desktop/               Shared desktop-environment modules.
│       ├── hyprland.nix      compositor + Wayland utils
│       ├── waybar.nix
│       ├── regreet.nix       greetd + ReGreet (graphical login)
│       ├── monitors.nix      host-specific NixOS-level monitor hook (currently a
│       │                      no-op; actual monitor layout lives in the dotfiles
│       │                      repo's hypr/monitors.conf, applied via Home Manager)
│       ├── hypremoji.nix     HyprEmoji package wiring (see hypremoji/)
│       └── hypremoji/        Source-built package (not in nixpkgs): package.nix
│                              + a vendored Cargo.lock (upstream doesn't ship one)
├── secrets/
│   └── secrets.yaml          sops-encrypted. Safe to be public - see Secrets below.
├── .sops.yaml                 sops creation rules (public age keys only)
├── home/                      git submodule -> the dotfiles repo (Hyprland,
│                              Alacritty, nwg-displays, waybar configs), applied
│                              via Home Manager.
└── assets/                    grub/, regreet/, wallpapers/ - theming placeholders.
```

Common configuration lives in `modules/`; anything host-specific (disk UUIDs,
hostname, monitor layout) lives under `hosts/<name>/`. Adding a second machine
means adding `hosts/<name>/` and a matching `nixosConfigurations.<name>` in
`flake.nix` - it reuses every shared module as-is, as `laptop` now does.

## Supported hosts

| Host | Status | Notes |
|---|---|---|
| `desktop` | Active, daily driver | UEFI, GRUB (os-prober enabled for a dual-boot Windows install), NVMe root, separate ext4 `/home` disk |
| `laptop` | Active | Victus by HP Gaming Laptop 15-fa1xxx, Intel i5-12450H + NVIDIA RTX 2050 (Ampere, GA107) hybrid graphics, single ext4 root |

## Rebuilding this machine

```sh
git clone --recurse-submodules https://github.com/nomadstar/nixos-config.git
cd nixos-config
sudo nixos-rebuild build --flake .#desktop   # build only, verify it succeeds
sudo nixos-rebuild switch --flake .#desktop  # only after build succeeds
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`
before building.

## Installing on new hardware from a NixOS Live ISO

```sh
# partition + format disks, mount at /mnt, then:
git clone --recurse-submodules https://github.com/nomadstar/nixos-config.git /mnt/etc/nixos-config
nixos-install --flake /mnt/etc/nixos-config#desktop
```

You will need a `hosts/<name>/hardware-configuration.nix` matching the actual
target hardware - either reuse an existing one if the hardware matches, or run
`nixos-generate-config` on the target and drop the result in before installing.

## Optional devShells

Tooling for specific domains (AI/local LLM work, pentesting, SDR) is **not**
installed into the base system. Instead:

```sh
nix develop .#ai        # python, ollama, claude (Claude Code CLI), ROCm diagnostics (rocminfo, rocm-smi)
nix develop .#ai-laptop  # same, with CUDA instead of ROCm (laptop's NVIDIA GPU)
nix develop .#pentest    # nmap, wireshark, gobuster, hydra, sqlmap, netcat
nix develop .#sdr        # rtl-sdr, gqrx, gnuradio
```

These are throwaway shells - nothing they provide persists outside the shell,
and none of it touches `environment.systemPackages`.

### AI: quick usage (no shell needed)

For one-off runs, `nix run` fetches and executes a package without entering a
shell or installing anything persistently:

```sh
nix run nixpkgs#opencode                              # OpenCode
nix run github:jacopone/antigravity-nix#agy            # Antigravity CLI (agy)
```

The second command pulls a third-party flake (not vetted as part of this
repo) - read it before trusting it, same as any `curl | sh`.

### GPU compatibility

The `ai` devShell is built by a small `mkAiShell { gpu }` helper in
`flake.nix` with a fixed policy, applied per host: **NVIDIA -> CUDA, AMD ->
ROCm, anything else -> no GPU packages added.** CUDA is unfree, so it's only
allowed for the specific `pkgs` instance used to build the CUDA variant
(`pkgsUnfree`) - the system-wide `pkgs` used for `nixosConfigurations` stays
unfree-free.

This desktop's GPU is an **AMD Radeon RX 9060 XT (Navi 44)** using the
in-tree open-source `amdgpu` driver - confirmed via `lspci` - so
`devShells.ai = mkAiShell { gpu = "amd"; }`, which adds `rocminfo` and
`rocm-smi` (Ollama itself detects and uses ROCm automatically when present).

The `laptop` host has an **NVIDIA GeForce RTX 2050 (Ampere, GA107)** -
confirmed via `lspci` - alongside integrated Intel UHD graphics. Its shell is
`devShells.ai-laptop = mkAiShell { gpu = "nvidia"; }`, pulling in
`cudaPackages.cudatoolkit` and `cuda_nvcc` under `pkgsUnfree`. NVIDIA
proprietary drivers / PRIME offload for the hybrid graphics setup aren't
configured at the NixOS level yet - see roadmap.

System-wide GPU acceleration (`hardware.graphics.enable`, ROCm OpenCL ICDs)
isn't enabled yet at the NixOS level - see roadmap.

## Secrets

Real secrets (Wi-Fi credentials, API keys, VPN configs) are managed with
[sops-nix](https://github.com/Mic92/sops-nix) and encrypted with
[age](https://github.com/FiloSottile/age), so `secrets/secrets.yaml` is safe
to publish: it's ciphertext. Decryption on the target machine reuses its
existing SSH host key (`/etc/ssh/ssh_host_ed25519_key`) - no separate key file
is generated or stored anywhere, in this repo or otherwise.

**What is genuinely never committed here:** plaintext passwords, password
hashes, private SSH/GPG/TLS keys, GitHub/API tokens, Wi-Fi PSKs, VPN secrets,
cookies, or browser profile data. `.gitignore` blocks common raw-key file
patterns as a backstop, but the real guarantee is that nothing plaintext-secret
is ever staged in the first place.

**What *is* published and is not a secret, just worth knowing about:**
filesystem UUIDs in `hosts/desktop/hardware-configuration.nix` (identify these
specific disks, not credentials), and the hostname/username
(`nanixos` / `nanixtus`).

## Known gaps (pre-existing, preserved intentionally during migration)

Carried over as-is from the working system rather than silently "fixed" during
the migration, per a preserve-behavior-first policy:

- `home/hypr/workspaces.conf` exists but is empty/unused.
- Hyprland keybindings are close to, but not a full match for, an i3 mental
  model yet (arrow-key focus/mouse-drag window movement rather than
  `H/J/K/L`).

## Status / roadmap

- [x] Flake conversion of the working configuration (`modules/core`,
      `modules/desktop`, `hosts/desktop`)
- [x] Home Manager managing Hyprland/Alacritty/nwg-displays from the `home/`
      submodule
- [x] sops-nix encrypted secrets pipeline (scaffolded, one demo value)
- [x] `ai` / `pentest` / `sdr` devShells
- [x] `monitors.conf` now sourced from `hyprland.conf` (nwg-displays layout
      actually applies)
- [x] `laptop` host (Victus 15-fa1xxx, Intel + NVIDIA RTX 2050 hybrid
      graphics) - reuses `modules/core`/`modules/desktop` as-is; its own
      `ai-laptop` devShell added
- [x] Nerd Fonts (`modules/core/fonts.nix`: JetBrainsMono + symbols-only),
      shared by both hosts
- [x] `nemo` (`modules/core/packages.nix`, with `services.gvfs.enable` for
      trash/mounts) - the `SUPER+W` keybinding now resolves to a real binary
- [x] HyprEmoji (`modules/desktop/hypremoji.nix`, built from source - not in
      nixpkgs) - `SUPER+.` opens it, keybind/window rules sourced from the
      `home/` dotfiles the same way `monitors.conf` is
- [x] `claude` (Claude Code CLI, via the `claude-code` flake input -
      `github:ryoppippi/nix-claude-code`) added to the `ai`/`ai-laptop`
      devShells
- [x] Waybar: real Hyprland config (`home/waybar/`) replacing the nixpkgs
      Sway example, whose missing `FontAwesome` font was why icons weren't
      showing at all
- [ ] Fix remaining known gaps above (dead workspaces.conf)
- [ ] i3-style `H/J/K/L` focus and window-movement keybindings
- [ ] Wofi: still running on package defaults, no custom config exists yet
- [ ] GRUB theming, ReGreet theming (`assets/grub`, `assets/regreet`)
- [ ] `laptop`'s age key was added to `.sops.yaml`, but `secrets/secrets.yaml`
      itself still needs `sops updatekeys` run from a machine that can
      already decrypt it (the desktop) before the laptop can actually read
      `example_secret`
- [ ] NVIDIA proprietary driver / PRIME offload for the laptop's hybrid
      graphics (currently unconfigured at the NixOS level)
- [ ] System-level GPU acceleration (`hardware.graphics.enable`, ROCm OpenCL
      ICDs for the desktop's AMD GPU) - currently only devShell-level
- [ ] `modules/development` (GPU compute - ROCm or CUDA depending on host
      GPU, general dev tooling) and `modules/security` (network security,
      reverse engineering) as opt-in NixOS modules, distinct from the
      ad-hoc devShells above
- [ ] Recovery/installer ISO generation
