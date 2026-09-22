# Connecting Crucible to Claude (MCP)

Crucible's door (`bin/crucible-agpl`) is an MCP server that speaks over stdio. This is how you attach it to
Claude Code or Claude Desktop. There is no one-click installer yet; this is the manual attach. For the full
build-from-source and rail setup, see [`INSTALL.md`](INSTALL.md).

## Prerequisites

Crucible needs three local rails. Nothing listens on the network — every service binds `127.0.0.1`.

- `bin/crucible-agpl` present (from a release tarball, or built per `INSTALL.md`).
- The two services running, **started from the install directory**:
  - `bin/prover_service_main` (the prover rail)
  - `bin/vacuity_service_main` (the vacuity rail)
- A model on `127.0.0.1`, named in `config/rail.conf`. For example:
  ```sh
  ollama pull qwen3-coder:30b
  ```
  Crucible ships no model and needs none of ours — any ollama- or OpenAI-shaped endpoint on localhost works.

## Claude Code

One command — replace the path with your install directory:

```sh
claude mcp add crucible -- sh -c 'cd /absolute/path/to/crucible && exec bin/crucible-agpl'
```

## Claude Desktop

Add this to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "crucible": {
      "command": "sh",
      "args": ["-c", "cd /absolute/path/to/crucible && exec bin/crucible-agpl"]
    }
  }
}
```

## Why the `cd`

The door finds `config/rail.conf` **and** `tower/base.bundle` **relative to the directory it is started in**.
Started anywhere else, every `forge` call is refused with `"stopped_at":"tower"` and `prove_unit` answers
`not_sent`. The `sh -c 'cd … && exec …'` wrapper starts it in the right place.

## Check it works

In Claude, the `crucible` server should list its tools (`intake_check`, `prove_unit`, `forge`, and the rest).
Ask it to `prove_unit` a small correct unit — a spec whose `Inc` has `Post => Inc'Result = X + 1` and a body
`(X + 1)` should answer **`proved`**; the same spec with a body of `(X + 2)` should answer **`not_proved`**.
If you get `not_sent`, the door was started from the wrong directory (see above) or `config/rail.conf` has no
valid `prover` line.
