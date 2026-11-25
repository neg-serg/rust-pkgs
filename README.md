# rust-pkgs

Rust crates that used to live in `neg-serg/nixos-config` under `packages/`, now a
flake of their own. Nothing here is published to crates.io: the crates are the
tools and `$PATH` helpers this host runs, and this repository is the single owner
of their sources, manifests, lockfiles and packaging.

## Layout

One directory per crate at the repository root:

```
<name>/Cargo.toml   manifest (a bump is this file plus Cargo.lock)
<name>/Cargo.lock   buildRustPackage reads it via cargoLock.lockFile
<name>/src/         the crate
<name>/package.nix  the derivation (reads its version from the manifest)
```

`local-bin-core` has no `package.nix`: it is the shared library the
`local-bin-*` binaries depend on as a path dependency.

## Crates

| crate | what it is |
| --- | --- |
| `blizzard` | Black-metal blizzard animated WebP generator |
| `dsh-patch` | Count-asserted exact-string patcher for dsh bundles and profiles |
| `game` | Unified game launcher — CPU pinning, Gamescope presets, session launching |
| `hwctl` | Hardware control CLI — CPU boost toggle, V-Cache masks, Nuvoton fan control |
| `hypr-focus` | Hyprland focus history tracker and window management CLI |
| `hypr-rearrange` | Move Hyprland windows to the workspaces the config routes them to |
| `local-bin-audio` | Audio helpers (audio-diag, jam, shabda, synth, midi-bridge, renoise-osc-config, sc-live, sc-record, flacspec, mp, nb, qe) as one multicall binary |
| `local-bin-core` | Shared library of the `local-bin-*` binaries (no package) |
| `local-bin-desktop` | Desktop/media helpers (pic-notify, screenrec, clip, screenshot-toast, pic-info, pic-ocr, pic-dirs-list, wl-restore, unlock, kitty-font-zoom, cursor-stretch, pngoptim, hypr-resize-proportional) |
| `local-bin-misc` | The last `local-bin` helpers (pb, any, v, sclang-pwj, renoise-pwj) |
| `local-bin-scripts` | Scripts helpers (pass-2col, punzip, tty-log, journal-clean, music-highlevel) |
| `local-bin-system` | System-level helpers (steam-cloud-fix, dsh-statusline, shade, main-menu, …) |
| `local-bin-tools` | Small `$PATH` helpers — album covers, unbound host entries, worktrees |
| `local-bin-zsh` | The last zsh helpers (iommu-info, music-rename, read_documents, pl, music-tui) |
| `local-bin-zsh-extra` | The remaining zsh helpers (gh-issues-export, mpd_del_album, sx, sys-relief, vol, win-vm) |
| `minibbs` | Tiny BBS-style message board (SQLite + HTTP) |
| `music-apply-tags` | Write ML mood/Discogs style tags into audio files (dry run by default) |
| `nixbuild-status` | One-line NixOS build status for status bars (waybar/i3bar/polybar) |
| `pretty-printer` | Pretty-printing helpers: coloured file info (`ppinfo`) and video info (`vid-info`) |
| `pwroute` | PipeWire audio router for RME HDSPe AIO Pro |
| `questyle-ctl` | Inspect and drive the Questyle QCC Dongle Pro2 (USB 0a12:4007) |
| `renoise-osc` | Send OSC messages to Renoise's built-in OSC server from the shell |
| `scratchpad-geometry` | Persist Hyprland scratchpad geometry across show/hide cycles |
| `swayimg-actions` | Rotate/move/copy/wallpaper/range actions for swayimg |
| `tidalctl` | TidalCycles session controller — engine start/stop, editor, recording |
| `vivaldi-prefs` | Re-assert Vivaldi preferences before the browser starts |
| `wineapps` | Declarative Wine app manager (list/install/uninstall/run) |
| `zalgo` | Zalgo text generator (stdin to stdout) |

## How the host consumes it

The host flake (`neg-serg/nixos-config`) adds

```nix
rust-pkgs = {
  url = "github:neg-serg/rust-pkgs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

and keeps its `pkgs.neg.<crate>` attribute names, so no module changed with the
extraction. Two details matter:

- The host calls `final.callPackage (inputs.rust-pkgs + "/<crate>/package.nix") { }`
  rather than consuming `packages.<system>.<crate>`. The packages take nixpkgs
  arguments (`hyprland`, `wineWow64Packages`, `sqlite`, `makeWrapper`), and only
  the host's own package set is the one its system closure already contains —
  building them against this flake's private nixpkgs would add second copies.
- `lib.slim` (full strip + fat LTO) is applied by the host through
  `inputs.rust-pkgs.lib.slim`, so the binaries keep the size they had when the
  sources were in-tree.

## Working here

```bash
nix build -L .#all        # every crate in one store path (the CI gate)
nix build .#"dsh-patch"   # one crate; dashed names need quoting
nix flake check -L        # evaluates the same output as `checks.build`
nix develop               # cargo, rustc, rustfmt, clippy, rust-analyzer

scripts/bump-version.sh <crate> [<version>]   # manifest + lockfile, one place
```

## Known gaps

- CI has no Nix cache, so `nix build .#all` compiles every crate on each push.
- The default `nixpkgs` pin is a snapshot of this host's channel. A consumer
  that does not pass `inputs.nixpkgs.follows` inherits it.
- CI runs `cargo fmt --check` and `cargo clippy` per crate in a loop rather than
  through a workspace: the crates are independent on purpose, and a shared
  workspace would merge 27 lockfiles into one.
