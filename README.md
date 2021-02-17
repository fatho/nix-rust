# nix-rust

This is a small experiment with a different way of doing rust builds with nix,
compared to the already existing infrastructure in nixpkgs.

Instead of building the whole set of dependencies of an application as a single derivation,
each rust package becomes a separate derivation that can depend on other rust package derivations.

In order to see it in action building a few select libraries, run:

```
nix-build --no-out-link test.nix
```

The downside of this approach is that `cargo` cannot be used,
and therefore some of its features need to be reimplemented in bash.