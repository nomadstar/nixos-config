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
│                             sops-nix, and the dotfiles repo.
├── hosts/
│   └── desktop/              Host-specific: hostname, timezone, locale, hardware
│       ├── default.nix       (disk UUIDs), and the home-manager wiring for this host.
│       ├── hardware-configuration.nix
│       └── home.nix
├── modules/
│   ├── core/                 Shared across all hosts.
│   │   ├── nix.nix           experimental-features (flakes, nix-command)
│   │   ├── boot.nix          GRUB / UEFI / os-prober
│   │   ├── networking.nix    NetworkManager, sshd
│   │   ├── users.nix         user account
│   │   ├── packages.nix      base CLI + diagnostics tools
│   │   └── secrets.nix       sops-nix wiring
│   └── desktop/               Shared desktop-environment modules.
│       ├── hyprland.nix      compositor + Wayland utils
│       ├── waybar.nix
│       ├── regreet.nix       greetd + ReGreet (graphical login)
│       └── monitors.nix      host-specific monitor wiring hook (currently a no-op,
│                              see Known gaps below)
├── secrets/
│   └── secrets.yaml          sops-encrypted. Safe to be public - see Secrets below.
├── .sops.yaml                 sops creation rules (public age keys only)
├── home/                      git submodule -> the dotfiles repo (Hyprland,
│                              Alacritty, nwg-displays configs), applied via
│                              Home Manager.
└── assets/                    grub/, regreet/, wallpapers/ - theming placeholders.
```

Common configuration lives in `modules/`; anything host-specific (disk UUIDs,
hostname, monitor layout) lives under `hosts/<name>/`. Adding a second machine
(e.g. `laptop`) means adding `hosts/laptop/` and a matching
`nixosConfigurations.laptop` in `flake.nix` - it reuses every shared module
as-is.

## Supported hosts

| Host | Status | Notes |
|---|---|---|
| `desktop` | Active, daily driver | UEFI, GRUB (os-prober enabled for a dual-boot Windows install), NVMe root, separate ext4 `/home` disk |
| `laptop` | Not yet added | Planned |

## Rebuilding this machine

```sh
git clone --recurse-submodules <this-repo-url>
cd nixos-config
sudo nixos-rebuild build --flake .#desktop   # build only, verify it succeeds
sudo nixos-rebuild switch --flake .#desktop  # only after build succeeds
```

If you cloned without `--recurse-submodules`, run `git submodule update --init`
before building.

## Installing on new hardware from a NixOS Live ISO

```sh
# partition + format disks, mount at /mnt, then:
git clone --recurse-submodules <this-repo-url> /mnt/etc/nixos-config
nixos-install --flake /mnt/etc/nixos-config#desktop
```

You will need a `hosts/<name>/hardware-configuration.nix` matching the actual
target hardware - either reuse an existing one if the hardware matches, or run
`nixos-generate-config` on the target and drop the result in before installing.

## Optional devShells

Tooling for specific domains (AI/local LLM work, pentesting, SDR) is **not**
installed into the base system. Instead:

```sh
nix develop .#ai        # python, ollama
nix develop .#pentest    # nmap, wireshark, gobuster, hydra, sqlmap, netcat
nix develop .#sdr        # rtl-sdr, gqrx, gnuradio
```

These are throwaway shells - nothing they provide persists outside the shell,
and none of it touches `environment.systemPackages`.

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

- `home/hypr/hyprland.conf` never sources `monitors.conf`, so the
  nwg-displays-generated dual-monitor layout likely isn't actually applied.
- `home/hypr/workspaces.conf` exists but is empty/unused.
- The `hyprland.conf` file-manager keybinding (`SUPER+W`) points at `nemo`,
  which isn't installed anywhere in this config.
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
- [ ] Fix the known gaps above (monitor source line, dead workspaces.conf,
      broken nemo binding)
- [ ] i3-style `H/J/K/L` focus and window-movement keybindings
- [ ] Waybar and Wofi: currently running on package defaults, no custom
      config exists yet
- [ ] GRUB theming, ReGreet theming (`assets/grub`, `assets/regreet`)
- [ ] `laptop` host
- [ ] `modules/development` (CUDA, general dev tooling) and
      `modules/security` (network security, reverse engineering) as
      opt-in NixOS modules, distinct from the ad-hoc devShells above
- [ ] Recovery/installer ISO generation
