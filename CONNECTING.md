# Connecting Crucible to Claude (MCP)

Crucible's door (`bin/crucible-agpl`) is an MCP server that speaks over stdio. This is how you attach
it to Claude Code or Claude Desktop. Since v0.2.1 the tarball ships a launcher that starts everything
the door needs — including the reef relay that reaches the tower — with one command.

## Prerequisites

Crucible needs its rails on `127.0.0.1`; nothing listens off-host except the reef relay's outbound
TLS to the tower. From a release tarball you already have the binaries:

- Unpack `crucible-v0.2.1-<platform>.tar.gz` and `cd crucible-v0.2.1`.
- Provide a model on `127.0.0.1`, named in `config/rail.conf`. For example:
  ```sh
  ollama pull qwen3-coder:30b
  ```
  Crucible ships no model and needs none of ours — any ollama- or OpenAI-shaped endpoint on
  localhost works.
- `nc` (netcat) is optional; the launcher uses it to notice a rail that is already up.

The launcher starts the prover rail, the vacuity rail, and the reef relay for you, and stops them
when the door exits. You do not start them by hand.

## Claude Code

One command — point it at the launcher in your unpacked directory:

```sh
claude mcp add crucible -- /absolute/path/to/crucible-v0.2.1/crucible-launch.sh
```

## Claude Desktop

Add this to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "crucible": {
      "command": "/absolute/path/to/crucible-v0.2.1/crucible-launch.sh"
    }
  }
}
```

## Why a launcher (and not just the binary)

The door finds `config/rail.conf` **and** `tower/base.bundle` **relative to the directory it is
started in**. Started anywhere else, every `forge` call is refused with `"stopped_at":"tower"` and
`prove_unit` answers `not_sent`. The door also needs three rails running — the prover, the vacuity
battery, and the reef relay that carries a line to the tower. `crucible-launch.sh` does both: it cds
into the install directory and starts (then later stops) exactly the rails your `config/rail.conf`
declares and whose binaries are present. When it starts, it also writes `config/prover-service.conf`
and `config/vacuity-service.conf` if they are absent, filling in this machine's gnatprove path and the
shipped battery path — nothing outside the install directory is written.

If you would rather wire it by hand, the equivalent is:

```sh
cd /absolute/path/to/crucible-v0.2.1
bin/prover_service_main & bin/vacuity_service_main & bin/reef_relay_main &
exec bin/crucible-agpl
```

(started by hand, the prover and vacuity services need their `config/*-service.conf` present — the
launcher writes those for you; by hand, copy the `.example` files and set the paths.)

## Connecting to the tower — what leaves the box

With the reef relay running, the start of every `forge` asks your tower
(`https://thereef.ink/rail`) what catalogue is current, and may bring down one public, signed
catalogue file. **No unit of yours leaves the box** — not your specification, not the generated code,
not the proof. The request is anonymous: you do not enrol or hold a key to read the public catalogue.
The relay is the only component that opens an outbound connection, and only to the tower.

To forge fully offline, delete the `reef` line from `config/rail.conf` (or simply run the door
without the relay). Everything else works unchanged; the door just records `reef_unreachable` and
forges on what you already have.

## Check it works

Run the launcher's self-check — it starts the rails, reports which are up, and stops them:

```sh
/absolute/path/to/crucible-v0.2.1/crucible-launch.sh --check
#   prover  8471 up
#   vacuity 8472 up
#   reef    8473 up
```

Then, in Claude, the `crucible` server should list its tools (`intake_check`, `prove_unit`, `forge`,
and the rest). Ask it to `prove_unit` a small correct unit — a spec whose `Inc` has
`Post => Inc'Result = X + 1` and a body `(X + 1)` should answer **`proved`**; the same spec with a
body of `(X + 2)` should answer **`not_proved`**. If you get `not_sent`, the door was started from
the wrong directory (use the launcher) or `config/rail.conf` has no valid `prover` line.

## Confirm it reached the tower

Every `forge` begins by asking the tower what catalogue is current, and the door records the outcome
of that one exchange — one row per attempt — in `state/tower-fetch.jsonl` (relative to your
`crucible-v0.2.1/` directory). Run any `forge`, then read the newest row:

```sh
tail -n1 state/tower-fetch.jsonl
```

The `"fetch"` field is the door's own verdict on the exchange:

- `{"fetch":"fetched", …}` — it reached the tower and brought a newer catalogue file down. **Connected.**
- `{"fetch":"current", …}` — it reached the tower; you already hold the current catalogue. **Connected.**
- `{"fetch":"reef_unreachable", …}` — the relay was up but the tower could not be reached (offline, or
  the tower is down). The forge still ran on what you already have.

A `fetched` or `current` row is the confirmation that a fresh install connects out of the box. The
word is not ours to fudge — it is written by the door's machine-checked freshness decider
(`Tower_Index_Pkg`), so the row is evidence, not a log line.
