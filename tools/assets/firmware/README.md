# Bundled Firmware Assets

This directory stores the `Navi14` firmware overlay files used by the project.

## Why they are bundled here

The goal of this repository is to keep the main bring-up flow locally reproducible.

That means the firmware files required by the documented `W5500` bring-up should live inside the repository, instead of forcing a reader to rediscover or redownload them during the critical repair path.

## Layout

- `navi14/`
  - bundled `navi14_*.bin` files used by `tools/w5500-rocm-bootstrap.sh install-firmware-overlay`

## Important note

These files are used as a practical firmware overlay for the specific `W5500 / Navi14 / gfx1012` bring-up path described in this repository.

They are not a blanket claim that every `Navi14` host should overwrite firmware blindly.
