##
# Rust slimming for this repository's crates, exposed as `lib.slim` (the host
# flake applies it as `inputs.rust-pkgs.lib.slim` to the crates it calls).
#
# Two measured levers, applied to every package the repo builds with
# rustPlatform.buildRustPackage:
#
#   strip — nixpkgs' strip hook removes debug sections only (`strip -S -p`, see
#   pkgs/build-support/setup-hooks/strip.sh), so the symbol table ships inside
#   every binary. `stripAllList = [ "bin" ]` turns that into a full strip:
#   measured 62.6 MiB off the 67 repository Rust binaries (per-file strip -s).
#
#   LTO — `CARGO_PROFILE_RELEASE_LTO = "fat"` with a single codegen unit.
#   Measured on graf (the wikilink-graph TUI, since removed): 5.19 MiB baseline
#   -> 4.00 MiB stripped -> 3.46 MiB
#   stripped+LTO (-36 % overall). panic=abort is deliberately not set: it
#   changes unwinding semantics and measured worse than plain fat LTO here.
#
# The caller owns the name lists; this file only knows how to slim a package.
pkg:
pkg.overrideAttrs (old: {
  stripAllList = [ "bin" ] ++ (old.stripAllList or [ ]);
  env = (old.env or { }) // {
    CARGO_PROFILE_RELEASE_LTO = "fat";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  };
})
