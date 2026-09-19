# CRUCIBLE — the inference rail (`rail.conf`)

RULING (Tony, 2026-09-11 16:52): "leave Rosie in place at the moment, but include a method to
repoint the llm." `rail.conf` IS that method. Edit it and restart; no rebuild.

Format (2026-09-12 21:3x, first reader is the expand_brief runner): ONE JSON line, read with the
proved `Json_Scan_Pkg`, so no new parser exists for it:

    {"model":"<ollama model>","host":"<dotted address>","port":"<digits>","rail":"ollama","sovereign":true}

- `sovereign` true marks the rail as sovereign: the front's `Sovereign_Gate_Pkg` then refuses any
  host that is not on the estate (loopback / localhost). Set it false only for a rail that is
  allowed to leave the estate.
- ⛔ NOT an environment variable, and not an argument. `mui:edition-is-compiled-not-argued` forbids
  `Ada.Environment_Variables` and `Ada.Command_Line` anywhere in src/, so that the EDITION cannot
  be talked out of its licence refusal. The rail is a different kind of thing — model choice moves
  cost, sovereignty and yield, never CORRECTNESS, because the proof gate decides correctness.
- Found stale 2026-09-12 21:2x: the previous key=value file named port 11435 while ollama answers
  on 11434; nothing had read the file until the runner, so nothing had noticed.

## One line per rail (2026-09-19)

The door's rail readers (`Model_Rail_Call_Pkg`, `Prover_Rail_Call_Pkg`, `Vacuity_Rail_Call_Pkg`) scan EVERY line and
take the first one that `Rail_Config_Pkg.Is_Valid` accepts for their rail. `rail` must be `model`, `prover` or
`vacuity`; every value is a JSON STRING, including `sovereign` ("true" / "false") and the numbers; required keys are
`rail host port timeout_seconds max_reply_bytes sovereign`, and a model line also needs `model protocol max_tokens`
(`protocol` is `ollama` or `openai`).

    {"rail":"model","host":"127.0.0.1","port":"11434","timeout_seconds":"600","max_reply_bytes":"1048576","sovereign":"true","model":"qwen3.8-27b-ada:v0.3","protocol":"ollama","max_tokens":"8192"}
    {"rail":"prover","host":"127.0.0.1","port":"8471","timeout_seconds":"600","max_reply_bytes":"1048576","sovereign":"true"}

**Line 1 is kept for the legacy `harness/expand_brief_main` runner**, which reads ONLY the first line in the older
format above (`"rail":"ollama"`, bare `true`). The door's readers skip it: `ollama` is not a rail word. Until
2026-09-19 that legacy line was the ONLY line, so every door rail read "no valid line" (found by the release plan).

**No vacuity line yet**: the vacuity service's source is not in this repo and its port is not on the record; it is
added when the service is vendored into `harness/` (ruling 2026-09-19).
