{ nixpkgs ? import <nixpkgs> {} }:
let
  rust-packages = nixpkgs.callPackage ./rust-packages.nix {};
in
  rust-packages.buildCratesIoCrate {
    name = "hello";
    version = "1.0.4";
    sha256 = "0kgyagy0xpzmb78wyfacnq33q85vndspaj610lhnm3qg1xk788jk";
  }