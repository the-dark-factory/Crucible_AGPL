# CRUCIBLE's toolchain recipe

`alire.toml` here pins the exact FSF toolchain CRUCIBLE is built and proved with:

| tool | pin |
|---|---|
| GNAT (`gnat_native`) | 15.1.2 |
| gprbuild | 26.0.1 |
| gnatprove | 15.1.0 |

We do not ship these tools. Alire fetches them from its index onto your machine
(ruling 2026-09-16: "use alire for fsf tools").

## Use

    cd toolchain
    alr update                      # fetches the pinned tools
    alr exec -- gnatprove --version # confirm the pin
    alr exec -- which gnatprove     # this absolute path goes in ../config/prover-service.conf

The prover service needs the **absolute path** that `alr exec -- which gnatprove` prints; put it in
`config/prover-service.conf` (template: `config/prover-service.conf.example`).

## Why a separate crate

CRUCIBLE's own `alire.toml` deliberately has no `[[depends-on]]` (`mui:crucible-depends-on-no-crate`).
Pinning the toolchain here keeps that true, and gives a stranger one command that installs the same
toolchain on every machine, instead of whatever `/usr/bin` happens to hold (the 2026-09-16
Pro-18 / GCC-13 mixing failure on one build host).

Changing a pin is a release event: re-prove CRUCIBLE with the new versions first.
