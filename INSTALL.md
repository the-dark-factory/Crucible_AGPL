# Installing CRUCIBLE

## The short path (a published release)

v0.4.0 ships prebuilt, signed tarballs. You do not need a toolchain to run the door — only to
build it yourself (see "Build from source" below).

1. Download the tarball for your platform and the checksum file from the release page:
   - `crucible-v0.4.0-macos-arm64.tar.gz` (macOS, Apple silicon)
   - `crucible-v0.4.0-linux-x86_64.tar.gz` (Linux, x86_64)
   - `RELEASE_TARBALLS.sha256`

2. Check what you downloaded, then unpack:
   ```sh
   sha256sum -c RELEASE_TARBALLS.sha256
   tar xzf crucible-v0.4.0-<platform>.tar.gz
   cd crucible-v0.4.0
   ```

3. Verify the signed file set INSIDE the tarball (this is the df-release signature):
   ```sh
   sha256sum -c SHA256SUMS
   ssh-keygen -Y verify -f SHA256SUMS.allowed_signers -I tower@thedarkfactory.co.uk \
       -n df-release -s SHA256SUMS.sig < SHA256SUMS
   ```
   A good run prints `Good "df-release" signature for tower@thedarkfactory.co.uk`.

The tarball unpacks to `crucible-v0.4.0/` with this layout — everything is relative to that
directory:
```
crucible-v0.4.0/
  crucible-launch.sh   the one-command launcher (starts the rails, serves the door, cleans up)
  bin/     crucible-agpl, prover_service_main, vacuity_service_main, reef_relay_main,
           vacuity-battery (+ its 38 kit-name links), vacuity_verdict_main, allowed_signers
  config/  rail.conf, reef-relay.conf, tower.conf
  tower/   base.bundle, sharer.bundle
  SHA256SUMS, SHA256SUMS.sig, SHA256SUMS.allowed_signers
```

> **Since v0.3.0:** the Go battery `check-cores-mcp` (shipped up to v0.2.1) is gone. `bin/` instead holds `vacuity-battery` (the battery, Ada, built from
> `battery/` in this tree), the 38 kit names in `battery/LINKS` as symbolic links to it, and
> `vacuity_verdict_main` (the grade edge) beside them. The battery's text scanning is Ada **edges**
> (built and probe-checked, not proved); its judgements are proven cores. Do not call the battery proved.

> The door finds `config/rail.conf` and `tower/base.bundle` **relative to the directory it is
> started in**. Start it from the `crucible-v0.4.0/` directory (not from inside `bin/`). The
> launcher does this for you.

### What each piece is

| piece | what it does | who supplies it |
|---|---|---|
| `crucible-launch.sh` | the launcher: cds into the install dir, starts the three rails (prover, vacuity, reef relay), serves the door, and stops the rails on exit. Writes `config/prover-service.conf` and `config/vacuity-service.conf` on first start (this machine's gnatprove path, the shipped battery) if they are absent — inside the install dir only | us — in the tarball |
| `bin/crucible-agpl` | the one executable: an MCP server on stdio (the "door") | us — in the tarball |
| `bin/prover_service_main` | the prover rail: runs gnatprove on one unit at a time | us — in the tarball |
| `bin/vacuity_service_main` | the vacuity rail: runs the `check-cores-mcp` battery | us — in the tarball |
| `bin/check-cores-mcp` | the vacuity battery the vacuity rail runs | us — in the tarball |
| `bin/reef_relay_main` | the reef rail: carries one line to thereef.ink over TLS and brings one back, so the door can ask the tower what catalog is current and fetch it | us — in the tarball |
| `bin/allowed_signers` | the trust file beside the binary. Names the tower's signing keys (df-tower, df-admission, df-index). The df-index key is what verifies the tower's signed catalog index on fetch. | us — in the tarball |
| `config/rail.conf` | where each rail is: one JSON line per rail, including the `reef` line pointing at the local relay | us — a working default is in the tarball |
| `config/reef-relay.conf` | the relay's port, the tower URL (`https://thereef.ink/rail`), and its staging dir | us — a working default is in the tarball |
| gnatprove | behind the prover service, so it can prove locally | you — install a GNAT/SPARK toolchain; the launcher finds it. The release runs without it (reef + vacuity still work); the prover rail needs it |
| model endpoint | the model rail (ollama, or any OpenAI-shaped server) on `127.0.0.1` | you — any model; we ship none |

Nothing listens off-host: every service binds `127.0.0.1`. The reef relay is the one component
that leaves the box, and only to `https://thereef.ink/rail`, and only to ask for and fetch the
public catalog — it sends no unit of yours.

## Start it

The shipped `config/rail.conf` points the model rail at `qwen3-coder:30b` on ollama at
`127.0.0.1:11434`. Pull it (`ollama pull qwen3-coder:30b`), or point the model line at any other model
you run on `127.0.0.1`. The door asks ollama for a 32,768-token context by default (the model line's `"num_ctx":"32768"`;
change it to any value from 2048 to 262144, or leave it out for 32768), so you do not need to set
`OLLAMA_CONTEXT_LENGTH`. A prompt too long for that context is refused by name (`prompt_exceeds_context`), never cut. Then connect your MCP host to the launcher — it starts the prover rail, the
vacuity rail, and the reef relay (which reaches the tower), serves the door on stdio, and stops the
rails when the door exits:

```sh
claude mcp add crucible -- /absolute/path/to/crucible-v0.4.0/crucible-launch.sh
```

That is the whole start. You do not start the rails by hand and you do not need a `cd` wrapper —
the launcher cds into the install directory for you. A quick self-check:

```sh
/absolute/path/to/crucible-v0.4.0/crucible-launch.sh --check
#   prover  8471 up
#   vacuity 8472 up
#   reef    8473 up
```

(If you have not installed a GNAT/SPARK toolchain, the prover rail reports itself off and the
launcher says so; the reef relay and vacuity rail still come up, and the tower connect still works.)

See `CONNECTING.md` for Claude Desktop and for the by-hand equivalent if you prefer not to use the
launcher.

## What connecting to the tower does

At the start of every `forge`, the door asks thereef.ink (through the local relay) what catalog is
current. If the tower names a newer catalog than the one you hold, the door brings that ONE file
down into `tower/sharer.bundle`, verifies its seal against the df-index key in `bin/allowed_signers`,
and re-checks it locally before anything is trusted. It never blocks a forge: no relay, an
unreachable tower, or a stale/unverified index all leave the forge to run on what you already have.
This fetch is anonymous — you do not enrol, hold a key, or send anything of yours to fetch the
public catalog. (Enrolment — `palais.enrol` — is the next phase's keyed economy layer and is
refused honestly until the tower publishes a signing key.)

### Confirm the connect

The door records the outcome of that exchange — one row per attempt — in `state/tower-fetch.jsonl`,
relative to your `crucible-v0.4.0/` directory. Run any `forge`, then read the newest row:

```sh
tail -n1 state/tower-fetch.jsonl
#   {"fetch":"fetched", …}  reached the tower, pulled a newer catalog   -> connected
#   {"fetch":"current", …}  reached the tower, already current          -> connected
#   {"fetch":"reef_unreachable", …}  relay up but tower not reached      -> offline; forge ran anyway
```

A `fetched` or `current` row is the proof a fresh install connects out of the box. The `"fetch"`
word is written by the door's machine-checked freshness decider (`Tower_Index_Pkg`), not a hand-rolled
log line — so the row is evidence. No row at all means the `reef` rail was not declared or the attempt
was rate-limited (at most one an hour); start the relay via the launcher and forge again.

## Build from source (optional)

A stranger who wants to build their own — a different platform, or their own network — builds from
source. It is one tree; both editions build from it.

### 1. Prerequisites

- **Alire** (`alr`), 2.x: <https://alire.ada.dev>
- **git**
- **curl** (Linux): Alire downloads the toolchain with it. If curl is missing, `alr update` tries to install it with
  `sudo apt-get install curl`; that fails where there is no sudo or no apt (a container, a minimal image). Install curl
  first, e.g. `apt-get install curl ca-certificates` as root. (Measured 2026-09-28 in a Debian 12 build image.)
- Optional: **ollama**, for the model rail.

### 2. Fetch the pinned toolchain

On Linux, install **curl** first (see Prerequisites): `alr update` downloads the toolchain with it.

```sh
cd toolchain
alr update
alr exec -- gnatprove --version
alr exec -- which gnatprove gnat gprbuild   # keep these absolute paths
cd ..
```

The pins are exact: GNAT 15.1.2, gprbuild 26.0.1, gnatprove 15.1.0. These builds report themselves as
"GNAT 15.0.1 (prerelease)", "GPRBUILD 26.0.0" and "FSF 15.0". That's expected; the check is the path.
The tree needs GNAT 15 (a 13.x toolchain will not compile it).

### 3. Guard the version, then build

Run the version guard first — it fails the build if the source version, `alire.toml`, and the tag you
intend disagree (the regression that once shipped a binary reporting the wrong version):

```sh
scripts/check-version.sh v0.4.0     # prints OK; STOP on a mismatch
```

Run every build command through the pinned toolchain, so that no other `gprbuild`/`gnat` on your
`PATH` gets mixed in (a real failure, 2026-09-16):

```sh
TC="$(cd toolchain && alr exec -- sh -c 'echo $PATH')"
mkdir -p obj/harness obj/battery-verdict bin                     # gnatmake -D needs its object dir to exist
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/stamp_build_main.adb -o bin/stamp_build_main          # the build stamp tool (Ada)
bin/stamp_build_main || exit 1                                     # records the commit you are building; STOP if it refuses
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/stamp_tower_main.adb -o bin/stamp_tower_main          # the tower stamp tool (Ada)
bin/stamp_tower_main || exit 1                                     # pins tower/base.bundle by digest and version; STOP if it refuses
PATH="$TC" gprbuild -P crucible.gpr -p -XCRUCIBLE_EDITION=agpl     # -> bin/crucible-agpl, bin/pack_tower, bin/certify_tower, bin/stamp_signers
bin/stamp_signers || exit 1                                        # writes bin/allowed_signers from the keys pinned in src/tower_keys_pkg.ads; never hand-write it. It WARNS for every STAND-IN key -- read those lines.
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/prover_service_main.adb -o bin/prover_service_main    # -> bin/prover_service_main
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/vacuity_service_main.adb -o bin/vacuity_service_main  # -> bin/vacuity_service_main
PATH="$TC" gnatmake -gnat2022 -D obj/harness -aIsrc -aIsrc/generated -aIsrc/edition-agpl \
    harness/reef_relay_main.adb -o bin/reef_relay_main            # -> bin/reef_relay_main (the reef rail)
PATH="$TC" gprbuild -P battery/vacuity_battery.gpr -p              # -> bin/vacuity-battery (the vacuity battery, Ada)
for n in $(cat battery/LINKS); do ln -sfn vacuity-battery bin/$n; done   # the battery's 38 kit names, links beside it
PATH="$TC" gnatmake -gnat2022 -gnatU -D obj/battery-verdict \
    battery/verdict/vacuity_verdict_main.adb -o bin/vacuity_verdict_main   # -> bin/vacuity_verdict_main (the grade edge)
```

The vacuity battery is `bin/vacuity-battery`: one executable that answers to each name in
`battery/LINKS` (it dispatches on the name it was started under), so **the links must sit beside it** —
it runs its stages as child processes by those names. Its sources are in `battery/`, each stamped and
byte-identical below the stamp to the ada-factory round it came from (`battery/SOURCES.tsv` lists every
file's unstamped and stamped sha256 and its origin). It replaces the Go `check-cores-mcp`, whose `wire`
output it reproduces byte for byte (485 of 485 on the oracle corpus, 2026-09-28).

**★ It needs a SECOND binary beside it: `vacuity_verdict_main`.** The battery decides no grade itself —
every grade comes from the proven core `Vacuity_Verdict_Pkg` through its Ada edge, and the battery locates
that edge as a SIBLING of its own executable (`VACUITY_EDGE` overrides the path). If the edge is absent,
the battery refuses everything — `functions_read: 0`, `package_grade: refused` — and the door then reports
`vacuity: outcome_hollow` and emits nothing. **A missing edge looks exactly like a hollow contract, so this
failure is silent and easy to misread.** The build above puts it in `bin/` next to `vacuity-battery`
(from `battery/verdict/`, the admitted lineage 3 of `wu-vacuity-verdict-3/edge/`).

### 4. Configure and start

The shipped launcher writes `config/prover-service.conf` and `config/vacuity-service.conf` for you on
first start. Building by hand, you can instead copy the examples and set the absolute paths:

```sh
cp config/prover-service.conf.example config/prover-service.conf     # set gnatprove + staging_root
cp config/vacuity-service.conf.example config/vacuity-service.conf   # set battery + staging_root
```

`config/rail.conf` ships a `reef` line by default (pointing at the local relay) and works as shipped
if ollama is on `127.0.0.1:11434`, the prover service on `:8471`, the vacuity service on `:8472`, and
the reef relay on `:8473`. Then start everything with the launcher:

```sh
./crucible-launch.sh --check        # prover / vacuity / reef all up
claude mcp add crucible -- /absolute/path/to/crucible/crucible-launch.sh
```

### 5. Check it works

Ask the door to prove a unit that is correct, then one that isn't:

- `prove_unit` with a spec whose `Inc` has `Post => Inc'Result = X + 1` and a body `(X + 1)` should
  answer **`proved`**; the same spec with a body of `(X + 2)` should answer **`not_proved`**.

Then the whole pipeline, with all three rails running. Give `forge` a four-line sheet:

```text
delivers: the index of the first occurrence of a value in a list
type List: an array of up to 100 integers
function Find (L : List; V : Integer) return Natural
post: the result is zero exactly when no element of L equals V; otherwise L at the result equals V and no element before the result equals V
```

It should answer `"final":"done"` and write `out/find_pkg.ads`, `out/find_pkg.adb` and
`out/receipt.json`, with `gates_passed` listing intake, decompose, emit_contract, prove_spec,
vacuity, fill_body, prove_body, seam, provenance and admission. If `forge` answers
`"stopped_at":"tower"`, the door was started from the wrong directory — use the launcher.

## What does not work yet

- **Enrolment and the palais market** (`palais.enrol`, `palais.shelf`, and the rest) — the keyed
  economy layer. `palais.enrol` refuses `no_reef_key_pinned` until the tower publishes a signing
  key. Fetching the public catalog needs none of this.
- **The receipt** does not yet record the prover version, model name, or rail endpoints.
- **No one-step installer / `factory.doctor` tool** yet.
