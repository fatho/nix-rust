{ pkgs, lib }:
let
  mkDerivation = {rustc, stdenv}: {
    name,
    version,
    src,
    doCheck ? true,
    features ? [],
    rustDepends ? [],
    rustBuildDepends ? [],
    rustDevDepends ? [],
    edition ? "2015",
  }: stdenv.mkDerivation {
    inherit name version src doCheck;

    phases = [ "unpackPhase" "buildPhase" "checkPhase" "installPhase" ];

    buildInputs = rustDevDepends ++ rustDepends;
    # TODO: how to doCheck when cross compiling
    nativeBuildInputs = [rustc] ++ rustBuildDepends;

    RUSTC=rustc + "/bin/rustc";

    crate_features = features;
    crate_extern = builtins.map (dep: "${dep.name}=${dep}/lib/lib${dep.name}.rlib") rustDepends;
    buildPhase = ''
      # rustc flags applicable to all builds
      rustc_flags=()
      # rustc flags only applicable to builds that are supposed to be run on the native architecture

      if [[ -f build.rs ]]; then
        echo "Building build script"
        rustc \
          --crate-type bin \
          --edition ${edition} \
          --crate-name build_script_build \
          --out-dir target/nix/build \
          build.rs

        echo "Running build script"
        
        while read -r line; do
          
          case "$line" in
            cargo:rustc-cfg=*)
              cfg=''${line#*=}
              rustc_flags+=("--cfg=$cfg")
              ;;
            *)
              echo "Unknown build script flag: $line"
              exit 1
          esac
        done < <(target/nix/build/build_script_build)
      fi

      for feature in "''${crate_features[@]}"; do
        rustc_flags+=("--cfg=feature=\"$feature\"")
      done

      for dep in "''${buildInputs[@]}"; do
        if [[ ! -z $dep ]] && [[ -d $dep/lib ]]; then
          rustc_flags+=("-L" "$dep/lib")
        fi
      done

      for dep in "''${crate_extern[@]}"; do
        if [[ ! -z $dep ]]; then
          rustc_flags+=("--extern" "$dep")
        fi
      done

      echo "''${rustc_flags[@]}"

      echo "Building library"

      rustc \
        --crate-type rlib \
        --edition ${edition} \
        --crate-name ${name} \
        --out-dir target/nix/lib \
        "''${rustc_flags[@]}" \
        src/lib.rs

      echo "Building tests"

      if (( doCheck )); then

        rustc \
          --edition ${edition} \
          --crate-name ${name} \
          --out-dir target/nix/test \
          --test \
          "''${rustc_flags[@]}" \
          src/lib.rs

        # TODO: rustdoc tests

      fi

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
          "''${rustc_flags[@]}" \
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
          "''${rustc_flags[@]}" \
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

  buildCratesIoCrate = {mkDerivation, fetchCratesIo, lib}: args@{
    name,
    version,
    sha256,
    ...
  }: 
    let
      fwdArgs = lib.filterAttrs (name: value: name != "sha256") args;
    in
      mkDerivation (fwdArgs // {
        src = fetchCratesIo { inherit name version sha256; };
      });
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