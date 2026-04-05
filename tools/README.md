# Tools Layout

This directory is meant to be usable on a local Linux machine without requiring an extra network fetch during the main bring-up flow.

## Structure

- `rdna1-rocm-bootstrap.sh`
  - generic staged helper entrypoint for `RDNA1 / Navi10 / Navi12 / Navi14 / gfx101x`
- `w5500-rocm-bootstrap.sh`
  - compatibility wrapper for the exact `W5500 / Navi14 / gfx1012` lane
- `assets/firmware/navi10/`
  - bundled `navi10_*.bin` firmware overlay files
- `assets/firmware/navi12/`
  - bundled `navi12_*.bin` firmware overlay files
- `assets/firmware/navi14/`
  - bundled `navi14_*.bin` firmware overlay files

## Design Intent

The toolchain is intentionally split into:

- diagnostics
- firmware backup / overlay
- ROCm 7 `gfx1012` userspace overlay
- ROCm 7 `gfx101x` userspace overlay
- build command emission

This is not a blind “one-click success” design.

It is a reproducible local toolkit that minimizes external dependencies during the actual bring-up process.

## Practical Scope

The main tool entrypoint is intended to serve the broader `RDNA1 / Navi1x / gfx101x` family:

- use `rdna1-rocm-bootstrap.sh` when you want the generic staged workflow
- use `w5500-rocm-bootstrap.sh` only if you explicitly want the exact `W5500 / Navi14 / gfx1012` compatibility wrapper

The evidence level is still asymmetric:

- `Navi14 / gfx1012 / W5500` is the strongest real-world validation path in this repository
- `Navi10` and `Navi12` are supported here as generalized workflow targets, but not yet validated to the same depth
