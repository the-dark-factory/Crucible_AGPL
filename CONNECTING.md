# Connecting Crucible to Claude (MCP)

Crucible's door (`bin/crucible-agpl`) is an MCP server that speaks over stdio. This is how you attach
it to Claude Code or Claude Desktop. Since v0.2.1 the tarball ships a launcher that starts everything
the door needs, including the reef relay that reaches the tower, with one command.

## Prerequisites

Crucible's own rails listen on `127.0.0.1` only; nothing listens off-host. The reef relay's outbound
TLS to the tower leaves the box. So does the model call, but only if you point the model line at
another machine (below). From a release tarball you already have the binaries:

- Unpack `crucible-v0.4.1-<platform>.tar.gz` and `cd crucible-v0.4.1`. (Linux x86_64 ships first;
  the macOS arm64 tarball follows once it is signed and notarised.)
- A model, named on the `"rail":"model"` line of `config/rail.conf`. The shipped default is
  `qwen3.8:27b` on ollama at `127.0.0.1:11434`. It needs ollama 0.32.12 or newer
  (<https://ollama.com/download>). We tested ollama 0.33.2 (the ROCm build) on an AMD Radeon R9700.
  With ollama on this machine, check its version and pull the model:
  ```sh
  ollama --version
  ollama pull qwen3.8:27b
  ```
  Without the `ollama` command here (the server runs elsewhere, or outside your container), ask the
  server itself. The first line prints its version; the second lists its models, and `qwen3.8:27b`
  must be among them (pull it on the machine that runs the server):
  ```sh
  curl -s http://127.0.0.1:11434/api/version
  curl -s http://127.0.0.1:11434/api/tags
  ```
  The model line says `"sovereign":"true"`, which allows only this machine (loopback). If the server
  runs on another machine, the simplest way is to forward its port here, for example
  `ssh -N -L 11434:127.0.0.1:11434 you@model-host`, and change nothing. Otherwise put that machine's
  IPv4 address in `host` and set `"sovereign":"false"` on that line. The door then talks to it in
  plain, unencrypted HTTP, and what the door sends the model (built from your sheet) leaves the box.
  "If the model is on another machine", below, says what the door answers when this is not right.

  You may name `qwen3-coder:30b` or any other model instead; `INSTALL.md` ("Start it") lists what we
  measured for each. Crucible ships no model and needs none of ours. Any ollama- or OpenAI-shaped
  endpoint works. To use another model, edit the line that says `"rail":"model"` (not the first
  line, `"rail":"ollama"`, which the door does not read).
  The door asks ollama for a 32,768-token context by default (`"num_ctx":"32768"` on the model line;
  any value from 2048 to 262144), so you do not need to set `OLLAMA_CONTEXT_LENGTH`.
- gnatprove, for the prover rail. See "Install gnatprove" in `INSTALL.md`.
- `ssh-keygen` at `/usr/bin/ssh-keygen`. Enrolment makes your key with it and every catalog fetch is
  signed with it. A fresh Ubuntu does not have it: `apt-get update`, then
  `apt-get install -y openssh-client`.
- `nc` (netcat) is optional; the launcher uses it to notice a rail that is already up.

The launcher starts the prover rail, the vacuity rail, and the reef relay for you, and stops them
when the door exits. You do not start them by hand.

## Claude Code

One command. Point it at the launcher in your unpacked directory:

```sh
claude mcp add crucible -- /absolute/path/to/crucible-v0.4.1/crucible-launch.sh
```

## Claude Desktop

Add this to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "crucible": {
      "command": "/absolute/path/to/crucible-v0.4.1/crucible-launch.sh"
    }
  }
}
```

## Why a launcher (and not just the binary)

The door finds `config/rail.conf` **and** `tower/base.bundle` **relative to the directory it is
started in**. Started anywhere else, every `forge` call is refused with `"stopped_at":"tower"` and
`prove_unit` answers `not_sent`. The door also needs three rails running: the prover, the vacuity
battery, and the reef relay that carries a line to the tower. `crucible-launch.sh` does both: it cds
into the install directory and starts (then later stops) exactly the rails your `config/rail.conf`
declares and whose binaries are present. When it starts, it also writes `config/prover-service.conf`
and `config/vacuity-service.conf` if they are absent, filling in this machine's gnatprove path and the
shipped battery path. The launcher writes nothing outside the install directory.

If you would rather wire it by hand, the equivalent is:

```sh
cd /absolute/path/to/crucible-v0.4.1
bin/prover_service_main & bin/vacuity_service_main & bin/reef_relay_main &
exec bin/crucible-agpl
```

(started by hand, the prover and vacuity services need their `config/*-service.conf` present. The
tarball ships no `.example` files. Run `./crucible-launch.sh --check` once first: it writes both
files, with this machine's gnatprove path and the shipped battery, and then stops. It writes the
prover's file only if it finds a gnatprove.)

## Connecting to the tower — what leaves the box

With the reef relay running, the start of every `forge` (at most once an hour) asks your tower
(`https://thereef.ink/rail`) what catalogue is current. Anyone may ask that. If the tower names a
newer catalogue, the door asks for that one file with a request signed by this install's own key.
**The tower serves the catalogue only to an enrolled install.** Until you enrol, the door sends no
fetch, and the forge runs on the catalogue shipped in `tower/base.bundle`.

**No unit of yours goes to the tower**: not your specification, not the generated code, not the
proof. (A model on another machine is sent what the door asks it, which is built from your sheet. That
is your choice; see "Prerequisites".)
What does leave:
- to ask what is current: nothing of yours.
- to enrol (`palais.enrol`): your public key's fingerprint, a factory id, a one-time number, and the
  codename you chose.
- to fetch: the catalogue's name, the minute, the network id, your key's fingerprint and public key,
  and a signature. The private key stays in `~/.crucible/key/`.

The relay is the only component that opens an outbound connection, and only to the tower. The one
exception is a model line with `"sovereign":"false"` and another machine's address.

To forge fully offline, delete the `reef` line from `config/rail.conf` (or simply run the door
without the relay). Everything else works unchanged; the door forges on what you already have.

## Enrol

Call the `palais.enrol` tool through your MCP host, for example by asking Claude to call it on the
`crucible` server. Each call is one step and never waits.

1. First call, with a codename (1 to 32 letters, digits, `-` or `_`): `{"codename":"my-forge"}`.
   The answer is `{"enrol":"pending","user_code":"…","url":"…"}`. Open the `url`:
   - `https://thereef.ink/enrol/welcome`: you are in. The Dark Factory admits members in waves; while
     a wave is open and has room, approval is automatic.
   - `https://thereef.ink/enrol/next-wave`: the wave is full or closed. Your key is queued. The Dark
     Factory opens the next wave.
2. Call `palais.enrol` again (no codename needed) to collect. `pending` means not yet; call again
   later. `accepted` means done: the record is kept in `state/reef-key.json`. If it answers
   `{"enrol":"refused","reason":"code_expired"}`, the code ran out while you waited. Call once more to
   start again; your place is kept by your key.
3. Forge again an hour or more after the last attempt, then check the row below.

`INSTALL.md` ("Enrol") lists every answer.

## Check it works

Run the launcher's self-check. It starts the rails, reports which are up, and stops them:

```sh
/absolute/path/to/crucible-v0.4.1/crucible-launch.sh --check 2> check.txt; cat check.txt
```

It prints about a dozen lines on standard error (which gnatprove it chose, the rails it starts). The last
three are the ones to read:

```
  prover 8471 up
  vacuity 8472 up
  reef 8473 up
```

Read them from the captured file after the command has ended: on a terminal, the last line can appear after
the prompt returns. `INSTALL.md` ("Start it") shows the rest of the output.

Then, in Claude, the `crucible` server should list its tools (`intake_check`, `prove_unit`, `forge`,
and the rest). Ask it to `prove_unit` the small unit in `INSTALL.md` ("First forge"): `Inc` with
`Pre => X < Integer'Last` and `Post => Inc'Result = X + 1`, body `(X + 1)`, answers **`proved`**; a
body of `(X + 2)` answers **`not_proved`**. Without the `Pre`, both are `not_proved`. If you get
`not_sent`, the door was started from the wrong directory (use the launcher) or `config/rail.conf`
has no valid `prover` line.

`--check` exits 0 even when it prints `prover  8471 DOWN`. Read the lines, not the exit code.

For a first whole forge, and for driving the door without an MCP host, see "First forge" in
`INSTALL.md`.

## If the model is on another machine

The `rail.show` tool lists the model line with a `"route"` word. The `forge` reply names the model's
answer in its `"reason"`. Two pairs of words matter here:

- `rail.show` says `"route":"refused_sovereign_off_estate"`, and `forge` answers `"final":"unmeasured"`
  with `"reason":"model: model_not_sent"`. The model line names another machine but still says
  `"sovereign":"true"`. The door refused to send the request, so nothing left the box and nothing was
  judged. To fix it, set `"sovereign":"false"` on that line. Or forward the port with `ssh -L` and put
  `"host":"127.0.0.1"` back.
- `rail.show` says `"route":"off_estate"`, and `forge` answers `model: model_unreachable`. The door
  tried that host and port, and nothing answered. Check the address and port. The server must also
  listen on an address this machine can reach, not only on its own loopback.

`"route":"on_estate"` means the host is this machine (`127.0.0.1`).

The expansion runner in the source tree reads only the first line of `config/rail.conf`, the
`"rail":"ollama"` line. For a model on another machine, change that line too: the same IPv4 address in
`host`, and `"sovereign":false`. On that line `true` and `false` have no quotes. If you leave it
`true`, the runner answers `sovereign rail refuses off-estate endpoint`. With an `ssh -L` forward, leave
the line as it is. `INSTALL.md` ("The expansion runner") has the rest.

## Confirm it reached the tower

Every `forge` begins by asking the tower what catalogue is current (at most once an hour), and the
door records the outcome of that one exchange (one row per attempt) in `state/tower-fetch.jsonl`
(relative to your `crucible-v0.4.1/` directory). Run any `forge`, then read the newest row:

```sh
tail -n1 state/tower-fetch.jsonl
```

The `"fetch"` field is the door's own verdict on the exchange:

- `{"fetch":"fetched", …}`: it reached the tower and brought a newer catalogue file down. **Connected.**
- `{"fetch":"current", …}`: it reached the tower; you already hold the current catalogue. **Connected.**
- `{"fetch":"fetch_failed", …}`: it reached the tower, which named a newer catalogue, but the file
  was not served. **Before enrolment this is the expected row.** The forge still ran, on the
  shipped catalogue. Enrol (above), then forge again an hour or more later.
- `{"fetch":"reef_unreachable", …}`: the relay was up but the tower could not be reached (offline, or
  the tower is down). The forge still ran on what you already have.

A second forge within the hour adds no row: the door writes `tower_fetch: rate_limited` to standard
error instead, and the newest row is still the earlier one. That is expected.

A `fetched` or `current` row confirms the install reached the tower. The word is not ours to fudge:
it is written by the door's machine-checked freshness decider (`Tower_Index_Pkg`), so the row is
evidence, not a log line.
