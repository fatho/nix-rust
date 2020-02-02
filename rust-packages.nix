{ pkgs, lib }:
let
  mkDerivation = {rustc, stdenv}: {
    name,
    version,
    src,
    doCheck ? true,
    edition ? "2018",
  }: stdenv.mkDerivation {
    inherit name version src doCheck;

    phases = [ "unpackPhase" "buildPhase" "checkPhase" "installPhase" ];

    nativeBuildInputs = [rustc];

    buildPhase = ''
      mkdir -p target/nix/lib

      echo "Building library"

      rustc \
        --crate-type rlib \
        --edition ${edition} \
        --crate-name ${name} \
        --out-dir target/nix/lib \
        src/lib.rs

      echo "Building tests"

      rustc \
        --edition ${edition} \
        --crate-name ${name} \
        --out-dir target/nix/test \
        --test \
        src/lib.rs

      echo "Building binaries"

      for bin in src/bin/*.rs; do
        local binname
        binname=$(basename -s .rs $bin)
        echo "> $binname"
        rustc \
          --crate-type bin \
          --edition ${edition} \
          --crate-name $binname \
          --out-dir target/nix/bin \
          --extern ${name}=./target/nix/lib/lib${name}.rlib \
          $bin
      done

      echo "Building examples"

      for ex in examples/*.rs; do
        local exname
        exname=$(basename -s .rs $ex)
        echo "> $exname"
        rustc \
          --crate-type bin \
          --edition ${edition} \
          --crate-name $exname \
          --out-dir target/nix/examples \
          --extern ${name}=./target/nix/lib/lib${name}.rlib \
          $ex
      done
    '';

    checkPhase = ''
      for test in target/nix/test/*; do
        echo "Running test $test"
        $test
      done
    '';

    installPhase = ''
      mkdir -p $out
      for type in lib examples bin test; do
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