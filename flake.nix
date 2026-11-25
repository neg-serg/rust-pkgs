{
  description = "neg-serg's Rust tools, crates and $PATH helpers";

  # Floating on purpose: the host flake (neg-serg/nixos-config) consumes these
  # crates through `inputs.rust-pkgs` with `inputs.nixpkgs.follows = "nixpkgs"`,
  # so every binary is built against the same nixpkgs as the system that runs
  # it. A standalone consumer gets whatever `flake.lock` pins here.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # One directory per crate at the repository root, each carrying
      # `Cargo.toml`, `Cargo.lock`, `src/` and `package.nix`, and each with its
      # own lockfile: the crates share no workspace and build independently.
      # `local-bin-core` is deliberately absent — it is the library the
      # `local-bin-*` binaries pull in as a path dependency, so it has no
      # package.nix and no output of its own.
      crates = [
        "blizzard"
        "dsh-patch"
        "game"
        "hwctl"
        "hypr-focus"
        "hypr-rearrange"
        "local-bin-audio"
        "local-bin-desktop"
        "local-bin-misc"
        "local-bin-scripts"
        "local-bin-system"
        "local-bin-tools"
        "local-bin-zsh"
        "local-bin-zsh-extra"
        "minibbs"
        "music-apply-tags"
        "nixbuild-status"
        "pretty-printer"
        "pwroute"
        "questyle-ctl"
        "renoise-osc"
        "scratchpad-geometry"
        "swayimg-actions"
        "tidalctl"
        "vivaldi-prefs"
        "wineapps"
        "zalgo"
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
    in
    {
      # `rustPkgs` is the namespace a consumer reads; `lib.mkMeta` is the shared
      # `meta` builder every package.nix expects as a `lib` attribute — the host
      # flake adds the same attribute to its own pkgs.lib
      # (packages/overlays/functions.nix), so the package files stay identical
      # on both sides.
      overlays.default = final: prev: {
        lib = prev.lib.extend (_: _: { mkMeta = prev.callPackage ./lib/mkMeta.nix { }; });
        rustPkgs = builtins.listToAttrs (
          map (name: {
            inherit name;
            value = final.callPackage (./. + "/${name}/package.nix") { };
          }) crates
        );
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.rustPkgs
        // {
          # The whole repository in one store path: `nix build -L .#all` is the
          # build gate here and what CI runs (dashed names need quoting:
          # `nix build .#"dsh-patch"`).
          all = pkgs.linkFarm "rust-pkgs" (
            map (name: {
              inherit name;
              path = pkgs.rustPkgs.${name};
            }) crates
          );
        }
      );

      # Full strip + fat LTO for these crates (the measured levers live in
      # lib/rust-slim.nix). The host applies it as `inputs.rust-pkgs.lib.slim`,
      # so the crates stay slimmed after leaving its tree.
      lib.slim = import ./lib/rust-slim.nix;

      checks = forAllSystems (system: { build = self.packages.${system}.all; });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            cargo
            rustc
            rustfmt
            clippy
            rust-analyzer
            pkg-config
            sqlite # minibbs is the only crate with a native build input
          ];
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
