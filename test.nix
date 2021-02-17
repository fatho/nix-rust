{ nixpkgs ? import <nixpkgs> {} }:
let
  rust-packages = nixpkgs.callPackage ./rust-packages.nix {};
  unkHash = "0000000000000000000000000000000000000000000000000000";
in
  rec {
    libc = rust-packages.buildCratesIoCrate {
      name = "libc";
      version = "0.2.66";
      sha256 = "0wz5fdpjpj8qp7wx7gq9rqckd2bdv7hcm5631hq03amxy5ikhi3l";
      features = ["std"];
    };

    rand_core = rust-packages.buildCratesIoCrate {
      name = "rand_core";
      version = "0.5.1";
      sha256 = "19qfnh77bzz0x2gfsk91h0gygy0z1s5l3yyc2j91gmprq60d6s3r";
      features = [];
    };

    rand_hc = rust-packages.buildCratesIoCrate {
      name = "rand_hc";
      version = "0.2.0";
      edition = "2018";
      sha256 = "0592q9kqcna9aiyzy6vp3fadxkkbpfkmi2cnkv48zhybr0v2yf01";
      features = [];
      rustDepends = [rand_core];
    };

    # memchr = rust-packages.buildCratesIoCrate {
    #   name = "memchr";
    #   version = "2.3.0";
    #   sha256 = "0sf6y998273290a6zxx5c28ps196vzz3q9yd0v5jxflpm3bp52f1";
    #   features = ["libc"];
    #   rustDepends = [libc];
    #   doCheck = false;
    # };
  }