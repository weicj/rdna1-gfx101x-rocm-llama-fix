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
- build command emission

This is not a blind “one-click success” design.

It is a reproducible local toolkit that minimizes external dependencies during the actual bring-up process.
