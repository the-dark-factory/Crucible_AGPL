# Installing CRUCIBLE

## The short path (a published release)

v0.4.0 ships prebuilt, signed tarballs. You do not need a toolchain to run the door. You need one only
to build it yourself (see "Build from source" below). You do need gnatprove for the prover rail (see
"Install gnatprove" below).

**Linux first.** The Linux x86_64 tarball ships now. The macOS (Apple silicon) tarball follows once it
is Developer-ID signed and notarised. The macOS lines below apply once that tarball is on the release
page.

1. Download the tarball for your platform and the checksum file from the release page:
   - `crucible-v0.4.0-linux-x86_64.tar.gz` (Linux, x86_64)
   - `crucible-v0.4.0-macos-arm64.tar.gz` (macOS, Apple silicon; once it is on the release page)
   - `RELEASE_TARBALLS.sha256`

2. Check what you downloaded, then unpack:
   ```sh
   sha256sum -c --ignore-missing RELEASE_TARBALLS.sha256
   tar xzf crucible-v0.4.0-<platform>.tar.gz
   cd crucible-v0.4.0
   ```

3. Verify the signed file set INSIDE the tarball (this is the df-release signature). This needs
   `ssh-keygen`. A minimal Ubuntu does not have it; install it first, as root:
   `apt-get install openssh-client`. (Enrolment and the signed catalog fetch need it too.)
   ```sh
   sha256sum -c SHA256SUMS
   ssh-keygen -Y verify -f SHA256SUMS.allowed_signers -I tower@thedarkfactory.co.uk \
       -n df-release -s SHA256SUMS.sig < SHA256SUMS
   ```
   A good run prints `Good "df-release" signature for tower@thedarkfactory.co.uk`.

The tarball unpacks to `crucible-v0.4.0/` with this layout. Everything is relative to that
directory:
```
crucible-v0.4.0/
  crucible-launch.sh   the one-command launcher (starts the rails, serves the door, cleans up)
  bin/     crucible-agpl, prover_service_main, vacuity_service_main, reef_relay_main,
           vacuity-battery (+ its 38 kit-name links), vacuity_verdict_main, allowed_signers
  config/  rail.conf, tower.conf, reef-allowed-signers, reef-relay.conf
  tower/   base.bundle
  state/   (empty; the door writes its records here)
  SHA256SUMS, SHA256SUMS.sig, SHA256SUMS.allowed_signers
```

`tower/sharer.bundle` is not in the tarball. The door fetches it from the tower at run time, once
this install is enrolled (see "What connecting to the tower does").

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
| `bin/vacuity_service_main` | the vacuity rail: runs the `vacuity-battery` battery | us — in the tarball |
| `bin/vacuity-battery` (+ 38 links) | the vacuity battery the vacuity rail runs. One executable; the 38 links in `battery/LINKS` are its stage names and must sit beside it | us — in the tarball |
| `bin/vacuity_verdict_main` | the grade edge. The battery asks it for every grade and finds it beside itself. Without it every grade is refused | us — in the tarball |
| `bin/reef_relay_main` | the reef rail: carries one line to thereef.ink over TLS and brings one back, so the door can ask the tower what catalog is current, enrol, and fetch | us — in the tarball |
| `bin/allowed_signers` | the trust file beside the binary. Names the tower's signing keys (df-tower, df-admission, df-index). The df-index key is what verifies the tower's signed catalog index on fetch. | us — in the tarball |
| `config/rail.conf` | where each rail is: one JSON line per rail, including the `reef` line pointing at the local relay | us — a working default is in the tarball |
| `config/reef-relay.conf` | the relay's port, the tower URL (`https://thereef.ink/rail`), and its staging dir | us — a working default is in the tarball |
| `config/reef-allowed-signers` | the Reef's key. Enrolment checks the Reef's signed record against it, and the signed fetch names the network by it | us — in the tarball |
| gnatprove | behind the prover service, so it can prove locally | you — see "Install gnatprove". The launcher finds it. Without it the prover rail is off, and no `forge` can end in a proved unit |
| model endpoint | the model rail (ollama, or any OpenAI-shaped server) on `127.0.0.1` | you — any model; we ship none |
| `ssh-keygen` at `/usr/bin/ssh-keygen` | makes this install's key, signs each catalog fetch, and checks signatures | you — a minimal Ubuntu does not have it: `apt-get install openssh-client` |

Nothing listens off-host: every service binds `127.0.0.1`. The reef relay is the one component
that leaves the box, and only to `https://thereef.ink/rail`. It sends no unit of yours. What it does
send is listed under "What connecting to the tower does".

### Install gnatprove

You need gnatprove only, not a GNAT compiler. The route we tested installs it with Alire's `alr`.

**Linux x86_64** (tested on a clean Ubuntu 24.04; about 3 minutes):

```sh
# as root
apt-get install curl ca-certificates unzip git
# as yourself
curl -fsSL -o alr.zip https://github.com/alire-project/alire/releases/download/v2.1.0/alr-2.1.0-bin-x86_64-linux.zip
unzip alr.zip
```

Then run the `alr` program from the unpacked zip:

```sh
alr -n install gnatprove=15.1.0       # use the path to the unpacked alr
~/.alire/bin/gnatprove --version      # FSF 15.0
```

(Not yet tested as written: our rehearsal did not record which folder `unzip` puts `alr` in. Use
`unzip -l alr.zip` to see it.)

You do not need to add `~/.alire/bin` to your `PATH`. The launcher finds `~/.alire/bin/gnatprove` by
itself and names it on standard error (`prover: gnatprove chosen: …`).

**macOS (Apple silicon)** — applies once the macOS tarball is on the release page. The same route,
with the macOS zip from the same Alire release page
(<https://github.com/alire-project/alire/releases/tag/v2.1.0>), then `alr -n install gnatprove=15.1.0`.
(Not yet tested on macOS.)

The launcher looks for gnatprove in this order, and uses the first one that runs on this machine:
every `gnatprove` on your `PATH`, then `~/.local/share/alire/releases/gnatprove_*/bin/gnatprove`,
then `~/.alire/bin/gnatprove`. It names the one it chose on standard error.

## Start it

The model is named in `config/rail.conf`, on the line that says `"rail":"model"`. The shipped default
is `qwen3.8:27b` on ollama at `127.0.0.1:11434`. Pull it:

```sh
ollama pull qwen3.8:27b
```

The choice is yours. Name any model you have pulled on that line. What we know about the options:

| model | what we measured |
|---|---|
| `qwen3.8:27b` (default) | on the `Saturating_Add` sheet in "First forge": 1 run of 3 reached `done`, in a clean Ubuntu 24.04 container (ollama 0.33.2 ROCm, AMD R9700) |
| `qwen3-coder:30b` (the default before 0.4.0) | on the same sheet: 0 runs of 3 reached `done` (ollama 0.32.9, macOS). On our v0.3 parity sheets: 0 of 13 |
| `qwen3.6:27b` | not measured in 0.4.0 |
| any other model you run | not measured by us |

All of these are small samples.

Edit only the `"rail":"model"` line. The file has another line that names the same model: the first
line, `"rail":"ollama"`, is kept for an older runner and the door does not read it.

If the model is not there, the forge stops early and says so: `unmeasured` at `decompose`, with
ollama's own message (`model '…' not found`).

**ollama.** `qwen3.8:27b` needs ollama 0.32.12 or newer (the model's own requirement). We tested
ollama 0.33.2, the ROCm build (`ollama/ollama:0.33.2-rocm`), on an AMD Radeon R9700.

The door asks ollama for a 32,768-token context by default (the model line's `"num_ctx":"32768"`;
change it to any value from 2048 to 262144, or leave it out for 32768), so you do not need to set
`OLLAMA_CONTEXT_LENGTH`. A prompt too long for that context is refused by name (`prompt_exceeds_context`), never cut. Then connect your MCP host to the launcher. It starts the prover rail, the
vacuity rail, and the reef relay (which reaches the tower), serves the door on stdio, and stops the
rails when the door exits:

```sh
claude mcp add crucible -- /absolute/path/to/crucible-v0.4.0/crucible-launch.sh
```

That is the whole start. You do not start the rails by hand and you do not need a `cd` wrapper.
The launcher cds into the install directory for you. A quick self-check:

```sh
/absolute/path/to/crucible-v0.4.0/crucible-launch.sh --check
#   prover  8471 up
#   vacuity 8472 up
#   reef    8473 up
```

If gnatprove is not found, the line reads `prover  8471 DOWN` and the launcher says
"install a GNAT/SPARK toolchain". The reef relay and vacuity rail still come up. No `forge` can end in
a proved unit until the prover rail is up. **Read the lines, not the exit code:** `--check` exits 0
even when the prover is down (see "What does not work yet").

See `CONNECTING.md` for Claude Desktop and for the by-hand equivalent if you prefer not to use the
launcher.

## First forge

### 1. The prover, alone

This needs gnatprove and no model. Give `prove_unit` the unit name `Inc_Pkg`, this spec:

```ada
package Inc_Pkg with SPARK_Mode is
   function Inc (X : Integer) return Integer with Pre => X < Integer'Last, Post => Inc'Result = X + 1;
end Inc_Pkg;
```

and this body (a whole package body):

```ada
package body Inc_Pkg with SPARK_Mode is
   function Inc (X : Integer) return Integer is (X + 1);
end Inc_Pkg;
```

It answers `{"outcome":"proved"}`. Change `(X + 1)` to `(X + 2)` and it answers
`{"outcome":"not_proved"}`, flagged `"isError":true`. That is the correct answer. (Leave out the
`Pre` and both bodies are `not_proved`, because `X + 1` can overflow.)

### 2. The whole pipeline

Give `forge` this three-line sheet. The tarball ships no `examples/` directory, so here is the text;
it is `examples/saturating_add.sheet` in the source tree:

```text
delivers: Saturating_Add
function Saturating_Add (A, B : Integer) return Integer
post: saturates to Integer'Last on overflow and Integer'First on underflow, else equals A + B
```

**In Claude Code:** ask Claude to call the `crucible` server's `forge` tool with that text as its
`sheet` argument. (Not yet tested through Claude Code: our rehearsal drove the door with the raw form
below.)

**Without an MCP host:** the door reads JSON-RPC lines on standard input. Put these lines in
`reqs.jsonl`, each on one line:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"rail.show","arguments":{}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"intake_check","arguments":{"sheet":"delivers: Saturating_Add\nfunction Saturating_Add (A, B : Integer) return Integer\npost: saturates to Integer'Last on overflow and Integer'First on underflow, else equals A + B\n"}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"forge","arguments":{"sheet":"delivers: Saturating_Add\nfunction Saturating_Add (A, B : Integer) return Integer\npost: saturates to Integer'Last on overflow and Integer'First on underflow, else equals A + B\n"}}}
```

then run, from the install directory:

```sh
./crucible-launch.sh < reqs.jsonl > out.jsonl 2> err.txt
```

The launcher starts the rails, the door answers each line, and everything stops at the end of the
input. The `prove_unit` check above works the same way:

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"prove_unit","arguments":{"unit":"Inc_Pkg","spec":"package Inc_Pkg with SPARK_Mode is\n   function Inc (X : Integer) return Integer with Pre => X < Integer'Last, Post => Inc'Result = X + 1;\nend Inc_Pkg;\n","body":"package body Inc_Pkg with SPARK_Mode is\n   function Inc (X : Integer) return Integer is (X + 1);\nend Inc_Pkg;\n","level":"2"}}}
```

### What a forge answers

`intake_check` answers `{"verdict":"may_forge","operation_count":"1"}`. The `forge` reply is one of:

- **Done.**
  `{"final":"done","stopped_at":"emit","transitions":"11","emit_allowed":"true","reason":"emit: wrote saturating_add_pkg.ads, saturating_add_pkg.adb and receipt.json"}`.
  The unit and its receipt are in `out/`. All ten gates passed: intake, decompose, emit_contract,
  prove_spec, vacuity, fill_body, prove_body, seam, provenance, admission. Read the contract in
  `out/saturating_add_pkg.ads` yourself: "proved" means the body meets that contract.
- **Refused.** For example
  `{"final":"refused","stopped_at":"vacuity",…,"reason":"vacuity: outcome_hollow, faults: not_theorem"}`,
  flagged `"isError":true`. This is a real outcome, not a broken install: the model wrote a contract
  that the vacuity check would not accept, so nothing was emitted. Run the same forge again; a later
  run can reach `done`.

What we measured on a clean Ubuntu 24.04 container with the Linux tarball, ollama 0.33.2 (ROCm) on an
AMD R9700, and the shipped default model `qwen3.8:27b`: on this sheet, 1 run of 3 reached `done`; the
other two were refused at `vacuity`. Three runs is a small sample. Crucible finishes a minority of
runs (see `README.md`).

### If it stops

A reply names the stage it stopped at.
- `"stopped_at":"tower"`: the door was started from the wrong directory. Use the launcher.
- `unmeasured` at `decompose` with `model '…' not found`: the model named on the `"rail":"model"` line
  is not pulled.
- A refusal at `vacuity`, `emit_contract` (for example `no_progress`) or `fill_body`: the model did not
  get there this run. Try again.

## What connecting to the tower does

**The catalog needs an enrolment.** In 0.4.0 every catalog fetch is signed with this install's own
key, and the tower serves the catalog only to an approved enrolment. Until this install is enrolled,
the door fetches nothing. The forge still runs, on the catalog shipped in `tower/base.bundle`.

At the start of every `forge` (at most once an hour), the door asks thereef.ink (through the local
relay) what catalog is current. Anyone may ask this. If the tower names a newer catalog than the one
you hold, the door sends a signed request for that ONE file. If the tower serves it, the door writes
it to `tower/sharer.bundle`, verifies its seal against the df-index key in `bin/allowed_signers`, and
re-checks it locally before anything is trusted. It never blocks a forge: no relay, an unreachable
tower, a stale or unverified index, or a refused fetch all leave the forge to run on what you already
have.

What leaves the box:
- to ask what is current: a request for the index. Nothing of yours.
- to enrol: your public key's fingerprint, a factory id, a one-time number, and the codename you chose.
- to fetch: the catalog's name, the minute, the network id, your key's fingerprint and public key, and
  a signature made with your private key.

No unit of yours, no specification and no proof is sent. The private key never leaves the machine.

### Enrol

Enrolment is one tool, `palais.enrol`, called through your MCP host (for example, ask Claude to call
the `crucible` server's `palais.enrol` tool). Each call is one step. It never waits.

1. **Start.** Call `palais.enrol` with a codename: 1 to 32 letters, digits, `-` or `_`. For example
   `{"codename":"my-forge"}`. The first call makes this install's key pair in `~/.crucible/key/`, if
   there is none, and asks the Reef to enrol it. The answer is:
   ```
   {"enrol":"pending","user_code":"…","url":"https://thereef.ink/enrol/…"}
   ```
   Open the `url`. It tells you where you stand:
   - `…/enrol/welcome`: you are in. The Dark Factory admits members in waves, and while a wave is open
     and has room, approval is automatic.
   - `…/enrol/next-wave`: the current wave is full or closed. Your key is queued, in order. The Dark
     Factory opens the next wave. Nothing went wrong on your side.

   The reply carries a `user_code`. Keep it, and quote it if you contact us. While a wave has room,
   approval is automatic.

2. **Collect.** Call `palais.enrol` again, from the same install (the codename is not needed). Each
   call asks the Reef once:
   - `{"enrol":"pending",…}`: not approved yet. Call again later.
   - `{"enrol":"accepted","codename":"…","role":"sender","expires_at":"…"}`: done. The door keeps the
     Reef's signed record in `state/reef-key.json`.
   - `{"enrol":"already","fingerprint":"…"}`: this install is already enrolled.
   - `{"enrol":"refused","reason":"code_expired"}`: the code from step 1 ran out. This is expected
     while you wait in a queue. Call `palais.enrol` again. A queued key that enrols again keeps its place
     in the queue and is approved first when room opens (measured on our staging Reef, 2026-10-21).

3. **After `accepted`.** The next `forge` that is at least an hour after the last fetch row fetches
   the catalog. Check it as below.

Other refusals name their cause: `no_reef_rail` (no `reef` line in `config/rail.conf`),
`reef_unreachable`, `reef_refused`, `bad_codename`, `keygen_failed` (no working
`/usr/bin/ssh-keygen`), `malformed`.

The key lives in `~/.crucible/key/`. The enrolment record lives in this install's
`state/reef-key.json`. Keep both if you move or upgrade the install.
Renewal after `expires_at` is not available in 0.4.0.

### Confirm the connect

The door records the outcome of each exchange (one row per attempt) in `state/tower-fetch.jsonl`,
relative to your `crucible-v0.4.0/` directory. Run any `forge`, then read the newest row:

```sh
tail -n1 state/tower-fetch.jsonl
#   {"fetch":"fetched", …}           reached the tower, pulled a newer catalog       -> connected
#   {"fetch":"current", …}           reached the tower, already current              -> connected
#   {"fetch":"fetch_failed", …}      reached the tower, the catalog was not served   -> not enrolled yet (expected)
#   {"fetch":"reef_unreachable", …}  relay up but tower not reached                  -> offline; forge ran anyway
```

**On a fresh install, before enrolment, `fetch_failed` is the expected row.** The tower answered
the index and named a newer catalog; the door sent no fetch, because it has no enrolment to sign
with. The forge ran on the shipped catalog. (If the tower names nothing newer than what you hold, the
row reads `current`, enrolled or not.) Enrol, then forge again an hour or more later. Once enrolled, `fetch_failed` means
the tower did not serve the file; your forge still ran.

The `"fetch"` word is written by the door's machine-checked freshness decider (`Tower_Index_Pkg`), not
a hand-rolled log line, so the row is evidence. Other words you may see: `index_unreadable`,
`index_unverified`, `index_stale`.

**A second forge within the hour adds no row.** The door asks the tower at most once an hour. Inside
that hour it writes `tower_fetch: rate_limited` to standard error and no new row, so the newest row is
still the earlier one. That is expected. No row at all means the `reef` rail was not declared; start
the relay via the launcher and forge again.

## Build from source (optional)

A stranger who wants to build their own (a different platform, or their own network) builds from
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

Run the version guard first. It fails the build if the source version, `alire.toml`, and the tag you
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
`battery/LINKS` (it dispatches on the name it was started under), so **the links must sit beside it**.
It runs its stages as child processes by those names. Its sources are in `battery/`, each stamped and
byte-identical below the stamp to the ada-factory round it came from (`battery/SOURCES.tsv` lists every
file's unstamped and stamped sha256 and its origin). It replaces the Go `check-cores-mcp`, whose `wire`
output it reproduces byte for byte (485 of 485 on the oracle corpus, 2026-09-28).

**★ It needs a SECOND binary beside it: `vacuity_verdict_main`.** The battery decides no grade itself.
Every grade comes from the proven core `Vacuity_Verdict_Pkg` through its Ada edge, and the battery locates
that edge as a SIBLING of its own executable (`VACUITY_EDGE` overrides the path). If the edge is absent,
the battery refuses everything (`functions_read: 0`, `package_grade: refused`) and the door then reports
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

The relay's config is not written for you. In a source tree it is only an example; copy it and set
`staging_root` to an absolute directory. Without it the launcher does not start the relay (it says
`config/reef-relay.conf is missing`):

```sh
cp config/reef-relay.conf.example config/reef-relay.conf             # set staging_root
```

`config/rail.conf` ships a `reef` line by default (pointing at the local relay) and works as shipped
if ollama is on `127.0.0.1:11434`, the prover service on `:8471`, the vacuity service on `:8472`, and
the reef relay on `:8473`. Then start everything with the launcher:

```sh
./crucible-launch.sh --check        # prover / vacuity / reef all up
claude mcp add crucible -- /absolute/path/to/crucible/crucible-launch.sh
```

### 5. Check it works

Follow "First forge" above. Then, to reach the catalog, follow "Enrol" and "Confirm the connect".

## What does not work yet

- **The palais market** (`palais.shelf`, claims and the rest): the keyed economy layer. `palais.enrol`
  works (see "Enrol"); the market behind it is not running yet.
- **The receipt** does not yet record the prover version, model name, or rail endpoints.
- **No one-step installer / `factory.doctor` tool** yet.
- **`crucible-launch.sh --check` exits 0 even when the prover rail is `DOWN`.** It prints `DOWN` and
  says why, but a script that reads only the exit code would take it as success. Read the lines.
- **The tarball ships no example sheets.** The smoke sheet is printed in "First forge".
