# nixos-config

This is the source code of my computing environment: a reproducible, modular
NixOS configuration built on flakes. It's not a dotfiles dump — the goal is
that this repository, plus its [`home`](https://github.com/nomadstar/dotfiles)
and [`nvim`](https://github.com/nomadstar/starter) submodules, is enough to
rebuild the machine it describes from a NixOS Live ISO.

Base: NixOS 25.11 (stable). Desktop: [Hyprland](https://hyprland.org/) on
Wayland, with an i3-inspired keybinding layout and a green-on-black "Matrix"
visual theme across the terminal, GTK apps, wallpaper, and boot.

## Architecture

```
nixos-config/
├── flake.nix / flake.lock   Entry point. Inputs: nixpkgs (25.11), home-manager,
│                             sops-nix, dotfiles + nvimConfig (this machine's
│                             personal configs, see home/ and nvim/ below), and
│                             three CLI/IDE-only flakes not in nixpkgs:
│                             claude-code, antigravity-nix (agy CLI + IDE),
│                             fluxcast (packaged from source in-repo, see
│                             modules/core/fluxcast.nix).
├── hosts/
│   ├── desktop/               Host-specific: hostname, timezone, locale, hardware
│   │   ├── default.nix        (disk UUIDs), and the home-manager wiring for this host.
│   │   ├── hardware-configuration.nix
│   │   └── home.nix
│   ├── laptop/                 Same shape as desktop/.
│   └── oh-my-posh-matrix.json  Shared bash prompt theme (see hosts/*/home.nix).
├── modules/
│   ├── core/                 Shared across all hosts.
│   │   ├── nix.nix           experimental-features (flakes, nix-command)
│   │   ├── boot.nix          GRUB (green/black Matrix colors) / Plymouth / UEFI / os-prober
│   │   ├── networking.nix    NetworkManager, sshd
│   │   ├── users.nix         user account
│   │   ├── packages.nix      base CLI + diagnostics tools, office/chat/remote-desktop
│   │   │                      apps (incl. nemo, gvfs, wpsoffice, discord/vesktop,
│   │   │                      wayvnc/tigervnc, obs-studio, fluxcast)
│   │   ├── fonts.nix         Nerd Fonts (JetBrainsMono + symbols-only)
│   │   ├── secrets.nix       sops-nix wiring
│   │   └── fluxcast.nix      Packages fluxcast + its missing PyPI dep (upnpclient)
│   │                          from source (not in nixpkgs); wraps in the
│   │                          gstreamer/ffmpeg/wf-recorder runtime deps its WFD
│   │                          path shells out to, and grants the
│   │                          `networkmanager` group read access to
│   │                          wpa_supplicant over D-Bus (NixOS's default
│   │                          policy there is root-only)
│   └── desktop/               Shared desktop-environment modules.
│       ├── hyprland.nix      compositor + Wayland utils
│       ├── waybar.nix
│       ├── regreet.nix       greetd + ReGreet (graphical login), pinned to a
│       │                      single output via a throwaway sway session (see
│       │                      below - cage can't do this)
│       ├── matrix-cursors.nix Green cursor theme, built by recoloring
│       │                      capitaine-cursors' SVGs before the normal build
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
│                              Alacritty, waybar, wofi, hyprpaper, nwg-displays
│                              configs + the generated Matrix wallpaper),
│                              applied via Home Manager.
├── nvim/                      git submodule -> a personal NvChad-based Neovim
│                              config, symlinked whole to ~/.config/nvim via
│                              the `nvimConfig` flake input.
└── assets/                    grub/, regreet/, wallpapers/ - originally
                                planned as theming asset directories; the
                                Matrix theme ended up living in modules/core/
                                boot.nix (GRUB colors, raw config) and the
                                home/ submodule (wallpaper, regreet reads GTK
                                dconf settings instead) rather than here, so
                                these are currently just placeholder READMEs.
```

Common configuration lives in `modules/`; anything host-specific (disk UUIDs,
hostname, monitor layout) lives under `hosts/<name>/`. Adding a second machine
means adding `hosts/<name>/` and a matching `nixosConfigurations.<name>` in
`flake.nix` - it reuses every shared module as-is, as `laptop` now does.

### Two-repo (three, counting `nvim/`) editing workflow

`home/` and `nvim/` are **separate git repositories**, checked out as
submodules for convenience but pulled reproducibly as their own flake inputs
(`dotfiles`, `nvimConfig`) pinned to a specific commit in `flake.lock`. This
means editing `home/hypr/hyprland.conf` (or waybar, alacritty, wofi, ...)
locally has **no effect** on a rebuild until you:

1. Commit and push inside `home/` (or `nvim/`) first.
2. From the repo root, run `nix flake lock --update-input dotfiles` (or
   `nvimConfig`) to bump the pin to the commit you just pushed.
3. Commit the resulting `flake.lock` change here, in `nixos-config`.
4. `sudo nixos-rebuild switch --flake .#<host>`.

Skipping step 1-2 and rebuilding will silently keep using whatever commit was
last pinned - this has bitten this exact workflow before.

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

**After every `switch`**, check that Home Manager's own activation actually
succeeded - `nixos-rebuild switch` can print "Done" for the system-level part
while `home-manager-<user>.service` fails separately (most commonly: a
pre-existing plain file sitting where Home Manager wants to place a symlink).
`systemctl status home-manager-nanixtus.service` should end in
`status=0/SUCCESS`; if not, back up (don't delete) the conflicting path it
names and re-run `systemctl restart home-manager-nanixtus.service` (a NixOS-
provided polkit rule lets the owning user do this without `sudo`). Some
autostarted user processes (`waybar`, `hyprpaper`) also don't pick up a new
generation on their own - kill and relaunch them after a switch if they still
look stale.

**If a switch leaves Hyprland (or anything else) crash-looping**,
`sudo nixos-rebuild switch --rollback` reactivates the previous generation
immediately, without a reboot. GRUB also lists every generation as a separate
boot entry if you can't get a shell at all. Hyprland writes a crash report to
`~/.cache/hyprland/hyprlandCrashReport*.txt`; running
`WLR_BACKENDS=headless Hyprland --config <path>` reproduces most config-time
crashes (bad plugin, malformed config value) without a real display, which is
how the `hyprexpo` plugin crash below was actually diagnosed.

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

Tooling for specific domains (AI/local LLM work, GUI editors, pentesting,
SDR) is **not** installed into the base system. Instead:

```sh
nix develop .#ai         # python, ollama, claude (Claude Code CLI), opencode,
                          # agy (Antigravity CLI), ROCm diagnostics (rocminfo, rocm-smi)
nix develop .#ai-laptop  # same, with CUDA instead of ROCm (laptop's NVIDIA GPU)
nix develop .#developer  # VS Code + Antigravity IDE - GUI editors, kept out of
                          # both the base system and the ai shell since they're
                          # heavy and only needed on demand
nix develop .#pentest    # nmap, wireshark, gobuster, hydra, sqlmap, netcat
nix develop .#sdr        # rtl-sdr, gqrx, gnuradio
```

These are throwaway shells - nothing they provide persists outside the shell,
and none of it touches `environment.systemPackages`.

### GPU compatibility

The `ai` devShell is built by a small `mkAiShell { gpu }` helper in
`flake.nix` with a fixed policy, applied per host: **NVIDIA -> CUDA, AMD ->
ROCm, anything else -> no GPU packages added.** CUDA is unfree, so it's only
allowed for the specific `pkgs` instance used to build the CUDA variant
(`pkgsUnfree`) - same instance `.#developer`'s VS Code (also unfree) uses. The
system-wide `pkgs` used for `nixosConfigurations` stays unfree-free except for
two deliberate, explicit exceptions: `discord` and `wpsoffice` (see
`modules/core/packages.nix`).

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

## Matrix theme

Green-on-black, applied consistently rather than in just one place:

- **Terminal**: `home/alacritty/alacritty.toml` - a full green-family
  `[colors]` palette.
- **Shell prompt**: `programs.oh-my-posh` in `hosts/*/home.nix`, themed from
  `hosts/oh-my-posh-matrix.json`.
- **Cursor**: `modules/desktop/matrix-cursors.nix` recolors
  `capitaine-cursors`' source SVGs (white -> `#00ff41`, blue accent -> same)
  before its normal inkscape+xcursorgen build, rather than hand-drawing a
  cursor theme from scratch.
- **GTK/libadwaita apps** (regreet, nemo, ...): `dconf.settings` in
  `hosts/*/home.nix` sets `color-scheme = "prefer-dark"` and
  `accent-color = "green"`. Needs `programs.dconf.enable` at the NixOS level
  (not on by default outside GNOME).
- **Wallpaper**: `home/wallpapers/matrix.png`, a generated green code-rain
  image, set via `hyprpaper` (`home/hypr/hyprpaper.conf`,
  `exec-once = hyprpaper` in `hyprland.conf`).
- **Window borders**: `col.active_border`/`col.inactive_border` in
  `hyprland.conf`'s `general {}` block.
- **Waybar**: `home/waybar/style.css` - dark translucent bar, green
  borders/text, glowing active workspace.
- **Wofi** (`SUPER+D` launcher): `home/wofi/{config,style.css}` - was running
  on unstyled package defaults before, now matches everything else.
- **Boot**: GRUB menu colors (`boot.loader.grub.extraConfig` in
  `modules/core/boot.nix`, since NixOS has no dedicated option for this) and
  Plymouth enabled with a plain dark built-in theme. A real animated
  code-rain boot splash would need a hand-built Plymouth theme (script +
  frame assets) - out of scope for now, tracked in the roadmap.

## Hyprland keybindings

i3-inspired, not a full port:

- `SUPER + arrows` - move focus between windows.
- `SUPER + SHIFT + arrows` - move the *active window* within the layout
  (the i3-style piece that was missing before - previously the only way to
  reposition a window was dragging it with the mouse).
- `SUPER + D` - app launcher (wofi, Matrix-themed).
- `SUPER + .` - HyprEmoji picker.
- `SUPER + R` - force a `hyprctl reload` (nwg-displays' monitor writes don't
  always trigger Hyprland's file watcher on their own).

**Known-broken, do not re-add without checking first**: `SUPER + TAB` was
briefly bound to a `hyprexpo` window-overview plugin
(`hyprlandPlugins.hyprexpo` from nixpkgs). That build of hyprexpo crashes
Hyprland 0.52.2 on plugin load - `std::out_of_range` inside Hyprlang's own
config parser, thrown before any of this repo's plugin config is even read -
confirmed with a headless Hyprland run, not a config mistake on this repo's
side. Fully reverted (`hyprland.conf`, and the per-host `nix-plugins.conf`
generation that supplied the plugin's Nix store path). No overview binding
exists right now; re-evaluate once nixpkgs' packaging catches up, or look at
pinning a matching hyprexpo/Hyprland pair by hand.

## Remote access & casting

- **VNC**: `wayvnc` (server, autostarted via `hyprland.conf`'s `exec-once`;
  no password configured - fine on a trusted LAN, set one in
  `~/.config/wayvnc/config` before exposing it further) and `tigervnc`
  (`vncviewer`, for connecting *out* to other VNC servers).
- **Wireless display casting** (Miracast/WFD, DLNA, Chromecast) via
  `fluxcast` - not in nixpkgs, packaged from source in
  `modules/core/fluxcast.nix` (including `upnpclient`, one of its PyPI
  dependencies, which also isn't packaged). Beta, single-maintainer upstream
  project - run `fluxcast --doctor` first on any given machine to see what's
  actually usable there before relying on it. Nothing about this repo
  auto-starts it or touches firewall config.

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
  model yet (window movement is direction-based via `movewindow`, not
  `H/J/K/L`).

## Status / roadmap

- [x] Flake conversion of the working configuration (`modules/core`,
      `modules/desktop`, `hosts/desktop`)
- [x] Home Manager managing Hyprland/Alacritty/nwg-displays/waybar/wofi from
      the `home/` submodule, and a personal Neovim config from `nvim/`
- [x] sops-nix encrypted secrets pipeline (scaffolded, one demo value)
- [x] `ai` / `developer` / `pentest` / `sdr` devShells
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
- [x] `claude` (Claude Code CLI), `opencode`, and `agy` (Antigravity CLI)
      added to the `ai`/`ai-laptop` devShells; VS Code + Antigravity IDE in
      a new `.#developer` devShell
- [x] Waybar: real Hyprland config (`home/waybar/`) replacing the nixpkgs
      Sway example, whose missing `FontAwesome` font was why icons weren't
      showing at all - now themed, plus window title and disk/network
      bandwidth modules
- [x] regreet pinned to a single physical output (`DP-1`) instead of
      spanning every monitor - cage can't do this, so regreet now runs under
      a throwaway sway session instead (`modules/desktop/regreet.nix`)
- [x] Matrix theme (terminal, cursor, GTK accent, wallpaper, waybar, wofi,
      GRUB) - see dedicated section above
- [x] i3-style `SUPER+SHIFT+arrows` window movement (focus movement via
      plain `SUPER+arrows` already existed)
- [x] Wofi: custom Matrix-themed config (`home/wofi/`), was on package
      defaults before
- [x] GRUB theming (green/black); Plymouth enabled with a plain dark theme
      (no custom animation yet, see gap below)
- [x] Remote desktop (`wayvnc` + `tigervnc`), office suite (`wpsoffice`),
      chat (`discord` + `vesktop`), screen recording (`obs-studio`),
      wireless display casting (`fluxcast`, packaged from source)
- [ ] Fix remaining known gaps above (dead workspaces.conf)
- [ ] Full i3-style `H/J/K/L` focus and window-movement keybindings (arrow
      keys work today)
- [ ] Hyprland window-overview binding - reverted after the packaged
      `hyprexpo` plugin turned out to crash this Hyprland version on load;
      see the keybindings section above before touching this again
- [ ] A real animated Plymouth boot theme (currently just a plain dark
      built-in one - a code-rain animation needs a hand-built theme, script
      + frames)
- [ ] `assets/` (grub/, regreet/, wallpapers/) is now stale placeholder
      READMEs - the theming that landed lives in `modules/core/boot.nix` and
      `home/` instead; either populate these directories for real or remove
      them
- [ ] `laptop`'s age key was added to `.sops.yaml`, but `secrets/secrets.yaml`
      itself still needs `sops updatekeys` run from a machine that can
      already decrypt it (the desktop) before the laptop can actually read
      `example_secret`
- [ ] NVIDIA proprietary driver / PRIME offload for the laptop's hybrid
      graphics (currently unconfigured at the NixOS level)
- [ ] System-level GPU acceleration (`hardware.graphics.enable`, ROCm OpenCL
      ICDs for the desktop's AMD GPU) - currently only devShell-level
- [ ] `modules/security` (network security, reverse engineering) as an
      opt-in NixOS module, distinct from the ad-hoc `pentest`/`sdr` devShells
      above
- [ ] Recovery/installer ISO generation
