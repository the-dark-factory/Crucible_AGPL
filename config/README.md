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
