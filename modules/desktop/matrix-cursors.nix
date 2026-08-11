{ ... }:

# A green "Matrix" cursor theme, derived from capitaine-cursors by recoloring
# its source SVGs (white -> matrix green, blue accent -> matrix green) before
# the normal inkscape+xcursorgen build. Only the "dark" variant is built,
# since that's the one meant for a dark desktop.
{
  nixpkgs.overlays = [
    (final: prev: {
      matrix-cursors = prev.capitaine-cursors.overrideAttrs (old: {
        pname = "matrix-cursors";

        postPatch = (old.postPatch or "") + ''
          sed -i \
            -e 's/fill="#fff"/fill="#00ff41"/g' \
            -e 's/fill="#3daee9"/fill="#00ff41"/g' \
            -e 's/fill="#959595"/fill="#00cc35"/g' \
            src/svg/dark/*.svg
        '';

        buildPhase = ''
          runHook preBuild
          HOME="$NIX_BUILD_ROOT" ./build.sh --max-dpi xhd --type dark
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -dm0755 $out/share/icons
          cp -pr dist/dark $out/share/icons/matrix-cursors
          runHook postInstall
        '';
      });
    })
  ];
}
