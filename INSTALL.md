# Installing CRUCIBLE

**Honest status (2026-09-19): there is no one-step install yet.** There are no published binaries for any
platform, and "the stand" (the installer) doesn't exist yet. What follows builds a working CRUCIBLE from
source, on macOS (Apple silicon) or Linux (x86_64). The stand will automate these same steps, and a Claude
Code skill will run the stand for you.

## What a working CRUCIBLE is

Turning prose into proved Ada takes four local processes (door, prover service, vacuity service, model), three config files and one toolchain. Nothing
listens on the network: every service binds `127.0.0.1`.

| piece | what it does | who supplies it |
|---|---|---|
| `bin/crucible-agpl` | the one executable: an MCP server on stdio (the "door") | us — built below |
| `bin/prover_service_main` | the prover rail: takes one unit at a time, runs gnatprove on it, reports the facts | us — built below |
| `bin/vacuity_service_main` | the vacuity rail: runs the battery `check-cores-mcp` over a spec and relays whether its contracts say anything | us — built below; the battery is our separate `check-cores-mcp` repo |
| FSF toolchain | GNAT, gprbuild, gnatprove | you, fetched by our pinned Alire recipe (`toolchain/`). We ship no toolchain binaries. |
| model endpoint | the model rail (ollama, or any OpenAI-shaped server) | you — any model; ours is Rosie (`qwen3.8-27b-ada:v0.3`) |
| `config/rail.conf` | where each rail is: one JSON line per rail | us — a working default is in the tree |
| `config/prover-service.conf` | the prover service's port, staging folder and gnatprove path | you, from `config/prover-service.conf.example` |
| `config/vacuity-service.conf` | the vacuity service's port, staging folder and battery path | you, from `config/vacuity-service.conf.example` |

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
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/vacuity_service_main.adb -o bin/vacuity_service_main  # -> bin/vacuity_service_main
```

## 4. Configure

```sh
cp config/prover-service.conf.example config/prover-service.conf
cp config/vacuity-service.conf.example config/vacuity-service.conf
```

Edit both: set `staging_root` to an absolute folder (for example `$HOME/.crucible/prover-staging`, spelled
out in full) and, in the prover file, `gnatprove` to the absolute path from step 2; in the vacuity file, `battery`
to your `check-cores-mcp` binary. Both files are per machine and git ignores them.

`config/rail.conf` works as shipped if ollama is on `127.0.0.1:11434` and gnatprove is behind the prover
service on `127.0.0.1:8471` and the vacuity service is on `127.0.0.1:8472`. To use a different model, edit the `"rail":"model"` line and restart. The
format is in `config/README.md`.

## 5. Start the two services

```sh
bin/prover_service_main
# prover-service: listening on 127.0.0.1:8471 (FSF 15.0)
bin/vacuity_service_main
# vacuity-service: listening on 127.0.0.1:8472 (check-cores-mcp)
```

Leave both running. Each serves one request at a time.

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

Then the whole pipeline, with all three rails running. Give `forge` a four-line sheet:

```text
delivers: the index of the first occurrence of a value in a list
type List: an array of up to 100 integers
function Find (L : List; V : Integer) return Natural
post: the result is zero when V is absent, otherwise L at the result equals V
```

It should answer `"final":"done"` and write `out/find_pkg.ads`, `out/find_pkg.adb` and `out/receipt.json`, with
`gates_passed` listing intake, decompose, emit_contract, prove_spec, vacuity, fill_body, prove_body, seam,
provenance and admission. Seen on macOS arm64 on 2026-09-19 with Rosie v0.3, in under two minutes. The
contract proves exactly what the `post:` line says, so if you want "first" guaranteed, say it in `post:`.

## What does not work yet

- **The palais tools** (`palais.shelf` and the rest) and `tower_import` are listed, but they answer
  "unknown tool": no rail behind them yet.
- **The vacuity battery** `check-cores-mcp` is a separate repo you build yourself (Go) until the stand ships it.
- **The receipt** does not yet record the prover version, the model name or the rail endpoints (it says so
  itself, under `not_recorded`).
- **No stand, no published binaries, no `factory.doctor` tool.** The plan is
  `PLAN_release_working_factory_install_2026-09-19` (Dark Factory records).
