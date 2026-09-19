# Installing CRUCIBLE

**Honest status (2026-09-19): there is no one-step install yet.** There are no published binaries for any
platform, and "the stand" (the installer) doesn't exist yet. What follows builds a working CRUCIBLE from
source, on macOS (Apple silicon) or Linux (x86_64). The stand will automate these same steps, and a Claude
Code skill will run the stand for you.

## What a working CRUCIBLE is

Turning prose into proved Ada takes three local processes, two config files and one toolchain. Nothing
listens on the network: both services bind `127.0.0.1`.

| piece | what it does | who supplies it |
|---|---|---|
| `bin/crucible-agpl` | the one executable: an MCP server on stdio (the "door") | us — built below |
| `bin/prover_service_main` | the prover rail: takes one unit at a time, runs gnatprove on it, reports the facts | us — built below |
| FSF toolchain | GNAT, gprbuild, gnatprove | you, fetched by our pinned Alire recipe (`toolchain/`). We ship no toolchain binaries. |
| model endpoint | the model rail (ollama, or any OpenAI-shaped server) | you — any model; ours is Rosie (`qwen3.8-27b-ada:v0.3`) |
| `config/rail.conf` | where each rail is: one JSON line per rail | us — a working default is in the tree |
| `config/prover-service.conf` | the prover service's port, staging folder and gnatprove path | you, from `config/prover-service.conf.example` |

You also need an MCP host (Claude Code, or any MCP client) to talk to the door.

## 1. Prerequisites

- **Alire** (`alr`), 2.x: <https://alire.ada.dev>
- **babashka** (`bb`): only needed to build, because the build stamp is written by `scripts/stamp-build.bb`
  (a forged Ada replacement is on the way).
- **git**
- Optional: **ollama**, for the model rail.

## 2. Fetch the pinned toolchain

```sh
cd toolchain
alr update
alr exec -- gnatprove --version
alr exec -- which gnatprove gnat gprbuild   # keep these absolute paths
cd ..
```

The pins are exact: GNAT 15.1.2, gprbuild 26.0.1, gnatprove 15.1.0. These builds report themselves as
"GNAT 15.0.1 (prerelease)", "GPRBUILD 26.0.0" and "FSF 15.0". That's expected; the check is the path.

## 3. Build

Run every build command through the pinned toolchain, so that no other `gprbuild`/`gnat` on your `PATH`
gets mixed in (a real failure, 2026-09-16):

```sh
TC="$(cd toolchain && alr exec -- sh -c 'echo $PATH')"
bb scripts/stamp-build.bb                                          # records the commit you are building
PATH="$TC" gprbuild -P crucible.gpr -p -XCRUCIBLE_EDITION=agpl     # -> bin/crucible-agpl
mkdir -p obj/harness
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/prover_service_main.adb -o bin/prover_service_main    # -> bin/prover_service_main
```

## 4. Configure

```sh
cp config/prover-service.conf.example config/prover-service.conf
```

Edit it: set `staging_root` to an absolute folder (for example `$HOME/.crucible/prover-staging`, spelled
out in full) and `gnatprove` to the absolute path from step 2. This file is per machine and git ignores it.

`config/rail.conf` works as shipped if ollama is on `127.0.0.1:11434` and gnatprove is behind the prover
service on `127.0.0.1:8471`. To use a different model, edit the `"rail":"model"` line and restart. The
format is in `config/README.md`.

## 5. Start the prover service

```sh
bin/prover_service_main
# prover-service: listening on 127.0.0.1:8471 (FSF 15.0)
```

Leave it running. It serves one request at a time.

## 6. Connect your MCP host

⚠ CRUCIBLE finds `config/rail.conf` **relative to the folder it is started in**. It must be started from
this directory. With Claude Code:

```sh
claude mcp add crucible -- sh -c 'cd /absolute/path/to/crucible && exec bin/crucible-agpl'
```

(The stand's launcher will do this for you.)

## 7. Check it works

Ask the door to prove a unit that is correct, then one that isn't:

- `prove_unit` with unit `add_one`, a spec whose `Inc` has `Post => Inc'Result = X + 1`, and a body
  `(X + 1)` should answer **`proved`**.
- The same spec with a body of `(X + 2)` should answer **`not_proved`**.

Both results were seen on macOS arm64 on 2026-09-19. If you get `not_sent`, the door didn't find a valid
`prover` line in `config/rail.conf`: check which folder it was started from (step 6).

## What does not work yet

- **The palais tools** (`palais.shelf` and the rest) and `tower_import` are listed, but they answer
  "unknown tool": no rail behind them yet.
- **The vacuity rail** has no service in this repo and no line in `rail.conf`.
- **The model rail** is configured but hasn't been checked end to end through the door.
- **No stand, no published binaries, no `factory.doctor` tool.** The plan is
  `PLAN_release_working_factory_install_2026-09-19` (Dark Factory records).
