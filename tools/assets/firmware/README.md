# Bundled Firmware Assets

This directory stores the bundled firmware overlay files used by the project for the main `RDNA1 / Navi1x / gfx101x` ASIC groups.

## Why they are bundled here

The goal of this repository is to keep the main bring-up flow locally reproducible.

That means the firmware files required by the documented `RDNA1 / Navi1x / gfx101x` bring-up paths should live inside the repository, instead of forcing a reader to rediscover or redownload them during the critical repair path.

## Layout

- `navi10/`
  - bundled `navi10_*.bin` files
- `navi12/`
  - bundled `navi12_*.bin` files
- `navi14/`
  - bundled `navi14_*.bin` files

## Important note

These files are used as practical firmware overlays for the `RDNA1 / Navi10 / Navi12 / Navi14 / gfx101x` bring-up paths documented in this repository.

The strongest real validation in this repository still comes from `Navi14 / gfx1012 / W5500`. The `navi10` and `navi12` bundled overlays are included so users on the same architecture generation can reproduce the same staged workflow locally without needing to fetch firmware during the critical repair path.

They are not a blanket claim that every board in these families should overwrite firmware blindly.
