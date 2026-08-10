{ lib, rustPlatform, fetchFromGitHub, pkg-config, wrapGAppsHook4, gtk4, wl-clipboard }:

rustPlatform.buildRustPackage rec {
  pname = "hypremoji";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "Musagy";
    repo = "hypremoji";
    tag = "v${version}";
    hash = "sha256-GFqjPeufG8Vh2nq1155Os7+MfvuGJXsfApImPIyeupM=";
  };

  # Upstream doesn't commit a Cargo.lock (PKGBUILD just runs `cargo build`
  # against crates.io on install). Vendored here via `cargo generate-lockfile`
  # against Cargo.toml at v1.3.0.
  cargoLock.lockFileContents = builtins.readFile ./Cargo.lock;
  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [ pkg-config wrapGAppsHook4 ];
  buildInputs = [ gtk4 ];

  # get_base_path() in src/utils/path_utils.rs only special-cases exe paths
  # under /usr; anywhere else (including the Nix store) it walks up from the
  # binary looking for a sibling "assets" dir, so it resolves fine as long as
  # assets/ sits directly under $out (bin/hypremoji -> bin -> $out/assets).
  postInstall = ''
    cp -r assets $out/assets
    cp -r config $out/config
  '';

  postFixup = ''
    wrapProgram $out/bin/hypremoji --prefix PATH : ${lib.makeBinPath [ wl-clipboard ]}
  '';

  meta = {
    description = "Lightweight and fast emoji picker for the Hyprland window manager, built with GTK4 and Rust";
    homepage = "https://github.com/Musagy/hypremoji";
    license = lib.licenses.isc;
    platforms = lib.platforms.linux;
    mainProgram = "hypremoji";
  };
}
