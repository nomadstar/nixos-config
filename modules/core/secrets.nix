{ config, ... }:

{
  # No new key to generate or store: decryption reuses the host's existing
  # SSH host key (already present, root-only, never leaves the machine).
  # The corresponding age *public* key lives in .sops.yaml at the repo root
  # and is not sensitive.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  # Demo secret proving the pipeline end-to-end. Real secrets (wifi, API
  # keys, VPN configs) get added the same way: `sops secrets/secrets.yaml`,
  # then `sops.secrets.<name> = { ... };` here, then reference
  # config.sops.secrets.<name>.path wherever the plaintext is needed.
  sops.secrets.example_secret = { };
}
