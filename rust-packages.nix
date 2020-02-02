{ pkgs, lib }:
let
  mkDerivation = {rustc, stdenv}: {
    name,
    version,
    src,
    edition ? "2018",
  }: stdenv.mkDerivation {
    inherit name version src;

    phases = [ "unpackPhase" "buildPhase" "installPhase" ];

    nativeBuildInputs = [rustc];

    buildPhase = ''
      mkdir -p target/nix/lib

      rustc \
        --crate-type rlib \
        --edition ${edition} \
        --crate-name ${name} \
        --out-dir target/nix/lib \
        src/lib.rs

      for ex in examples/*.rs; do
        rustc \
          --crate-type bin \
          --edition ${edition} \
          --crate-name $(basename -s .rs $ex) \
          --out-dir target/nix/examples \
          --extern ${name}=./target/nix/lib/lib${name}.rlib \
          $ex
      done
    '';

    installPhase = ''
      mkdir -p $out
      for type in lib examples bin; do
        if [[ -d target/nix/$type ]]; then
          mv target/nix/$type $out/$type
        fi
      done
    '';
  };

  buildCratesIoCrate = {mkDerivation, fetchCratesIo}: {
    name,
    version,
    sha256,
  }: mkDerivation {
    inherit name version;
    src = fetchCratesIo { inherit name version sha256; };
  };
in
  lib.makeScope pkgs.newScope (self: {
    inherit (pkgs) rustc cargo;

    mkDerivation = self.callPackage mkDerivation {};

    fetchCratesIo = { name, version, sha256 ? null }:
      let
        url = "https://crates.io/api/v1/crates/${name}/${version}/download";
      in
        if sha256 == null
          then builtins.fetchTarball url
          else builtins.fetchTarball {
            inherit url sha256;
          };

    buildCratesIoCrate = self.callPackage buildCratesIoCrate {};
  })