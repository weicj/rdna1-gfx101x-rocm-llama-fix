# Hardware Scope

This project is conceptually aimed at the `RDNA1 / Navi14 / gfx101x` discrete GPU family.

That does **not** mean every card below has been tested here.

It means the methods, failure modes, and repair logic are most likely to be relevant to these cards, because they belong to the same architectural generation and driver family.

## Real Tested Environment

The concrete field validation behind this repository was performed primarily on:

- host platform: `Mac Pro 5,1`
- boot stack: `OpenCore`
- OS: `Ubuntu`
- GPU: `Radeon Pro W5500`
- ASIC: `Navi14`
- arch: `gfx1012`

This is the environment that produced the actual performance numbers and deployment conclusions recorded in this repository.

## Likely Relevant GPU Family

### `gfx1010 / Navi10`

Major known RDNA1 dGPU variants in this class include:

- `Radeon RX 5600 XT`
- `Radeon RX 5700`
- `Radeon RX 5700 XT`
- `Radeon Pro W5700`
- `Radeon Pro W5700X`
- `Radeon Pro V520`
- some mobile `5600M / 5700M` derivatives

Status in this repository:

- architecture-family relevant
- not directly validated here

### `gfx1011 / Navi12`

Major known variants include:

- `Radeon Pro 5600M`

Status in this repository:

- architecture-family relevant
- not directly validated here

### `gfx1012 / Navi14`

Major known variants include:

- `Radeon RX 5300`
- `Radeon RX 5500`
- `Radeon RX 5500 XT`
- `Radeon Pro W5500`
- `Radeon Pro W5500X`
- `Radeon Pro 5300M`
- `Radeon Pro 5500M`
- `Radeon RX 5300M`
- `Radeon RX 5500M`

Status in this repository:

- closest family match
- directly validated here on `Radeon Pro W5500`

## Important Caveat

This repository should be read as:

- a strong field reference
- a practical engineering notebook
- a real deployment record

It should **not** be read as:

- a universal support matrix
- a guarantee for every board vendor
- a promise that every PCIe topology, bridge chain, firmware state, or kernel lane will behave the same way

Use it as a high-value starting point. Use it at your own risk.
