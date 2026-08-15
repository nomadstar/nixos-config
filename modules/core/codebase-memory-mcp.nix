{ config, lib, pkgs, codebaseMemoryMcp, ... }:

{
  # Persistent, system-wide install - not a devShell throwaway. Built from
  # source by Nix (see the codebase-memory-mcp flake input in flake.nix,
  # which pulls in upstream's own flake.nix: pure C11 + vendored
  # tree-sitter grammars, no prebuilt-binary trust needed). Nix owns this
  # binary's version; `codebase-memory-mcp update`/`install`/`uninstall`
  # are never run anywhere in this repo - those are upstream's own
  # commands, and `install`/`update` in particular auto-detect and rewrite
  # up to 43 different coding agents' config files (~/.claude.json,
  # .cursor/mcp.json, .gemini/settings.json, ...). `nix flake update` is
  # the only thing that bumps this tool's version here.
  environment.systemPackages = [ codebaseMemoryMcp ];

  # Index/database storage explicitly outside /nix/store (immutable, and
  # wiped by garbage collection) - matches upstream's own default
  # (~/.cache/codebase-memory-mcp) exactly, just pinned here so it's
  # documented instead of left as an implicit upstream default that could
  # change.
  environment.sessionVariables.CBM_CACHE_DIR = "$HOME/.cache/codebase-memory-mcp";

  # One-shot registration of this repo with codebase-memory-mcp's own
  # graph store, run once per login - NOT an agent-config write, just
  # populating CBM's local SQLite index (same effect as running
  # `codebase-memory-mcp cli index_repository` by hand once). With
  # upstream's default `auto_watch=true`, any later CBM-connected agent
  # session (see the repo-root .mcp.json) keeps it fresh from there;
  # this only covers the initial registration, so nixos-config is indexed
  # even if no agent session ever connects.
  systemd.user.services.cbm-index-nixos-config = {
    description = "Index nixos-config into codebase-memory-mcp";
    wantedBy = [ "default.target" ];
    unitConfig = {
      # Same fixed clone location assumed elsewhere in this repo (see
      # modules/desktop/devshell-picker.nix) - skip quietly if it isn't
      # there yet (e.g. a fresh install before the first clone).
      ConditionPathExists = "/home/nanixtus/nixos-config";
    };
    environment.CBM_CACHE_DIR = "%h/.cache/codebase-memory-mcp";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${codebaseMemoryMcp}/bin/codebase-memory-mcp cli index_repository --repo-path /home/nanixtus/nixos-config";
    };
  };
}
