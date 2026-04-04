# Tools Layout

This directory is meant to be usable on a local Linux machine without requiring an extra network fetch during the main bring-up flow.

## Structure

- `w5500-rocm-bootstrap.sh`
  - staged helper entrypoint
- `assets/firmware/navi14/`
  - bundled `navi14_*.bin` firmware overlay files used by the firmware-install step

## Design Intent

The toolchain is intentionally split into:

- diagnostics
- firmware backup / overlay
- ROCm 7 `gfx1012` userspace overlay
- build command emission

This is not a blind “one-click success” design.

It is a reproducible local toolkit that minimizes external dependencies during the actual bring-up process.
